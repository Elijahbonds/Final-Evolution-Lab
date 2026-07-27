// Rollback — live multiplayer, built on the machinery that already verifies a
// match.
//
// THE INSIGHT WORTH STATING FIRST
// Re-running a match from its inputs to check it (`HeadlessSim`) and re-running
// the last few frames because a remote input arrived late are THE SAME
// OPERATION at different scales. Once a mode can be simulated from
// (seed + inputs), rollback netcode is mostly bookkeeping.
//
// That is why the order of this ten-phase pass matters more than it looked:
// M83's fixed timestep made determinism possible, M90 needed it for money, and
// Phase 8 gets multiplayer largely for free. Had netcode come first it would
// have needed all of the same work and delivered none of the verification.
//
// WHY ROLLBACK RATHER THAN DELAY
// Two options for a deterministic peer-to-peer game:
//
//   DELAY-BASED  wait for the remote input before simulating. Simple, and it
//                adds the full round-trip to EVERY input. At 80ms ping that is
//                80ms of lag on every button press, which is over the 66ms
//                budget MotionModel set in M81 — so the game would fail its
//                own responsiveness bar before a packet was ever dropped.
//   ROLLBACK     predict the remote input, simulate immediately, and if the
//                prediction was wrong, rewind and re-run. Local input is
//                ALWAYS zero-latency; the cost is occasional visual correction
//                on the remote character.
//
// Rollback is strictly better for anything where the player's own input must
// feel immediate, which is every real-time mode FEL has. The cost is that the
// simulation must be cheap to re-run, which is exactly the property
// `SimulatableMode` already requires.
//
// TRANSPORT-AGNOSTIC ON PURPOSE
// This file never opens a socket. The standing constraint against writing
// netcode against backend infrastructure this repo cannot see still holds —
// and it is not a limitation, because rollback's hard part is the state
// bookkeeping, not the transport. Feed it inputs from a WebSocket, WebRTC, or
// a test harness; it does not care.

import { FIXED_DT } from './FixedStep';
import type { Intent } from './PlayerSlot';
import { IDLE_INTENT } from './Replay';

/**
 * How many ticks of history to keep.
 *
 * 8 ticks is ~133ms at 60Hz, which covers most connections. Beyond the buffer
 * a late input CANNOT be applied — the simulation has moved on and the frames
 * are gone. That is a real limit and it is better to state it than to pretend
 * a bigger buffer is free: every extra tick is a full state snapshot held in
 * memory and a longer worst-case re-simulation.
 */
export const ROLLBACK_FRAMES = 8;

export type PlayerId = 0 | 1;

export interface TickInputs {
  tick: number;
  /** Per player. `null` means "not received yet — predicted". */
  inputs: [Intent | null, Intent | null];
}

export interface RollbackStats {
  /** How many times the simulation has been rewound. */
  rollbacks: number;
  /** Total ticks re-simulated. The real cost of a bad connection. */
  ticksResimulated: number;
  /** Inputs that arrived too late to apply at all. */
  dropped: number;
  /** Longest rewind seen. Approaching ROLLBACK_FRAMES means trouble. */
  worstRollback: number;
}

/**
 * Predict a missing remote input.
 *
 * REPEAT THE LAST ONE. This looks lazy and is correct: human input is highly
 * autocorrelated at 60Hz — a player holding forward this frame is
 * overwhelmingly likely to hold it next frame — so repetition is right the
 * large majority of the time and wrong cheaply.
 *
 * A cleverer predictor (extrapolating stick movement, say) is wrong in more
 * interesting ways and produces larger corrections when it misses. In rollback
 * the cost of a misprediction is a visible snap, so a boring predictor that is
 * usually right beats a smart one that is sometimes very wrong.
 *
 * EDGES ARE NOT REPEATED. Repeating a button press turns one shot into sixty.
 */
export function predictInput(last: Intent | null): Intent {
  if (!last) return IDLE_INTENT;
  return {
    ...last,
    action: false,
    pass: false,
    steal: false,
  };
}

