// Replay — record a match as an input stream, play it back exactly.
//
// THIS IS MULTIPLAYER PHASE A, AND IT NEEDS NO SERVER.
//
// `core/PlayerSlot.ts` (M48) already made this cheap: every body on the court
// is driven by a `ControlSource` that returns an `Intent` each tick, and no
// game logic reads the input bus directly. A recorded opponent is just another
// ControlSource. That decision, made a year before it was needed, is why this
// file is 200 lines instead of a rewrite.
//
// WHAT A RECORDING IS
//   · a seed (so every random decision replays identically)
//   · the tick-indexed input stream
//   · enough header to refuse a replay that would not reproduce
//
// It is NOT a recording of positions. Positions are output; replaying them
// gives you a video, and a video cannot be played against. Replaying INPUTS
// re-runs the actual match, which is what makes a ghost a real opponent and
// what lets a server re-simulate a prize-pool result and audit it.
//
// WHY THIS COMES BEFORE REAL NETCODE
// It needs no transport, no matchmaking, no lag compensation, and no
// infrastructure this repo cannot see. It delivers most of "I played against
// someone" for a fraction of the cost — and the recording format is exactly
// what real netcode will need anyway.

import type { Intent } from './PlayerSlot';

/** Bump when the format changes incompatibly. An old replay is refused, never
 *  half-understood. */
export const REPLAY_VERSION = 1;

/**
 * Analog values are quantised to 1/127 before storage.
 *
 * Two reasons, and the second is the important one. It shrinks the file — but
 * it also removes the last-bit float differences between devices, so a replay
 * recorded on one phone reproduces on another instead of drifting apart over
 * a few thousand ticks.
 */
export const QUANT = 127;

export function quantise(v: number): number {
  return Math.round(Math.max(-1, Math.min(1, v)) * QUANT);
}
export function dequantise(q: number): number { return q / QUANT; }

/** One tick of input, packed. Field order is part of the format. */
export type PackedIntent = [
  moveX: number, moveY: number, held: number, flags: number,
];

const F_SPRINT = 1, F_ACTION = 2, F_PASS = 4, F_STEAL = 8;

export function pack(i: Intent): PackedIntent {
  return [
    quantise(i.moveX), quantise(i.moveY), quantise(i.actionHeld),
    (i.sprint ? F_SPRINT : 0) | (i.action ? F_ACTION : 0)
    | (i.pass ? F_PASS : 0) | (i.steal ? F_STEAL : 0),
  ];
}

export function unpack(p: PackedIntent): Intent {
  const [x, y, held, flags] = p;
  return {
    moveX: dequantise(x), moveY: dequantise(y),
    actionHeld: dequantise(held),
    sprint: (flags & F_SPRINT) !== 0,
    action: (flags & F_ACTION) !== 0,
    pass: (flags & F_PASS) !== 0,
    steal: (flags & F_STEAL) !== 0,
  };
}

export function sameIntent(a: PackedIntent, b: PackedIntent): boolean {
  return a[0] === b[0] && a[1] === b[1] && a[2] === b[2] && a[3] === b[3];
}

/**
 * A run-length entry: this input, held for this many ticks.
 *
 * Input is overwhelmingly repetitive — a player holds forward for 90 ticks at
 * a time. Storing per-tick would be ~16 bytes × 60/s × 180s ≈ 170KB for a
 * three-minute match; run-length brings a typical match to a few KB, which is
 * the difference between a ghost you can put in a leaderboard row and one you
 * cannot.
 *
 * EDGES ARE NEVER MERGED. `action`, `pass` and `steal` are one-tick edges, so
 * a run always has length 1 when any edge flag is set. Merging them would turn
 * one shot into ninety.
 */
export interface Run { i: PackedIntent; n: number }

export interface ReplayHeader {
  version: number;
  modeId: string;
  seed: number;
  /** Simulation dt. A replay recorded at a different tick rate cannot be
   *  trusted, so it is refused rather than resampled. */
  dt: number;
  /** PRQ at record time — DDA read it, so it must be restored or the AI
   *  behaves differently and the ghost desyncs. */
  playerPRQ: number;
  totalTicks: number;
  score: number;
  outcome: string;
  recordedAt: string;
  /** stateHash at the final tick, if the recorder supplied one. */
  finalHash?: number;
}

export interface ReplayData {
  header: ReplayHeader;
  runs: Run[];
}

/** Records one ControlSource's intent stream. */
export class ReplayRecorder {
  private runs: Run[] = [];
  private ticks = 0;
  // Written out longhand rather than as constructor parameter properties:
  // `node --experimental-strip-types` rejects those outright, and these files
  // are executed by the test suite. See docs/abacus-batches/KNOWN-ERRORS.md.
  public readonly modeId: string;
  public readonly seed: number;
  public readonly playerPRQ: number;
  public readonly dt: number;

