// node --experimental-strip-types tests/determinism_test.ts
//
// Determinism is a property you cannot see by looking. A simulation that
// diverges on one machine in a hundred looks perfect on yours, and the symptom
// — a ghost that drifts, a prize match that cannot be audited — appears far
// from the cause.
//
// So the centrepiece here is not a unit test. It is a full record-and-replay
// round trip through a toy simulation that uses the fixed step, the seeded RNG
// and the replay format together, asserting the second run is bit-identical to
// the first. That is the actual claim this batch makes.

import {
  FixedStep, FIXED_DT, MAX_TICKS_PER_FRAME, MAX_FRAME_SEC,
  lerp, lerpAngle, stateHash,
} from '../core/FixedStep.ts';
import { Rng } from '../core/Rng.ts';
import {
  ReplayRecorder, ReplayPlayer, validateReplay, serialiseReplay, parseReplay,
  quantise, dequantise, pack, unpack, REPLAY_VERSION, IDLE_INTENT,
  type ReplayData,
} from '../core/Replay.ts';
import {
  GhostSource, ghostFidelity, ghostsSuitable, verifyDeterminism, GHOST_FIDELITY,
} from '../core/GhostSource.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };
const near = (a: number, b: number, eps = 1e-9) => Math.abs(a - b) < eps;

type Intent = ReturnType<typeof unpack>;
const intent = (o: Partial<Intent> = {}): Intent => ({ ...IDLE_INTENT, ...o });

// ── FixedStep ────────────────────────────────────────────────────────────
{
  const fs = new FixedStep();
  ok('a perfect 60Hz frame is one tick', fs.advance(FIXED_DT).ticks === 1);
  ok('the tick counter advances', fs.tick === 1);
  ok('half a frame is no tick', fs.advance(FIXED_DT / 2).ticks === 0);
  ok('the remainder is banked, not lost', fs.advance(FIXED_DT / 2).ticks === 1);
}
{
  const fs = new FixedStep();
  ok('a 30Hz frame is two ticks', fs.advance(1 / 30).ticks === 2);
}
{
  // THE POINT: total simulated ticks must not depend on frame rate.
  const at60 = new FixedStep();
  for (let i = 0; i < 120; i++) at60.advance(1 / 60);
  const at30 = new FixedStep();
  for (let i = 0; i < 60; i++) at30.advance(1 / 30);
  const at144 = new FixedStep();
  for (let i = 0; i < 288; i++) at144.advance(1 / 144);
  ok('THE POINT: 2 seconds is 120 ticks at 60, 30 and 144 Hz',
    at60.tick === 120 && at30.tick === 120 && at144.tick === 120,
    `${at60.tick} / ${at30.tick} / ${at144.tick}`);
  ok('simTime is derived from ticks, so it matches too',
    near(at60.simTime, 2) && near(at144.simTime, 2));
}
{
  // Jittery real-world frames must still land on the right tick count.
  const fs = new FixedStep();
  const jitter = [0.016, 0.021, 0.009, 0.033, 0.014, 0.018, 0.012, 0.020];
  let total = 0;
  for (const f of jitter) { fs.advance(f); total += f; }
  ok('jittered frames still yield the right tick count',
    fs.tick === Math.floor(total / FIXED_DT), `${fs.tick} vs ${Math.floor(total / FIXED_DT)}`);
}
{
  const fs = new FixedStep();
  const r = fs.advance(10);
  ok('a backgrounded tab does not simulate ten seconds', r.ticks <= MAX_TICKS_PER_FRAME);
  ok('and it is reported as a stall', r.stalled);
  ok('discarded time is not banked for later', fs.advance(FIXED_DT).ticks === 1);
}
{
  // A frame long enough to owe more than the cap, but SHORT enough that the
  // discard-absurd-frames guard does not fire first. 0.2s is 12 ticks owed
  // against a cap of 5, and sits under MAX_FRAME_SEC.
  const fs = new FixedStep();
  const r = fs.advance(0.2);
  ok('SPIRAL OF DEATH: ticks are capped', r.ticks === MAX_TICKS_PER_FRAME, `${r.ticks}`);
  ok('the backlog is dropped rather than owed forever', r.stalled);
  ok('and the dropped backlog really is gone', fs.advance(FIXED_DT).ticks === 1);
}
{
  const fs = new FixedStep();
  ok('a negative dt is ignored, not run backwards', fs.advance(-5).ticks === 0);
  ok('NaN is ignored', fs.advance(NaN).ticks === 0 && fs.tick === 0);
  // MAX_FRAME_SEC is 0.25s, which is 15 ticks — over the per-frame cap. So it
  // is not DISCARDED as absurd, but it IS reported as a stall by the tick cap.
  // Two different guards, and this frame trips the second one.
  const edge = new FixedStep().advance(MAX_FRAME_SEC);
  ok('a frame exactly at the discard threshold is not discarded outright',
    edge.ticks === MAX_TICKS_PER_FRAME);
  ok('but it is still reported as a stall, by the tick cap', edge.stalled);
}
{
  const fs = new FixedStep();
  fs.advance(FIXED_DT * 1.5);
  ok('alpha reports progress through the next tick', fs.advance(0).alpha > 0.4);
  fs.reset();
  ok('reset clears the clock', fs.tick === 0 && fs.advance(0).alpha === 0);
}

