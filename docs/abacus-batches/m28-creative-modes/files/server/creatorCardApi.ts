// Creator Card server API — save/publish/remix with SERVER-enforced license
// gate, discipline validation, moderation queue, and remix royalties.

import {
  NEEDS_REVIEW, REMIX_ROYALTY_COINS, FREE_CARD_SLOTS,
  type CreatorCard, type Discipline,
} from '../creator/CreatorCardTypes';

export interface EconomyService {
  creditCoins(userId: string, amount: number, reason: string): Promise<void>;
  debitShards(userId: string, amount: number, reason: string): Promise<{ ledgerId: string }>;
}
export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
  query<T>(c: string, where: Record<string, unknown>): Promise<T[]>;
}
type Ctx = { userId: string; economy: EconomyService; db: Db };

const C = { cards: 'creator_cards', slots: 'card_slots' };
const EXTRA_SLOT_SHARDS = 200;

// ── POST /api/cards ─────────────────────────────────────────────────────────
export async function createCard(
  ctx: Ctx, input: Omit<CreatorCard, 'id' | 'ownerId' | 'createdAt' | 'reviewState'>,
): Promise<CreatorCard> {
  // License gate is SERVER-side — a tampered client cannot skip it.
  if (input.licenseAccepted !== true) throw err(422, 'license acceptance required');
  if (input.secondary.length > 2) throw err(422, 'max 2 secondary disciplines');
  if (input.secondary.includes(input.primary)) throw err(422, 'secondary duplicates primary');
  const needsSport = input.primary === 'sport' || input.secondary.includes('sport');
  if (needsSport && !input.sportDesignation) throw err(422, 'sport designation required');
  if (input.art.kind !== input.primary) throw err(422, 'art payload must match primary discipline');

  // Slot check: 3 free, extras purchased with shards
  const mine = await ctx.db.query<CreatorCard>(C.cards, { ownerId: ctx.userId });
  const slotDoc = await ctx.db.get<{ extra: number }>(C.slots, ctx.userId);
  const slots = FREE_CARD_SLOTS + (slotDoc?.extra ?? 0);
  if (mine.length >= slots) throw err(402, `card slots full (${slots}) — purchase another slot`);

  const card: CreatorCard = {
    ...input,
    id: `card_${ctx.userId}_${Date.now()}`,
    ownerId: ctx.userId,
    createdAt: new Date().toISOString(),
    // UGC audio disciplines queue for moderation before they can be public
    reviewState: NEEDS_REVIEW.includes(input.primary) ? 'pending_review' : 'approved',
    isPublic: NEEDS_REVIEW.includes(input.primary) ? false : input.isPublic,
  };
  await ctx.db.put(C.cards, card.id, card);

  // Publish faucet (coins) — only for approved public cards
  if (card.isPublic && card.reviewState === 'approved') {
    await ctx.economy.creditCoins(ctx.userId, 50, `publish:${card.id}`);
  }

  // Remix royalty: the social/retention loop — parent creator earns on remix
  if (card.remixOf) {
    const parent = await ctx.db.get<CreatorCard>(C.cards, card.remixOf);
    if (parent && parent.ownerId !== ctx.userId) {
      await ctx.economy.creditCoins(parent.ownerId, REMIX_ROYALTY_COINS, `remix_royalty:${card.id}`);
    }
  }
  return card;
}

// ── POST /api/cards/slots/buy ───────────────────────────────────────────────
export async function buyCardSlot(ctx: Ctx): Promise<{ slots: number }> {
  await ctx.economy.debitShards(ctx.userId, EXTRA_SLOT_SHARDS, 'card_slot');
  const doc = await ctx.db.get<{ extra: number }>(C.slots, ctx.userId);
  const extra = (doc?.extra ?? 0) + 1;
  await ctx.db.put(C.slots, ctx.userId, { userId: ctx.userId, extra });
  return { slots: FREE_CARD_SLOTS + extra };
}

// ── GET /api/cards/browse?discipline= ───────────────────────────────────────
export async function browse(ctx: Ctx, discipline?: Discipline): Promise<CreatorCard[]> {
  const where: Record<string, unknown> = { isPublic: true, reviewState: 'approved' };
  if (discipline) where.primary = discipline;
  return ctx.db.query<CreatorCard>(C.cards, where);
}

// ── Moderation (founder/mod role — role check done by the route layer) ──────
export async function reviewCard(
  ctx: Ctx, cardId: string, decision: 'approved' | 'rejected',
): Promise<{ ok: true }> {
  const card = await ctx.db.get<CreatorCard>(C.cards, cardId);
  if (!card) throw err(404, 'no card');
  await ctx.db.put(C.cards, cardId, {
    ...card,
    reviewState: decision,
    isPublic: decision === 'approved' ? true : false,
  });
  if (decision === 'approved') {
    await ctx.economy.creditCoins(card.ownerId, 50, `publish:${card.id}`);
  }
  return { ok: true };
}

function err(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status; return e;
}
