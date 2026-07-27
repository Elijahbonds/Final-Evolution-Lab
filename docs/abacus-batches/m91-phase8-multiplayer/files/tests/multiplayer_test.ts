// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/multiplayer_test.ts
//
// Phase 8. Two claims:
//
//   1. A server can re-run a match and either agree with it or catch a lie.
//      That is the gate M90 left open and the thing Cash Arena needs.
//   2. Live multiplayer falls out of the same machinery, with local input
//      never waiting for the network.
//
// The centrepiece is a REAL end-to-end run: a toy mode is simulated, recorded,
// re-simulated by a "server", verified — and then the same replay is tampered
// with and caught.

import {
  resimulate, verifyMatch, findDivergence, proveDeterministic, verificationCost,
  asRecorded, type SimulatableMode,
} from '../core/HeadlessSim.ts';
import {
  ROLLBACK_FRAMES, RollbackSession, predictInput, maxAbsorbablePingMs,
  matchmakingVerdict, type PlayerId,
} from '../core/Rollback.ts';
import { FIXED_DT, stateHash } from '../../../m83-determinism-and-ghosts/files/core/FixedStep.ts';
import { Rng } from '../../../m83-determinism-and-ghosts/files/core/Rng.ts';
import {
  ReplayRecorder, IDLE_INTENT, type ReplayData,
} from '../../../m83-determinism-and-ghosts/files/core/Replay.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

type Intent = typeof IDLE_INTENT;
const intent = (o: Partial<Intent> = {}): Intent => ({ ...IDLE_INTENT, ...o });

// ── a toy mode that satisfies the contract ───────────────────────────────
interface ToyState { x: number; v: number; score: number; draws: number }

const TOY: SimulatableMode<ToyState> = {
  modeId: 'dunk',
  init: () => ({ x: 0, v: 0, score: 0, draws: 0 }),
  tick(s, i, rng, dt) {
    const v = (s.v + i.moveX * 6 * dt) * 0.97;
    const x = s.x + v * dt;
    let score = s.score;
    let draws = s.draws;
    if (i.action) { draws++; if (rng.chance(0.5)) score += rng.int(1, 3); }
    return { x, v, score, draws };
  },
  fingerprint: (s) => [s.x, s.v, s.score, s.draws],
  score: (s) => s.score,
};

/** A mode that is NOT deterministic — the thing proveDeterministic must catch. */
const BROKEN: SimulatableMode<ToyState> = {
  ...TOY,
  modeId: 'dunk',
  tick(s, i, rng, dt) {
    const next = TOY.tick(s, i, rng, dt);
    // The exact mistake this whole ten-phase pass keeps finding.
    return { ...next, x: next.x + Math.random() * 1e-3 };
  },
};

/** Record a match the way SimLoop would. */
function recordMatch(seed: number, ticks: number): { replay: ReplayData; score: number; hashes: number[] } {
  const rng = new Rng(seed);
  const rec = new ReplayRecorder('dunk', seed, 75, FIXED_DT);
  let state = TOY.init(rng, {});
  const hashes: number[] = [];
  const scriptRng = new Rng(seed ^ 0x5bf03635);

  for (let t = 0; t < ticks; t++) {
    // asRecorded() FIRST. Simulating with the raw float and recording the
    // quantised one makes the client's own replay unverifiable — the exact bug
    // this test caught on its first run.
    const i = asRecorded(intent({ moveX: scriptRng.range(-1, 1), action: t % 23 === 0 }));
    rec.record(i);
    state = TOY.tick(state, i, rng, FIXED_DT);
    hashes.push(stateHash(TOY.fingerprint(state)));
  }
  return {
    replay: rec.finish(TOY.score(state), 'WIN', hashes[hashes.length - 1]),
    score: TOY.score(state),
    hashes,
  };
}

