// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/creative_test.ts
//
// Phase 6. Two claims:
//
//   1. The Mental Resiliency Index measures something. It currently measures
//      nothing — ARV and ESI default to 50 and no mode overwrites them.
//   2. What you make becomes what you play with, and never makes you better.

import {
  MRI_ARV_WEIGHT, MRI_ESI_WEIGHT, MRI_PACING_WEIGHT, MIN_SAMPLES,
  gradeMri, computeArv, computeEsi, computePacing, assessResilience,
  resilienceNote, ResilienceTracker, loadCurve, timeAllowedMs,
  type PerfSample,
} from '../core/MentalResilience.ts';
import {
  SLOT_ACCEPTS, MODE_PRODUCES, EMPTY_LOADOUT, InvalidEquip, GAMEPLAY_KEYS,
  slotAcceptsIn, equip, unequip, activeIn, assertCosmetic, creationFrom,
  willAppearIn, attributionFor,
  type Creation, type EquipSlot,
} from '../core/CreatorLoop.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };
const near = (a: number, b: number, eps = 1e-9) => Math.abs(a - b) < eps;

// ══ MENTAL RESILIENCE ════════════════════════════════════════════════════
// Parity with backend/app/utils/constants.py and formulas.py.
ok('parity: ARV weight is 0.30', MRI_ARV_WEIGHT === 0.30);
ok('parity: ESI weight is 0.45 — the dominant term', MRI_ESI_WEIGHT === 0.45);
ok('parity: pacing weight is 0.25', MRI_PACING_WEIGHT === 0.25);
ok('the weights sum to 1', near(MRI_ARV_WEIGHT + MRI_ESI_WEIGHT + MRI_PACING_WEIGHT, 1));
ok('parity: 85+ is UNBREAKABLE', gradeMri(85) === 'UNBREAKABLE');
ok('parity: 65-84 is RESILIENT', gradeMri(65) === 'RESILIENT' && gradeMri(84) === 'RESILIENT');
ok('parity: 45-64 is ADAPTING', gradeMri(45) === 'ADAPTING');
ok('parity: below 45 is VULNERABLE', gradeMri(44) === 'VULNERABLE');
ok('grading clamps out-of-range input', gradeMri(500) === 'UNBREAKABLE' && gradeMri(-50) === 'VULNERABLE');

const sample = (o: Partial<PerfSample> = {}): PerfSample =>
  ({ tick: 0, success: true, load: 0.5, quality: 1, ...o });
const series = (n: number, f: (i: number) => Partial<PerfSample>): PerfSample[] =>
  Array.from({ length: n }, (_, i) => sample({ tick: i, ...f(i) }));

// THE BASELINE FAILURE THIS FIXES
ok('THE BUG: with no samples everything is 50 — which is exactly what every '
  + 'player scores today', assessResilience([]).mri === 50);
ok('and it says so honestly rather than reporting a grade',
  /too short/.test(assessResilience([]).note));
ok('a short session has low confidence', assessResilience(series(3, () => ({}))).confidence < 0.3);
ok('a full session has full confidence', assessResilience(series(20, () => ({}))).confidence === 1);

// ── ARV: recovery after a setback ────────────────────────────────────────
{
  // Tilt: every failure is followed by worse performance.
  const tilts = series(20, (i) => {
    const failed = i % 5 === 0;
    const afterFail = i % 5 === 1 || i % 5 === 2;
    return { success: !failed, quality: failed ? 0 : afterFail ? 0.2 : 1 };
  });
  // Reset: failures are followed by a return to form.
  const resets = series(20, (i) => {
    const failed = i % 5 === 0;
    return { success: !failed, quality: failed ? 0 : 1 };
  });
  ok('THE ARV CLAIM: tilting after a mistake scores worse than resetting',
    computeArv(tilts) < computeArv(resets), `${computeArv(tilts)} vs ${computeArv(resets)}`);
  // Returning to exactly your prior form is NEUTRAL, by definition: 50 means
  // adversity cost you nothing. Scoring above it requires coming back
  // STRONGER, which is what resilience beyond mere recovery looks like.
  ok('a clean reset is neutral — adversity cost nothing',
    Math.abs(computeArv(resets) - 50) < 6, `${computeArv(resets)}`);
  ok('a player who tilts scores well below neutral', computeArv(tilts) < 45,
    `${computeArv(tilts)}`);

  const surges = series(20, (i) => {
    const failed = i % 5 === 0;
    const afterFail = i % 5 === 1 || i % 5 === 2;
    return { success: !failed, quality: failed ? 0 : afterFail ? 1 : 0.6 };
  });
  ok('and coming back STRONGER scores above neutral', computeArv(surges) > 55,
    `${computeArv(surges)}`);
}
{
  const flawless = series(20, () => ({ success: true, quality: 1 }));
  ok('NO FAILURES IS AN UNTESTED RESILIENCE, NOT A PERFECT ONE',
    computeArv(flawless) < 70,
    'otherwise an easy session mints an UNBREAKABLE grade');
  ok('but it is not penalised either', computeArv(flawless) >= 55);
}
{
  // Measured against the player's OWN baseline, not an absolute.
  const weakButSteady = series(20, (i) => ({ success: i % 4 !== 0, quality: i % 4 === 0 ? 0 : 0.4 }));
  const strongButFragile = series(20, (i) => {
    const failed = i % 4 === 0;
    return { success: !failed, quality: failed ? 0 : (i % 4 === 1 ? 0.3 : 0.95) };
  });
  ok('A WEAK PLAYER WHO HOLDS THEIR LEVEL BEATS A STRONG ONE WHO FALLS APART',
    computeArv(weakButSteady) > computeArv(strongButFragile),
    `${computeArv(weakButSteady)} vs ${computeArv(strongButFragile)}`);
}

