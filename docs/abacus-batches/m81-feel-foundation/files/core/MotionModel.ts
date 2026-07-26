// MotionModel — the layer between "a key is down" and "the character moves".
//
// This layer never existed. Intent went from the input bus almost straight to
// a position, and that is why movement reads as broken in every 3-D mode at
// once. Nine specific defects, all in code this repo has shipped:
//
//   a) THE PLAYER IS ALWAYS SPRINTING. LocalInputSource sets
//      `sprint: Math.hypot(moveX, moveY) > 0.85`, and keyboard WASD emits
//      x,y ∈ {-1,0,1} — a single key held is magnitude 1.0. There is no walk
//      speed, anywhere, on keyboard. This one line is most of the problem.
//   b) Diagonals are 41% faster. hypot(1,1) = 1.414 and nothing normalises it.
//   c) The stick is digital. 0 → max → 0 in one frame. Weightless and twitchy.
//   d) Keys stick on blur — handled in InputBus v3, not here.
//   e) A hard deadzone cliff: |v| < 0.15 ? 0 : v. At 0.149 you get nothing, at
//      0.151 you get 0.151. Motion appears out of nowhere.
//   f) No turn rate. Facing snaps, so the character has no weight.
//   g) No coyote time. Walking off a ledge and pressing jump does nothing.
//   h) No input buffer. A jump pressed 50ms before landing is swallowed.
//   i) Probably not camera-relative — "forward" changes meaning when the
//      camera swings. In a third-person game this is the single largest
//      contributor to feeling out of control.
//
// EVERYTHING HERE IS PURE. No Babylon, no DOM, no time source. `step()` takes
// the previous state and returns the next one. That is deliberate: movement
// feel is the hardest thing in this product to verify by looking at it, and
// the only way to hold it still is to make it arithmetic that a test can pin.

/** Tuned constants. Every one of these is a feel decision, so each is named. */
export interface MotionConfig {
  /** Radial deadzone, RESCALED so output is continuous from zero. */
  deadzone: number;
  /** ms for a standing start to reach full commanded speed. */
  accelMs: number;
  /** ms to come to rest. SHORTER than accel — stopping must feel crisp. */
  decelMs: number;
  /** Ground turn rate, deg/sec. Fast enough to obey, slow enough to have weight. */
  turnRateDeg: number;
  /** Air turn rate. Much lower: you commit to a jump. */
  airTurnRateDeg: number;
  /** Jump still allowed this long after leaving the ground. */
  coyoteMs: number;
  /** A jump pressed this long before landing still fires on touchdown. */
  bufferMs: number;
  /** Fraction of top speed when not sprinting. */
  walkFactor: number;
}

export const DEFAULT_MOTION: MotionConfig = {
  deadzone: 0.12,
  accelMs: 120,
  decelMs: 90,
  turnRateDeg: 540,
  airTurnRateDeg: 180,
  coyoteMs: 100,
  bufferMs: 130,
  walkFactor: 0.45,
};

export interface MotionInput {
  /** Raw stick, -1..1. Screen space: +y is "up"/forward on the stick. */
  x: number;
  y: number;
  /** EXPLICIT. Never derived from stick magnitude on a digital source. */
  sprint: boolean;
  /** Edge-triggered: true only on the frame the button went down. */
  jumpPressed: boolean;
  grounded: boolean;
  /** Camera yaw in degrees. Movement is expressed relative to this. */
  cameraYawDeg: number;
}

export interface MotionState {
  /** 0..1 of top speed. */
  speed: number;
  /** Unit world-space direction on the ground plane. Zero when idle. */
  dirX: number;
  dirZ: number;
  /** Degrees, world space. Lags dir by the turn rate — this is the weight. */
  facingDeg: number;
  coyoteLeft: number;
  bufferLeft: number;
  /** True for exactly one step when a jump should actually happen. */
  jumpFired: boolean;
  wasGrounded: boolean;
}

export const NEUTRAL_MOTION: MotionState = {
  speed: 0, dirX: 0, dirZ: 0, facingDeg: 0,
  coyoteLeft: 0, bufferLeft: 0, jumpFired: false, wasGrounded: true,
};

/**
 * Radial deadzone with rescale.
 *
 * The rescale is the whole point. A plain cutoff produces a step
 * discontinuity: nothing at 0.149, then 0.151 all at once. Rescaling maps the
 * live range back onto 0..1 so the smallest push you can feel produces the
 * smallest movement you can see. Magnitude is also clamped to 1, which is what
 * kills the 41%-faster diagonal.
 */
export function applyDeadzone(x: number, y: number, dz: number): { x: number; y: number; mag: number } {
  const raw = Math.hypot(x, y);
  if (raw <= dz) return { x: 0, y: 0, mag: 0 };
  const mag = Math.min(1, (raw - dz) / (1 - dz));
  return { x: (x / raw) * mag, y: (y / raw) * mag, mag };
}

/**
 * Stick space → world direction on the ground plane, relative to the camera.
 *
 * Yaw 0 means the camera looks along +Z, so "stick up" is +Z. Push the stick
 * up and the character goes away from the camera no matter where the camera
 * is — which is the entire definition of "I feel in control" in third person.
 */