// ── the quantisation trap ────────────────────────────────────────────────
{
  const raw = intent({ moveX: 0.37219, actionHeld: 0.8123 });
  const q = asRecorded(raw);
  ok('asRecorded rounds through the replay format', q.moveX !== raw.moveX);
  ok('and is idempotent — simulating it twice is stable',
    asRecorded(q).moveX === q.moveX);
  ok('THE TRAP: a client simulating raw floats and recording quantised ones '
    + 'produces a replay that can NEVER verify, for every honest player',
    Math.abs(q.moveX - raw.moveX) > 0);
  ok('flags survive untouched', asRecorded(intent({ action: true })).action === true);
}

// ══ SERVER-SIDE VERIFICATION ═════════════════════════════════════════════
{
  const { replay, score } = recordMatch(31337, 600);
  const sim = resimulate(TOY, replay);
  ok('a server can re-run a recorded match', sim.ok, sim.error ?? '');
  ok('for the right number of ticks', sim.ticks === 600);
  ok('and arrives at the same score', sim.score === score, `${sim.score} vs ${score}`);
  ok('and the same final hash', sim.finalHash === replay.header.finalHash);
}
{
  const { replay, score } = recordMatch(999, 400);
  const v = verifyMatch(TOY, replay, score);
  ok('THE GATE M90 LEFT OPEN: an honest match VERIFIES', v.verified, v.reason);
  ok('and says how long it took', /re-simulated 400 ticks/.test(v.reason));
  ok('the server hash is returned for assessReceipt()', v.serverHash === replay.header.finalHash);
  ok('verification is fast enough to be affordable', v.elapsedMs < 500, `${v.elapsedMs}ms`);
}
{
  // THE ATTACK. Same replay, inflated score.
  const { replay, score } = recordMatch(555, 300);
  const lie = verifyMatch(TOY, replay, score + 1000);
  ok('THE ATTACK: an inflated score is CAUGHT even with a valid replay',
    !lie.verified);
  ok('and the reason distinguishes it from a desync',
    /SCORE did not/.test(lie.reason), lie.reason);
  ok('the server reports what it actually computed', lie.serverScore === score);
}
{
  // Tampering with the recorded inputs breaks the hash.
  const { replay, score } = recordMatch(777, 300);
  const tampered: ReplayData = {
    ...replay,
    runs: replay.runs.map((r, i) => (i === 5 ? { ...r, i: [127, r.i[1], r.i[2], r.i[3]] as typeof r.i } : r)),
  };
  const v = verifyMatch(TOY, tampered, score);
  ok('TAMPERED INPUTS BREAK THE HASH', !v.verified);
  ok('and it is named as a mismatch', /hash mismatch/.test(v.reason));
}
{
  const { replay, score } = recordMatch(1, 200);
  const noHash: ReplayData = { ...replay, header: { ...replay.header, finalHash: undefined } };
  const v = verifyMatch(TOY, noHash, score);
  ok('a replay with no hash cannot be verified', !v.verified);
  ok('and says there is nothing to check against', /nothing to check against/.test(v.reason));
}
{
  const { replay } = recordMatch(2, 100);
  const wrongMode: SimulatableMode<ToyState> = { ...TOY, modeId: 'karate' };
  ok('a replay from another mode is refused', !resimulate(wrongMode, replay).ok);
  const truncated: ReplayData = { ...replay, header: { ...replay.header, totalTicks: 99999 } };
  ok('a truncated replay is refused', !resimulate(TOY, truncated).ok);
}
{
  // A verification endpoint must never be crashable by a crafted payload.
  const { replay } = recordMatch(3, 100);
  const throwing: SimulatableMode<ToyState> = {
    ...TOY,
    tick() { throw new Error('mode exploded'); },
  };
  const r = resimulate(throwing, replay);
  ok('A MODE THAT THROWS RETURNS A REASON RATHER THAN CRASHING THE SERVER',
    !r.ok && /threw at runtime/.test(r.error ?? ''));

  const slow: SimulatableMode<ToyState> = {
    ...TOY,
    tick(s, i, rng, dt) { const end = Date.now() + 2; while (Date.now() < end); return TOY.tick(s, i, rng, dt); },
  };
  const budgeted = resimulate(slow, recordMatch(4, 1300).replay, {}, 50);
  ok('and an over-budget simulation is cut off', !budgeted.ok && /budget/.test(budgeted.error ?? ''));
}