/**
 * The rollback state machine.
 *
 * `S` is the mode's simulation state — the same type `SimulatableMode` uses,
 * so a mode that can be verified can be played online with no further work.
 */
export class RollbackSession<S> {
  private confirmed: Map<number, [Intent | null, Intent | null]> = new Map();
  private snapshots: Map<number, S> = new Map();
  private state: S;
  /** Everything up to and including this tick uses only real inputs. */
  private confirmedTick = -1;

  public tick = 0;
  public readonly stats: RollbackStats =
    { rollbacks: 0, ticksResimulated: 0, dropped: 0, worstRollback: 0 };

  // Longhand rather than constructor parameter properties: strip-types rejects
  // those and these files are executed by the test suite.
  // See docs/abacus-batches/KNOWN-ERRORS.md.
  private step: (state: S, inputs: [Intent, Intent], dt: number) => S;
  private clone: (state: S) => S;

  constructor(
    initial: S,
    step: (state: S, inputs: [Intent, Intent], dt: number) => S,
    clone: (state: S) => S,
  ) {
    this.step = step;
    this.clone = clone;
    this.state = initial;
    this.snapshots.set(-1, clone(initial));
  }

  get current(): S { return this.state; }
  /** True while the visible state depends on a guess. */
  get predicting(): boolean { return this.tick > this.confirmedTick + 1; }

  /**
   * Advance one tick using the local input and a prediction for the remote.
   *
   * Local input is applied IMMEDIATELY. That is the entire point — the
   * player's own character never waits for the network.
   */
  advance(local: Intent, localPlayer: PlayerId): S {
    const known = this.confirmed.get(this.tick) ?? [null, null];
    const remotePlayer: PlayerId = localPlayer === 0 ? 1 : 0;

    const pair: [Intent | null, Intent | null] = [null, null];
    pair[localPlayer] = local;
    pair[remotePlayer] = known[remotePlayer] ?? null;
    this.confirmed.set(this.tick, pair);

    const applied: [Intent, Intent] = [IDLE_INTENT, IDLE_INTENT];
    applied[localPlayer] = local;
    applied[remotePlayer] = pair[remotePlayer] ?? predictInput(this.lastKnown(remotePlayer));

    this.state = this.step(this.state, applied, FIXED_DT);
    this.tick++;
    this.snapshots.set(this.tick - 1, this.clone(this.state));
    this.prune();
    this.advanceConfirmed();
    return this.state;
  }

  /**
   * A remote input arrived. Rewind and re-run if it contradicts the guess.
   *
   * Returns how many ticks were re-simulated — 0 when the prediction was
   * right, which is the common case and the reason rollback is affordable.
   */
  receiveRemote(tick: number, input: Intent, remotePlayer: PlayerId): number {
    if (tick < this.tick - ROLLBACK_FRAMES) {
      // Too old to apply. The simulation has moved past the frames it would
      // have changed, and those frames are gone.
      this.stats.dropped++;
      return 0;
    }

    const existing = this.confirmed.get(tick) ?? [null, null];
    const previous = existing[remotePlayer];
    existing[remotePlayer] = input;
    this.confirmed.set(tick, existing);

    if (tick >= this.tick) { this.advanceConfirmed(); return 0; }   // future; nothing to redo

    const predicted = predictInput(this.lastKnownBefore(remotePlayer, tick));
    if (previous === null && sameIntent(predicted, input)) {
      // The guess was right — the whole reason this is cheap.
      this.advanceConfirmed();
      return 0;
    }
    if (previous !== null && sameIntent(previous, input)) {
      this.advanceConfirmed();
      return 0;
    }

    return this.rollbackTo(tick);
  }

