// TrickLine — a run is a LINE, not a list of tricks.
//
// WHAT SKATE HAS TODAY
// `boardCore.TrickMachine` has five tricks and a combo counter that increments
// on each landing. Land a kickflip, land a 360, land a grab: combo 3. There is
// no notion of a LINE — nothing links one trick to the next except that you
// happened to land both, and nothing is lost by stopping.
//
// So the optimal play is to find one high-value trick and repeat it in the
// safest spot in the park. That is a score attack with extra steps.
//
// WHAT MAKES TRICK-LINE SKATING WORK
// A line is a continuous run of tricks linked by things that keep the chain
// alive — a grind, a manual, a transfer — where:
//
//   1. THE MULTIPLIER GROWS WITH THE LINE, so a long line is worth far more
//      than the sum of its tricks.
//   2. THE CHAIN DIES IF YOU TOUCH DOWN NEUTRAL, so you must always be doing
//      something.
//   3. BALANCE DEGRADES the longer you hold it, so you cannot hold a manual
//      forever, and bailing loses EVERYTHING banked.
//
// Point 3 is what makes it a game. The longer the line, the more you have to
// lose, so every extra trick is a real decision about whether to cash out. A
// combo counter with no bail risk is a number going up; a line you can lose is
// tension.
//
// This is also why the trick vocabulary being thin matters less than it looks.
// Five tricks that can be linked in a hundred orders across a park is a deeper
// system than thirty tricks thrown in isolation.

import { Rng } from './Rng';

export type TrickKind = 'air' | 'flip' | 'spin' | 'grab' | 'grind' | 'manual' | 'transfer';

export interface TrickSpec {
  id: string;
  name: string;
  kind: TrickKind;
  base: number;
  /** Balance cost per second while held. 0 for instant tricks. */
  drainPerSec: number;
  /** How hard it is to start cleanly, 0..1. Feeds the landing check. */
  difficulty: number;
  clipId?: string;
}

/**
 * The vocabulary.
 *
 * The five original tricks, plus the three LINKS that make lines possible.
 * Grinds, manuals and transfers score modestly on their own — their value is
 * that they keep a chain alive over ground where you would otherwise have to
 * touch down neutral.
 */
export const TRICKS: Record<string, TrickSpec> = {
  ollie:     { id: 'ollie',     name: 'OLLIE',     kind: 'air',      base: 50,  drainPerSec: 0,    difficulty: 0.1 },
  kickflip:  { id: 'kickflip',  name: 'KICKFLIP',  kind: 'flip',     base: 120, drainPerSec: 0,    difficulty: 0.35, clipId: 'board_kickflip' },
  heelflip:  { id: 'heelflip',  name: 'HEELFLIP',  kind: 'flip',     base: 120, drainPerSec: 0,    difficulty: 0.35, clipId: 'board_heelflip' },
  spin360:   { id: 'spin360',   name: '360',       kind: 'spin',     base: 140, drainPerSec: 0,    difficulty: 0.45, clipId: 'board_360' },
  grab:      { id: 'grab',      name: 'GRAB',      kind: 'grab',     base: 90,  drainPerSec: 0.15, difficulty: 0.2,  clipId: 'board_grab' },
  // ── the links ──────────────────────────────────────────────────────────
  grind:     { id: 'grind',     name: 'GRIND',     kind: 'grind',    base: 70,  drainPerSec: 0.28, difficulty: 0.4,  clipId: 'board_grind' },
  manual:    { id: 'manual',    name: 'MANUAL',    kind: 'manual',   base: 40,  drainPerSec: 0.42, difficulty: 0.3,  clipId: 'board_manual' },
  transfer:  { id: 'transfer',  name: 'TRANSFER',  kind: 'transfer', base: 110, drainPerSec: 0,    difficulty: 0.55 },
};

export const LINK_KINDS: TrickKind[] = ['grind', 'manual', 'transfer'];
export const isLink = (t: TrickSpec): boolean => LINK_KINDS.includes(t.kind);

export type LineEnd = 'landed' | 'bailed' | 'grounded';

export interface LineState {
  /** Tricks in the current line, in order. */
  chain: string[];
  /** Points banked but not yet cashed. Lost entirely on a bail. */
  banked: number;
  /** 0..1. Reaches 0 and you bail. */
  balance: number;
  /** Seconds the current held trick has been held. */
  heldSec: number;
  /** The trick currently being held, if any. */
  holding: string | null;
  /** True once the line has been cashed or lost. */
  closed: boolean;
}

export const NEW_LINE: LineState = {
  chain: [], banked: 0, balance: 1, heldSec: 0, holding: null, closed: false,
};

/**
 * Multiplier for a chain of length n.
 *
 * Grows faster than linear, so a six-trick line is worth far more than two
 * three-trick lines — which is the entire incentive to keep going. Capped at
 * 8× so a single monster line cannot outscore a whole run, because a scoring
 * system where one attempt decides everything makes the other four minutes
 * pointless.
 */
export function lineMultiplier(chainLength: number): number {
  if (chainLength <= 1) return 1;
  return Math.min(8, 1 + (chainLength - 1) * 0.65);
}

/**
 * VARIETY, not repetition.
 *
 * Repeating the same trick pays a fraction. Without this the optimal line is
 * one trick spammed, which is exactly what the current combo counter rewards.
 */
