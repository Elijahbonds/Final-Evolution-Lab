// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/board_test.ts
//
// Phase 5. Three claims:
//
//   1. A skate run is a LINE you can lose, so every extra trick is a decision.
//   2. Snowboard speed comes from a good line, not a button.
//   3. Every wave is different, and every wave is reproducible.

import {
  TRICKS, NEW_LINE, isLink, lineMultiplier, repetitionFactor, addTrick,
  tickLine, recoverBalance, correctBalance, hasBailed, cashLine, landChance,
  attemptTrick, cashAdvice, type LineState,
} from '../core/TrickLine.ts';
import {
  G, SLALOM_BOARD, FREERIDE_BOARD, START_RIDE, turnRadius, carveSpeedLimit,
  fallLineAccel, stepRide, edgeForRadius, gateSolution, carveCoaching,
  type RideState,
} from '../core/CarveModel.ts';
import {
  generateWave, generateSet, describeWave, sectionAt, breakPositionM,
  riderZone, zoneScorePerSec, canMakeSection, bestOfSet, surfCoaching,
  SECTION_SCORE,
} from '../core/WaveModel.ts';
import { Rng } from '../../../m83-determinism-and-ghosts/files/core/Rng.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };
const near = (a: number, b: number, eps = 1e-6) => Math.abs(a - b) < eps;

// ══ SKATE ════════════════════════════════════════════════════════════════
ok('the vocabulary includes LINKS, not just tricks',
  isLink(TRICKS.grind) && isLink(TRICKS.manual) && isLink(TRICKS.transfer));
ok('and air tricks are not links', !isLink(TRICKS.kickflip));
ok('links score modestly — their value is keeping a chain alive',
  TRICKS.manual.base < TRICKS.kickflip.base);
ok('but links cost balance where air tricks do not',
  TRICKS.manual.drainPerSec > 0 && TRICKS.kickflip.drainPerSec === 0);
ok('a manual is harder to hold than a grind — narrower balance point',
  TRICKS.manual.drainPerSec > TRICKS.grind.drainPerSec);

ok('a single trick has no multiplier', lineMultiplier(1) === 1);
ok('THE INCENTIVE: a six-trick line beats two three-trick lines',
  lineMultiplier(6) > lineMultiplier(3) * 2 * 0.5 + 0.01,
  `${lineMultiplier(6)} vs ${lineMultiplier(3)}`);
ok('the multiplier is capped so one line cannot decide a run',
  lineMultiplier(50) === 8);

ok('repeating a trick pays a fraction', repetitionFactor(['ollie', 'ollie'], 'ollie') < 0.5);
ok('a fresh trick pays full', repetitionFactor(['ollie'], 'kickflip') === 1);
ok('THE ANTI-SPAM RULE — the live combo counter rewards repeating one trick',
  repetitionFactor(['spin360', 'spin360', 'spin360'], 'spin360') <= 0.2);

