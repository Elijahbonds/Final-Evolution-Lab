// M21 server API: schedule materialization (Wed/Fri 5:30), purchases, join gating,
// private-booking lifecycle, founder admin. Seams as in prior packages.

import {
  SESSION_CONFIG,
  type LiveSession, type SessionsResponse, type JoinResponse,
  type PrivateBooking, type SessionTicket,
} from '../shared/sessionContracts';

export interface EconomyService {
  debitShards(userId: string, amount: number, reason: string): Promise<{ ledgerId: string; balance: number }>;
  refund(ledgerId: string): Promise<void>;
}
export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
  query<T>(c: string, where: Record<string, unknown>): Promise<T[]>;
}
export interface StreamService {
  /** Creates/returns the private stream room; issues per-user expiring join tokens. */
  ensureRoom(sessionId: string, title: string): Promise<{ streamId: string }>;
  issueJoinToken(streamId: string, userId: string): Promise<JoinResponse>;
  isLive(streamId: string): Promise<boolean>;
}
export interface UserService {
  isFounder(userId: string): Promise<boolean>;
  ageOf(userId: string): Promise<number | null>;
  hasActiveMonthlyPass(userId: string): Promise<boolean>;   // M18 class_monthly
}

type Ctx = { userId: string; economy: EconomyService; db: Db; streams: StreamService; users: UserService };

const C = { sessions: 'live_sessions_v2', tickets: 'session_tickets', bookings: 'private_bookings' };
const DAY_MS = 86400_000;

// ── Schedule: materialize the standing Wed/Fri 17:30 group workouts ─────────
function upcomingGroupSlots(days = 14): { id: string; startsAt: Date }[] {
  const out: { id: string; startsAt: Date }[] = [];
  const now = new Date();
  for (let d = 0; d < days; d++) {
    const date = new Date(now.getTime() + d * DAY_MS);
    for (const slot of SESSION_CONFIG.groupWorkout.slots) {
      if (date.getDay() !== slot.day) continue;
      const [h, m] = slot.time.split(':').map(Number);
      const start = new Date(date); start.setHours(h, m, 0, 0);
      if (+start < Date.now()) continue;
      out.push({ id: `gw_${start.toISOString().slice(0, 10)}`, startsAt: start });
    }
  }
  return out;
}

async function materialize(ctx: Ctx): Promise<LiveSession[]> {
  const existing = await ctx.db.query<LiveSession>(C.sessions, {});
  const byId = new Map(existing.map((s) => [s.id, s]));
  for (const slot of upcomingGroupSlots()) {
    if (byId.has(slot.id)) continue;
    const s: LiveSession = {
      id: slot.id, type: 'group_workout',
      title: 'Group Workout — Live with Elijah Bonds',
      startsAt: slot.startsAt.toISOString(),
      durationMin: SESSION_CONFIG.groupWorkout.durationMin,
      capacity: SESSION_CONFIG.groupWorkout.capacity,
      priceShards: SESSION_CONFIG.groupWorkout.priceShards,
      state: 'scheduled', attendeeCount: 0,
    };
    await ctx.db.put(C.sessions, s.id, s);
    byId.set(s.id, s);
  }
  return [...byId.values()].filter((s) => s.state !== 'cancelled');
}

// ── GET /api/sessions ───────────────────────────────────────────────────────
export async function getSessions(ctx: Ctx): Promise<SessionsResponse> {
  const all = await materialize(ctx);
  const horizon = Date.now() + SESSION_CONFIG.private1on1.fallbackWindowDays * DAY_MS;
  const upcoming = all
    .filter((s) => s.type !== 'private_1on1' && +new Date(s.startsAt) < horizon && s.state !== 'ended')
    .sort((a, b) => +new Date(a.startsAt) - +new Date(b.startsAt));

  const seminarScheduled = upcoming.some((s) => s.type === 'private_seminar');
  const tickets = await ctx.db.query<SessionTicket>(C.tickets, { userId: ctx.userId });
  const myBookings = await ctx.db.query<PrivateBooking>(C.bookings, { userId: ctx.userId });

  return {
    upcoming,
    mine: tickets.map((t) => ({ sessionId: t.sessionId })),
    seminarScheduled,
    bookingSlots: seminarScheduled ? [] : bookableSlots(myBookings),
    myBookings,
    config: {
      timezone: SESSION_CONFIG.timezone,
      groupPrice: SESSION_CONFIG.groupWorkout.priceShards,
      seminarPrice: SESSION_CONFIG.seminar.defaultPriceShards,
      privatePrice: SESSION_CONFIG.private1on1.priceShards,
    },
  };
}

function bookableSlots(existing: PrivateBooking[]): string[] {
  const taken = new Set(existing.filter((b) => ['requested', 'confirmed'].includes(b.state)).map((b) => b.slotIso));
  const out: string[] = [];
  for (let d = 1; d <= SESSION_CONFIG.private1on1.fallbackWindowDays; d++) {
    const date = new Date(Date.now() + d * DAY_MS);
    for (const a of SESSION_CONFIG.private1on1.availability) {
      if (date.getDay() !== a.day) continue;
      const [fh] = a.from.split(':').map(Number);
      const [th] = a.to.split(':').map(Number);
      for (let h = fh; h < th; h++) {
        const slot = new Date(date); slot.setHours(h, 0, 0, 0);
        const iso = slot.toISOString();
        if (!taken.has(iso)) out.push(iso);
      }
    }
  }
  return out.slice(0, 24);
}