// ── ESI: does accuracy hold as load rises? ───────────────────────────────
{
  const holds = series(20, (i) => ({ load: i / 19, quality: 0.6 }));
  const collapses = series(20, (i) => ({ load: i / 19, quality: 1 - (i / 19) * 0.7 }));
  ok('THE ESI CLAIM: holding accuracy under load beats collapsing',
    computeEsi(holds) > computeEsi(collapses), `${computeEsi(holds)} vs ${computeEsi(collapses)}`);
  ok('a flat curve scores at or above neutral', computeEsi(holds) >= 50);
  ok('a collapsing one scores well below', computeEsi(collapses) < 40);
}
{
  // THE ORDERING THAT MAKES IT RESILIENCE RATHER THAN SKILL.
  const mediocreSteady = series(20, (i) => ({ load: i / 19, quality: 0.58 + (i % 2) * 0.02 }));
  const brilliantFragile = series(20, (i) => ({ load: i / 19, quality: i < 10 ? 0.95 : 0.6 }));
  ok('60% throughout beats 95%-then-60% — a resilience metric measures the '
    + 'DROP, not the level', computeEsi(mediocreSteady) > computeEsi(brilliantFragile),
    `${computeEsi(mediocreSteady)} vs ${computeEsi(brilliantFragile)}`);
}
{
  const noBand = series(20, (i) => ({ load: i / 19, quality: 0.7 }));
  const withBand = series(20, (i) => ({ load: i / 19, quality: 0.7, exertion: i / 19 }));
  ok('exertion data is a BONUS, not a requirement — most players never wear a '
    + 'band and the metric must still mean something',
    computeEsi(noBand) > 0 && computeEsi(withBand) > 0);
  const fadesUnderExertion = series(20, (i) => ({ load: 0.5, quality: i > 12 ? 0.3 : 0.9, exertion: i / 19 }));
  ok('holding accuracy at a high heart rate is rewarded over fading',
    computeEsi(withBand) > computeEsi(fadesUnderExertion));
}

// ── Pacing ───────────────────────────────────────────────────────────────
{
  const steady = series(21, () => ({ quality: 0.7 }));
  const fades = series(21, (i) => ({ quality: 1 - (i / 20) * 0.7 }));
  const builds = series(21, (i) => ({ quality: 0.4 + (i / 20) * 0.5 }));
  ok('fading scores worse than sustaining', computePacing(fades) < computePacing(steady));
  ok('IMPROVING SCORES ABOVE NEUTRAL — finishing stronger is good pacing, not '
    + 'inconsistency', computePacing(builds) > 50, `${computePacing(builds)}`);
  const erratic = series(21, (i) => ({ quality: i % 2 === 0 ? 0.1 : 1 }));
  ok('but wild oscillation is penalised even when it starts and ends alike',
    computePacing(erratic) < computePacing(steady), `${computePacing(erratic)}`);
}

