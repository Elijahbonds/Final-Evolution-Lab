// arenaStore — the Db implementation behind cashArenaApi + weekly contest
// seeding. Mongo when MONGO_URL is set (and MOCK_DB!=1), in-memory otherwise —
// so the smoke test and local dev run with zero infrastructure.

import type { Contest } from '../shared/arenaContracts';
import type { Db } from './cashArenaApi';

// ── In-memory Db (MOCK_DB=1 / no MONGO_URL) ────────────────────────────────
export class MemoryDb implements Db {
  private cols = new Map<string, Map<string, unknown>>();
  private col(c: string) {
    if (!this.cols.has(c)) this.cols.set(c, new Map());
    return this.cols.get(c)!;
  }
  async get<T>(c: string, id: string): Promise<T | null> {
    return (this.col(c).get(id) as T) ?? null;
  }
  async put<T>(c: string, id: string, doc: T): Promise<void> {
    this.col(c).set(id, structuredClone(doc));
  }
  async query<T>(c: string, where: Record<string, unknown>): Promise<T[]> {
    return [...this.col(c).values()].filter((d) =>
      Object.entries(where).every(([k, v]) => (d as Record<string, unknown>)[k] === v),
    ) as T[];
  }
}

// ── Mongo Db ───────────────────────────────────────────────────────────────
export class MongoDb implements Db {
  // `db` is a connected mongodb Db instance — reuse the app's existing client.
  constructor(private db: { collection(c: string): {
    findOne(f: Record<string, unknown>): Promise<unknown>;
    replaceOne(f: Record<string, unknown>, d: unknown, o: { upsert: boolean }): Promise<unknown>;
    find(f: Record<string, unknown>): { toArray(): Promise<unknown[]> };
  } }) {}
  private static PREFIX = 'fel_';
  async get<T>(c: string, id: string): Promise<T | null> {
    const doc = await this.db.collection(MongoDb.PREFIX + c).findOne({ _id: id });
    return (doc as T) ?? null;
  }
  async put<T>(c: string, id: string, doc: T): Promise<void> {
    await this.db.collection(MongoDb.PREFIX + c)
      .replaceOne({ _id: id }, { _id: id, ...doc }, { upsert: true });
  }
  async query<T>(c: string, where: Record<string, unknown>): Promise<T[]> {
    return (await this.db.collection(MongoDb.PREFIX + c).find(where).toArray()) as T[];
  }
}

let singleton: Db | null = null;
/** Wire your existing Mongo connection here; falls back to memory. */
export function getArenaDb(mongo?: ConstructorParameters<typeof MongoDb>[0]): Db {
  if (!singleton) {
    singleton = process.env.MOCK_DB !== '1' && mongo ? new MongoDb(mongo) : new MemoryDb();
  }
  return singleton;
}

// ── Weekly contest seeding (idempotent — ids are date-derived) ─────────────
function isoWeek(d: Date): string {
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  t.setUTCDate(t.getUTCDate() + 4 - (t.getUTCDay() || 7));
  const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  const week = Math.ceil((((+t - +yearStart) / 86400000) + 1) / 7);
  return `${t.getUTCFullYear()}w${String(week).padStart(2, '0')}`;
}
function nextFriday(d: Date, hourUtc: number): Date {
  const out = new Date(d);
  out.setUTCDate(out.getUTCDate() + ((5 - out.getUTCDay() + 7) % 7 || 7));
  out.setUTCHours(hourUtc, 0, 0, 0);
  return out;
}

/** Call from GET /contests (cheap upsert) — the schedule maintains itself. */
export async function ensureWeeklyContests(db: Db, now = new Date()): Promise<void> {
  const wk = isoWeek(now);
  const endOfDay = new Date(now); endOfDay.setUTCHours(23, 59, 0, 0);
  const friday = nextFriday(now, 25 - 24);               // Fri 01:00 UTC ≈ US evening
  const sunday = new Date(friday); sunday.setUTCDate(sunday.getUTCDate() + 2);

  const defs: Contest[] = [
    {
      id: `free_daily_${now.toISOString().slice(0, 10)}`,
      surface: 'ingame', title: 'Daily Open Run', entryUsdCents: 0,
      maxEntrants: 10_000, seed: '', opensAt: now.toISOString(),
      locksAt: endOfDay.toISOString(), state: 'open', entrantCount: 0, prizePoolUsdCents: 0,
    },
    {
      id: `cash_friday_${wk}`,
      surface: 'ingame', title: 'Friday Night Eastbay Open', entryUsdCents: 500,
      maxEntrants: 256, seed: '', opensAt: now.toISOString(),
      locksAt: friday.toISOString(), state: 'open', entrantCount: 0, prizePoolUsdCents: 0,
    },
    {
      id: `irl_free_${wk}`,
      surface: 'irl', title: 'IRL Proving Ground (Free)', entryUsdCents: 0,
      maxEntrants: 10_000, seed: '', opensAt: now.toISOString(),
      locksAt: sunday.toISOString(), state: 'open', entrantCount: 0, prizePoolUsdCents: 0,
    },
    {
      id: `irl_cash_${wk}`,
      surface: 'irl', title: 'IRL $1000 Vert Challenge', entryUsdCents: 1000,
      maxEntrants: 128, seed: '', opensAt: now.toISOString(),
      locksAt: sunday.toISOString(), state: 'open', entrantCount: 0, prizePoolUsdCents: 0,
    },
  ];
  for (const c of defs) {
    c.seed = c.id;                                       // deterministic conditions
    const existing = await db.get<Contest>('arena_contests', c.id);
    if (!existing) await db.put('arena_contests', c.id, c);
  }
}

// ── Ghost storage ──────────────────────────────────────────────────────────
export interface GhostDoc { id: string; contestId: string; userId: string; data: string; createdAt: string }

export async function saveGhost(db: Db, contestId: string, userId: string, data: string): Promise<string> {
  if (data.length > 200_000) throw Object.assign(new Error('ghost too large'), { status: 413 });
  const id = `g_${contestId}_${userId}`;
  await db.put<GhostDoc>('arena_ghosts', id, {
    id, contestId, userId, data, createdAt: new Date().toISOString(),
  });
  return id;
}

/** A rival ghost for the vs-screen: deterministic pick, never your own. */
export async function pickRivalGhost(db: Db, contestId: string, userId: string): Promise<GhostDoc | null> {
  const all = (await db.query<GhostDoc>('arena_ghosts', { contestId }))
    .filter((g) => g.userId !== userId)
    .sort((a, b) => a.id.localeCompare(b.id));
  if (!all.length) return null;
  let h = 0;
  for (const ch of userId) h = (h * 31 + ch.charCodeAt(0)) | 0;
  return all[Math.abs(h) % all.length];
}