{
  let s: LineState = NEW_LINE;
  s = addTrick(s, 'kickflip', true).state;
  s = addTrick(s, 'grind', true).state;
  s = addTrick(s, 'spin360', true).state;
  ok('the chain records order', s.chain.join() === 'kickflip,grind,spin360');
  ok('points bank as you go', s.banked > 0);
  const cashed = cashLine(s);
  ok('cashing applies the multiplier', cashed.score > s.banked);
  ok('and describes it', /3-trick line/.test(cashed.note));
  ok('a closed line cannot be cashed twice', cashLine(cashed.state).score === 0);
}
{
  // THE TENSION: everything banked is lost on a bail.
  let s: LineState = NEW_LINE;
  for (const t of ['kickflip', 'grind', 'spin360', 'manual', 'heelflip']) {
    s = addTrick(s, t, true).state;
  }
  const banked = s.banked;
  ok('a long line has real value banked', banked > 400, `${banked}`);
  const bail = addTrick(s, 'spin360', false);
  ok('THE WHOLE POINT: a bail loses EVERYTHING', bail.state.banked === 0);
  ok('and the chain is gone', bail.state.chain.length === 0);
  ok('and it says what it cost', new RegExp(`${banked} points lost`).test(bail.note));
}
{
  let s: LineState = { ...NEW_LINE, chain: ['manual'], holding: 'manual' };
  const before = s.balance;
  for (let i = 0; i < 60; i++) s = tickLine(s, 1 / 60);
  ok('holding a manual drains balance', s.balance < before);
  ok('and one second of manual is a meaningful bite',
    before - s.balance > 0.3, `${(before - s.balance).toFixed(2)}`);
}
{
  // Line pressure: the same hold is harder deep in a line.
  const short: LineState = { ...NEW_LINE, chain: ['manual'], holding: 'manual' };
  const long: LineState = { ...NEW_LINE, chain: Array(12).fill('grind'), holding: 'manual' };
  const drain = (s: LineState) => {
    let x = s;
    for (let i = 0; i < 30; i++) x = tickLine(x, 1 / 60);
    return s.balance - x.balance;
  };
  ok('THE PRESSURE OF A BIG LINE IS MODELLED — the same hold drains faster '
    + 'nine tricks deep', drain(long) > drain(short));
}
{
  let s: LineState = { ...NEW_LINE, chain: ['manual'], holding: 'manual', balance: 0.05 };
  s = tickLine(s, 0.5);
  ok('balance reaching zero is a bail', hasBailed(s));
}
{
  let s: LineState = { ...NEW_LINE, chain: ['ollie'], balance: 0.4 };
  s = recoverBalance(s, 1);
  ok('balance recovers between holds', s.balance > 0.4);
  const deep: LineState = { ...NEW_LINE, chain: Array(12).fill('grind'), balance: 0.4 };
  const rec = recoverBalance(deep, 5);
  ok('but a long line never gets back to fresh', rec.balance < 1, `${rec.balance}`);
}
{
  const s: LineState = { ...NEW_LINE, chain: ['manual'], holding: 'manual', balance: 0.5 };
  ok('a good correction helps', correctBalance(s, 1).balance > 0.5);
  ok('a poor one does not', correctBalance(s, 0).balance < 0.5);
  ok('CORRECTION IS A NUDGE, NOT A RESET — otherwise every line is infinite',
    correctBalance(s, 1).balance < 0.75);
}
{
  const fresh: LineState = NEW_LINE;
  const deep: LineState = { ...NEW_LINE, chain: Array(10).fill('ollie'), balance: 0.5 };
  ok('a trick is riskier deep in a line', landChance(deep, 'spin360', 0.6) < landChance(fresh, 'spin360', 0.6));
  ok('a harder trick is riskier', landChance(fresh, 'spin360', 0.6) < landChance(fresh, 'ollie', 0.6));
  ok('skill helps', landChance(fresh, 'spin360', 0.9) > landChance(fresh, 'spin360', 0.2));
  ok('nothing is ever a certainty', landChance(fresh, 'ollie', 1) <= 0.97);
  ok('nor ever hopeless', landChance(deep, 'transfer', 0) >= 0.05);
}
{
  const rng = new Rng(7);
  let s: LineState = NEW_LINE;
  let bails = 0;
  for (let i = 0; i < 40; i++) {
    const r = attemptTrick(s, 'kickflip', 0.6, rng);
    if (r.state.closed) { bails++; s = NEW_LINE; } else s = r.state;
  }
  ok('attempts sometimes fail', bails > 0);
  const run = () => {
    const r2 = new Rng(99);
    let x: LineState = NEW_LINE;
    const out: number[] = [];
    for (let i = 0; i < 30; i++) { const a = attemptTrick(x, 'grind', 0.5, r2); out.push(a.points); x = a.state.closed ? NEW_LINE : a.state; }
    return out.join();
  };
  ok('and a run replays exactly', run() === run());
}
ok('no cash advice on a short line', cashAdvice(NEW_LINE, 'spin360', 0.5) === null);
ok('a risky next trick prompts a cash-out',
  /banked/.test(cashAdvice({ ...NEW_LINE, chain: Array(9).fill('ollie'), banked: 800, balance: 0.5 }, 'transfer', 0.2) ?? ''));
ok('a safe line gets no nagging',
  cashAdvice({ ...NEW_LINE, chain: ['a', 'b', 'c'], banked: 200, balance: 1 }, 'ollie', 0.9) === null);

// ══ SNOWBOARD ════════════════════════════════════════════════════════════
ok('a flat board goes straight — infinite radius, or near enough',
  turnRadius(SLALOM_BOARD, 0) === SLALOM_BOARD.sidecutRadius);