  /** Rewind to `tick` and re-run to the present with corrected inputs. */
  private rollbackTo(tick: number): number {
    const from = Math.max(tick - 1, this.oldestSnapshot());
    const snapshot = this.snapshots.get(from);
    if (snapshot === undefined) { this.stats.dropped++; return 0; }

    this.state = this.clone(snapshot);
    const target = this.tick;
    let redone = 0;

    for (let t = from + 1; t < target; t++) {
      const known = this.confirmed.get(t) ?? [null, null];
      const applied: [Intent, Intent] = [
        known[0] ?? predictInput(this.lastKnownBefore(0, t)),
        known[1] ?? predictInput(this.lastKnownBefore(1, t)),
      ];
      this.state = this.step(this.state, applied, FIXED_DT);
      this.snapshots.set(t, this.clone(this.state));
      redone++;
    }

    this.stats.rollbacks++;
    this.stats.ticksResimulated += redone;
    this.stats.worstRollback = Math.max(this.stats.worstRollback, redone);
    this.advanceConfirmed();
    return redone;
  }

  private lastKnown(player: PlayerId): Intent | null {
    return this.lastKnownBefore(player, this.tick);
  }

  private lastKnownBefore(player: PlayerId, tick: number): Intent | null {
    for (let t = tick - 1; t >= this.oldestSnapshot(); t--) {
      const got = this.confirmed.get(t)?.[player];
      if (got) return got;
    }
    return null;
  }

  /** Walk the confirmed frontier forward over fully-known ticks. */
  private advanceConfirmed(): void {
    while (this.confirmedTick + 1 < this.tick) {
      const pair = this.confirmed.get(this.confirmedTick + 1);
      if (!pair || pair[0] === null || pair[1] === null) break;
      this.confirmedTick++;
    }
  }

  private oldestSnapshot(): number { return Math.max(-1, this.tick - ROLLBACK_FRAMES - 1); }

  private prune(): void {
    const cutoff = this.oldestSnapshot();
    for (const t of this.snapshots.keys()) if (t < cutoff) this.snapshots.delete(t);
    for (const t of this.confirmed.keys()) if (t < cutoff) this.confirmed.delete(t);
  }

  /**
   * Is this connection playable?
   *
   * A rollback game degrades gracefully until it suddenly does not. Naming the
   * threshold means the product can tell a player their connection is the
   * problem, rather than letting them conclude the game is broken.
   */
  get health(): { playable: boolean; note: string } {
    if (this.stats.dropped > 0) {
      return {
        playable: false,
        note: `${this.stats.dropped} input(s) arrived too late to apply. `
          + `Beyond ${ROLLBACK_FRAMES} frames (~${Math.round(ROLLBACK_FRAMES * FIXED_DT * 1000)}ms) `
          + 'the frames they would have changed are already gone.',
      };
    }
    if (this.stats.worstRollback > ROLLBACK_FRAMES * 0.75) {
      return { playable: true, note: 'Connection is marginal — corrections are close to the buffer limit.' };
    }
    return { playable: true, note: 'Connection is healthy.' };
  }
}

function sameIntent(a: Intent, b: Intent): boolean {
  return a.moveX === b.moveX && a.moveY === b.moveY && a.sprint === b.sprint
    && a.action === b.action && a.actionHeld === b.actionHeld
    && a.pass === b.pass && a.steal === b.steal;
}

/**
 * Ping a rollback buffer can absorb.
 *
 * Round-trip, not one-way: an input must reach the peer AND be applied within
 * the window. This is the number that decides matchmaking radius, and it is
 * better to compute it than to guess a region list.
 */
export function maxAbsorbablePingMs(frames = ROLLBACK_FRAMES): number {
  return Math.round(frames * FIXED_DT * 1000);
}

/**
 * Should these two be matched?
 *
 * Deliberately refuses rather than degrading. A match played beyond the buffer
 * is not a worse match — it is one where inputs are silently dropped and both
 * players experience a game that lies to them. Refusing with a reason is
 * kinder and far easier to support.
 */
export function matchmakingVerdict(pingMs: number): { allowed: boolean; reason: string } {
  const max = maxAbsorbablePingMs();
  if (pingMs <= max * 0.6) return { allowed: true, reason: `${pingMs}ms — comfortable` };
  if (pingMs <= max) return { allowed: true, reason: `${pingMs}ms — playable, expect visible corrections` };
  return {
    allowed: false,
    reason: `${pingMs}ms exceeds the ${max}ms this buffer can absorb. Inputs would be dropped, `
      + 'and a match that silently drops inputs is worse than no match.',
  };
}
