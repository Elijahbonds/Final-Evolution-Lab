// Cash Arena server — contest lifecycle with compliance gates, server-side
// score verification, pooled payouts through the Stripe Connect seam.

import {
  GEO_RULES, LIMITS, PLATFORM_RAKE, PAYOUT_SPLIT, REVIEW_WINDOW_HOURS,
  type ArenaEntry, type ComplianceState, type Contest, type DunkRunTelemetry,
  type JudgeScorecard, type Payout,
} from '../shared/arenaContracts';
import { scoreRun, verifyRun, type CommentarySeam } from './aiJudges';

export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
  query<T>(c: string, where: Record<string, unknown>): Promise<T[]>;
}
export interface PayoutService {
  /** Stripe Connect transfer to the competitor's Express account. */
  transfer(userId: string, amountUsdCents: number, ref: string): Promise<{ transferId: string }>;
  hasPayoutAccount(userId: string): Promise<boolean>;
  onboardingLink(userId: string): Promise<string>;
}
export interface IdentityService {
  /** Stripe Identity (or equivalent) verification state. */
  isAgeVerified(userId: string): Promise<boolean>;
  regionOf(userId: string): Promise<string | null>;   // 'US-CA'
}
export interface Simulator {
  simulate(seed: string, inputStream: string): Promise<DunkRunTelemetry>;
}
type Ctx = {
  userId: string; db: Db; payouts: PayoutService;
  identity: IdentityService; sim: Simulator; commentary?: CommentarySeam;
};

const C = { contests: 'arena_contests', entries: 'arena_entries', payouts: 'arena_payouts', compliance: 'arena_compliance' };

// ── Compliance gate (every cash action passes through) ──────────────────────
async function gateCash(ctx: Ctx, entryUsdCents: number): Promise<void> {
  if (entryUsdCents === 0) return;                    // free contests: no gate
  const region = await ctx.identity.regionOf(ctx.userId);
  const country = region?.split('-')[0] ?? null;
  if (!country || !GEO_RULES.allowedCountries.includes(country)) throw err(451, 'cash contests unavailable in your region');
  if (region && GEO_RULES.blockedSubdivisions.includes(region)) throw err(451, 'cash contests unavailable in your region');
  if (!(await ctx.identity.isAgeVerified(ctx.userId))) throw err(403, 'age verification required (18+)');

  const comp = (await ctx.db.get<ComplianceState>(C.compliance, ctx.userId)) ?? {
    userId: ctx.userId, ageVerified: true, region, selfExcludedUntil: null,
    weeklyEntries: 0, weeklyDepositUsdCents: 0,
  };
  if (comp.selfExcludedUntil && +new Date(comp.selfExcludedUntil) > Date.now()) throw err(403, 'self-exclusion active');
  if (comp.weeklyEntries >= LIMITS.maxWeeklyCashEntries) throw err(429, 'weekly entry limit reached');
  if (comp.weeklyDepositUsdCents + entryUsdCents > LIMITS.maxWeeklyDepositUsdCents) throw err(429, 'weekly deposit limit reached');
  comp.weeklyEntries++; comp.weeklyDepositUsdCents += entryUsdCents;
  await ctx.db.put(C.compliance, ctx.userId, comp);
}

// ── POST /api/arena/:id/enter (fee flows through M25 Stripe Checkout; the
//    webhook calls confirmEntry with the event id — same idempotency ledger) ──
export async function confirmEntry(
  ctx: Ctx, contestId: string, paidLedgerRef: string | null,
): Promise<ArenaEntry> {
  const contest = await ctx.db.get<Contest>(C.contests, contestId);
  if (!contest || contest.state !== 'open') throw err(404, 'contest closed');
  if (+new Date(contest.locksAt) < Date.now()) throw err(410, 'entries locked');
  if (contest.entrantCount >= contest.maxEntrants) throw err(409, 'contest full');
  const existing = await ctx.db.get<ArenaEntry>(C.entries, `${contestId}_${ctx.userId}`);
  if (existing) throw err(409, 'already entered');
  await gateCash(ctx, contest.entryUsdCents);
  if (contest.entryUsdCents > 0 && !paidLedgerRef) throw err(402, 'entry fee required');

  const entry: ArenaEntry = {
    contestId, userId: ctx.userId, paidLedgerRef,
    ghostId: null, scorecard: null, verified: false,
    enteredAt: new Date().toISOString(),
  };
  await ctx.db.put(C.entries, `${contestId}_${ctx.userId}`, entry);
  contest.entrantCount++;
  contest.prizePoolUsdCents = Math.floor(contest.entrantCount * contest.entryUsdCents * (1 - PLATFORM_RAKE));
  await ctx.db.put(C.contests, contestId, contest);
  return entry;
}

