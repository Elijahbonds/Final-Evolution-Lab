// Stripe server integration: checkout creation + webhook fulfillment.
// SECURITY MODEL: shards are credited ONLY here, only after signature-verified
// checkout.session.completed with payment_status === 'paid', idempotent per event.

import Stripe from 'stripe';
import { getPack } from '../shared/shardPacks';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY as string);
const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET as string;
const BASE_URL = process.env.APP_BASE_URL ?? 'https://finalevolution.abacusai.app';

// ── Integration seams (bind to the app's real services) ─────────────────────
export interface EconomyService {
  /** MUST be idempotent per ledgerRef (the Stripe event id). */
  creditShards(userId: string, amount: number, ledgerRef: string, note: string): Promise<void>;
  /** Claw back on refund; returns false if already spent (caller flags account). */
  tryDebitShards(userId: string, amount: number, ledgerRef: string): Promise<boolean>;
  flagForReview(userId: string, reason: string): Promise<void>;
}
export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
}
type Ctx = { economy: EconomyService; db: Db };

const C = { events: 'stripe_events', purchases: 'shard_purchases' };

// ── POST /api/store/checkout  { packId } → { url } ──────────────────────────
export async function createCheckout(
  ctx: Ctx, userId: string, body: { packId: string },
): Promise<{ url: string }> {
  const pack = getPack(body.packId);
  if (!pack) throw err(404, 'unknown pack');

  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    // Reconciliation: who + what, on the session AND the payment intent
    client_reference_id: userId,
    metadata: { userId, packId: pack.id, shards: String(pack.shards + pack.bonus) },
    line_items: [{
      quantity: 1,
      price_data: {
        currency: 'usd',
        unit_amount: pack.usdCents,
        product_data: {
          name: `${pack.name} — ${pack.shards + pack.bonus} Shards`,
          description: 'Final Evolution virtual currency (prepaid, non-refundable once spent, no cash value).',
        },
      },
    }],
    automatic_tax: { enabled: true },              // Stripe Tax (setup guide §5)
    allow_promotion_codes: true,
    success_url: `${BASE_URL}/shop/shards?paid=1&cs={CHECKOUT_SESSION_ID}`,
    cancel_url: `${BASE_URL}/shop/shards?canceled=1`,
  });

  if (!session.url) throw err(502, 'stripe did not return a checkout url');
  await ctx.db.put(C.purchases, session.id, {
    userId, packId: pack.id, state: 'created', createdAt: new Date().toISOString(),
  });
  return { url: session.url };
}

// ── POST /api/stripe/webhook  (RAW BODY — no JSON parsing middleware!) ──────
export async function handleWebhook(
  ctx: Ctx, rawBody: Buffer | string, signature: string,
): Promise<{ received: true }> {
  let event: Stripe.Event;
  try {
    event = stripe.webhooks.constructEvent(rawBody, signature, WEBHOOK_SECRET);
  } catch {
    throw err(400, 'invalid signature');
  }

  // Idempotency: one credit per event id, ever — duplicate deliveries no-op.
  const seen = await ctx.db.get(C.events, event.id);
  if (seen) return { received: true };
  await ctx.db.put(C.events, event.id, { type: event.type, at: new Date().toISOString() });

  switch (event.type) {
    case 'checkout.session.completed': {
      const s = event.data.object as Stripe.Checkout.Session;
      // Async payment methods can complete with payment still pending — only
      // fulfill when funds are actually captured.
      if (s.payment_status !== 'paid') break;
      const userId = s.client_reference_id ?? s.metadata?.userId;
      const shards = Number(s.metadata?.shards ?? 0);
      const packId = s.metadata?.packId ?? 'unknown';
      if (!userId || !Number.isFinite(shards) || shards <= 0) {
        console.error('[FEL-STRIPE] completed session missing metadata', s.id);
        break;
      }
      await ctx.economy.creditShards(userId, shards, event.id, `stripe:${packId}:${s.id}`);
      await ctx.db.put(C.purchases, s.id, {
        userId, packId, shards, state: 'fulfilled',
        amountTotal: s.amount_total, currency: s.currency,
        paymentIntent: s.payment_intent, eventId: event.id,
        fulfilledAt: new Date().toISOString(),
      });
      break;
    }
    case 'charge.refunded': {
      const charge = event.data.object as Stripe.Charge;
      const pi = typeof charge.payment_intent === 'string' ? charge.payment_intent : charge.payment_intent?.id;
      if (!pi) break;
      // Find the fulfilled purchase for this payment intent (indexed lookup in real db)
      const purchase = await ctx.db.get<{ userId: string; shards: number; state: string }>(C.purchases, `pi_${pi}`)
        ?? await findPurchaseByPI(ctx, pi);
      if (!purchase || purchase.state !== 'fulfilled') break;
      const clawed = await ctx.economy.tryDebitShards(purchase.userId, purchase.shards, `refund_${event.id}`);
      if (!clawed) {
        await ctx.economy.flagForReview(purchase.userId, `refund after spend: ${pi}`);
      }
      break;
    }
    default:
      break;   // ignore unhandled events (we only subscribed to two)
  }
  return { received: true };
}

// Seam: implement as an indexed query (purchases by paymentIntent) in the real db.
async function findPurchaseByPI(
  _ctx: Ctx, _pi: string,
): Promise<{ userId: string; shards: number; state: string } | null> {
  return null;
}

// ── GET /api/store/checkout-status?cs=... (success-page poll helper) ────────
export async function checkoutStatus(
  ctx: Ctx, userId: string, sessionId: string,
): Promise<{ fulfilled: boolean }> {
  const p = await ctx.db.get<{ userId: string; state: string }>(C.purchases, sessionId);
  return { fulfilled: !!p && p.userId === userId && p.state === 'fulfilled' };
}

function err(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status; return e;
}