// ── the whole assessment ─────────────────────────────────────────────────
{
  const strong = series(24, (i) => ({ load: i / 23, quality: 0.85, success: true }));
  const weak = series(24, (i) => ({
    load: i / 23,
    quality: i < 8 ? 0.9 : 0.2,
    success: i < 8,
  }));
  const a = assessResilience(strong);
  const b = assessResilience(weak);
  ok('a resilient session outscores a fragile one', a.mri > b.mri, `${a.mri} vs ${b.mri}`);
  ok('and the MRI matches the backend formula exactly',
    near(a.mri, Math.round((a.arv * 0.3 + a.esi * 0.45 + a.pacing * 0.25) * 100) / 100));
  ok('the grade follows the score', a.grade === gradeMri(a.mri));
  ok('all three parts are in 0-100, matching the receipt schema',
    [a.arv, a.esi, a.pacing].every((v) => v >= 0 && v <= 100));
}
{
  ok('the note names the WEAKEST axis, because that is the actionable one',
    /load rises/.test(resilienceNote(80, 30, 80)));
  ok('a tilt problem is named as one', /after a miss/.test(resilienceNote(30, 80, 80)));
  ok('a fade is named as one', /fade/.test(resilienceNote(80, 80, 30)));
  ok('and a strong session is told so', /held your level/.test(resilienceNote(80, 80, 80)));
}
{
  const t = new ResilienceTracker();
  for (let i = 0; i < 20; i++) t.recordSimple(i, i % 4 !== 0, i / 19);
  ok('the tracker accumulates', t.count === 20);
  const f = t.receiptFields();
  ok('and produces exactly the receipt fields',
    'arv' in f && 'esi' in f && 'pacing_score' in f);
  ok('which are no longer the default 50',
    f.arv !== 50 || f.esi !== 50 || f.pacing_score !== 50);
  t.reset();
  ok('and it resets', t.count === 0);
}
{
  // MODE-AGNOSTIC is the point: MRI across the whole product, not just quizzes.
  const quiz = series(20, (i) => ({ load: i / 19, quality: 0.7 }));
  const rally = series(20, (i) => ({ load: i / 19, quality: 0.7 }));
  ok('a quiz and a rally producing the same shape score the same — which is '
    + 'what lets MRI be measured product-wide',
    assessResilience(quiz).mri === assessResilience(rally).mri);
}

// ── escalating load ──────────────────────────────────────────────────────
{
  ok('load rises across a round', loadCurve(0, 10) < loadCurve(9, 10));
  ok('it starts gently', loadCurve(0, 10) <= 0.25);
  ok('and finishes at maximum', loadCurve(9, 10) === 1);
  ok('a single-question round is neutral', loadCurve(0, 1) === 0.5);
  ok('WITHOUT ESCALATION, ESI IS 50 BY CONSTRUCTION — a quiz at one difficulty '
    + 'cannot measure stability under load',
    computeEsi(series(20, () => ({ load: 0.5, quality: 0.7 }))) === 50);
  ok('time pressure tightens with load', timeAllowedMs(5000, 1) < timeAllowedMs(5000, 0));
  ok('and never reaches zero', timeAllowedMs(5000, 1) > 0);
}

// ══ CREATOR LOOP ═════════════════════════════════════════════════════════
const creation = (o: Partial<Creation> = {}): Creation => ({
  id: 'c1', kind: 'track', authorId: 'alice', title: 'Test',
  sourceMode: 'music', createdAt: '2026-01-01', payload: { bpm: 120 }, ...o,
});

ok('each creative mode produces something', Object.keys(MODE_PRODUCES).length === 4);
ok('music makes tracks', MODE_PRODUCES.music === 'track');
ok('art makes skins', MODE_PRODUCES.art === 'skin');
ok('dance makes emotes', MODE_PRODUCES.dance === 'emote');
ok('acting makes callouts', MODE_PRODUCES.acting === 'callout');

{
  const l = equip(EMPTY_LOADOUT, 'soundtrack', creation());
  ok('a track equips to the soundtrack slot', l.equipped.soundtrack === 'c1');
  ok('unequipping clears it', unequip(l, 'soundtrack').equipped.soundtrack === undefined);
  ok('the original loadout is not mutated', EMPTY_LOADOUT.equipped.soundtrack === undefined);
}
{
  let threw = false;
  try { equip(EMPTY_LOADOUT, 'venue_skin', creation({ kind: 'track' })); }
  catch (e) { threw = e instanceof InvalidEquip && /cannot go in/.test((e as Error).message); }
  ok('A WRONG EQUIP THROWS RATHER THAN SILENTLY DOING NOTHING — which is '
    + 'exactly what applyArtCard did for months', threw);
}
{
  ok('a soundtrack plays everywhere', slotAcceptsIn('soundtrack', 'dunk'));
  ok('EXCEPT in Music and Dance — your own track over Music is a loop with no '
    + 'meaning, and Dance needs its own beat to score against',
    !slotAcceptsIn('soundtrack', 'music') && !slotAcceptsIn('soundtrack', 'dance'));
  ok('a court skin applies to court modes', slotAcceptsIn('venue_skin', 'dunk'));
  ok('and not to tennis', !slotAcceptsIn('venue_skin', 'tennis'));
}
{
  const lib = new Map<string, Creation>([
    ['t1', creation({ id: 't1', kind: 'track' })],
    ['s1', creation({ id: 's1', kind: 'skin', sourceMode: 'art' })],
  ]);
  const l = equip(equip(EMPTY_LOADOUT, 'soundtrack', lib.get('t1')), 'venue_skin', lib.get('s1'));

  const onCourt = activeIn(l, 'dunk', lib);
  ok('both apply on a court', onCourt.active.soundtrack && onCourt.active.venue_skin);

  const onTennis = activeIn(l, 'tennis', lib);
  ok('only the track applies in tennis', !!onTennis.active.soundtrack && !onTennis.active.venue_skin);
  ok('AND THE INACTIVE SLOT IS REPORTED, so the UI can explain it rather than '
    + 'looking broken', onTennis.inactive.includes('venue_skin'));

  const deleted = activeIn({ equipped: { soundtrack: 'gone' } }, 'dunk', lib);
  ok('a deleted creation is skipped, not an error',
    Object.keys(deleted.active).length === 0 && deleted.inactive.length === 0);
}

