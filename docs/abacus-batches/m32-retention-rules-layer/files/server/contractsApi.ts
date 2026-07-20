// Daily contracts — deterministic date-seeded rotation (no cron), server-side
// progress from SessionResult stats, claim-once rewards.

import {
  CONTRACT_POOL, type ContractDef, type DailyContractState,
} from '../shared/progressionContracts';
import type { SessionResult } from '../core/sessionResult';

export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
}
export interface EconomyService {
  creditCoins(userId: string, amount: number, reason: string): Promise<void>;
  grantSeasonXp(userId: string, xp: number, reason: string): Promise<void>;
}
type Ctx = { userId: string; db: Db; economy: EconomyService };

const C = { progress: 'contract_progress' };
const PER_DAY = 3;

/** Same 3 contracts for everyone on a given UTC date — seeded, deploy-free. */
export function contractsForDate(dateIso = new Date().toISOString().slice(0, 10)): ContractDef[] {
  let seed = 0;
  for (const ch of dateIso) seed = (seed * 31 + ch.charCodeAt(0)) >>> 0;
  const picks: ContractDef[] = [];
  const pool = [...CONTRACT_POOL];
  for (let i = 0; i < PER_DAY && pool.length; i++) {
    seed = (seed * 1103515245 + 12345) >>> 0;
    picks.push(pool.splice(seed % pool.length, 1)[0]);
  }
  return picks;
}

const dayKey = (userId: string) => `${userId}_${new Date().toISOString().slice(0, 10)}`;

async function getState(ctx: Ctx): Promise<Record<string, DailyContractState>> {
  const doc = await ctx.db.get<{ states: Record<string, DailyContractState> }>(C.progress, dayKey(ctx.userId));
  if (doc) return doc.states;
  const states: Record<string, DailyContractState> = {};
  for (const c of contractsForDate()) {
    states[c.id] = { contractId: c.id, progress: 0, target: c.target, claimed: false };
  }
  return states;
}
const saveState = (ctx: Ctx, states: Record<string, DailyContractState>) =>
  ctx.db.put(C.progress, dayKey(ctx.userId), { userId: ctx.userId, states });

// ── Call from the session-result handler ────────────────────────────────────
export async function applySessionToContracts(ctx: Ctx, result: SessionResult): Promise<string[]> {
  const states = await getState(ctx);
  const completedNow: string[] = [];
  for (const def of contractsForDate()) {
    const s = states[def.id];
    if (!s || s.claimed || s.progress >= s.target) continue;
    if (def.modeId && def.modeId !== result.modeId) continue;
    const gain = def.statKey === '_sessions' ? 1 : Number(result.stats[def.statKey] ?? 0);
    if (gain <= 0) continue;
    const before = s.progress;
    s.progress = Math.min(s.target, s.progress + gain);
    if (before < s.target && s.progress >= s.target) completedNow.push(def.id);
  }
  await saveState(ctx, states);
  return completedNow;               // surface "CONTRACT COMPLETE" toasts
}

// ── GET /api/contracts ──────────────────────────────────────────────────────
export async function getContracts(ctx: Ctx): Promise<Array<ContractDef & DailyContractState>> {
  const states = await getState(ctx);
  return contractsForDate().map((def) => ({ ...def, ...states[def.id] }));
}

// ── POST /api/contracts/:id/claim — pays ONCE (replay → 409) ────────────────
export async function claimContract(ctx: Ctx, contractId: string): Promise<{ ok: true }> {
  const states = await getState(ctx);
  const def = contractsForDate().find((c) => c.id === contractId);
  const s = states[contractId];
  if (!def || !s) throw err(404, 'not one of today’s contracts');
  if (s.progress < s.target) throw err(422, 'contract not complete');
  if (s.claimed) throw err(409, 'already claimed');
  s.claimed = true;
  await saveState(ctx, states);
  await ctx.economy.creditCoins(ctx.userId, def.rewardCoins, `contract:${def.id}:${dayKey(ctx.userId)}`);
  await ctx.economy.grantSeasonXp(ctx.userId, def.rewardSeasonXp, `contract:${def.id}`);
  return { ok: true };
}

function err(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status; return e;
}

// NOTE for modes: contracts watch SessionResult.stats keys — dunk must report
// sigDunks, football evaded/yards, karate kos/wave, boards coinsCollected/combo,
// tennis hits. All already reported by the M27 modes except sigDunks: add
// `sigDunks` to DunkMode's end() stats (count of made SIG-style dunks).