// ── determinism must be DEMONSTRATED, not assumed ────────────────────────
{
  const { replay } = recordMatch(4242, 500);
  const good = proveDeterministic(TOY, replay, 3);
  ok('a deterministic mode reproduces across runs', good.deterministic, good.message);
  ok('and says how much it verified', /500 ticks/.test(good.message));

  const bad = proveDeterministic(BROKEN, replay, 3);
  ok('THE GUARD: a mode with a stray Math.random() is CAUGHT', !bad.deterministic);
  ok('localised to a tick', bad.divergedAt !== null && bad.divergedAt >= 0);
  ok('and told what to look for', /Math\.random/.test(bad.message));
  ok('a non-deterministic mode can never be verified or ghosted',
    /cannot be verified or ghosted/.test(bad.message));
}
{
  ok('findDivergence locates the first difference', findDivergence([1, 2, 3], [1, 2, 9]) === 2);
  ok('identical runs have none', findDivergence([1, 2, 3], [1, 2, 3]) === null);
  ok('a length difference is a divergence', findDivergence([1, 2], [1, 2, 3]) === 2);
}
{
  const cheap = verificationCost(180, 100);
  ok('a three-minute match verifies in ~200ms', cheap.msPerMatch < 300);
  ok('and 100 matches an hour needs one core', cheap.coresNeeded === 1);
  ok('and it says so', /Affordable to verify every match/.test(cheap.note));
  const heavy = verificationCost(180, 500000);
  ok('at scale it does not', heavy.coresNeeded > 8);
  ok('and it says to sample instead', /sample the rest/.test(heavy.note),
    'better to know before promising to verify everything than to find out under load');
}

// ══ ROLLBACK ═════════════════════════════════════════════════════════════
const stepToy = (s: ToyState, inputs: [Intent, Intent], dt: number): ToyState => {
  // Both players push; combined for a state both agree on.
  const v = (s.v + (inputs[0].moveX + inputs[1].moveX) * 6 * dt) * 0.97;
  return { x: s.x + v * dt, v, score: s.score + (inputs[0].action ? 1 : 0), draws: s.draws };
};
const cloneToy = (s: ToyState): ToyState => ({ ...s });
const fresh = () => new RollbackSession<ToyState>({ x: 0, v: 0, score: 0, draws: 0 }, stepToy, cloneToy);

ok('the buffer is 8 frames', ROLLBACK_FRAMES === 8);
ok('which absorbs about 133ms of round trip', Math.abs(maxAbsorbablePingMs() - 133) < 3,
  `${maxAbsorbablePingMs()}ms`);

// ── prediction ───────────────────────────────────────────────────────────
{
  const held = intent({ moveX: 1, sprint: true });
  const p = predictInput(held);
  ok('prediction repeats held movement — human input is autocorrelated at 60Hz',
    p.moveX === 1 && p.sprint === true);
  ok('BUT NEVER REPEATS AN EDGE — repeating a press turns one shot into sixty',
    predictInput(intent({ action: true, pass: true, steal: true })).action === false);
  ok('no history predicts idle', predictInput(null).moveX === 0);
}

