// node --experimental-strip-types tests/motion_test.ts
//
// Movement feel is the hardest thing in this product to verify by looking at
// it — "does it feel right" is not a check anyone can run. So the model is
// pure arithmetic and these tests pin the arithmetic. Each of the nine
// defects named in MotionModel.ts has a test that fails if it comes back.

import {
  applyDeadzone, cameraRelative, angleDelta, wrap360, approach, approachAngle,
  step, DEFAULT_MOTION, NEUTRAL_MOTION, estimatedResponseMs, RESPONSE_BUDGET_MS,
  type MotionInput, type MotionState,
} from '../core/MotionModel.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };
const near = (a: number, b: number, eps = 1e-6) => Math.abs(a - b) < eps;

// ── deadzone ─────────────────────────────────────────────────────────────
ok('centre is dead', applyDeadzone(0, 0, 0.12).mag === 0);
ok('inside the deadzone is dead', applyDeadzone(0.1, 0, 0.12).mag === 0);
ok('exactly at the edge is dead', applyDeadzone(0.12, 0, 0.12).mag === 0);

const justOut = applyDeadzone(0.13, 0, 0.12);
ok('just outside is a TINY value, not a jump', justOut.mag > 0 && justOut.mag < 0.02,
  `got ${justOut.mag}`);

ok('full deflection is full magnitude', near(applyDeadzone(1, 0, 0.12).mag, 1));
ok('deadzone rescale is continuous',
  applyDeadzone(0.121, 0, 0.12).mag < applyDeadzone(0.2, 0, 0.12).mag);

// THE DIAGONAL BUG
const diag = applyDeadzone(1, 1, 0.12);
ok('DEFECT b: diagonals are NOT faster than cardinals', near(diag.mag, 1),
  `diagonal magnitude ${diag.mag}, should be 1`);
ok('diagonal direction is preserved', near(diag.x, diag.y));
ok('diagonal components are 1/√2', near(diag.x, Math.SQRT1_2, 1e-6));

ok('deadzone is radial, not per-axis',
  applyDeadzone(0.09, 0.09, 0.12).mag > 0,
  'a 0.127-magnitude diagonal push must register');

// ── camera-relative basis ────────────────────────────────────────────────
const fwd0 = cameraRelative(0, 1, 0);
ok('DEFECT i: at yaw 0, stick-up is +Z', near(fwd0.x, 0) && near(fwd0.z, 1));

const fwd90 = cameraRelative(0, 1, 90);
ok('at yaw 90, stick-up is +X', near(fwd90.x, 1, 1e-9) && near(fwd90.z, 0, 1e-9));

const fwd180 = cameraRelative(0, 1, 180);
ok('at yaw 180, stick-up is -Z', near(fwd180.z, -1, 1e-9));

const right0 = cameraRelative(1, 0, 0);
ok('at yaw 0, stick-right is +X', near(right0.x, 1) && near(right0.z, 0));

const right90 = cameraRelative(1, 0, 90);
ok('at yaw 90, stick-right is -Z', near(right90.z, -1, 1e-9));

ok('rotation preserves magnitude at every yaw',
  [0, 37, 90, 180, 271, 359].every((yaw) => {
    const v = cameraRelative(0.6, 0.8, yaw);
    return near(Math.hypot(v.x, v.z), 1, 1e-9);
  }));

// ── angles ───────────────────────────────────────────────────────────────
ok('angleDelta takes the short way round', angleDelta(350, 10) === 20);
ok('angleDelta signs correctly backwards', angleDelta(10, 350) === -20);
ok('angleDelta of nothing is nothing', angleDelta(90, 90) === 0);
ok('angleDelta at exactly 180 does not oscillate', Math.abs(angleDelta(0, 180)) === 180);
ok('wrap360 handles negatives', wrap360(-90) === 270);
ok('wrap360 handles overflow', wrap360(450) === 90);

// ── approach ─────────────────────────────────────────────────────────────
ok('approach reaches the target in exactly the stated time',
  near(approach(0, 1, 0.12, 120), 1));