export function cameraRelative(x: number, y: number, camYawDeg: number): { x: number; z: number } {
  const r = (camYawDeg * Math.PI) / 180;
  const s = Math.sin(r);
  const c = Math.cos(r);
  // forward = (sin, cos), right = (cos, -sin)
  return { x: y * s + x * c, z: y * c - x * s };
}

/**
 * Signed shortest angular difference in degrees, in **[-180, 180)**.
 *
 * Note the half-open interval: an exact 180° reversal returns -180, i.e. it
 * turns left. That direction is arbitrary — a perfect about-face has no short
 * way round — but it must be *consistent*, or a character asked to reverse
 * would jitter between turning left and right on alternate frames.
 */
export function angleDelta(fromDeg: number, toDeg: number): number {
  return ((((toDeg - fromDeg) % 360) + 540) % 360) - 180;
}

/** Normalise to [0, 360). */
export function wrap360(deg: number): number {
  return ((deg % 360) + 360) % 360;
}

/**
 * Move `current` toward `target` at a rate that crosses the full 0..1 range in
 * `ms` milliseconds — never overshooting.
 *
 * Framerate independence matters more than it looks: at 30fps a naive lerp
 * moves half as far per second as at 60fps, so the game would literally feel
 * different on a slower phone.
 */
export function approach(current: number, target: number, dt: number, ms: number): number {
  if (ms <= 0) return target;
  const step = dt / (ms / 1000);
  const d = target - current;
  if (Math.abs(d) <= step) return target;
  return current + Math.sign(d) * step;
}

/** Rotate `fromDeg` toward `toDeg`, capped at `rateDegPerSec`. */
export function approachAngle(fromDeg: number, toDeg: number, dt: number, rateDegPerSec: number): number {
  const d = angleDelta(fromDeg, toDeg);
  const max = rateDegPerSec * dt;
  if (Math.abs(d) <= max) return wrap360(toDeg);
  return wrap360(fromDeg + Math.sign(d) * max);
}

/**
 * Advance the motion state by one frame.
 *
 * Returns a NEW state — never mutates. `jumpFired` is true for exactly one
 * step, so a caller can act on it without tracking edges itself.
 */
export function step(
  prev: MotionState, input: MotionInput, dt: number, cfg: MotionConfig = DEFAULT_MOTION,
): MotionState {
  const { x, y, mag } = applyDeadzone(input.x, input.y, cfg.deadzone);

  // Commanded speed. Sprint is a decision the player makes, never something
  // inferred from how hard a digital key is pressed — that inference is the
  // always-sprinting bug.
  const ceiling = input.sprint ? 1 : cfg.walkFactor;
  const target = mag * ceiling;

  // Accelerating and decelerating are different feels and get different rates.
  const speed = approach(prev.speed, target, dt, target > prev.speed ? cfg.accelMs : cfg.decelMs);

  // Direction is held while decelerating: a character that slides to a stop
  // keeps facing where it was going. Zeroing it here makes stopping snap.
  let dirX = prev.dirX;
  let dirZ = prev.dirZ;
  let facingDeg = prev.facingDeg;
  if (mag > 0) {
    const w = cameraRelative(x, y, input.cameraYawDeg);
    const len = Math.hypot(w.x, w.z) || 1;
    dirX = w.x / len;
    dirZ = w.z / len;
    const wantDeg = (Math.atan2(dirX, dirZ) * 180) / Math.PI;
    facingDeg = approachAngle(
      prev.facingDeg, wantDeg, dt,
      input.grounded ? cfg.turnRateDeg : cfg.airTurnRateDeg,
    );
  }

  // ── coyote time ──────────────────────────────────────────────────────
  // Refilled while grounded, drains in the air. Without it, walking off a
  // ledge and pressing jump does nothing, and the player blames themselves
  // for a frame they could not have hit.
  let coyoteLeft = input.grounded
    ? cfg.coyoteMs / 1000
    : Math.max(0, prev.coyoteLeft - dt);

  // ── input buffer ─────────────────────────────────────────────────────
  // A jump pressed slightly before landing fires on touchdown instead of
  // being swallowed. This is what makes repeated jumps feel responsive.
  let bufferLeft = input.jumpPressed ? cfg.bufferMs / 1000 : Math.max(0, prev.bufferLeft - dt);

  const jumpFired = bufferLeft > 0 && coyoteLeft > 0;
  if (jumpFired) { bufferLeft = 0; coyoteLeft = 0; }

  return {
    speed, dirX, dirZ, facingDeg,
    coyoteLeft, bufferLeft, jumpFired,
    wasGrounded: input.grounded,
  };
}

/**
 * Input→response latency budget, in milliseconds.
 *
 * 66ms is four frames at 60fps. Past roughly this point players stop
 * attributing the result to their own input, and no amount of animation
 * quality buys it back. Anything that adds latency — smoothing, buffering,
 * animation blend-in — spends from this budget.
 */
export const RESPONSE_BUDGET_MS = 66;

/**
 * Worst-case latency this config adds before movement is VISIBLE.
 *
 * Deliberately not "time to full speed": the player needs to see the
 * character react, not finish reacting. 20% of the accel ramp is the
 * threshold where movement reads as started.
 */
export function estimatedResponseMs(cfg: MotionConfig = DEFAULT_MOTION): number {
  return cfg.accelMs * 0.2 + 16.7; // ramp to visible + one frame of render
}