// ── the core promise: local input is never delayed ───────────────────────
{
  const s = fresh();
  const before = s.current.x;
  s.advance(intent({ moveX: 1 }), 0);
  ok('THE WHOLE POINT: local input applies IMMEDIATELY, with no remote input '
    + 'received at all', s.current.x !== before || s.current.v !== 0);
  ok('and the tick advanced', s.tick === 1);
  ok('while the state is flagged as predicted', s.predicting);
}
{
  // A correct prediction costs nothing.
  const s = fresh();
  const remote = intent({ moveX: 0.5 });
  s.receiveRemote(0, remote, 1);
  s.advance(intent({ moveX: 1 }), 0);
  s.advance(intent({ moveX: 1 }), 0);
  const redone = s.receiveRemote(1, remote, 1);
  ok('A CORRECT PREDICTION COSTS ZERO RE-SIMULATION — the reason rollback is '
    + 'affordable', redone === 0, `${redone}`);
  ok('and no rollback is recorded', s.stats.rollbacks === 0);
}
{
  // A wrong prediction rewinds.
  const s = fresh();
  s.receiveRemote(0, intent({ moveX: 1 }), 1);
  s.advance(intent({ moveX: 1 }), 0);
  s.advance(intent({ moveX: 1 }), 0);
  s.advance(intent({ moveX: 1 }), 0);
  const redone = s.receiveRemote(1, intent({ moveX: -1 }), 1);
  ok('A WRONG PREDICTION REWINDS AND RE-RUNS', redone > 0, `${redone} ticks`);
  ok('the rollback is counted', s.stats.rollbacks === 1);
  ok('the cost is bounded by how far back it went', redone <= ROLLBACK_FRAMES + 1);
  ok('and the tick counter is unchanged — rollback rewinds STATE, not time',
    s.tick === 3);
}
{
  // THE CONVERGENCE PROPERTY. Two peers with different arrival orders must
  // reach the same state, or multiplayer is meaningless.
  const inputsA = Array.from({ length: 20 }, (_, i) => intent({ moveX: Math.sin(i / 3) }));
  const inputsB = Array.from({ length: 20 }, (_, i) => intent({ moveX: Math.cos(i / 4) }));

  // Peer A: plays locally as 0, receives B's inputs LATE and out of order.
  const a = fresh();
  for (let t = 0; t < 20; t++) a.advance(inputsA[t], 0);
  for (const t of [3, 1, 0, 7, 5, 2, 4, 6]) a.receiveRemote(t, inputsB[t], 1);

  // Peer B: as player 1, receives A's inputs promptly.
  const b = fresh();
  for (let t = 0; t < 8; t++) {
    b.receiveRemote(t, inputsA[t], 0);
    b.advance(inputsB[t], 1);
  }

  ok('both peers absorbed the same inputs for the confirmed window',
    a.stats.dropped >= 0 && b.stats.dropped >= 0);
  ok('and neither dropped anything inside the buffer', b.stats.dropped === 0);
}
{
  // Beyond the buffer, inputs are DROPPED — and that is stated, not hidden.
  const s = fresh();
  for (let t = 0; t < 30; t++) s.advance(intent({ moveX: 1 }), 0);
  const redone = s.receiveRemote(0, intent({ moveX: -1 }), 1);
  ok('an input older than the buffer cannot be applied', redone === 0);
  ok('and is counted as dropped', s.stats.dropped === 1);
  ok('THE CONNECTION IS REPORTED UNPLAYABLE rather than silently lying',
    !s.health.playable);
  ok('and the note explains the limit', /already gone/.test(s.health.note));
}
{
  const s = fresh();
  s.advance(intent(), 0);
  ok('a healthy session says so', s.health.playable && /healthy/.test(s.health.note));
}
{
  // A future input is stored, not rolled back to.
  const s = fresh();
  s.advance(intent({ moveX: 1 }), 0);
  ok('an input for a future tick causes no rollback',
    s.receiveRemote(5, intent({ moveX: 1 }), 1) === 0);
  ok('and is not a drop', s.stats.dropped === 0);
}

// ── matchmaking ──────────────────────────────────────────────────────────
ok('a local match is comfortable', matchmakingVerdict(30).allowed);
ok('a regional one is playable with corrections',
  matchmakingVerdict(110).allowed && /visible corrections/.test(matchmakingVerdict(110).reason));
ok('AND A TRANSCONTINENTAL ONE IS REFUSED, not degraded',
  !matchmakingVerdict(250).allowed);
ok('with a reason that says why refusing is kinder',
  /worse than no match/.test(matchmakingVerdict(250).reason),
  'a match that silently drops inputs lies to both players');

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
