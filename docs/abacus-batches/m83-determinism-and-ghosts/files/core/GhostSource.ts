// GhostSource — a recorded player, as a ControlSource.
//
// This is the whole payoff of M48's PlayerSlot decision. Every body on the
// court already reads intent from a `ControlSource`; a ghost implements that
// interface and drops into a slot with no change to any game logic. Basketball,
// karate, skateboarding — anything built on PlayerSlot gets an opponent for
// free.
//
// WHAT A GHOST IS NOT
// It is not an AI trained on a player, and it is not a video. It is the
// player's actual inputs, re-executed against a deterministic simulation. Given
// the same seed and the same tick rate it reproduces the match exactly — which
// is why the FixedStep and Rng work had to land first, and why a server can
// re-run a prize-pool result and audit it.
//
// WHAT IT CANNOT DO, STATED PLAINLY
// A ghost cannot react to you. It replays a match against whatever it faced
// when it was recorded. In a rally sport that is nearly indistinguishable from
// a live opponent; in 1v1 basketball, a ghost that drives left because the
// ORIGINAL defender was on its right will look wrong when you are on its left.
//
// So ghosts are honest in some modes and a lie in others, and `GHOST_FIDELITY`
// below records which is which rather than letting each mode discover it the
// hard way. Shipping a ghost into a mode that cannot support one is how a
// feature gets a reputation it never recovers from.

import type { ControlSource, Intent } from './PlayerSlot';
import {
  ReplayPlayer, validateReplay, IDLE_INTENT,
  type ReplayData,
} from './Replay';

/**
 * How well a recorded opponent holds up per mode.
 *
 *   'exact'      the ghost faced no opponent, so replay IS the performance —
 *                a score attack. Indistinguishable from the real thing.
 *   'good'       exchanges are discrete; a ghost's turn plays out on its own
 *                terms and reads as a real opponent.
 *   'poor'       continuous mutual reaction. A ghost will visibly ignore you.
 *                Do not ship a ghost here; wait for real netcode.
 */
export type GhostFidelity = 'exact' | 'good' | 'poor';

export const GHOST_FIDELITY: Record<string, GhostFidelity> = {
  // Solo performances — the ghost is a score to beat, and replay is perfect.
  dunk: 'exact', dunkduel: 'exact', skateboard: 'exact', snowboard: 'exact',
  surf: 'exact', gymnastics: 'exact', golf: 'exact', baseball: 'exact',
  irl: 'exact', music: 'exact', dance: 'exact', art: 'exact',
  // Discrete exchanges — a ghost takes its turn convincingly.
  tennis: 'good', volleyball: 'good', soccer: 'good', football: 'good',
  brain_brawl: 'good', who_scene_it: 'good', acting: 'good', carnival: 'good',
  // Continuous mutual reaction — a ghost cannot respond to where you actually
  // are, and it shows immediately.
  onevone: 'poor', threevthree: 'poor', karate: 'poor',
  'karate-vs': 'poor', mixedcombat: 'poor',
};

export function ghostFidelity(modeId: string): GhostFidelity {
  return GHOST_FIDELITY[modeId] ?? 'poor';   // unknown modes are pessimistic
}

/** Should this mode offer a ghost opponent at all? */
export function ghostsSuitable(modeId: string): boolean {
  return ghostFidelity(modeId) !== 'poor';
}

export interface GhostOptions {
  /** Called once when the recording runs out. */
  onFinished?: () => void;
  /** Play at a different rate — a 0.9× ghost is a gentler target. Applied by
   *  repeating or skipping ticks, so the recording is never resampled. */
  speed?: number;
}

/**
 * Drives a player slot from a recording.
 *
 * `poll()` ignores its `dt` argument on purpose. A ghost advances one
 * RECORDED tick per SIMULATION tick, never per rendered frame — that is what
 * keeps it in lockstep with the world it is replaying. If poll() is being
 * called from a variable-rate render loop, the mode has not been migrated to
 * FixedStep and the ghost will drift.
 */
export class GhostSource implements ControlSource {
  private player: ReplayPlayer;
  private notified = false;
  private carry = 0;
  private readonly speed: number;
  private opts: GhostOptions;

