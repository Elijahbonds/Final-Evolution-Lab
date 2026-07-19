// Server API for the personalized-workout product. Framework-light handlers —
// mount into the app's router (Next API routes, Express, or the Abacus server layer).
// INTEGRATION: EconomyService = the server-authoritative wallet from the 10-phase
// pass (Phase 6). db = the app's persistence layer; collection names mirror the
// existing FastAPI backend (payments, prq_metrics, vertical_jump_log).

import { analyze } from '../shared/movementScreen';
import { buildAvatar } from '../shared/avatarBuilder';
import { retargetScan } from '../shared/clipRetargeter';
import { generatePlan } from '../shared/planGenerator';
import {
  SHARD_PRICES,
  type ScanSubmission, type ScanStatusResponse, type PurchaseReceipt,
  type WorkoutPlan, type ScanReplayClip, type ScreenResult, type MiniAvatarSpec,
} from '../shared/contracts';

// ── Integration seams (declared per Kimi-brief rules; bind to real services) ──
export interface EconomyService {
  /** Atomically debit shards; throws InsufficientFunds. Returns ledger entry id + balance. */
  debitShards(userId: string, amount: number, reason: string): Promise<{ ledgerId: string; balance: number }>;
  refund(ledgerId: string): Promise<void>;
}
export interface Db {
  get<T>(collection: string, id: string): Promise<T | null>;
  put<T>(collection: string, id: string, doc: T): Promise<void>;
  delete(collection: string, id: string): Promise<void>;
  query<T>(collection: string, where: Record<string, unknown>): Promise<T[]>;
}

type Ctx = { userId: string; economy: EconomyService; db: Db };

// Collections
const C = {
  entitlements: 'workout_entitlements',
  scans: 'movement_scans',            // keypoints + results (NO raw video)
  avatars: 'avatar_profiles',
  plans: 'workout_plans',
  replays: 'scan_replays',
  prq: 'prq_metrics',                 // existing — mirror system_scan.py
  vjump: 'vertical_jump_log',         // existing
};

// ── POST /api/workout/purchase ──────────────────────────────────────────────
export async function purchase(ctx: Ctx, body: { product: 'workout_4w' | 'program_12w' }): Promise<PurchaseReceipt> {
  const price = SHARD_PRICES[body.product];
  if (!price) throw httpError(400, 'unknown product');

  const existing = await ctx.db.get<{ product: string }>(C.entitlements, ctx.userId);
  if (existing?.product === body.product) throw httpError(409, 'already owned');

  const { ledgerId, balance } = await ctx.economy.debitShards(
    ctx.userId, price, `purchase:${body.product}`,
  );
  await ctx.db.put(C.entitlements, ctx.userId, {
    userId: ctx.userId, product: body.product, ledgerId,
    purchasedAt: new Date().toISOString(), consumedScanId: null,
  });
  return { ok: true, ledgerId, product: body.product, shardsSpent: price, balance };
}

// ── POST /api/workout/scan  (keypoints only — raw video never hits this path) ──
export async function submitScan(ctx: Ctx, sub: ScanSubmission): Promise<ScanStatusResponse> {
  const ent = await ctx.db.get<{ product: 'workout_4w' | 'program_12w'; ledgerId: string }>(
    C.entitlements, ctx.userId,
  );
  if (!ent) throw httpError(402, 'purchase required');

  // Guard rails: payload sanity before any processing
  if (!sub.frames?.length || sub.frames.length < 24) throw httpError(422, 'scan too short — need ≥1s of tracked movement');
  if (sub.frames.length > 24 * 120) throw httpError(422, 'scan too long — 2 minutes max');
  if (!(sub.athleteHeightCm >= 100 && sub.athleteHeightCm <= 230)) throw httpError(422, 'height out of range');

  await ctx.db.put(C.scans, sub.scanId, {
    userId: ctx.userId, status: 'analyzing',
    kind: sub.kind, activity: sub.activity, submittedAt: new Date().toISOString(),
  });

  try {
    // Pipeline is synchronous CPU work on a few hundred KB — run inline.
    const result: ScreenResult = analyze(sub);
    if (result.metrics.confidence < 0.45) {
      await ctx.db.put(C.scans, sub.scanId, { userId: ctx.userId, status: 'failed', error: 'low tracking confidence — refilm with full body in frame' });
      return { scanId: sub.scanId, status: 'failed', error: 'low tracking confidence' };
    }

    const avatar: MiniAvatarSpec = buildAvatar(sub.frames, {
      athleteHeightCm: sub.athleteHeightCm, scanId: sub.scanId,
    });
    const replay: ScanReplayClip = retargetScan(sub.scanId, sub.frames);
    const plan: WorkoutPlan = generatePlan(result, avatar, ent.product);

    await ctx.db.put(C.avatars, ctx.userId, avatar);
    await ctx.db.put(C.replays, sub.scanId, replay);
    await ctx.db.put(C.plans, ctx.userId, plan);
    await ctx.db.put(C.scans, sub.scanId, {
      userId: ctx.userId, status: 'ready', result, completedAt: new Date().toISOString(),
    });
    await ctx.db.put(C.entitlements, ctx.userId, { ...ent, userId: ctx.userId, consumedScanId: sub.scanId });

    // Feed the existing System Scan pillars (mirrors backend/routers/system_scan.py)
    await syncSystemScan(ctx, result);

    return { scanId: sub.scanId, status: 'ready' };
  } catch (e) {
    await ctx.db.put(C.scans, sub.scanId, { userId: ctx.userId, status: 'failed', error: String(e) });
    throw e;
  }
}

