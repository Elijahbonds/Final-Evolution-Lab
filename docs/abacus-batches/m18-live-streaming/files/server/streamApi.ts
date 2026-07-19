// FEL LIVE server API. Same integration seams as workoutApi (EconomyService, Db).

import {
  CLASS_PASSES,
  type GuideResponse, type StreamMeta, type AdCreative, type AdSlotId,
  type TipRequest, type WatchHeartbeat, type WatchGrant,
} from '../shared/streamContracts';
import { CHANNELS, WEEKLY_TEMPLATE, HOUSE_ADS, DEFAULT_SPOTLIGHTS } from '../shared/programGuide';

export interface EconomyService {
  debitShards(userId: string, amount: number, reason: string): Promise<{ ledgerId: string; balance: number }>;
  grantSeasonXp(userId: string, xp: number, reason: string): Promise<void>;
}
export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
  query<T>(c: string, where: Record<string, unknown>): Promise<T[]>;
  incr(c: string, id: string, field: string, by: number): Promise<number>;
}
type Ctx = { userId: string; economy: EconomyService; db: Db };

const C = {
  streams: 'live_streams',          // materialized instances (admin/scheduler writes)
  ads: 'ad_creatives',
  impressions: 'ad_impressions',
  passes: 'class_passes',
  tips: 'stream_tips',
  watch: 'watch_sessions',
};

const WATCH_XP_PER_TICK = 5;        // per 60s heartbeat
const WATCH_XP_DAILY_CAP = 60;

// ── Guide ───────────────────────────────────────────────────────────────────
export async function getGuide(ctx: Ctx): Promise<GuideResponse> {
  const all = await ctx.db.query<StreamMeta>(C.streams, {});
  const now = Date.now();
  const in48h = now + 48 * 3600_000;
  const soonest = (a: StreamMeta, b: StreamMeta) => +new Date(a.startsAt) - +new Date(b.startsAt);

  const materialized = all.length ? all : materializeWeek(); // seed fallback pre-admin

  return {
    liveNow: materialized.filter((s) => s.state === 'live'),
    upNext: materialized
      .filter((s) => s.state === 'scheduled' && +new Date(s.startsAt) < in48h)
      .sort(soonest),
    replays: materialized.filter((s) => s.state === 'replay').slice(0, 12),
    channels: CHANNELS,
    spotlights: DEFAULT_SPOTLIGHTS,
    banner: await pickAd(ctx, 'banner_live_tab'),
  };
}

/** Stamp the weekly template onto this week's dates (server-local tz; refine later). */
function materializeWeek(): StreamMeta[] {
  const monday = new Date();
  monday.setDate(monday.getDate() - ((monday.getDay() + 6) % 7));
  return WEEKLY_TEMPLATE.map((t, i) => {
    const d = new Date(monday);
    d.setDate(d.getDate() + t.day);
    const [h, m] = t.timeLocal.split(':').map(Number);
    d.setHours(h, m, 0, 0);
    const { day, timeLocal, ...rest } = t;
    return {
      ...rest,
      id: `wk_${i}_${d.toISOString().slice(0, 10)}`,
      startsAt: d.toISOString(),
      state: +d < Date.now() ? 'ended' : 'scheduled',
    };
  });
}

// ── Ads ─────────────────────────────────────────────────────────────────────
export async function pickAd(ctx: Ctx, slot: AdSlotId): Promise<AdCreative | null> {
  const sold = (await ctx.db.query<AdCreative>(C.ads, { slot, active: true, kind: 'sold' }));
  const pool = sold.length ? sold : HOUSE_ADS.filter((a) => a.slot === slot && a.active);
  if (!pool.length) return null;
  const total = pool.reduce((s, a) => s + a.weight, 0);
  let r = Math.random() * total;
  const pick = pool.find((a) => (r -= a.weight) <= 0) ?? pool[0];
  await ctx.db.put(C.impressions, `${pick.id}_${ctx.userId}_${Date.now()}`, {
    creativeId: pick.id, slot, at: new Date().toISOString(), userId: ctx.userId,
  });
  return pick;
}

export async function adClick(ctx: Ctx, creativeId: string): Promise<{ ok: true }> {
  await ctx.db.incr(C.ads, creativeId, 'clicks', 1);
  return { ok: true };
}

// ── Class passes ────────────────────────────────────────────────────────────
export async function buyClassPass(
  ctx: Ctx, body: { productId: 'class_single' | 'class_monthly'; streamId?: string },
): Promise<{ ok: true; ledgerId: string }> {
  const product = CLASS_PASSES.find((p) => p.id === body.productId);
  if (!product) throw err(400, 'unknown pass');
  if (product.scope === 'one_stream' && !body.streamId) throw err(400, 'streamId required');
  const { ledgerId } = await ctx.economy.debitShards(ctx.userId, product.shards, `pass:${product.id}`);
  await ctx.db.put(C.passes, `${ctx.userId}_${ledgerId}`, {
    userId: ctx.userId, product: product.id, streamId: body.streamId ?? null,
    expiresAt: product.scope === 'all_access_30d'
      ? new Date(Date.now() + 30 * 86400_000).toISOString() : null,
    ledgerId, at: new Date().toISOString(),
  });
  return { ok: true, ledgerId };
}

export async function canWatch(ctx: Ctx, stream: StreamMeta): Promise<boolean> {
  if (stream.access === 'free') return true;
  const passes = await ctx.db.query<{ product: string; streamId: string | null; expiresAt: string | null }>(
    C.passes, { userId: ctx.userId },
  );
  return passes.some((p) =>
    (p.product === 'class_monthly' && p.expiresAt && +new Date(p.expiresAt) > Date.now()) ||
    (p.product === 'class_single' && p.streamId === stream.id),
  );
}

// ── Tips ────────────────────────────────────────────────────────────────────
export async function tip(ctx: Ctx, body: TipRequest): Promise<{ ok: true; shoutout: string }> {
  if (![25, 50, 100, 500].includes(body.shards)) throw err(400, 'invalid tip amount');
  await ctx.economy.debitShards(ctx.userId, body.shards, `tip:${body.streamId}`);
  await ctx.db.put(C.tips, `${body.streamId}_${ctx.userId}_${Date.now()}`, {
    userId: ctx.userId, streamId: body.streamId, shards: body.shards, at: new Date().toISOString(),
  });
  return { ok: true, shoutout: `sent ${body.shards} ◆` };
}

// ── Watch XP drip (anti-idle) ───────────────────────────────────────────────
export async function watchHeartbeat(ctx: Ctx, hb: WatchHeartbeat): Promise<WatchGrant> {
  if (!hb.interacted) return { seasonXp: 0, capped: false };      // idle: no XP
  const dayKey = `${ctx.userId}_${new Date().toISOString().slice(0, 10)}`;
  const total = await ctx.db.incr(C.watch, dayKey, 'xp', WATCH_XP_PER_TICK);
  if (total > WATCH_XP_DAILY_CAP) return { seasonXp: 0, capped: true };
  await ctx.economy.grantSeasonXp(ctx.userId, WATCH_XP_PER_TICK, `watch:${hb.streamId}`);
  return { seasonXp: WATCH_XP_PER_TICK, capped: false };
}

function err(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status; return e;
}
