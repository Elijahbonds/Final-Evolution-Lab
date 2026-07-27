// SimLoop — one object that turns a mode's variable-rate update into a
// deterministic, recordable one.
//
// Deliberately ADDITIVE rather than another ModeHarness rewrite. M81 already
// replaced ModeHarness; shipping a second competing copy here would make the
// two batches order-dependent and conflict-prone. This is a helper the harness
// calls in one line, so M83 can land whether or not M81 has.
//
// It also exists because "described precisely in a README" is the delivery
// mode that has already failed once in this project: M69's CameraStandoff was
// specified perfectly and never integrated, while groundSnap from the same
// batch did land. A concrete object gets wired; a paragraph gets skipped.
//
// WHAT IT OWNS
//   · the accumulator (so no mode touches wall-clock time)
//   · the per-tick record hook (so a ghost is a side effect, not a feature)
//   · the render alpha (so interpolation is available but never mandatory)

import { FixedStep, FIXED_DT, stateHash } from './FixedStep';
import { ReplayRecorder, type ReplayData } from './Replay';
import { Rng, reseedSession } from './Rng';
import type { Intent } from './PlayerSlot';

export interface SimLoopOptions {
  modeId: string;
  /** Omit for a fresh match; pass a ghost's seed to replay its conditions. */
  seed?: number;
  /** PRQ at match start. Stored in the recording so DDA restores identically. */
  playerPRQ: number;
  /** Record this match? Off by default — recording every session is storage
   *  nobody asked for. Turn it on for a ranked run or a ghost attempt. */
  record?: boolean;
  /** Sample a state fingerprint each tick. Dev only: it is the raw material
   *  for verifyDeterminism() and costs a hash per tick. */
  captureHashes?: boolean;
}

export class SimLoop {
  readonly clock: FixedStep;
  readonly rng: Rng;
  readonly modeId: string;
  private recorder: ReplayRecorder | null;
  private hashes: number[] = [];
  private capture: boolean;
  /** 0..1 through the next tick. Read by the RENDER only. */
  public alpha = 0;

  constructor(opts: SimLoopOptions) {
    this.modeId = opts.modeId;
    this.clock = new FixedStep(FIXED_DT);
    this.rng = reseedSession(opts.seed);
    this.capture = opts.captureHashes ?? false;
    this.recorder = opts.record
      ? new ReplayRecorder(opts.modeId, this.rng.seed, opts.playerPRQ, FIXED_DT)
      : null;
  }

  /**
   * Call once per RENDERED frame. Runs zero or more fixed simulation ticks.
   *
   * `tickFn` receives the FIXED dt, never the frame's. That is the whole
   * point, and it is the one thing a mode must not work around: reaching for
   * `engine.getDeltaTime()` inside `tickFn` reintroduces every problem this
   * file exists to remove.
   *
   * `intentFn` supplies the intent that tick consumed, so recording happens
   * here rather than in every mode. A mode that does not use PlayerSlot can
   * omit it and still get determinism, just no ghost.
   */
  frame(
    frameSec: number,
    tickFn: (dt: number, tick: number) => void,
    intentFn?: () => Intent,
    stateFn?: () => number[],
  ): number {
    const r = this.clock.advance(frameSec);
    for (let i = 0; i < r.ticks; i++) {
      const intent = intentFn?.();
      tickFn(FIXED_DT, this.clock.tick - r.ticks + i);
      if (intent && this.recorder) this.recorder.record(intent);
      if (this.capture && stateFn) this.hashes.push(stateHash(stateFn()));
    }
    this.alpha = r.alpha;
    if (r.stalled) {
      console.warn(`[FEL-SIM] ${this.modeId}: frame stall at tick ${this.clock.tick}. `
        + 'Simulation time was discarded — a recording made across this point may not replay.');
    }
    return r.ticks;
  }

  get tick(): number { return this.clock.tick; }
  get simTime(): number { return this.clock.simTime; }
  get recording(): boolean { return this.recorder !== null; }
  /** Dev-only fingerprints, for verifyDeterminism(). */
  get capturedHashes(): readonly number[] { return this.hashes; }

  /**
   * Close out the recording.
   *
   * Returns null when not recording, so a caller can always call it. The final
   * hash goes into the header: a server re-simulating this match compares
   * against it and can tell a genuine result from a tampered one.
   */
  finish(score: number, outcome: string): ReplayData | null {
    if (!this.recorder) return null;
    const final = this.hashes.length ? this.hashes[this.hashes.length - 1] : undefined;
    const data = this.recorder.finish(score, outcome, final);
    console.info(`[FEL-SIM] ${this.modeId}: recorded ${data.header.totalTicks} ticks `
      + `in ${data.runs.length} runs (seed ${data.header.seed}).`);
    return data;
  }
}