ok('lerp interpolates', lerp(0, 10, 0.25) === 2.5);
ok('lerpAngle takes the short way across 0', near(lerpAngle(350, 10, 0.5), 360));
ok('lerpAngle handles the plain case', near(lerpAngle(0, 90, 0.5), 45));

ok('stateHash is stable', stateHash([1, 2, 3]) === stateHash([1, 2, 3]));
ok('stateHash separates different states', stateHash([1, 2, 3]) !== stateHash([1, 2, 4]));
ok('stateHash is order-sensitive', stateHash([1, 2]) !== stateHash([2, 1]));
ok('stateHash tolerates sub-quantum float noise',
  stateHash([1.00000001]) === stateHash([1.0]),
  'an alarm that trips on the last bits of a float is one nobody keeps listening to');
ok('stateHash still catches a real difference', stateHash([1.002]) !== stateHash([1.0]));

// ── Rng ──────────────────────────────────────────────────────────────────
{
  const a = new Rng(12345);
  const b = new Rng(12345);
  ok('THE POINT: the same seed gives the same sequence',
    Array.from({ length: 50 }, () => a.next()).join()
    === Array.from({ length: 50 }, () => b.next()).join());
}
ok('different seeds give different sequences', new Rng(1).next() !== new Rng(2).next());
{
  const r = new Rng(7);
  const vals = Array.from({ length: 2000 }, () => r.next());
  ok('output stays in [0,1)', vals.every((v) => v >= 0 && v < 1));
  const mean = vals.reduce((s, v) => s + v, 0) / vals.length;
  ok('the distribution is roughly uniform', Math.abs(mean - 0.5) < 0.03, `mean ${mean}`);
  const buckets = new Array(10).fill(0);
  for (const v of vals) buckets[Math.floor(v * 10)]++;
  ok('every decile is populated', buckets.every((b) => b > 120), buckets.join(','));
  ok('draws are counted', r.draws === 2000);
}
{
  const r = new Rng(9);
  const ints = Array.from({ length: 500 }, () => r.int(1, 6));
  ok('int() is INCLUSIVE of both ends — matching Swift',
    ints.includes(1) && ints.includes(6) && ints.every((v) => v >= 1 && v <= 6));
  ok('int() with min === max is that value', r.int(3, 3) === 3);
  ok('an inverted range does not hang or NaN', r.int(5, 1) === 5);
}
{
  const r = new Rng(11);
  const src = [1, 2, 3, 4, 5];
  const sh = r.shuffle(src);
  ok('shuffle preserves every element', [...sh].sort().join() === src.join());
  ok('SHUFFLE IS NOT IN PLACE — a shared content pack must not be mutated',
    src.join() === '1,2,3,4,5');
  ok('the same seed shuffles the same way',
    new Rng(11).shuffle(src).join() === new Rng(11).shuffle(src).join());
  ok('pick returns undefined for an empty array, rather than throwing',
    r.pick([]) === undefined);
}
{
  const parent = new Rng(42);
  const ai = parent.fork('ai');
  const crowd = parent.fork('crowd');
  ok('forked streams are independent', ai.next() !== crowd.next());
  ok('a fork is reproducible from the parent seed',
    new Rng(42).fork('ai').next() === new Rng(42).fork('ai').next());
  // The reason forking exists at all:
  const before = new Rng(42).fork('ai');
  const afterAddingCrowdEffects = new Rng(42).fork('ai');
  for (let i = 0; i < 10; i++) new Rng(42).fork('crowd').next();
  ok('THE POINT OF FORKING: draining the crowd stream cannot change AI decisions',
    before.next() === afterAddingCrowdEffects.next());
}
{
  const r = new Rng(5);
  for (let i = 0; i < 10; i++) r.next();
  const snap = r.snapshot();
  const restored = Rng.restore(snap.seed, snap.state, snap.draws);
  ok('a mid-stream snapshot restores exactly', r.next() === restored.next());
}

