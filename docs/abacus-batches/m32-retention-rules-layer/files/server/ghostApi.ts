// Ghost runs + SKATE challenges — async multiplayer on the recorded-transform
// tech. Ghosts are input/trick streams (tiny), never video.

import {
  NEXT_LETTER, type GhostRun, type GhostTrick, type SkateLetters,
} from '../shared/progressionContracts';

export interface Db {
  get<T>(c: string, id: string): Promise<T | null>;
  put<T>(c: string, id: string, doc: T): Promise<void>;
  query<T>(c: string, where: Record<string, unknown>): Promise<T[]>;
}
type Ctx = { userId: string; db: Db };

const C = { ghosts: 'ghost_runs', matches: 'skate_matches' };
const MAX_TRICKS = 12;

export interface SkateMatch {
  id: string;
  ghostId: string;
  challengerId: string;          // ghost owner
  opponentId: string | null;     // filled when the link is accepted
  opponentLetters: SkateLetters;
  currentTrickIdx: number;
  state: 'open' | 'active' | 'complete';
  winnerId?: string;
}

// ── POST /api/ghosts — record a run ─────────────────────────────────────────
export async function saveGhost(
  ctx: Ctx, body: { modeId: string; tricks: GhostTrick[]; inputStream?: string },
): Promise<GhostRun> {
  if (!body.tricks?.length) throw err(422, 'no tricks in run');
  const ghost: GhostRun = {
    id: `gh_${ctx.userId}_${Date.now()}`,
    ownerId: ctx.userId,
    modeId: body.modeId,
    tricks: body.tricks.slice(0, MAX_TRICKS),
    inputStream: body.inputStream,
    createdAt: new Date().toISOString(),
  };
  await ctx.db.put(C.ghosts, ghost.id, ghost);
  return ghost;
}

// ── POST /api/skate/challenge — create the shareable match ──────────────────
export async function createChallenge(ctx: Ctx, ghostId: string): Promise<{ matchId: string; link: string }> {
  const ghost = await ctx.db.get<GhostRun>(C.ghosts, ghostId);
  if (!ghost || ghost.ownerId !== ctx.userId) throw err(404, 'ghost not found');
  const match: SkateMatch = {
    id: `sk_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
    ghostId, challengerId: ctx.userId, opponentId: null,
    opponentLetters: '', currentTrickIdx: 0, state: 'open',
  };
  await ctx.db.put(C.matches, match.id, match);
  return { matchId: match.id, link: `/skate/challenge/${match.id}` };   // CHALLENGE A FRIEND deep link
}

// ── POST /api/skate/:matchId/accept ─────────────────────────────────────────
export async function acceptChallenge(ctx: Ctx, matchId: string): Promise<{ match: SkateMatch; ghost: GhostRun }> {
  const match = await ctx.db.get<SkateMatch>(C.matches, matchId);
  if (!match || match.state === 'complete') throw err(404, 'challenge unavailable');
  if (match.challengerId === ctx.userId) throw err(422, 'cannot play your own line');
  match.opponentId = ctx.userId;
  match.state = 'active';
  await ctx.db.put(C.matches, matchId, match);
  const ghost = (await ctx.db.get<GhostRun>(C.ghosts, match.ghostId))!;
  return { match, ghost };
}

// ── POST /api/skate/:matchId/attempt — one trick attempt result ─────────────
export async function reportAttempt(
  ctx: Ctx, matchId: string, body: { trickIdx: number; landed: boolean },
): Promise<SkateMatch> {
  const match = await ctx.db.get<SkateMatch>(C.matches, matchId);
  if (!match || match.state !== 'active' || match.opponentId !== ctx.userId) throw err(404, 'no active match');
  if (body.trickIdx !== match.currentTrickIdx) throw err(409, 'out-of-order attempt');

  if (!body.landed) match.opponentLetters = NEXT_LETTER[match.opponentLetters];
  match.currentTrickIdx++;

  const ghost = (await ctx.db.get<GhostRun>(C.ghosts, match.ghostId))!;
  const outOfTricks = match.currentTrickIdx >= ghost.tricks.length;
  if (match.opponentLetters === 'SKATE') {
    match.state = 'complete';
    match.winnerId = match.challengerId;                 // opponent lettered out
  } else if (outOfTricks) {
    match.state = 'complete';
    match.winnerId = match.opponentId;                   // survived the line
  }
  await ctx.db.put(C.matches, matchId, match);
  return match;
}

// ── GET /api/skate/mine — my open/active matches ────────────────────────────
export async function myMatches(ctx: Ctx): Promise<SkateMatch[]> {
  const asChallenger = await ctx.db.query<SkateMatch>(C.matches, { challengerId: ctx.userId });
  const asOpponent = await ctx.db.query<SkateMatch>(C.matches, { opponentId: ctx.userId });
  return [...asChallenger, ...asOpponent].filter((m) => m.state !== 'complete');
}

function err(status: number, message: string): Error & { status: number } {
  const e = new Error(message) as Error & { status: number };
  e.status = status; return e;
}
