/**
 * Standing regression suite for the feel systems (DoD engineering checks).
 * These are the invariants that make "console feel" hold across changes:
 * frame-rate independence, buffered-input semantics, FSM contract,
 * arc-drive continuity, gravity-curve boundaries.
 */
import { FixedStepLoop } from '../core/FixedStepLoop.js';
import { InputBuffer } from '../systems/InputBuffer.js';
import { StateMachine } from '../systems/StateMachine.js';
import { ArcDrive } from '../systems/ArcDrive.js';
import { feelConfig } from '../systems/feelConfig.js';
import { VENICE_COURT_MANIFEST, validateManifestShape } from '../core/sceneManifest.js';

/** Minimal vertical simulator using the production gravity curve. */
function makeJumpSim() {
  const g = feelConfig.gravity;
  const state = { y: 0, vy: feelConfig.jump.impulse, landed: false };
  return {
    state,
    update(dt) {
      if (state.landed) return;
      const scale =
        state.vy > g.peakVelocityWindow ? g.ascentScale
        : state.vy >= -g.peakVelocityWindow ? g.peakScale
        : g.descentScale;
      state.vy -= g.base * scale * dt;
      state.y += state.vy * dt;
      if (state.y <= 0 && state.vy < 0) { state.y = 0; state.landed = true; }
    },
  };
}

/** Drive a loop with a fixed render cadence until N sim steps have run. */
function runAtFps(fps, steps) {
  const sim = makeJumpSim();
  const loop = new FixedStepLoop({
    hz: feelConfig.timestepHz,
    maxAccumulatedMs: feelConfig.maxAccumulatedMs,
    update: (dt) => sim.update(dt),
  });
  loop.start();
  const frameMs = 1000 / fps;
  while (loop.stepCount < steps) loop.tick(frameMs);
  return { y: sim.state.y, vy: sim.state.vy, steps: loop.stepCount };
}

describe('FixedStepLoop — frame-rate independence (DoD)', () => {
  test('same input produces the same arc at 30, 60, and 144 fps', () => {
    const at30 = runAtFps(30, 50);
    const at60 = runAtFps(60, 50);
    const at144 = runAtFps(144, 50);
    expect(at60.y).toBeCloseTo(at30.y, 9);
    expect(at144.y).toBeCloseTo(at30.y, 9);
    expect(at60.vy).toBeCloseTo(at30.vy, 9);
    expect(at144.vy).toBeCloseTo(at30.vy, 9);
  });

  test('runs at exactly the configured Hz', () => {
    const loop = new FixedStepLoop({ hz: 60, update: () => {} });
    loop.start();
    for (let i = 0; i < 120; i++) loop.tick(1000 / 60);
    expect(loop.stepCount).toBe(120);
  });

  test('hitStop freezes the sim and resumes cleanly', () => {
    let steps = 0;
    const loop = new FixedStepLoop({ hz: 60, update: () => { steps++; } });
    loop.start();
    loop.tick(16.7);
    loop.hitStop(100);
    const before = steps;
    for (let i = 0; i < 6; i++) loop.tick(16.7); // ~100ms frozen
    expect(steps).toBe(before);
    for (let i = 0; i < 6; i++) loop.tick(16.7); // resumed
    expect(steps).toBeGreaterThan(before);
  });

  test('spiral-of-death clamp bounds catch-up work', () => {
    let steps = 0;
    const loop = new FixedStepLoop({ hz: 60, maxAccumulatedMs: 250, update: () => { steps++; } });
    loop.start();
    loop.tick(10_000); // tab slept 10s
    expect(steps).toBeLessThanOrEqual(Math.ceil(250 / (1000 / 60)));
  });
});

describe('InputBuffer — buffered-press semantics (DoD)', () => {
  test('fires within the window, once, and expires outside it', () => {
    let now = 0;
    const buf = new InputBuffer({ windowMs: 150, now: () => now });
    buf.press('jump');
    now = 100;
    expect(buf.consume('jump')).toBe(true);   // within window
    expect(buf.consume('jump')).toBe(false);  // single-fire
    buf.press('jump');
    now = 300;
    expect(buf.consume('jump')).toBe(false);  // expired (200ms later)
  });
});