// ── Replay format ────────────────────────────────────────────────────────
ok('quantise clamps above 1', quantise(5) === 127);
ok('quantise clamps below -1', quantise(-5) === -127);
ok('quantise round-trips within one step',
  Math.abs(dequantise(quantise(0.37)) - 0.37) < 1 / 127);
ok('zero survives exactly', dequantise(quantise(0)) === 0);

{
  const i = intent({ moveX: 0.5, moveY: -0.25, sprint: true, action: true, actionHeld: 0.8, steal: true });
  const back = unpack(pack(i));
  ok('every flag survives packing',
    back.sprint && back.action && back.steal && !back.pass);
  ok('analog values survive packing',
    Math.abs(back.moveX - 0.5) < 0.01 && Math.abs(back.moveY + 0.25) < 0.01);
}
{
  const rec = new ReplayRecorder('dunk', 999, 82, FIXED_DT);
  for (let i = 0; i < 100; i++) rec.record(intent({ moveY: 1 }));
  const data = rec.finish(42, 'WIN');
  ok('a held input compresses to ONE run', data.runs.length === 1);
  ok('the run carries its length', data.runs[0].n === 100);
  ok('the tick count is preserved', data.header.totalTicks === 100);
  ok('compression is what makes a ghost storable', rec.approxBytes < 400);
}
{
  const rec = new ReplayRecorder('dunk', 1, 75, FIXED_DT);
  for (let i = 0; i < 5; i++) rec.record(intent({ moveY: 1, action: true }));
  const data = rec.finish(1, 'WIN');
  ok('EDGES ARE NEVER MERGED — five shots stay five, not one held for five',
    data.runs.length === 5);
}
{
  const rec = new ReplayRecorder('karate', 1, 75, FIXED_DT);
  const script = [
    ...Array(30).fill(intent({ moveY: 1 })),
    intent({ moveY: 1, action: true }),
    ...Array(20).fill(intent({ moveX: -1 })),
    intent({ pass: true }),
    ...Array(10).fill(intent()),
  ];
  for (const i of script) rec.record(i);
  const data = rec.finish(7, 'WIN');

  const player = new ReplayPlayer(data);
  const out: Intent[] = [];
  while (!player.finished) out.push(player.next());
  ok('THE ROUND TRIP: every tick comes back', out.length === script.length);
  ok('and every tick comes back identical',
    out.every((o, i) => JSON.stringify(o) === JSON.stringify(unpack(pack(script[i])))));
  ok('past the end a ghost stands still rather than looping',
    JSON.stringify(player.next()) === JSON.stringify(IDLE_INTENT));

  player.seek(31);
  ok('seek lands on the right tick', player.tick === 31);
  ok('and on the right input', player.next().moveX < 0);

  const json = serialiseReplay(data);
  const back = parseReplay(json);
  ok('a replay survives serialisation', back !== null && back.header.totalTicks === data.header.totalTicks);
  ok('and its runs survive', back!.runs.length === data.runs.length);
  ok('a three-minute match is a few KB, not hundreds', json.length < 4000, `${json.length} bytes`);
}
ok('malformed JSON parses to null, never throws', parseReplay('{{{ not json') === null);
ok('valid JSON of the wrong shape parses to null', parseReplay('{"nope":1}') === null);

// ── validation: refuse anything that would not reproduce ─────────────────
{
  const base = new ReplayRecorder('dunk', 5, 75, FIXED_DT);
  for (let i = 0; i < 10; i++) base.record(intent({ moveY: 1 }));
  const good = base.finish(10, 'WIN');

  ok('a matching replay validates', validateReplay(good, 'dunk', FIXED_DT) === null);
  ok('a different mode is refused',
    /not "karate"/.test(validateReplay(good, 'karate', FIXED_DT) ?? ''));
  ok('A DIFFERENT TICK RATE IS REFUSED — it would silently desync',
    /Hz/.test(validateReplay(good, 'dunk', 1 / 30) ?? ''));

  const oldVersion: ReplayData = { ...good, header: { ...good.header, version: REPLAY_VERSION - 1 } };
  ok('an old format version is refused', validateReplay(oldVersion, 'dunk', FIXED_DT) !== null);

  const truncated: ReplayData = { ...good, header: { ...good.header, totalTicks: 999 } };
  ok('a TRUNCATED stream is caught',
    /truncated/.test(validateReplay(truncated, 'dunk', FIXED_DT) ?? ''));

  const seedless: ReplayData = { ...good, header: { ...good.header, seed: NaN } };
  ok('a replay with no seed is refused',
    /seed/.test(validateReplay(seedless, 'dunk', FIXED_DT) ?? ''));
}