// ── POST /api/sessions/:id/ticket ───────────────────────────────────────────
export async function purchaseTicket(ctx: Ctx, sessionId: string): Promise<{ ok: true }> {
  const s = await ctx.db.get<LiveSession>(C.sessions, sessionId);
  if (!s || s.state === 'cancelled' || s.state === 'ended') throw err(404, 'session unavailable');
  if (s.type === 'private_1on1') throw err(403, '1-on-1 rooms are booking-only');
  if (s.attendeeCount >= s.capacity) throw err(409, 'session full');

  const already = await ctx.db.get<SessionTicket>(C.tickets, `${sessionId}_${ctx.userId}`);
  if (already) throw err(409, 'already holding entry');

  // Monthly all-access covers GROUP WORKOUTS only — seminars always paid
  const viaPass = s.type === 'group_workout'
    && SESSION_CONFIG.groupWorkout.includedInMonthlyPass
    && await ctx.users.hasActiveMonthlyPass(ctx.userId);

  const ledgerId = viaPass
    ? 'pass'
    : (await ctx.economy.debitShards(ctx.userId, s.priceShards, `session:${sessionId}`)).ledgerId;

  await ctx.db.put(C.tickets, `${sessionId}_${ctx.userId}`, {
    sessionId, userId: ctx.userId, ledgerId, viaMonthlyPass: viaPass,
    purchasedAt: new Date().toISOString(),
  } satisfies SessionTicket);
  await ctx.db.put(C.sessions, sessionId, { ...s, attendeeCount: s.attendeeCount + 1 });
  return { ok: true };
}

// ── POST /api/sessions/:id/join — gated HLS/token issue ─────────────────────
export async function join(ctx: Ctx, sessionId: string): Promise<JoinResponse> {
  const s = await ctx.db.get<LiveSession>(C.sessions, sessionId);
  if (!s) throw err(404, 'no session');
  const ticket = await ctx.db.get<SessionTicket>(C.tickets, `${sessionId}_${ctx.userId}`);
  const booking = s.type === 'private_1on1'
    ? (await ctx.db.query<PrivateBooking>(C.bookings, { userId: ctx.userId, sessionId, state: 'confirmed' }))[0]
    : null;
  if (!ticket && !booking && !(await ctx.users.isFounder(ctx.userId))) throw err(403, 'no entry for this session');

  const { streamId } = await ctx.streams.ensureRoom(sessionId, s.title);
  if (s.streamId !== streamId) await ctx.db.put(C.sessions, sessionId, { ...s, streamId });
  return ctx.streams.issueJoinToken(streamId, ctx.userId);   // single-user, expiring
}

// ── POST /api/sessions/book — private 1-on-1 request (fallback path) ────────
export async function bookPrivate(ctx: Ctx, body: { slotIso: string; note: string }): Promise<PrivateBooking> {
  const age = await ctx.users.ageOf(ctx.userId);
  if (age !== null && age < SESSION_CONFIG.private1on1.minAge) throw err(403, 'private sessions are 18+');

  const sessions = await materialize(ctx);
  const horizon = Date.now() + SESSION_CONFIG.private1on1.fallbackWindowDays * DAY_MS;
  if (sessions.some((s) => s.type === 'private_seminar' && +new Date(s.startsAt) < horizon && s.state === 'scheduled')) {
    throw err(409, 'a seminar is scheduled — join that instead');
  }

  const { ledgerId } = await ctx.economy.debitShards(
    ctx.userId, SESSION_CONFIG.private1on1.priceShards, `booking:${body.slotIso}`,
  );
  const booking: PrivateBooking = {
    id: `bk_${ctx.userId}_${Date.parse(body.slotIso)}`,
    userId: ctx.userId, slotIso: body.slotIso,
    note: body.note.slice(0, 500), state: 'requested', ledgerId,
  };
  await ctx.db.put(C.bookings, booking.id, booking);
  return booking;
}

// ── Founder admin ───────────────────────────────────────────────────────────
export async function resolveBooking(
  ctx: Ctx, bookingId: string, action: 'confirm' | 'decline',
): Promise<{ ok: true }> {
  if (!(await ctx.users.isFounder(ctx.userId))) throw err(403, 'founder only');
  const b = await ctx.db.get<PrivateBooking>(C.bookings, bookingId);
  if (!b || b.state !== 'requested') throw err(404, 'no pending booking');

  if (action === 'decline') {
    await ctx.economy.refund(b.ledgerId);
    await ctx.db.put(C.bookings, bookingId, { ...b, state: 'declined' });
    return { ok: true };
  }
  const session: LiveSession = {
    id: `p1_${b.id}`, type: 'private_1on1',
    title: 'Private Session — 1 on 1',
    startsAt: b.slotIso, durationMin: SESSION_CONFIG.private1on1.durationMin,
    capacity: 1, priceShards: SESSION_CONFIG.private1on1.priceShards,
    state: 'scheduled', attendeeCount: 1,
  };
  await ctx.db.put(C.sessions, session.id, session);
  await ctx.db.put(C.bookings, bookingId, { ...b, state: 'confirmed', sessionId: session.id });
  return { ok: true };
}

export async function cancelSession(ctx: Ctx, sessionId: string): Promise<{ ok: true; refunded: number }> {
  if (!(await ctx.users.isFounder(ctx.userId))) throw err(403, 'founder only');
  const s = await ctx.db.get<LiveSession>(C.sessions, sessionId);
  if (!s) throw err(404, 'no session');
  const holders = await ctx.db.query<SessionTicket>(C.tickets, { sessionId });
  for (const t of holders) if (!t.viaMonthlyPass) await ctx.economy.refund(t.ledgerId);
  await ctx.db.put(C.sessions, sessionId, { ...s, state: 'cancelled' });
  return { ok: true, refunded: holders.filter((t) => !t.viaMonthlyPass).length };
}

function err(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status; return e;
}
