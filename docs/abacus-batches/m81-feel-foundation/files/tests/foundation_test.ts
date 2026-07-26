// node --experimental-strip-types tests/foundation_test.ts
//
// DDA, Teardown, and the pure parts of InputBus v3.
//
// The DDA tests are also a PARITY CHECK against
// FinalEvolutionLab/Models/DynamicDifficulty.swift. Two platforms that
// silently disagree about difficulty would be worse than one platform with no
// difficulty scaling at all, so the constants are asserted, not just the
// behaviour.

import {
  aggression, aiResponseDelay, ddaWindowScale, rubberBandFactor, momentumBonus,
  scaledSuccessWindow, PRQDrivenDDA, loadDDA, PRQ_DEFAULT,
  MAX_AGGRESSION, MIN_AGGRESSION,
  TIER_FEINT_CHANCE, TIER_COUNTER_WINDOW, TIER_PATTERN_COMPLEXITY,
} from '../core/DDA.ts';
import { Teardown } from '../core/Teardown.ts';
// From inputCore, not InputBus: InputBus pulls in Babylon-adjacent modules and
// DOM globals that do not exist here. The rules live in inputCore precisely so
// they can be tested without a browser.
import {
  classifyRelease, stickFromKeys, isGameKey, shouldPreventDefault,
  TAP_MAX_MS, DEFAULT_BINDINGS,
} from '../core/inputCore.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };
const near = (a: number, b: number, eps = 1e-9) => Math.abs(a - b) < eps;

// ── DynamicDifficulty parity ─────────────────────────────────────────────
ok('parity: max aggression is 1.4', MAX_AGGRESSION === 1.4);
ok('parity: min aggression is 0.6', MIN_AGGRESSION === 0.6);
ok('ahead by 5 pins aggression to max', aggression(5, 0) === MAX_AGGRESSION);
ok('ahead by more still pins to max', aggression(50, 0) === MAX_AGGRESSION);
ok('behind by 5 pins to min', aggression(0, 5) === MIN_AGGRESSION);
ok('level is the midpoint', near(aggression(3, 3), 1.0));
ok('aggression is monotonic in the gap',
  aggression(0, 3) < aggression(0, 0) && aggression(0, 0) < aggression(3, 0));

ok('response delay shortens as aggression rises',
  aiResponseDelay(5, 0) < aiResponseDelay(0, 5));
ok('response delay is floored at 0.2s', aiResponseDelay(99, 0) >= 0.2);
ok('parity: a level match responds in 0.8s', near(aiResponseDelay(0, 0), 0.8));

// window scale — keyed on PROGRESS, not raw points
ok('losing badly widens the window', ddaWindowScale(0, 9, 10) === 1.35);
ok('losing widens it a little', ddaWindowScale(5, 7, 10) === 1.15);
ok('winning easily tightens it', ddaWindowScale(9, 0, 10) === 0.75);
ok('a level match leaves it alone', ddaWindowScale(5, 5, 10) === 1.0);
ok('a zero target is safe, not a divide-by-zero', ddaWindowScale(1, 1, 0) === 1.0);
ok('window scale is progress-relative, not points-relative',
  ddaWindowScale(0, 9, 10) === ddaWindowScale(0, 18, 20));

ok('rubber band helps the trailing side', rubberBandFactor(0, 9, 10) === 0.7);
ok('rubber band presses the leader', rubberBandFactor(9, 0, 10) === 1.3);
ok('momentum caps at five wins', momentumBonus(99) === momentumBonus(5));
ok('parity: five straight wins is +40%', near(momentumBonus(5), 1.4));
ok('no wins is no bonus', momentumBonus(0) === 1.0);

ok('parity: football has the widest windows', scaledSuccessWindow(1, 5, 5, 10, 'football') === 1.2);
ok('parity: golf has the tightest', scaledSuccessWindow(1, 5, 5, 10, 'golf') === 0.9);
ok('an unknown mode is neutral, not zero', scaledSuccessWindow(1, 5, 5, 10, 'nonesuch') === 1.0);

// ── PRQDrivenDDA — PRQ actually changing gameplay ────────────────────────
const rookie = new PRQDrivenDDA({ playerPRQ: 20, modeId: 'karate' });
const mid = new PRQDrivenDDA({ playerPRQ: 75, modeId: 'karate' });
const legend = new PRQDrivenDDA({ playerPRQ: 95, modeId: 'karate' });

ok('tier: 20 is ROOKIE', rookie.tier === 'ROOKIE');
// Parity note, not a bug in the port: Swift's band is `0.75..<0.9 -> .elite`,
// so the DEFAULT player (PRQ 75) starts at ELITE, not COMPETITIVE. That is a
// product question — a brand-new account meeting elite AI — but the two
// platforms must agree before anyone changes it, so it is pinned here.
ok('parity: 75 (the default) is ELITE, matching Swift', mid.tier === 'ELITE');
ok('COMPETITIVE is the band below',
  new PRQDrivenDDA({ playerPRQ: 60, modeId: 'karate' }).tier === 'COMPETITIVE');