// ── THE NON-NEGOTIABLE RULE ──────────────────────────────────────────────
{
  ok('a cosmetic payload passes', (() => {
    assertCosmetic({ bpm: 120, key: 'Am', colors: ['#fff'] }); return true;
  })());

  for (const key of ['speed', 'damage', 'multiplier', 'prq']) {
    let threw = false;
    try { assertCosmetic({ [key]: 2 }); } catch { threw = true; }
    ok(`a payload carrying "${key}" is REFUSED`, threw);
  }
  let nested = false;
  try { assertCosmetic({ style: { visual: { accuracy: 1.2 } } }); } catch { nested = true; }
  ok('and nested gameplay fields are caught too', nested);
  ok('the refusal explains WHY, not just that it failed', (() => {
    try { assertCosmetic({ power: 5 }); return false; }
    catch (e) { return /pay-to-win/.test((e as Error).message); }
  })());
  ok('the guard covers the obvious levers', GAMEPLAY_KEYS.length >= 10);
}
{
  const { creation: c, equipNow } = creationFrom('music', 'bob', 'Night Court', { bpm: 92 });
  ok('finishing a creative session yields a creation', c.kind === 'track' && c.authorId === 'bob');
  ok('THE LOOP: it comes back with a slot to equip it into, immediately',
    equipNow === 'soundtrack',
    'a player who has to find a loadout screen never discovers the loop exists');
  ok('a non-creative mode produces nothing', (() => {
    try { creationFrom('dunk', 'bob', 'x', {}); return false; } catch { return true; }
  })());
  ok('and a creation carrying a gameplay field is refused at birth', (() => {
    try { creationFrom('art', 'bob', 'x', { damage: 5 }); return false; } catch { return true; }
  })());
}
{
  const modes = ['dunk', 'onevone', 'tennis', 'music', 'dance', 'karate'];
  const forTrack = willAppearIn('track', modes);
  ok('a track appears in most modes', forTrack.length >= 4);
  // A track reaches Music and Dance through the INTRO slot, not the
  // soundtrack slot — an intro card plays before the session starts, so it
  // does not fight the mode's own audio. The exclusion is per-SLOT, and an
  // earlier assertion here over-generalised it to the whole creation.
  ok('but its SOUNDTRACK slot is still excluded there',
    !slotAcceptsIn('soundtrack', 'music') && !slotAcceptsIn('soundtrack', 'dance'));
  ok('while the intro slot is fine, because it plays before the mode does',
    slotAcceptsIn('intro', 'music'));
  const forSkin = willAppearIn('skin', modes);
  ok('a skin appears only on courts', forSkin.includes('dunk') && !forSkin.includes('tennis'));
  ok('CONCRETE BEATS "EQUIPPED!" — a creator can see exactly where their work '
    + 'will be seen', forTrack.length > 0);
}
{
  const active = {
    soundtrack: creation({ id: 't1', authorId: 'alice' }),
    venue_skin: creation({ id: 's1', kind: 'skin', authorId: 'carol' }),
  } as Partial<Record<EquipSlot, Creation>>;

  const attr = attributionFor(active, 'bob');
  ok('both authors are credited', attr.length === 2);
  ok('with the slot and creation id', attr[0].slot && attr[0].creationId);

  const own = attributionFor(active, 'alice');
  ok('YOU DO NOT PAY YOURSELF', own.length === 1 && own[0].authorId === 'carol');

  const authors = new Set(attr.map((a) => a.authorId));
  ok('ONE HOP ONLY — attribution names the author and nobody above them, which '
    + 'is what keeps this a flat marketplace rather than a recruitment scheme',
    authors.size === attr.length && !attr.some((a) => a.authorId === 'bob'));
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