  constructor(data: ReplayData, opts: GhostOptions = {}) {
    this.player = new ReplayPlayer(data);
    this.opts = opts;
    this.speed = opts.speed && opts.speed > 0 ? opts.speed : 1;
  }

  /**
   * Build from stored JSON, refusing anything that would not reproduce.
   *
   * Returns null and says why rather than throwing. A bad ghost must degrade
   * to "no ghost" — never to "no match".
   */
  static from(
    data: ReplayData | null, modeId: string, dt: number, opts: GhostOptions = {},
  ): GhostSource | null {
    if (!data) { console.warn('[FEL-GHOST] no recording supplied.'); return null; }
    const why = validateReplay(data, modeId, dt);
    if (why) {
      console.warn(`[FEL-GHOST] refusing this recording: ${why}. `
        + 'Playing a ghost that cannot reproduce is worse than playing none — '
        + 'the player would lose to an opponent that never existed.');
      return null;
    }
    if (!ghostsSuitable(modeId)) {
      console.warn(`[FEL-GHOST] "${modeId}" is fidelity '${ghostFidelity(modeId)}': a ghost `
        + 'cannot react to the live player here and will visibly ignore them.');
    }
    return new GhostSource(data, opts);
  }

  poll(): Intent {
    if (this.player.finished) {
      if (!this.notified) { this.notified = true; this.opts.onFinished?.(); }
      return IDLE_INTENT;
    }
    // Speed is applied by repeating or dropping whole recorded ticks. Blending
    // between two ticks would invent inputs the player never made.
    this.carry += this.speed;
    let out = IDLE_INTENT;
    let advanced = false;
    while (this.carry >= 1 && !this.player.finished) {
      out = this.player.next();
      this.carry -= 1;
      advanced = true;
    }
    return advanced ? out : IDLE_INTENT;
  }

  /** 0..1 through the recording — for a progress bar against the ghost. */
  get progress(): number {
    const total = this.player.data.header.totalTicks;
    return total > 0 ? Math.min(1, this.player.tick / total) : 1;
  }

  get finished(): boolean { return this.player.finished; }
  /** The score the ghost is on its way to. Lets the HUD show a live gap. */
  get targetScore(): number { return this.player.data.header.score; }
  /** PRQ the ghost was recorded at — restore it into DDA or the AI diverges. */
  get recordedPRQ(): number { return this.player.data.header.playerPRQ; }
  get seed(): number { return this.player.data.header.seed; }

  reset(): void { this.player.reset(); this.notified = false; this.carry = 0; }
  dispose(): void { /* nothing owned */ }
}

/**
 * Verify that a replay reproduces, by comparing state hashes.
 *
 * The single most valuable thing here. Run it after recording, in dev: it
 * re-simulates the match and compares the result against what was captured
 * live. If they differ, something in the mode is still non-deterministic —
 * almost always a stray `Math.random()` or a `Date.now()` — and it is caught
 * on the machine that made it rather than by a player losing to a ghost that
 * drifted.
 *
 * `simulate` must run the mode from a clean state and return the hash at each
 * tick.
 */
export function verifyDeterminism(
  data: ReplayData,
  simulate: (intents: Intent[], seed: number) => number[],
  capturedHashes: number[],
): { ok: boolean; divergedAt: number | null; message: string } {
  const player = new ReplayPlayer(data);
  const intents: Intent[] = [];
  while (!player.finished) intents.push(player.next());

  const replayed = simulate(intents, data.header.seed);
  const n = Math.min(replayed.length, capturedHashes.length);
  for (let i = 0; i < n; i++) {
    if (replayed[i] !== capturedHashes[i]) {
      return {
        ok: false, divergedAt: i,
        message: `NON-DETERMINISTIC: diverged at tick ${i} of ${n} `
          + `(${(i * data.header.dt).toFixed(2)}s in). Look for Math.random(), Date.now(), `
          + 'Object key iteration order, or physics reading a variable dt. '
          + 'Rng.detectRawRandom() will find the first of those.',
      };
    }
  }
  if (replayed.length !== capturedHashes.length) {
    return {
      ok: false, divergedAt: n,
      message: `tick count differs: replay ran ${replayed.length}, capture had ${capturedHashes.length}`,
    };
  }
  return { ok: true, divergedAt: null, message: `deterministic across ${n} ticks` };
}
