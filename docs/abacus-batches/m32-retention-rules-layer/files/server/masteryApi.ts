// Mastery tracks — per-mode cumulative points → tier sigils. Server-side only;
// call recordMastery() from the existing session-result handler.

import { tierFor, type MasteryTier, type ModeMastery } from '../shared/progressionContracts';

export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
  query<T>(c: string, where: Record<string, unknown>): Promise<T[]>;
}
export interface EconomyService {
  creditCoins(userId: string, amount: number, reason: string): Promise<void>;
}
type Ctx = { userId: string; db: Db; economy: EconomyService };

const C = { mastery: 'mode_mastery' };
const TIER_UP_COINS: Record<MasteryTier, number> = {
  none: 0, bronze: 100, silver: 250, gold: 600, platinum: 1500, legend: 4000,
};

/** Accrue a finished session's score into the mode's mastery track. */
export async function recordMastery(
  ctx: Ctx, modeId: string, sessionScore: number,
): Promise<{ mastery: ModeMastery; tierUp: MasteryTier | null }> {
  const id = `${ctx.userId}_${modeId}`;
  const prev = (await ctx.db.get<ModeMastery>(C.mastery, id))
    ?? { modeId, points: 0, tier: 'none' as MasteryTier };
  const points = prev.points + Math.max(0, Math.round(sessionScore));
  const tier = tierFor(points);
  const mastery: ModeMastery = { modeId, points, tier };
  await ctx.db.put(C.mastery, id, { userId: ctx.userId, ...mastery });

  let tierUp: MasteryTier | null = null;
  if (tier !== prev.tier) {
    tierUp = tier;
    await ctx.economy.creditCoins(ctx.userId, TIER_UP_COINS[tier], `mastery:${modeId}:${tier}`);
  }
  return { mastery, tierUp };       // tierUp drives the celebration banner
}

/** External bonuses (e.g. KOTC crown) — same accrual path, tagged reason. */
export async function grantMasteryBonus(
  ctx: Ctx, modeId: string, points: number,
): Promise<void> {
  await recordMastery(ctx, modeId, points);
}

// ── GET /api/mastery — sigils for hub avatar + mode cards ───────────────────
export async function getMastery(ctx: Ctx): Promise<ModeMastery[]> {
  const rows = await ctx.db.query<ModeMastery & { userId: string }>(C.mastery, { userId: ctx.userId });
  return rows.map(({ modeId, points, tier }) => ({ modeId, points, tier }));
}