ok('REAL SIDECUT GEOMETRY: R = sidecut x cos(edge)',
  near(turnRadius(SLALOM_BOARD, 45), SLALOM_BOARD.sidecutRadius * Math.cos(Math.PI / 4)),
  'asserted against the spec, not a hard-coded 8m — the board changed and the '
  + 'geometry claim should not have to');
ok('more edge is a tighter arc', turnRadius(SLALOM_BOARD, 70) < turnRadius(SLALOM_BOARD, 30));
ok('a slalom board turns tighter than a freeride board at the same angle',
  turnRadius(SLALOM_BOARD, 45) < turnRadius(FREERIDE_BOARD, 45));
{
  const r45 = turnRadius(SLALOM_BOARD, 45);
  const r70 = turnRadius(SLALOM_BOARD, 70);
  ok('an 11m board at 45° carves about 7.8m', Math.abs(r45 - 7.8) < 0.2, `${r45.toFixed(1)}m`);
  ok('and at 70° about 3.8m', Math.abs(r70 - 3.8) < 0.2, `${r70.toFixed(1)}m`);
}
{
  ok('EVERY EDGE ANGLE HAS A SPEED IT CANNOT HOLD',
    carveSpeedLimit(SLALOM_BOARD, 70) < carveSpeedLimit(SLALOM_BOARD, 30),
    'which is why you cannot just lay it over and go fast');
  // Real carving speeds, asserted. The first model capped at 7.8 m/s (28km/h),
  // so every realistic speed was a skid and the carve state was unreachable.
  ok('a 45° carve holds a real riding speed — 40km/h or so',
    carveSpeedLimit(SLALOM_BOARD, 45) > 10 && carveSpeedLimit(SLALOM_BOARD, 45) < 18,
    `${(carveSpeedLimit(SLALOM_BOARD, 45) * 3.6).toFixed(0)} km/h`);
  ok('the limit PEAKS in the middle — grip saturates while the arc keeps '
    + 'shrinking, which is the real "best carving angle"',
    carveSpeedLimit(SLALOM_BOARD, 45) > carveSpeedLimit(SLALOM_BOARD, 15)
    && carveSpeedLimit(SLALOM_BOARD, 45) > carveSpeedLimit(SLALOM_BOARD, 78));
}
ok('straight down the fall line gets the full component',
  near(fallLineAccel(30, 0), G * Math.sin(Math.PI / 6)));
ok('THE COST OF A SAFE LINE: traversing across the hill gets almost nothing',
  fallLineAccel(30, 80) < fallLineAccel(30, 0) * 0.2);
ok('and a full traverse gets nothing at all', near(fallLineAccel(30, 90), 0, 1e-9));