describe('StateMachine — contract', () => {
  test('enter/exit hooks fire in order; self-transition is a no-op', () => {
    const log = [];
    const sm = new StateMachine({
      initial: 'A',
      states: {
        A: { enter: () => log.push('A+'), exit: () => log.push('A-') },
        B: { enter: () => log.push('B+') },
      },
    });
    expect(sm.transition('A')).toBe(false);
    expect(sm.transition('B')).toBe(true);
    expect(log).toEqual(['A+', 'A-', 'B+']);
    expect(sm.previous).toBe('A');
  });
});

describe('ArcDrive — continuity (DoD: never jerks)', () => {
  test('ends exactly at the target with bounded per-step displacement', () => {
    const arc = new ArcDrive();
    const pos = { x: 0, y: 1.0, z: -9 };
    arc.begin({
      start: pos,
      target: { x: 0, y: feelConfig.dunkArc.rimApproachY, z: -12.7 },
      apexY: 1.0 + feelConfig.dunkArc.apexBoostM,
      durationMs: feelConfig.dunkArc.durationMs,
    });
    let prevY = pos.y; let prevZ = pos.z;
    let maxStep = 0; let done = false; let guard = 0;
    while (!done && guard++ < 200) {
      done = arc.advance(1 / 60, pos);
      maxStep = Math.max(maxStep, Math.hypot(pos.y - prevY, pos.z - prevZ));
      prevY = pos.y; prevZ = pos.z;
    }
    expect(done).toBe(true);
    expect(pos.z).toBeCloseTo(-12.7, 6);
    expect(pos.y).toBeCloseTo(feelConfig.dunkArc.rimApproachY, 6);
    expect(maxStep).toBeLessThan(0.25);                    // no teleports
    expect(arc.endVerticalVelocity()).toBeLessThan(0);     // handing back falling
    expect(Number.isFinite(arc.endVerticalVelocity())).toBe(true);
  });
});

describe('sceneManifest — shape contract', () => {
  test('the Venice manifest is well-formed', () => {
    const r = validateManifestShape(VENICE_COURT_MANIFEST);
    expect(r.ok).toBe(true);
    expect(VENICE_COURT_MANIFEST.requiredNodes).toContain('hoop');
    expect(VENICE_COURT_MANIFEST.requiredNodes).toContain('backboard');
  });

  test('court archetype without a player spawn fails', () => {
    const r = validateManifestShape({
      sceneId: 'x', mode: 'y', archetype: 'court-free-3d',
      requiredNodes: ['court'], spawnPoints: [],
    });
    expect(r.ok).toBe(false);
    expect(r.problems.join()).toMatch(/spawn/);
  });
});

describe('feelConfig — gravity curve boundaries', () => {
  test('curve values keep the arc finite and snappy', () => {
    const g = feelConfig.gravity;
    expect(g.peakScale).toBeGreaterThan(0);        // exactly 0 = never falls
    expect(g.descentScale).toBeGreaterThan(g.ascentScale); // snappy, not floaty
    expect(g.peakVelocityWindow).toBeGreaterThan(0);
  });

  test('a full jump lands (no infinite float) and hangs at the peak', () => {
    const sim = makeJumpSim();
    let peakSteps = 0; let totalSteps = 0;
    const g = feelConfig.gravity;
    while (!sim.state.landed && totalSteps < 60 * 10) {
      sim.update(1 / 60);
      totalSteps++;
      if (Math.abs(sim.state.vy) <= g.peakVelocityWindow) peakSteps++;
    }
    expect(sim.state.landed).toBe(true);           // finite arc
    expect(peakSteps * (1000 / 60)).toBeGreaterThan(300); // visible hang (>300ms)
  });
});