ok('the 0.75 boundary belongs to ELITE, not COMPETITIVE',
  new PRQDrivenDDA({ playerPRQ: 74.9, modeId: 'karate' }).tier === 'COMPETITIVE'
  && new PRQDrivenDDA({ playerPRQ: 75, modeId: 'karate' }).tier === 'ELITE');
ok('tier: 95 is LEGENDARY', legend.tier === 'LEGENDARY');
ok('tier boundary at 0.55 is inclusive',
  new PRQDrivenDDA({ playerPRQ: 55, modeId: 'karate' }).tier === 'COMPETITIVE');
ok('tier boundary at 0.9 is inclusive',
  new PRQDrivenDDA({ playerPRQ: 90, modeId: 'karate' }).tier === 'LEGENDARY');

ok('THE POINT: higher PRQ means a more aggressive opponent',
  legend.scaledAggression(0, 0) > rookie.scaledAggression(0, 0));
ok('higher PRQ means a faster opponent',
  legend.aiReactionSpeed(0, 0) < rookie.aiReactionSpeed(0, 0));
ok('higher PRQ means tighter windows for you',
  legend.qteWindowScale(0, 0, 10) < rookie.qteWindowScale(0, 0, 10));
ok('higher PRQ means more opponent combos',
  legend.aiComboChance(0, 0) > rookie.aiComboChance(0, 0));
ok('higher PRQ means the opponent blocks more',
  legend.aiBlockChance(0, 0) > rookie.aiBlockChance(0, 0));

ok('aggression is clamped into the tier band',
  (() => {
    for (const [p, a] of [[0, 20], [-20, 0], [10, 0], [0, 10]] as const) {
      const v = legend.scaledAggression(p, a);
      if (v < legend.aiAggressionFloor - 1e-9 || v > legend.aiAggressionCeiling + 1e-9) return false;
    }
    return true;
  })());
ok('a legend faces a higher floor than a rookie',
  legend.aiAggressionFloor > rookie.aiAggressionFloor);
ok('reaction speed never goes below 0.1s', legend.aiReactionSpeed(99, 0) >= 0.1);
ok('combo chance is capped at 0.6', legend.aiComboChance(99, 0) <= 0.6);
ok('block chance is capped at 0.55', legend.aiBlockChance(99, 0) <= 0.55);

ok('PRQ is clamped to 0..100 — 900 does not break the maths',
  new PRQDrivenDDA({ playerPRQ: 900, modeId: 'karate' }).prqNormalized === 1);
ok('negative PRQ clamps to zero',
  new PRQDrivenDDA({ playerPRQ: -50, modeId: 'karate' }).prqNormalized === 0);

ok('high neural drive presses harder than PRQ alone',
  new PRQDrivenDDA({ playerPRQ: 75, neuralDrive: 95, modeId: 'karate' }).scaledAggression(0, 0)
  > new PRQDrivenDDA({ playerPRQ: 75, neuralDrive: 50, modeId: 'karate' }).scaledAggression(0, 0));
ok('neural drive defaults to PRQ when unknown',
  new PRQDrivenDDA({ playerPRQ: 60, modeId: 'karate' }).neuralDrive === 60);

// per-mode point scaling
ok('parity: football scales opponent points up',
  new PRQDrivenDDA({ playerPRQ: 100, modeId: 'football' }).opponentMaxPoints(3)
  > new PRQDrivenDDA({ playerPRQ: 100, modeId: 'golf' }).opponentMaxPoints(3));
ok('opponent points never drop below 1',
  new PRQDrivenDDA({ playerPRQ: 0, modeId: 'golf' }).opponentMaxPoints(1) >= 1);
ok('an unknown mode still scales sanely',
  new PRQDrivenDDA({ playerPRQ: 75, modeId: 'nonesuch' }).opponentMaxPoints(3) >= 1);

ok('neutral() is the documented default', PRQDrivenDDA.neutral('karate').playerPRQ === PRQ_DEFAULT);

// tier tables
ok('a rookie never faces a feint', TIER_FEINT_CHANCE.ROOKIE === 0);
ok('feint chance rises with tier', TIER_FEINT_CHANCE.LEGENDARY > TIER_FEINT_CHANCE.ELITE);
ok('counter windows shrink with tier', TIER_COUNTER_WINDOW.LEGENDARY < TIER_COUNTER_WINDOW.ROOKIE);
ok('pattern complexity rises with tier',
  TIER_PATTERN_COMPLEXITY.LEGENDARY === 5 && TIER_PATTERN_COMPLEXITY.ROOKIE === 1);

// loadDDA must NEVER block or throw — a guest still gets a game
const okFetch = async () => ({ ok: true, json: async () => ({ overall_score: 88, mental: 90 }) }) as unknown as Response;
const badFetch = async () => { throw new Error('offline'); };
const notFound = async () => ({ ok: false, status: 404, json: async () => ({}) }) as unknown as Response;
const junk = async () => ({ ok: true, json: async () => ({ nonsense: true }) }) as unknown as Response;