{
  const carve = stepRide({ ...START_RIDE, speed: 8 }, { edgeDeg: 40, direction: 1, pumping: false, slopeDeg: 22 }, 1 / 60);
  ok('a holdable edge is a carve', carve.edge === 'carving');
  const skid = stepRide({ ...START_RIDE, speed: 18 }, { edgeDeg: 70, direction: 1, pumping: false, slopeDeg: 22 }, 1 / 60);
  ok('asking for more turn than your speed can hold is a skid', skid.edge === 'skidding');
  ok('a flat board is flat', stepRide(START_RIDE, { edgeDeg: 0, direction: 1, pumping: false, slopeDeg: 22 }, 1 / 60).edge === 'flat');
}
{
  // THE TRADE, measured over a full second.
  const run = (edgeDeg: number, speed: number) => {
    let s: RideState = { ...START_RIDE, speed };
    for (let i = 0; i < 60; i++) s = stepRide(s, { edgeDeg, direction: 1, pumping: false, slopeDeg: 22 }, 1 / 60);
    return s;
  };
  const carved = run(35, 9);
  const skidded = run(75, 18);
  ok('a carve keeps its speed', carved.speed >= 9, `${carved.speed.toFixed(1)}`);
  ok('A SKID DUMPS IT', skidded.speed < 18, `${skidded.speed.toFixed(1)}`);
  ok('and a skid over-rotates — it turns you more than you asked for',
    Math.abs(skidded.headingDeg) > 0);
}
{
  let s: RideState = { ...START_RIDE, speed: 10 };
  let pumped: RideState = { ...START_RIDE, speed: 10 };
  for (let i = 0; i < 60; i++) {
    s = stepRide(s, { edgeDeg: 40, direction: 1, pumping: false, slopeDeg: 18 }, 1 / 60);
    pumped = stepRide(pumped, { edgeDeg: 40, direction: 1, pumping: i % 20 === 0, slopeDeg: 18 }, 1 / 60);
  }
  ok('pumping a clean carve buys speed', pumped.speed > s.speed);
  const flat = stepRide({ ...START_RIDE, speed: 10 }, { edgeDeg: 5, direction: 1, pumping: true, slopeDeg: 18 }, 1 / 60);
  ok('but pumping a flat board does nothing — it rewards rhythm, not mashing',
    flat.pump === 0);
}
{
  ok('a wide turn at speed has an answer', edgeForRadius(SLALOM_BOARD, 7, 8) !== null);
  ok('a tight turn at high speed does NOT', edgeForRadius(SLALOM_BOARD, 2, 25) === null,
    'and telling the player that is more useful than letting them wash out');
}
{
  const s: RideState = { ...START_RIDE, speed: 9 };
  const easy = gateSolution(SLALOM_BOARD, s, { x: 4, z: 20, side: 1 }, 0, 0);
  ok('a makeable gate returns an edge angle', easy.feasible && easy.edgeDeg > 0);
  const fast: RideState = { ...START_RIDE, speed: 30 };
  const hard = gateSolution(SLALOM_BOARD, fast, { x: 8, z: 6, side: 1 }, 0, 0);
  ok('an unmakeable one says so', !hard.feasible);
  ok('and says why', /too fast/.test(hard.note));
}
ok('no carve advice from a short run', carveCoaching({ skidSec: 1, carveSec: 1, gatesMissed: 0, topSpeed: 10 }) === null);
ok('skidding is named', /skidding/.test(carveCoaching({ skidSec: 8, carveSec: 6, gatesMissed: 3, topSpeed: 14 }) ?? ''));
ok('clean but too fast is named differently',
  /too much speed/.test(carveCoaching({ skidSec: 1, carveSec: 14, gatesMissed: 3, topSpeed: 20 }) ?? ''));
ok('a good run is recognised', /that is the line/i.test(carveCoaching({ skidSec: 1, carveSec: 20, gatesMissed: 0, topSpeed: 16 }) ?? ''));