// ── POST /api/arena/:id/submit — run in, verified + judged server-side ──────
export async function submitRun(
  ctx: Ctx, contestId: string, body: { telemetry: DunkRunTelemetry; ghostId: string },
): Promise<JudgeScorecard> {
  const contest = await ctx.db.get<Contest>(C.contests, contestId);
  const entry = await ctx.db.get<ArenaEntry>(C.entries, `${contestId}_${ctx.userId}`);
  if (!contest || !entry) throw err(404, 'no entry');
  if (entry.scorecard) throw err(409, 'run already submitted');
  if (body.telemetry.seed !== contest.seed) throw err(422, 'wrong contest seed');

  // ANTI-CHEAT: deterministic server replay must reproduce the claim
  const check = await verifyRun(body.telemetry, ctx.sim.simulate);
  if (!check.verified) {
    console.error(`[FEL-ARENA] verification FAILED user=${ctx.userId} contest=${contestId} ${check.delta}`);
    entry.verified = false;
    await ctx.db.put(C.entries, `${contestId}_${ctx.userId}`, entry);
    throw err(422, 'run failed verification');
  }

  const scorecard = await scoreRun(body.telemetry, {
    apexHeight: body.telemetry.apexHeight, hangTimeMs: body.telemetry.hangTimeMs,
  }, ctx.commentary);
  entry.ghostId = body.ghostId;
  entry.scorecard = scorecard;
  entry.verified = true;
  await ctx.db.put(C.entries, `${contestId}_${ctx.userId}`, entry);
  return scorecard;
}

// ── Settlement (cron/admin after locksAt): rank → payouts → review window ───
export async function settleContest(ctx: Ctx, contestId: string): Promise<Payout[]> {
  const contest = await ctx.db.get<Contest>(C.contests, contestId);
  if (!contest || !['open', 'judging'].includes(contest.state)) throw err(409, 'not settleable');
  const entries = (await ctx.db.query<ArenaEntry>(C.entries, { contestId }))
    .filter((e) => e.verified && e.scorecard)
    .sort((a, b) => b.scorecard!.grandTotal - a.scorecard!.grandTotal);

  const payouts: Payout[] = [];
  for (let i = 0; i < Math.min(PAYOUT_SPLIT.length, entries.length); i++) {
    payouts.push({
      contestId, userId: entries[i].userId, position: i + 1,
      amountUsdCents: Math.floor(contest.prizePoolUsdCents * PAYOUT_SPLIT[i]),
      state: 'pending_review',
    });
  }
  for (const p of payouts) await ctx.db.put(C.payouts, `${contestId}_${p.userId}`, p);
  contest.state = 'review';
  await ctx.db.put(C.contests, contestId, contest);
  return payouts;                    // release via releasePayouts after 24h window
}

export async function releasePayouts(ctx: Ctx, contestId: string): Promise<number> {
  const contest = await ctx.db.get<Contest>(C.contests, contestId);
  if (!contest || contest.state !== 'review') throw err(409, 'not in review');
  const ageMs = Date.now() - +new Date(contest.locksAt);
  if (ageMs < REVIEW_WINDOW_HOURS * 3600_000) throw err(425, 'review window still open');

  const payouts = await ctx.db.query<Payout>(C.payouts, { contestId });
  let released = 0;
  for (const p of payouts) {
    if (p.state !== 'pending_review') continue;
    if (!(await ctx.payouts.hasPayoutAccount(p.userId))) continue;   // UI prompts onboarding
    const { transferId } = await ctx.payouts.transfer(p.userId, p.amountUsdCents, `${contestId}:${p.position}`);
    p.state = 'paid'; p.connectTransferId = transferId;
    await ctx.db.put(C.payouts, `${contestId}_${p.userId}`, p);
    released++;
  }
  contest.state = 'paid';
  await ctx.db.put(C.contests, contestId, contest);
  return released;
}

function err(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status; return e;
}