ok('approach is half-way at half the time', near(approach(0, 1, 0.06, 120), 0.5));
ok('approach never overshoots', approach(0.99, 1, 1.0, 120) === 1);
ok('approach works downward too', near(approach(1, 0, 0.045, 90), 0.5));
ok('approach with 0ms is instant', approach(0, 1, 0.001, 0) === 1);

// FRAMERATE INDEPENDENCE — the same wall-clock, different frame rates
const at60 = Array.from({ length: 6 }).reduce<number>((v) => approach(v, 1, 1 / 60, 100), 0);
const at30 = Array.from({ length: 3 }).reduce<number>((v) => approach(v, 1, 1 / 30, 100), 0);
ok('accel is framerate independent', near(at60, at30, 1e-9), `${at60} vs ${at30}`);

ok('approachAngle respects the rate cap', near(approachAngle(0, 90, 0.1, 540), 54));
// An exact 180° reversal has no short way round. The direction is arbitrary;
// what matters is that it moves exactly the capped amount and picks the SAME
// side every time — otherwise a reversing character jitters left/right on
// alternate frames.
ok('a 180° reversal turns by exactly the cap',
  near(Math.abs(angleDelta(0, approachAngle(0, 180, 0.1, 540))), 54));
ok('a 180° reversal is deterministic',
  approachAngle(0, 180, 0.1, 540) === approachAngle(0, 180, 0.1, 540));
ok('approachAngle snaps when within the cap', approachAngle(0, 10, 0.1, 540) === 10);
ok('approachAngle goes the short way', near(approachAngle(350, 10, 1, 5), 355));

// ── step(): the whole model ──────────────────────────────────────────────
const input = (o: Partial<MotionInput> = {}): MotionInput => ({
  x: 0, y: 0, sprint: false, jumpPressed: false, grounded: true, cameraYawDeg: 0, ...o,
});
const run = (frames: number, i: MotionInput, from: MotionState = NEUTRAL_MOTION, dt = 1 / 60) => {
  let s = from;
  for (let n = 0; n < frames; n++) s = step(s, i, dt);
  return s;
};

// THE HEADLINE BUG
const walking = run(60, input({ y: 1, sprint: false }));
ok('DEFECT a: holding forward WALKS, it does not sprint',
  near(walking.speed, DEFAULT_MOTION.walkFactor, 1e-6), `speed ${walking.speed}`);

const sprinting = run(60, input({ y: 1, sprint: true }));
ok('sprint reaches full speed', near(sprinting.speed, 1, 1e-6));
ok('sprinting is meaningfully faster than walking', sprinting.speed > walking.speed * 2);

const diagWalk = run(60, input({ x: 1, y: 1, sprint: false }));
ok('DEFECT b at the model level: diagonal walk == straight walk',
  near(diagWalk.speed, walking.speed, 1e-6));

// DEFECT c — the ramp exists
const oneFrame = step(NEUTRAL_MOTION, input({ y: 1, sprint: true }), 1 / 60);
ok('DEFECT c: speed ramps rather than snapping to max',
  oneFrame.speed > 0 && oneFrame.speed < 0.2, `${oneFrame.speed}`);

// stopping
const stopping = run(10, input(), sprinting);
ok('releasing the stick decelerates', stopping.speed < sprinting.speed);
ok('deceleration is quicker than acceleration',
  DEFAULT_MOTION.decelMs < DEFAULT_MOTION.accelMs);
ok('comes fully to rest', near(run(60, input(), sprinting).speed, 0));
ok('facing is HELD while stopping, not reset',
  near(run(60, input(), sprinting).facingDeg, sprinting.facingDeg));

// DEFECT f — turn rate
const facingNorth = run(60, input({ y: 1 }));
ok('running forward faces +Z (0°)', near(wrap360(facingNorth.facingDeg), 0, 1e-6));
const turned = step(facingNorth, input({ x: 1, y: 0 }), 1 / 60);
ok('DEFECT f: facing turns at a capped rate, it does not snap',
  turned.facingDeg > 0 && turned.facingDeg < 90, `${turned.facingDeg}`);
