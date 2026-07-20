// stripeRails — the real-money plumbing: Checkout for entry fees, webhook →
// confirmEntry (idempotent by event id, auto-refund on failure), Connect
// Express payouts, Identity-backed age verification.
// ENV (Abacus secrets — NEVER hardcode): STRIPE_SECRET_KEY,
// STRIPE_WEBHOOK_SECRET, APP_URL.

import Stripe from 'stripe';
import type { Contest } from '../shared/arenaContracts';
import { confirmEntry, type Db, type IdentityService, type PayoutService } from './cashArenaApi';
import type { Simulator } from './cashArenaApi';

let stripe: Stripe | null = null;
export function getStripe(): Stripe {
  if (!stripe) {
    const key = process.env.STRIPE_SECRET_KEY;
    if (!key) throw new Error('STRIPE_SECRET_KEY not configured');
    stripe = new Stripe(key);
  }
  return stripe;
}

// ── Entry fee → Stripe Checkout ────────────────────────────────────────────
export async function createEntryCheckout(
  userId: string, contest: Contest,
): Promise<{ url: string }> {
  const appUrl = process.env.APP_URL ?? 'https://finalevolution.abacusai.app';
  const session = await getStripe().checkout.sessions.create({
    mode: 'payment',
    line_items: [{
      quantity: 1,
      price_data: {
        currency: 'usd',
        unit_amount: contest.entryUsdCents,
        product_data: { name: `Entry — ${contest.title}`, description: 'Skill contest entry fee' },
      },
    }],
    metadata: { kind: 'arena_entry', contestId: contest.id, userId },
    success_url: `${appUrl}/arena?entered=${contest.id}`,
    cancel_url: `${appUrl}/arena?cancelled=${contest.id}`,
  });
  if (!session.url) throw new Error('stripe returned no checkout url');
  return { url: session.url };
}

// ── Webhook (RAW body — see route file) ────────────────────────────────────
export async function handleStripeWebhook(
  rawBody: string, signature: string,
  deps: { db: Db; identity: IdentityService; payouts: PayoutService; sim: Simulator },
): Promise<{ received: true }> {
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!secret) throw new Error('STRIPE_WEBHOOK_SECRET not configured');
  const event = getStripe().webhooks.constructEvent(rawBody, signature, secret);

  // Idempotency ledger — an event id is processed exactly once, ever.
  if (await deps.db.get('stripe_events', event.id)) return { received: true };
  await deps.db.put('stripe_events', event.id, { id: event.id, type: event.type, at: new Date().toISOString() });

  if (event.type === 'checkout.session.completed') {
    const s = event.data.object as Stripe.Checkout.Session;
    if (s.metadata?.kind === 'arena_entry' && s.metadata.contestId && s.metadata.userId) {
      try {
        await confirmEntry(
          { userId: s.metadata.userId, db: deps.db, payouts: deps.payouts, identity: deps.identity, sim: deps.sim },
          s.metadata.contestId, event.id,
        );
      } catch (e) {
        // Contest filled/locked between checkout and webhook → refund in full.
        console.error(`[FEL-ARENA] entry confirm failed, refunding: ${(e as Error).message}`);
        if (typeof s.payment_intent === 'string') {
          await getStripe().refunds.create(
            { payment_intent: s.payment_intent },
            { idempotencyKey: `refund_${event.id}` },
          );
        }
      }
    }
  }

  if (event.type === 'identity.verification_session.verified') {
    const v = event.data.object as Stripe.Identity.VerificationSession;
    const userId = v.metadata?.userId;
    if (userId) {
      const rec = (await deps.db.get<IdentityRecord>('arena_identity', userId))
        ?? { userId, ageVerified: false, region: null };
      rec.ageVerified = true;
      await deps.db.put('arena_identity', userId, rec);
    }
  }

  return { received: true };
}

// ── IdentityService impl ───────────────────────────────────────────────────
export interface IdentityRecord { userId: string; ageVerified: boolean; region: string | null }

export class StripeIdentityService implements IdentityService {
  constructor(private db: Db) {}
  async isAgeVerified(userId: string): Promise<boolean> {
    return (await this.db.get<IdentityRecord>('arena_identity', userId))?.ageVerified ?? false;
  }
  async regionOf(userId: string): Promise<string | null> {
    return (await this.db.get<IdentityRecord>('arena_identity', userId))?.region ?? null;
  }
  /** Routes call this on every arena request with the CDN geo headers
   *  (x-vercel-ip-country / x-vercel-ip-country-region) — region stays fresh. */
  async recordRegion(userId: string, country: string | null, subdivision: string | null): Promise<void> {
    const rec = (await this.db.get<IdentityRecord>('arena_identity', userId))
      ?? { userId, ageVerified: false, region: null };
    rec.region = country ? (subdivision ? `${country}-${subdivision}` : country) : rec.region;
    await this.db.put('arena_identity', userId, rec);
  }
  /** 18+ gate → Stripe Identity hosted flow. */
  async startVerification(userId: string): Promise<{ url: string }> {
    const appUrl = process.env.APP_URL ?? 'https://finalevolution.abacusai.app';
    const session = await getStripe().identity.verificationSessions.create({
      type: 'document',
      metadata: { userId },
      return_url: `${appUrl}/arena?verified=1`,
    });
    return { url: session.url ?? appUrl };
  }
}

// ── PayoutService impl (Connect Express) ───────────────────────────────────
interface ConnectRecord { userId: string; accountId: string; payoutsEnabled: boolean }

export class StripeConnectPayouts implements PayoutService {
  constructor(private db: Db) {}

  private async record(userId: string): Promise<ConnectRecord | null> {
    return this.db.get<ConnectRecord>('connect_accounts', userId);
  }

  async hasPayoutAccount(userId: string): Promise<boolean> {
    const rec = await this.record(userId);
    if (!rec) return false;
    if (rec.payoutsEnabled) return true;
    const acct = await getStripe().accounts.retrieve(rec.accountId);   // re-check
    if (acct.payouts_enabled) {
      rec.payoutsEnabled = true;
      await this.db.put('connect_accounts', userId, rec);
    }
    return !!acct.payouts_enabled;
  }

  async onboardingLink(userId: string): Promise<string> {
    const appUrl = process.env.APP_URL ?? 'https://finalevolution.abacusai.app';
    let rec = await this.record(userId);
    if (!rec) {
      const acct = await getStripe().accounts.create({
        type: 'express', metadata: { userId },
        capabilities: { transfers: { requested: true } },
      });
      rec = { userId, accountId: acct.id, payoutsEnabled: false };
      await this.db.put('connect_accounts', userId, rec);
    }
    const link = await getStripe().accountLinks.create({
      account: rec.accountId, type: 'account_onboarding',
      refresh_url: `${appUrl}/arena/payouts`, return_url: `${appUrl}/arena/payouts?done=1`,
    });
    return link.url;
  }

  async transfer(userId: string, amountUsdCents: number, ref: string): Promise<{ transferId: string }> {
    const rec = await this.record(userId);
    if (!rec) throw new Error('no payout account');
    const t = await getStripe().transfers.create(
      { amount: amountUsdCents, currency: 'usd', destination: rec.accountId, metadata: { ref } },
      { idempotencyKey: `arena_${ref}_${userId}` },      // double-release safe
    );
    return { transferId: t.id };
  }
}