  constructor(modeId: string, seed: number, playerPRQ: number, dt: number) {
    this.modeId = modeId;
    this.seed = seed;
    this.playerPRQ = playerPRQ;
    this.dt = dt;
  }

  /** Call once per FIXED tick, with the intent that tick consumed. */
  record(intent: Intent): void {
    const p = pack(intent);
    this.ticks++;
    const last = this.runs[this.runs.length - 1];
    const isEdge = p[3] & (F_ACTION | F_PASS | F_STEAL);
    if (last && !isEdge && !(last.i[3] & (F_ACTION | F_PASS | F_STEAL)) && sameIntent(last.i, p)) {
      last.n++;
      return;
    }
    this.runs.push({ i: p, n: 1 });
  }

  get tickCount(): number { return this.ticks; }

  finish(score: number, outcome: string, finalHash?: number): ReplayData {
    return {
      header: {
        version: REPLAY_VERSION,
        modeId: this.modeId, seed: this.seed, dt: this.dt,
        playerPRQ: this.playerPRQ,
        totalTicks: this.ticks,
        score, outcome,
        recordedAt: new Date().toISOString(),
        finalHash,
      },
      runs: this.runs,
    };
  }

  /** Rough serialised size, so a caller can decide whether to keep it. */
  get approxBytes(): number { return this.runs.length * 12 + 200; }
}

/** Neutral intent — what a finished ghost does. */
export const IDLE_INTENT: Intent = {
  moveX: 0, moveY: 0, sprint: false, action: false, actionHeld: 0,
  pass: false, steal: false,
};

/** Expands a recording back into per-tick intents. */
export class ReplayPlayer {
  private runIndex = 0;
  private withinRun = 0;
  public tick = 0;
  public readonly data: ReplayData;

  constructor(data: ReplayData) { this.data = data; }

  get finished(): boolean { return this.tick >= this.data.header.totalTicks; }

  /**
   * The intent for the current tick; advances by one.
   *
   * Past the end it returns IDLE rather than looping or throwing. A ghost that
   * finishes its run should stand still, not restart mid-match.
   */
  next(): Intent {
    const run = this.data.runs[this.runIndex];
    if (!run) return IDLE_INTENT;
    const out = unpack(run.i);
    this.tick++;
    this.withinRun++;
    if (this.withinRun >= run.n) { this.runIndex++; this.withinRun = 0; }
    return out;
  }

  /** Jump to a tick. O(runs), which is fine — used for scrubbing, not per-frame. */
  seek(tick: number): void {
    this.runIndex = 0; this.withinRun = 0; this.tick = 0;
    let remaining = Math.max(0, tick);
    while (remaining > 0 && this.runIndex < this.data.runs.length) {
      const run = this.data.runs[this.runIndex];
      if (remaining >= run.n - this.withinRun) {
        remaining -= run.n - this.withinRun;
        this.tick += run.n - this.withinRun;
        this.runIndex++; this.withinRun = 0;
      } else {
        this.withinRun += remaining; this.tick += remaining; remaining = 0;
      }
    }
  }

  reset(): void { this.runIndex = 0; this.withinRun = 0; this.tick = 0; }
}

/**
 * Why this replay cannot be trusted, or null if it can.
 *
 * Called BEFORE playback. A replay that will not reproduce must be refused
 * outright — silently playing a desynced ghost is worse than showing no
 * ghost, because the player has no way to know the opponent they lost to was
 * never real.
 */
export function validateReplay(
  data: ReplayData, modeId: string, dt: number,
): string | null {
  const h = data.header;
  if (h.version !== REPLAY_VERSION) {
    return `recorded in format v${h.version}, this build reads v${REPLAY_VERSION}`;
  }
  if (h.modeId !== modeId) return `recorded in "${h.modeId}", not "${modeId}"`;
  if (Math.abs(h.dt - dt) > 1e-9) {
    return `recorded at ${(1 / h.dt).toFixed(0)}Hz, this build simulates at ${(1 / dt).toFixed(0)}Hz`;
  }
  if (!Number.isFinite(h.seed)) return 'no seed — the match cannot be reproduced';
  const declared = data.runs.reduce((n, r) => n + r.n, 0);
  if (declared !== h.totalTicks) {
    return `truncated: header claims ${h.totalTicks} ticks, stream holds ${declared}`;
  }
  return null;
}

export function serialiseReplay(data: ReplayData): string {
  return JSON.stringify({
    h: data.header,
    r: data.runs.map((run) => [...run.i, run.n]),
  });
}

/** Returns null on anything malformed. A corrupt ghost must never take a mode
 *  down — the match still has to start. */
export function parseReplay(json: string): ReplayData | null {
  try {
    const raw = JSON.parse(json) as { h: ReplayHeader; r: number[][] };
    if (!raw?.h || !Array.isArray(raw.r)) return null;
    return {
      header: raw.h,
      runs: raw.r.map((a) => ({ i: [a[0], a[1], a[2], a[3]] as PackedIntent, n: a[4] })),
    };
  } catch {
    return null;
  }
}