// ── GhostSource ──────────────────────────────────────────────────────────
{
  const rec = new ReplayRecorder('dunk', 77, 88, FIXED_DT);
  for (let i = 0; i < 20; i++) rec.record(intent({ moveY: 1, sprint: i > 10 }));
  const data = rec.finish(31, 'WIN');

  const g = GhostSource.from(data, 'dunk', FIXED_DT);
  ok('a valid recording yields a ghost', g !== null);
  ok('the ghost carries its target score', g!.targetScore === 31);
  ok('and the PRQ it was recorded at — restore it or DDA diverges',
    g!.recordedPRQ === 88);
  ok('and the seed', g!.seed === 77);

  for (let i = 0; i < 20; i++) g!.poll();
  ok('the ghost finishes', g!.finished);
  ok('progress reaches 1', g!.progress === 1);
  ok('a finished ghost idles rather than restarting',
    JSON.stringify(g!.poll()) === JSON.stringify(IDLE_INTENT));

  g!.reset();
  ok('reset rewinds', !g!.finished && g!.progress === 0);

  ok('A GHOST THAT CANNOT REPRODUCE IS REFUSED, NOT PLAYED',
    GhostSource.from(data, 'karate', FIXED_DT) === null);
  ok('a null recording is handled', GhostSource.from(null, 'dunk', FIXED_DT) === null);
}
{
  let finished = false;
  const rec = new ReplayRecorder('golf', 1, 75, FIXED_DT);
  for (let i = 0; i < 4; i++) rec.record(intent({ moveX: 1 }));
  const g = new GhostSource(rec.finish(3, 'WIN'), { onFinished: () => { finished = true; } });
  for (let i = 0; i < 6; i++) g.poll();
  ok('onFinished fires exactly once', finished);
}
{
  const rec = new ReplayRecorder('golf', 1, 75, FIXED_DT);
  for (let i = 0; i < 10; i++) rec.record(intent({ moveX: i / 10 }));
  const slow = new GhostSource(rec.finish(1, 'WIN'), { speed: 0.5 });
  let advanced = 0;
  for (let i = 0; i < 10; i++) { const before = slow.progress; slow.poll(); if (slow.progress > before) advanced++; }
  ok('a half-speed ghost advances half as often', advanced === 5, `${advanced}`);
}

// fidelity — the honesty layer
ok('a dunk ghost is exact — there was no opponent to react to',
  ghostFidelity('dunk') === 'exact');
ok('a tennis ghost is good — exchanges are discrete',
  ghostFidelity('tennis') === 'good');
ok('a 1v1 ghost is POOR and must not ship — it cannot react to you',
  ghostFidelity('onevone') === 'poor');
ok('karate is poor for the same reason', ghostFidelity('karate-vs') === 'poor');
ok('an unknown mode is assumed poor, not assumed fine',
  ghostFidelity('some_new_mode') === 'poor');
ok('ghostsSuitable gates on that', ghostsSuitable('dunk') && !ghostsSuitable('onevone'));
ok('every registry mode has a fidelity rating',
  ['dunk', 'onevone', 'threevthree', 'dunkduel', 'carnival', 'karate', 'karate-vs',
   'mixedcombat', 'soccer', 'football', 'baseball', 'tennis', 'golf', 'volleyball',
   'gymnastics', 'skateboard', 'snowboard', 'surf', 'music', 'dance', 'art',
   'acting', 'irl', 'brain_brawl', 'who_scene_it']
    .every((m) => GHOST_FIDELITY[m] !== undefined));