export function repetitionFactor(chain: string[], trickId: string): number {
  const already = chain.filter((t) => t === trickId).length;
  return Math.max(0.2, 1 - already * 0.35);
}

/**
 * Add a trick to the line.
 *
 * `landed` comes from the mode's own physics — this owns the scoring and the
 * chain, not the collision.
 */
export function addTrick(
  s: LineState, trickId: string, landed: boolean,
): { state: LineState; points: number; note: string } {
  if (s.closed) return { state: s, points: 0, note: 'line already closed' };
  const spec = TRICKS[trickId];
  if (!spec) return { state: s, points: 0, note: `unknown trick ${trickId}` };

  if (!landed) {
    return {
      state: { ...s, chain: [], banked: 0, balance: 1, holding: null, heldSec: 0, closed: true },
      points: 0,
      note: `bailed the ${spec.name} — ${s.banked} points lost`,
    };
  }

  const chain = [...s.chain, trickId];
  const pts = Math.round(spec.base * repetitionFactor(s.chain, trickId));
  return {
    state: {
      ...s,
      chain,
      banked: s.banked + pts,
      holding: spec.drainPerSec > 0 ? trickId : null,
      heldSec: 0,
    },
    points: pts,
    note: `${spec.name} x${lineMultiplier(chain.length).toFixed(1)}`,
  };
}

/**
 * Advance one FIXED tick while a trick is held.
 *
 * Balance drains at the held trick's rate, and drains FASTER the longer the
 * line — the pressure of a big line is modelled directly, so holding a manual
 * to link a nine-trick run is genuinely harder than holding it to link a two.
 */
export function tickLine(s: LineState, dt: number): LineState {
  if (s.closed || !s.holding) return s;
  const spec = TRICKS[s.holding];
  if (!spec) return s;
  const pressure = 1 + (s.chain.length - 1) * 0.08;
  const balance = Math.max(0, s.balance - spec.drainPerSec * pressure * dt);
  return { ...s, balance, heldSec: s.heldSec + dt };
}

/** Balance recovers while not holding anything — but never fully mid-line. */
export function recoverBalance(s: LineState, dt: number): LineState {
  if (s.closed || s.holding) return s;
  // Ceiling falls as the line grows: you can steady yourself, but a long line
  // never gets back to fresh.
  const ceiling = Math.max(0.45, 1 - s.chain.length * 0.05);
  return { ...s, balance: Math.min(ceiling, s.balance + dt * 0.35) };
}

/**
 * Correcting balance — the input the player actually uses to hold a line.
 *
 * A NUDGE, not a reset. Perfect correction would make holds free and every
 * line infinite; too weak and holds are a countdown you cannot influence.
 * `accuracy` is how close the stick was to the needed direction, 0..1.
 */
export function correctBalance(s: LineState, accuracy: number): LineState {
  if (s.closed || !s.holding) return s;
  return { ...s, balance: Math.min(1, s.balance + accuracy * 0.18 - 0.02) };
}

/** Has the line failed on balance? */
export function hasBailed(s: LineState): boolean {
  return !s.closed && s.balance <= 0;
}

/**
 * Cash the line out.
 *
 * The decision the whole system exists to create: bank what you have, or push
 * for one more trick and risk all of it.
 */
export function cashLine(s: LineState): { state: LineState; score: number; note: string } {
  if (s.closed) return { state: s, score: 0, note: 'already closed' };
  const mult = lineMultiplier(s.chain.length);
  const score = Math.round(s.banked * mult);
  return {
    state: { ...s, closed: true },
    score,
    note: s.chain.length > 1
      ? `${s.chain.length}-trick line — ${s.banked} x${mult.toFixed(1)} = ${score}`
      : `${score}`,
  };
}

/**
 * Chance a trick is landed cleanly.
 *
 * Difficulty, current balance and line length all work against you. A trick
 * that is trivial at the start of a line is genuinely risky nine deep, which
 * is what makes cashing out a real decision rather than an obvious one.
 */
export function landChance(s: LineState, trickId: string, skill: number): number {
  const spec = TRICKS[trickId];
  if (!spec) return 0;
  const linePressure = Math.min(0.35, s.chain.length * 0.03);
  const raw = 0.55 + skill * 0.4 - spec.difficulty * 0.5 - linePressure + (s.balance - 0.5) * 0.3;
  return Math.min(0.97, Math.max(0.05, raw));
}

export function attemptTrick(s: LineState, trickId: string, skill: number, rng: Rng) {
  return addTrick(s, trickId, rng.chance(landChance(s, trickId, skill)));
}

/**
 * Should the player cash out?
 *
 * Exposed for a HUD prompt, and it is the most useful thing the mode can tell
 * a new player: skating games are usually lost by not knowing when to stop.
 */
export function cashAdvice(s: LineState, nextTrickId: string, skill: number): string | null {
  if (s.closed || s.chain.length < 3) return null;
  const chance = landChance(s, nextTrickId, skill);
  const now = Math.round(s.banked * lineMultiplier(s.chain.length));
  if (chance < 0.45) return `${now} banked — that next trick lands ${Math.round(chance * 100)}% of the time`;
  if (s.balance < 0.3) return `${now} banked and your balance is going`;
  return null;
}