async function syncSystemScan(ctx: Ctx, result: ScreenResult): Promise<void> {
  const m = result.metrics;
  const prev = (await ctx.db.get<Record<string, number>>(C.prq, ctx.userId)) ?? {};
  // Map screen outcomes onto the 8-axis PRQ metric block (0–100 scale, best-known)
  const axis = (val: number | null, lo: number, hi: number, invert = false) => {
    if (val === null) return undefined;
    let p = (val - lo) / (hi - lo);
    if (invert) p = 1 - p;
    return Math.round(Math.min(1, Math.max(0, p)) * 100);
  };
  await ctx.db.put(C.prq, ctx.userId, {
    ...prev,
    power: axis(m.jumpHeightCm, 20, 80) ?? prev.power ?? 0,
    flexibility: axis(m.squatDepthDeg, 140, 70, false) ?? prev.flexibility ?? 0,
    agility: axis(m.asymmetryPct, 60, 0) ?? prev.agility ?? 0,
    speed: axis(m.cadenceSpm, 140, 190) ?? prev.speed ?? 0,
  });
  if (m.jumpHeightCm !== null) {
    await ctx.db.put(C.vjump, `${ctx.userId}_${Date.now()}`, {
      user_id: ctx.userId, height_cm: m.jumpHeightCm,
      source: 'video_scan', recorded_at: new Date().toISOString(),
    });
  }
}

// ── GET /api/workout/scan/:id/status ────────────────────────────────────────
export async function scanStatus(ctx: Ctx, scanId: string): Promise<ScanStatusResponse> {
  const doc = await ctx.db.get<{ userId: string; status: ScanStatusResponse['status']; error?: string }>(C.scans, scanId);
  if (!doc || doc.userId !== ctx.userId) throw httpError(404, 'scan not found');
  return { scanId, status: doc.status, error: doc.error };
}

// ── GET /api/workout/plan ───────────────────────────────────────────────────
export async function getPlan(ctx: Ctx): Promise<{ plan: WorkoutPlan; replay: ScanReplayClip | null }> {
  const plan = await ctx.db.get<WorkoutPlan>(C.plans, ctx.userId);
  if (!plan) throw httpError(404, 'no plan — purchase and scan first');
  const replay = await ctx.db.get<ScanReplayClip>(C.replays, plan.basedOn.scanId);
  return { plan, replay };
}

// ── DELETE /api/workout/scan-data  (privacy: delete-my-scan) ────────────────
export async function deleteScanData(ctx: Ctx): Promise<{ ok: true }> {
  const scans = await ctx.db.query<{ _id?: string; scanId?: string }>(C.scans, { userId: ctx.userId });
  for (const s of scans) {
    const id = (s as any).scanId ?? (s as any)._id;
    if (id) { await ctx.db.delete(C.scans, id); await ctx.db.delete(C.replays, id); }
  }
  await ctx.db.delete(C.avatars, ctx.userId);
  await ctx.db.delete(C.plans, ctx.userId);
  // Entitlement survives — they paid; they can rescan.
  return { ok: true };
}

function httpError(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status;
  return e;
}