// ── THE WHOLE CLAIM: record a match, replay it, get the same match ───────
{
  /**
   * A toy simulation that touches everything this batch changed: fixed ticks,
   * seeded randomness, and intent-driven movement. If the pieces do not
   * compose, this is where it shows.
   */
  function simulate(intents: Intent[], seed: number): number[] {
    const r = new Rng(seed);
    const ai = r.fork('ai');
    let x = 0, v = 0, score = 0;
    const hashes: number[] = [];
    for (const i of intents) {
      v += i.moveX * 0.5 * FIXED_DT;
      v *= 0.98;
      x += v;
      if (i.action && ai.chance(0.5)) score += ai.int(1, 3);
      hashes.push(stateHash([x, v, score, ai.draws]));
    }
    return hashes;
  }

  const rec = new ReplayRecorder('dunk', 31337, 75, FIXED_DT);
  const live = new Rng(31337);
  const script: Intent[] = [];
  for (let t = 0; t < 400; t++) {
    const i = intent({
      moveX: live.range(-1, 1),
      action: t % 37 === 0,
      sprint: t > 200,
    });
    script.push(i);
    rec.record(i);
  }
  const data = rec.finish(50, 'WIN');

  const first = simulate(script.map((i) => unpack(pack(i))), 31337);
  const check = verifyDeterminism(data, simulate, first);
  ok('THE WHOLE CLAIM: a recorded match replays bit-identically',
    check.ok, check.message);
  ok('and it says how many ticks it verified', /400 ticks/.test(check.message));

  // And it must actually be able to FAIL — a green check that cannot go red
  // is worse than no check.
  const nonDeterministic = (intents: Intent[], seed: number): number[] => {
    const h = simulate(intents, seed);
    h[123] = (h[123] ^ 0xff) >>> 0;   // stand in for a stray Math.random()
    return h;
  };
  const caught = verifyDeterminism(data, nonDeterministic, first);
  ok('a divergence is CAUGHT', !caught.ok);
  ok('and localised to the exact tick', caught.divergedAt === 123);
  ok('and the message names the usual causes', /Math\.random/.test(caught.message));
}

// ── SimLoop: the pieces composed, as a mode would use them ───────────────
{
  const { SimLoop } = await import('../core/SimLoop.ts');
  const loop = new SimLoop({ modeId: 'dunk', seed: 4242, playerPRQ: 80, record: true, captureHashes: true });
  let x = 0;
  let ticks = 0;
  const jitter = [1 / 60, 1 / 30, 1 / 144, 0.05, 1 / 60, 1 / 60];
  for (const f of jitter) {
    loop.frame(f,
      (dt) => { x += dt; ticks++; },
      () => intent({ moveY: 1 }),
      () => [x, ticks]);
  }
  ok('SimLoop runs a whole number of fixed ticks', ticks === loop.tick);
  ok('the mode only ever sees the FIXED dt',
    near(x, ticks * FIXED_DT, 1e-9), `${x} vs ${ticks * FIXED_DT}`);
  ok('recording happened alongside simulation', loop.recording);
  ok('one hash per tick was captured', loop.capturedHashes.length === ticks);
  ok('alpha stays in range', loop.alpha >= 0 && loop.alpha < 1);

  const data = loop.finish(21, 'WIN');
  ok('finish yields a replay', data !== null && data.header.totalTicks === ticks);
  ok('the seed is carried through', data.header.seed === 4242);
  ok('the PRQ is carried through', data.header.playerPRQ === 80);
  ok('the final hash is stamped for server-side audit',
    data.header.finalHash === loop.capturedHashes[loop.capturedHashes.length - 1]);

  const ghost = GhostSource.from(data, 'dunk', FIXED_DT);
  ok('and the recording immediately becomes a playable ghost', ghost !== null);
  ok('the ghost knows the score it is chasing', ghost.targetScore === 21);
}
{
  const { SimLoop } = await import('../core/SimLoop.ts');
  const loop = new SimLoop({ modeId: 'golf', seed: 1, playerPRQ: 75 });
  loop.frame(1 / 60, () => {});
  ok('recording is OFF by default — storage nobody asked for', !loop.recording);
  ok('and finish() is still safe to call', loop.finish(1, 'WIN') === null);
}
{
  // Two SimLoops on one seed must draw identically, or nothing above holds.
  const { SimLoop } = await import('../core/SimLoop.ts');
  const a = new SimLoop({ modeId: 'dunk', seed: 5150, playerPRQ: 75 });
  const b = new SimLoop({ modeId: 'dunk', seed: 5150, playerPRQ: 75 });
  ok('two loops on one seed draw identically',
    Array.from({ length: 20 }, () => a.rng.next()).join()
    === Array.from({ length: 20 }, () => b.rng.next()).join());
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