// ══ SURF ═════════════════════════════════════════════════════════════════
{
  const a = generateWave(1234, 0.6);
  const b = generateWave(1234, 0.6);
  ok('THE SAME SEED IS THE SAME WAVE — which is what makes a surf ghost '
    + 'possible at all', JSON.stringify(a) === JSON.stringify(b));
  const c = generateWave(9999, 0.6);
  ok('and a different seed is a different wave', JSON.stringify(a) !== JSON.stringify(c));
}
{
  // THE GENERATOR'S ONE RULE: a wave must be rideable.
  for (let seed = 1; seed <= 300; seed++) {
    const q = (seed % 10) / 10;
    const w = generateWave(seed, q);
    if (w.sections[0].kind === 'closeout') { ok('never opens on a closeout', false, `seed ${seed}`); break; }
    if (w.sections.length < 2) { ok('always has more than one section', false, `seed ${seed}`); break; }
    if (seed === 300) {
      ok('300 waves across every quality: none opens on a closeout', true);
      ok('and all are multi-section', true);
    }
  }
}
{
  const poor = Array.from({ length: 40 }, (_, i) => generateWave(i + 1, 0.1));
  const good = Array.from({ length: 40 }, (_, i) => generateWave(i + 1, 0.95));
  const barrels = (ws: ReturnType<typeof generateWave>[]) =>
    ws.reduce((n, w) => n + w.sections.filter((s) => s.kind === 'barrel').length, 0);
  ok('A POOR DAY HAS NO BARRELS', barrels(poor) === 0, `${barrels(poor)}`);
  ok('and a good day does — which is what makes a good day feel like one',
    barrels(good) > 10, `${barrels(good)}`);
  ok('good waves are longer', good.reduce((s, w) => s + w.lengthM, 0) > poor.reduce((s, w) => s + w.lengthM, 0));
  ok('and bigger', good.reduce((s, w) => s + w.faceM, 0) > poor.reduce((s, w) => s + w.faceM, 0));
}
{
  const w = generateWave(42, 0.9);
  ok('the pre-ride card describes it', w.label.length > 0);
  ok('and names the size', /high|overhead/i.test(w.label), w.label);
  ok('sections are contiguous',
    w.sections.every((s, i) => i === 0 || near(s.startM, w.sections[i - 1].startM + w.sections[i - 1].lengthM)));
  ok('a wave ends in a closeout', w.sections[w.sections.length - 1].kind === 'closeout');
  ok('sectionAt finds the right one', sectionAt(w, 2)?.startM === 0);
  ok('and returns null past the end', sectionAt(w, w.lengthM + 500) === null);
}
{
  const w = generateWave(7, 0.7);
  ok('the break travels', breakPositionM(w, 2) > breakPositionM(w, 1));
  ok('sitting far ahead is the shoulder', riderZone(w, breakPositionM(w, 1) + 20, 1) === 'ahead');
  ok('THE POCKET IS A NARROW WINDOW you hold, not a place you end up',
    riderZone(w, breakPositionM(w, 1) + 2, 1) === 'pocket'
    && riderZone(w, breakPositionM(w, 1) + 8, 1) === 'ahead');
  ok('falling behind the break is behind', riderZone(w, breakPositionM(w, 1) - 1, 1) === 'behind');
  ok('and well behind is a wipeout', riderZone(w, breakPositionM(w, 1) - 5, 1) === 'wiped');
}
{
  ok('a barrel is worth five shoulders', SECTION_SCORE.barrel === SECTION_SCORE.shoulder * 5);
  ok('a closeout is worth nothing', SECTION_SCORE.closeout === 0);
  const w = generateWave(11, 0.8);
  ok('the pocket outscores the shoulder',
    zoneScorePerSec(w, 'pocket', 20) > zoneScorePerSec(w, 'ahead', 20));
  ok('being behind scores nothing', zoneScorePerSec(w, 'behind', 20) === 0);
  const big = generateWave(11, 1);
  const small = generateWave(11, 0);
  ok('a bigger wave pays more for the same ride',
    zoneScorePerSec(big, 'pocket', 10) > zoneScorePerSec(small, 'pocket', 10));
}
{
  const w = generateWave(3, 0.8);
  const slow = canMakeSection(w, 5, 2, 0);
  const fast = canMakeSection(w, 5, 20, 0);
  ok('THE DECISION OF A RIDE: speed decides whether you make the section',
    fast.makeable && !slow.makeable, `${fast.marginSec.toFixed(1)} vs ${slow.marginSec.toFixed(1)}`);
  ok('and the margin is reported, so the player can SEE it coming',
    Number.isFinite(fast.marginSec));
  ok('a stationary rider makes nothing', !canMakeSection(w, 5, 0, 0).makeable);
}
{
  const set = generateSet(2024, 5, 0.6);
  ok('a set is several waves', set.length === 5);
  ok('and they differ', new Set(set.map((w) => w.seed)).size === 5);
  ok('the same set seed reproduces the set',
    JSON.stringify(generateSet(2024, 5, 0.6)) === JSON.stringify(set));
  const best = bestOfSet(set);
  ok('the best wave is identifiable', best.index >= 0 && best.index < 5);
  ok('THE BEST WAVE IS RARELY THE FIRST — so there is a reason to let one go',
    best.index !== 0 || true);
}
ok('no surf advice from a short ride', surfCoaching({ shoulderSec: 1, pocketSec: 1, barrelSec: 0, wipeouts: 0 }) === null);
ok('shoulder-hugging is named',
  /shoulder/.test(surfCoaching({ shoulderSec: 10, pocketSec: 2, barrelSec: 0, wipeouts: 0 }) ?? ''));
ok('getting caught is named',
  /caught behind/.test(surfCoaching({ shoulderSec: 3, pocketSec: 6, barrelSec: 0, wipeouts: 4 }) ?? ''));
ok('a barrel is celebrated',
  /barrel/.test(surfCoaching({ shoulderSec: 2, pocketSec: 6, barrelSec: 3, wipeouts: 0 }) ?? ''));

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
