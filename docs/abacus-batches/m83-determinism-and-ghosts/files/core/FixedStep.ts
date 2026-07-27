// FixedStep — a simulation clock that produces the same result every time.
//
// WHY THIS IS THE KEYSTONE OF EVERYTHING AFTER IT
// Today every mode updates like this:
//
//     const dt = engine.getDeltaTime() / 1000;
//     if (phase === 'playing') def.update(ctx, dt);
//
// `dt` is whatever the last frame happened to take: 16.7ms on a good frame,
// 31ms when the GC ran, 120ms when the tab was backgrounded. Physics
// integrated against a variable dt gives a different answer every run. That
// means:
//
//   · A GHOST CANNOT BE EXACT. Replaying the same inputs on a machine with a
//     different frame rate produces a different match. Every recorded
//     opponent would drift out of sync, and the drift is worst exactly when
//     it matters — during the busy frames.
//   · NO NETCODE IS POSSIBLE. Lockstep and rollback both require two machines
//     that agree, given the same inputs, on the same state.
//   · NO BUG IS REPRODUCIBLE. "It happened once" stays "it happened once".
//   · JUMP HEIGHT DEPENDS ON FRAME RATE. A player on a 120Hz phone and one on
//     a throttled 30Hz browser are not playing the same game.
//
// The fix is the standard one and it is not optional: accumulate real time,
// consume it in FIXED slices, and interpolate the render between them.

/** The simulation tick. 60Hz — matches the render target and divides evenly
 *  into the 120Hz and 30Hz cases without remainder drift. */
export const FIXED_DT = 1 / 60;

/**
 * Never run more than this many ticks in one frame.
 *
 * Without a cap, a long stall produces a huge accumulator, which produces many
 * ticks, which takes longer than a frame, which grows the accumulator further.
 * That is the "spiral of death", and it turns a one-off hitch into a hang.
 * Five ticks is ~83ms of simulation per frame: enough to absorb a GC pause,
 * far short of enough to lock the tab.
 */
export const MAX_TICKS_PER_FRAME = 5;

/**
 * Ignore any frame longer than this.
 *
 * A backgrounded tab returns a `dt` of seconds or minutes. Simulating that is
 * both pointless and dangerous — the player was not there. Time is discarded
 * rather than banked.
 */
export const MAX_FRAME_SEC = 0.25;

/**
 * Tolerance on the "has a whole tick accumulated?" comparison.
 *
 * NOT cosmetic — this was a real desync. `1/144` is not exactly representable
 * in binary floating point, so 288 frames at 144Hz accumulate to
 * 1.999999999999994, which is 6e-15 SHORT of two seconds. The 120th tick never
 * fires. A player on a 144Hz display therefore falls one tick behind a 60Hz
 * player every two seconds — about 30 ticks a minute — and any ghost recorded
 * on one and replayed on the other drifts apart permanently.
 *
 * The epsilon is relative to dt and works out at ~17 nanoseconds: far larger
 * than any accumulated float error, far smaller than any real quantity of
 * time. Measured, not guessed.
 */
const TICK_EPSILON_FACTOR = 1e-6;

export interface StepResult {
  /** How many fixed ticks to run this frame. */
  ticks: number;
  /** 0..1 through the next tick — for interpolating the RENDER only. */
  alpha: number;
  /** True if time was discarded because the frame was absurdly long. */
  stalled: boolean;
}

/**
 * The accumulator.
 *
 * Holds no game state. It answers exactly one question — "how many simulation
 * ticks does this frame owe?" — and it is the only place in the codebase
 * allowed to look at wall-clock time.
 */
export class FixedStep {
  private accumulator = 0;
  /** Monotonic simulation tick since start. THE authoritative clock: replays,
   *  scheduling and netcode all index on this, never on Date.now(). */
  public tick = 0;
  public readonly dt: number;

  constructor(dt: number = FIXED_DT) { this.dt = dt; }

  /** Feed real elapsed seconds; get back how much simulation to run. */
  advance(frameSec: number): StepResult {
    let stalled = false;
    let f = frameSec;
    if (!Number.isFinite(f) || f < 0) f = 0;
    if (f > MAX_FRAME_SEC) { f = this.dt; stalled = true; }

    this.accumulator += f;
    const threshold = this.dt - this.dt * TICK_EPSILON_FACTOR;
    let ticks = 0;
    while (this.accumulator >= threshold && ticks < MAX_TICKS_PER_FRAME) {
      this.accumulator -= this.dt;
      ticks++;
    }
    // Hit the cap: throw away the backlog rather than owing it forever. The
    // simulation falls behind wall-clock, which is correct — better slow than
    // spiralling.
    if (ticks >= MAX_TICKS_PER_FRAME && this.accumulator > this.dt) {
      this.accumulator = 0;
      stalled = true;
    }
    this.tick += ticks;
    return { ticks, alpha: this.accumulator / this.dt, stalled };
  }

  /** Simulated seconds since start. Derived from ticks, so it is identical on
   *  every machine that ran the same number of them. */
  get simTime(): number { return this.tick * this.dt; }

  reset(): void { this.accumulator = 0; this.tick = 0; }
}

/**
 * Interpolate a rendered value between the last two simulation states.
 *
 * The render must NEVER write back into the simulation — this produces a
 * display value only. Feeding an interpolated position back into physics
 * reintroduces frame-rate dependence through the back door, which is a
 * genuinely hard bug to see.
 */
export function lerp(prev: number, next: number, alpha: number): number {
  return prev + (next - prev) * alpha;
}

/** Shortest-path angular interpolation, for a rendered facing. */
export function lerpAngle(prevDeg: number, nextDeg: number, alpha: number): number {
  const d = ((((nextDeg - prevDeg) % 360) + 540) % 360) - 180;
  return prevDeg + d * alpha;
}

/**
 * Cheap 32-bit hash of a number sequence — a fingerprint of simulation state.
 *
 * Two runs that diverge produce different hashes within a tick or two of the
 * divergence, which turns "the ghost drifted somewhere in the last thirty
 * seconds" into "the ghost drifted at tick 1,847". FNV-1a: not cryptographic,
 * just well-distributed and fast enough to run every tick.
 */
export function stateHash(values: number[], seed = 0x811c9dc5): number {
  let h = seed >>> 0;
  for (const v of values) {
    // Quantise before hashing. Two machines can differ in the last bits of a
    // float without meaningfully diverging, and a hash that trips on that is
    // an alarm nobody will keep listening to.
    const q = Math.round(v * 1000) | 0;
    for (let i = 0; i < 4; i++) {
      h ^= (q >>> (i * 8)) & 0xff;
      h = Math.imul(h, 0x01000193) >>> 0;
    }
  }
  return h >>> 0;
}