ok('loadDDA reads a real PRQ', (await loadDDA('karate', okFetch as typeof fetch)).playerPRQ === 88);
ok('loadDDA survives the network being down',
  (await loadDDA('karate', badFetch as unknown as typeof fetch)).playerPRQ === PRQ_DEFAULT);
ok('loadDDA survives a 404',
  (await loadDDA('karate', notFound as typeof fetch)).playerPRQ === PRQ_DEFAULT);
ok('loadDDA survives a malformed body',
  (await loadDDA('karate', junk as typeof fetch)).playerPRQ === PRQ_DEFAULT);

// ── Teardown ─────────────────────────────────────────────────────────────
{
  const order: string[] = [];
  const t = new Teardown();
  t.add('first', () => order.push('first'));
  t.add('second', () => order.push('second'));
  t.add('third', () => order.push('third'));
  t.run();
  ok('teardown runs in REVERSE order', order.join() === 'third,second,first');
}
{
  const order: string[] = [];
  const t = new Teardown();
  t.add('engine', () => order.push('engine'));
  t.add('scene', () => { throw new Error('scene blew up'); });
  t.add('input', () => order.push('input'));
  t.run();
  ok('THE BUG: a throwing step does not strand the engine',
    order.join() === 'input,engine', order.join());
  ok('the failure is recorded', t.failures.length === 1 && t.failures[0].label === 'scene');
}
{
  let n = 0;
  const t = new Teardown();
  t.add('x', () => { n++; });
  t.run(); t.run(); t.run();
  ok('teardown is idempotent — React StrictMode calls cleanup twice', n === 1);
}
{
  let late = 0;
  const t = new Teardown();
  t.run();
  t.add('late', () => { late++; });
  ok('registering after teardown disposes immediately rather than leaking', late === 1);
}
{
  const t = new Teardown();
  ok('disposed is false before run', t.disposed === false);
  t.add('a', () => {});
  ok('size tracks registrations', t.size === 1);
  t.run();
  ok('disposed is true after run', t.disposed === true);
  ok('steps are released after run', t.size === 0);
}
{
  const t = new Teardown();
  t.run();
  ok('an empty teardown is fine', t.failures.length === 0);
}

// ── InputBus v3 pure logic ───────────────────────────────────────────────
ok('a short press is a tap', classifyRelease(50) === 'tap');
ok('a long press is a charge release', classifyRelease(600) === 'charge');
ok('the boundary is exclusive', classifyRelease(TAP_MAX_MS) === 'charge');
ok('just under the boundary is a tap', classifyRelease(TAP_MAX_MS - 1) === 'tap');
ok('DEFECT f: tap and charge are DIFFERENT — v2 emitted both every time',
  classifyRelease(50) !== classifyRelease(600));

const keys = (...k: string[]) => stickFromKeys(new Set(k));
ok('W is forward', keys('w').y === 1 && keys('w').x === 0);
ok('S is back', keys('s').y === -1);
ok('A is left', keys('a').x === -1);
ok('D is right', keys('d').x === 1);
ok('W+D is a diagonal', keys('w', 'd').x === 1 && keys('w', 'd').y === 1);
ok('opposite keys cancel', keys('a', 'd').x === 0);
ok('all four keys cancel to nothing', keys('w', 'a', 's', 'd').x === 0 && keys('w', 'a', 's', 'd').y === 0);
ok('no keys is neutral', keys().x === 0 && keys().y === 0);
ok('unrelated keys are ignored', keys('w', 'p', 'z').y === 1);
ok('stickFromKeys does NOT normalise — MotionModel owns magnitude',
  Math.hypot(keys('w', 'd').x, keys('w', 'd').y) > 1);

ok('default bindings cover the face buttons',
  ['A', 'B', 'X', 'Y'].every((b) => Object.values(DEFAULT_BINDINGS).includes(b as never)));
ok('bindings are a table, so remapping is a data change',
  typeof DEFAULT_BINDINGS === 'object' && DEFAULT_BINDINGS.j === 'A');

// preventDefault: the page must stop scrolling under the game, WITHOUT eating
// the user's own browser shortcuts.
const B = DEFAULT_BINDINGS;
ok('space is swallowed', shouldPreventDefault(' ', false, B));
ok('arrow keys are swallowed', shouldPreventDefault('arrowdown', false, B));
ok('DEFECT: Cmd-R is NEVER swallowed', !shouldPreventDefault('r', true, B));
ok('a modifier chord on a game key is still not swallowed',
  !shouldPreventDefault(' ', true, B));
ok('an unrelated key is left alone', !shouldPreventDefault('p', false, B));
ok('j is a game key but the browser does nothing with it, so it is not swallowed',
  isGameKey('j', B) && !shouldPreventDefault('j', false, B));

ok('WASD are game keys', ['w', 'a', 's', 'd'].every((k) => isGameKey(k, B)));
ok('shift is a game key — sprint is explicit', isGameKey('shift', B));
ok('space is a game key', isGameKey(' ', B));
ok('arrows are game keys', isGameKey('arrowleft', B));
ok('an unbound key is not', !isGameKey('p', B));
ok('a remapped key becomes a game key', isGameKey('p', { ...B, p: 'A' }));

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