ok('a full 90° turn completes in about 1/6 s at 540°/s',
  near(run(11, input({ x: 1, y: 0 }), facingNorth).facingDeg, 90, 1e-6));
ok('air turning is slower than ground turning',
  step(facingNorth, input({ x: 1, y: 0, grounded: false }), 1 / 60).facingDeg
  < step(facingNorth, input({ x: 1, y: 0, grounded: true }), 1 / 60).facingDeg);

// camera-relative at the model level
const camSwung = run(60, input({ y: 1, sprint: true, cameraYawDeg: 90 }));
ok('DEFECT i: swinging the camera changes where forward goes',
  near(camSwung.dirX, 1, 1e-6) && near(camSwung.dirZ, 0, 1e-9));
ok('facing follows the camera-relative direction',
  near(wrap360(camSwung.facingDeg), 90, 1e-6));

// DEFECT g — coyote time
let s: MotionState = run(30, input({ y: 1 }));
ok('grounded keeps coyote topped up', near(s.coyoteLeft, DEFAULT_MOTION.coyoteMs / 1000));
s = step(s, input({ y: 1, grounded: false }), 0.05);      // 50ms after leaving
const coyoteJump = step(s, input({ y: 1, grounded: false, jumpPressed: true }), 1 / 60);
ok('DEFECT g: a jump just after leaving the ground still fires', coyoteJump.jumpFired);

let late = run(30, input({ y: 1 }));
late = step(late, input({ y: 1, grounded: false }), 0.2); // 200ms — well past
const lateJump = step(late, input({ y: 1, grounded: false, jumpPressed: true }), 1 / 60);
ok('but a jump long after leaving does NOT fire', !lateJump.jumpFired);

// DEFECT h — input buffer
let air = run(30, input({ y: 1 }));
air = step(air, input({ y: 1, grounded: false }), 0.5);   // airborne, coyote spent
const buffered = step(air, input({ y: 1, grounded: false, jumpPressed: true }), 1 / 60);
ok('a jump pressed mid-air does not fire immediately', !buffered.jumpFired);
const onLanding = step(buffered, input({ y: 1, grounded: true }), 1 / 60);
ok('DEFECT h: …but fires on landing, from the buffer', onLanding.jumpFired);

const stale = step(
  step(buffered, input({ y: 1, grounded: false }), 0.2),   // buffer expires
  input({ y: 1, grounded: true }), 1 / 60,
);
ok('a stale buffered jump does not fire', !stale.jumpFired);

const held = step(onLanding, input({ y: 1, grounded: true, jumpPressed: false }), 1 / 60);
ok('jumpFired is a one-frame edge, not a level', !held.jumpFired);

// ── purity and safety ────────────────────────────────────────────────────
const before = { ...NEUTRAL_MOTION };
step(NEUTRAL_MOTION, input({ y: 1, jumpPressed: true }), 1 / 60);
ok('step does not mutate its input state',
  JSON.stringify(before) === JSON.stringify(NEUTRAL_MOTION));

ok('a huge dt does not produce NaN or overshoot',
  (() => { const r = step(NEUTRAL_MOTION, input({ y: 1, sprint: true }), 5); return r.speed === 1 && Number.isFinite(r.facingDeg); })());
ok('a zero dt is a no-op on speed', step(NEUTRAL_MOTION, input({ y: 1 }), 0).speed === 0);
ok('out-of-range stick input is clamped, not amplified',
  near(run(60, input({ x: 5, y: 5, sprint: true })).speed, 1, 1e-6));

// ── the latency budget ───────────────────────────────────────────────────
ok(`response estimate is inside the ${RESPONSE_BUDGET_MS}ms budget`,
  estimatedResponseMs() < RESPONSE_BUDGET_MS, `${estimatedResponseMs().toFixed(1)}ms`);
ok('a sloppier accel ramp would blow the budget',
  estimatedResponseMs({ ...DEFAULT_MOTION, accelMs: 400 }) > RESPONSE_BUDGET_MS);

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
