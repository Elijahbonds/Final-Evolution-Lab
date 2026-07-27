// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/field_test.ts
//
// Phase 4. Three claims:
//
//   1. Football evades are a READ — commit to a direction and it can be wrong.
//   2. Baseball is a classification problem under a deadline, not a timing bar.
//   3. A rally builds pressure, so the winner is struck two shots after the
//      shot that actually won the point.

import {
  EVADES, evadeBeatsPursuit, resolveEvade, correctEvade, StyleChain, evasionCoaching,
  type Pursuit, type EvadeType,
} from '../core/EvasionCore.ts';
import {
  PITCHES, flightTimeMs, decisionWindowMs, SWING_DURATION_MS, recognitionAt,
  identifyConfidence, resolvePlateAppearance, PitchSelector, hittingCoaching,
  type PitchType,
} from '../core/PitchRecognition.ts';
import {
  FRESH, TENNIS_COURT, COMFORTABLE_UNITS_PER_SEC, MAX_UNITS_PER_SEC,
  courtDistance, movementCost, receiveShot,
  shotQualityUnderPressure, degradePlacement, shotDemand, isReachable,
  chooseTarget, rallyNote,
  type PlayerCourtState,
} from '../core/RallyPressure.ts';
import { Rng } from '../../../m83-determinism-and-ghosts/files/core/Rng.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// ══ FOOTBALL ═════════════════════════════════════════════════════════════
const pursuit = (o: Partial<Pursuit> = {}): Pursuit =>
  ({ angleDeg: 45, distance: 1.5, closingSpeed: 6, committed: false, ...o });

// THE CORE CLAIM: the same input, opposite outcomes, decided by a read.
{
  const fromRight = pursuit({ angleDeg: 45 });
  const away = evadeBeatsPursuit('juke', -1, fromRight);
  const into = evadeBeatsPursuit('juke', 1, fromRight);
  ok('THE READ: juking AWAY from the pursuit works', away.beats, away.reason);
  ok('and juking INTO it does not', !into.beats, into.reason);
  ok('the failure names the mistake', /juked INTO them/.test(into.reason));
}
{
  ok('a juke against a head-on defender fails — no line to step off',
    !evadeBeatsPursuit('juke', -1, pursuit({ angleDeg: 5 })).beats);
  ok('a TRUCK is the answer head-on',
    evadeBeatsPursuit('truck', 1, pursuit({ angleDeg: 5 })).beats);
  ok('but a truck at 45° hits nothing',
    !evadeBeatsPursuit('truck', 1, pursuit({ angleDeg: 45 })).beats);
  ok('a hurdle also answers head-on',
    evadeBeatsPursuit('hurdle', 1, pursuit({ angleDeg: 10 })).beats);
  ok('a spin needs an angle, like a juke',
    !evadeBeatsPursuit('spin', 1, pursuit({ angleDeg: 5 })).beats);
  ok('but a spin does NOT care which way you turn — it is the forgiving one',
    evadeBeatsPursuit('spin', 1, pursuit({ angleDeg: 55 })).beats
    && evadeBeatsPursuit('spin', -1, pursuit({ angleDeg: 55 })).beats);
}
{
  // The design rule, asserted: no evade answers every angle.
  const angles = [0, 15, 30, 45, 60, 80, 95];
  for (const e of Object.keys(EVADES) as EvadeType[]) {
    const beatsAll = angles.every((a) =>
      evadeBeatsPursuit(e, -1, pursuit({ angleDeg: a })).beats
      || evadeBeatsPursuit(e, 1, pursuit({ angleDeg: a })).beats);
    ok(`NO SINGLE ANSWER: ${e} does not beat every angle`, !beatsAll);
  }
  ok('but every angle has SOME answer',
    angles.every((a) => (Object.keys(EVADES) as EvadeType[]).some((e) =>
      evadeBeatsPursuit(e, -1, pursuit({ angleDeg: a })).beats
      || evadeBeatsPursuit(e, 1, pursuit({ angleDeg: a })).beats)),
    'an unanswerable situation is a cheap shot, not difficulty');
}
{
  ok('the spin is the most forgiving and pays for it in recovery',
    EVADES.spin.toleranceDeg > EVADES.juke.toleranceDeg
    && EVADES.spin.recovery > EVADES.juke.recovery);
  ok('the truck is the slowest to start — power is committal',
    EVADES.truck.startup >= Math.max(...Object.values(EVADES).map((e) => e.startup)));
  ok('the juke keeps the most momentum',
    EVADES.juke.speedMul > EVADES.truck.speedMul);
}
{
  const rng = new Rng(1);
  ok('evading with nobody near is a wasted move',
    resolveEvade('juke', -1, pursuit({ distance: 6 }), rng).outcome === 'no_contact');
  const clean = resolveEvade('juke', -1, pursuit({ angleDeg: 45 }), rng);
  ok('a correct read gains yards', clean.outcome === 'clean' && clean.yards > 0);
  ok('and pays style', clean.style > 0);

  const baited = resolveEvade('juke', -1, pursuit({ angleDeg: 45, committed: true }), rng);
  ok('BAITING A COMMITMENT PAYS MORE — the same skill Phase 2 rewards',
    baited.yards > clean.yards && baited.style > clean.style);
}
{
  // A wrong read must not be a coin flip, but it must not be an instant stop
  // either — a graze tells the player they were close.
  const rng = new Rng(9);
  let tackled = 0; let grazed = 0;
  for (let i = 0; i < 200; i++) {
    const r = resolveEvade('juke', 1, pursuit({ angleDeg: 45 }), rng);
    if (r.outcome === 'tackled') tackled++;
    if (r.outcome === 'grazed') grazed++;
  }
  ok('a wrong read is usually a tackle', tackled > grazed, `${tackled}/${grazed}`);
  ok('but sometimes only a graze — binary outcomes feel arbitrary', grazed > 0);
  ok('a tackle loses yards',
    resolveEvade('juke', 1, pursuit({ angleDeg: 45, closingSpeed: 6 }), new Rng(2)).yards <= 0);
}
{
  ok('the right answer head-on is truck', correctEvade(pursuit({ angleDeg: 5 })).evade === 'truck');
  ok('at 45° it is a juke away from them',
    correctEvade(pursuit({ angleDeg: 45 })).evade === 'juke'
    && correctEvade(pursuit({ angleDeg: 45 })).direction === -1);
  ok('and the named answer actually works at every angle',
    [0, 10, 30, 45, 70, 90].every((a) => {
      const c = correctEvade(pursuit({ angleDeg: a }));
      return evadeBeatsPursuit(c.evade, c.direction, pursuit({ angleDeg: a })).beats;
    }),
    'a tutorial that teaches a losing answer is worse than none');
}
{
  const chain = new StyleChain();
  ok('a tackle pays nothing and breaks the streak', chain.record('juke', 'tackled') === 0);
  const first = chain.record('juke', 'clean');
  ok('a new evade type pays a variety bonus', first >= 25);
  const repeat = chain.record('juke', 'clean');
  ok('repeating the same type pays less', repeat < first);
  ok('VARIETY IS ONLY PAID ON SUCCESS — the live version paid for cycling '
    + 'buttons regardless of whether each was the right read',
    new StyleChain().record('spin', 'tackled') === 0);
  ok('variety counts only what worked', chain.variety === 1);
  for (let i = 0; i < 10; i++) chain.record('spin', 'clean');
  ok('the streak bonus plateaus so one long run cannot outscore a game',
    chain.record('spin', 'clean') <= 25 + 25);
}
ok('no evasion advice from a small sample',
  evasionCoaching({ attempts: 2, tackled: 2, wrongWay: 2, early: 0 }) === null);
ok('juking into tackles is named',
  /INTO the tackle/.test(evasionCoaching({ attempts: 10, tackled: 5, wrongWay: 5, early: 0 }) ?? ''));
ok('evading early is named',
  /too early/.test(evasionCoaching({ attempts: 10, tackled: 2, wrongWay: 1, early: 5 }) ?? ''));
ok('a good drive gets no lecture',
  evasionCoaching({ attempts: 10, tackled: 1, wrongWay: 1, early: 1 }) === null);

// ══ BASEBALL ═════════════════════════════════════════════════════════════
{
  const fb = flightTimeMs(PITCHES.fastball);
  ok('a 150kph fastball reaches the plate in about 440ms', fb > 400 && fb < 470, `${fb}ms`);
  ok('THE PREMISE: the decision window is under 300ms',
    decisionWindowMs(PITCHES.fastball) < 300, `${decisionWindowMs(PITCHES.fastball)}ms`);
  ok('which is barely above simple human reaction time (~200ms)',
    decisionWindowMs(PITCHES.fastball) > 150,
    'and this is a FOUR-WAY classification, not a simple stimulus');
  ok('a slower pitch buys real time',
    decisionWindowMs(PITCHES.curveball) > decisionWindowMs(PITCHES.fastball));
  ok('the swing itself costs 150ms of that budget', SWING_DURATION_MS === 150);
}
{
  ok('a pitch is unidentifiable at release', recognitionAt(PITCHES.fastball, 0) === 0);
  ok('and obvious by the time it arrives',
    recognitionAt(PITCHES.fastball, flightTimeMs(PITCHES.fastball)) === 1);
  ok('recognition only ever increases',
    [0, 50, 100, 200, 300, 400].every((t, i, a) =>
      i === 0 || recognitionAt(PITCHES.changeup, t) >= recognitionAt(PITCHES.changeup, a[i - 1])));

  const window = decisionWindowMs(PITCHES.changeup);
  ok('THE CHANGEUP IS THE HARDEST PITCH IN BASEBALL, and it falls out of the '
    + 'model rather than being asserted',
    recognitionAt(PITCHES.changeup, window) < recognitionAt(PITCHES.fastball, decisionWindowMs(PITCHES.fastball)),
    `changeup ${recognitionAt(PITCHES.changeup, window).toFixed(2)}`);
  ok('because a good changeup leaves the hand looking like a fastball',
    Math.abs(PITCHES.changeup.tell.apparentSpeed - PITCHES.fastball.tell.apparentSpeed) < 0.06);
  ok('while a curveball gives itself away out of the hand',
    PITCHES.curveball.tell.apparentSpeed < 0.85 && PITCHES.curveball.deception < PITCHES.changeup.deception);
}
{
  const t = 200;
  ok('a better hitter identifies sooner',
    identifyConfidence(PITCHES.slider, t, 0.9) > identifyConfidence(PITCHES.slider, t, 0.1));
  ok('but nobody identifies at release',
    identifyConfidence(PITCHES.slider, 0, 1) === 0);
}
{
  const pa = (o: Partial<Parameters<typeof resolvePlateAppearance>[0]> = {}) =>
    resolvePlateAppearance({
      pitch: PITCHES.fastball, guessed: 'fastball', decision: 'swing',
      committedAtMs: 100, inZone: true, ...o,
    });

  ok('taking a strike is a called strike', pa({ decision: 'take' }).outcome === 'called_strike');
  ok('taking a ball is a ball', pa({ decision: 'take', inZone: false }).outcome === 'ball');
  ok('chasing out of the zone whiffs', pa({ inZone: false }).outcome === 'whiff');

  ok('THE PRINCIPLE: a correct read, struck on time, is barrelled',
    pa({ committedAtMs: 50 }).outcome === 'barrelled');
  ok('a correct read slightly late is still solid contact',
    ['solid', 'foul'].includes(pa({ committedAtMs: 340 }).outcome));

  const sat = pa({ pitch: PITCHES.changeup, guessed: 'fastball', committedAtMs: 50 });
  ok('SITTING FASTBALL ON A CHANGEUP IS A WHIFF, however good the timing',
    sat.outcome === 'whiff', sat.outcome);
  ok('and it says why', /out in front/.test(sat.note));

  const near = pa({ pitch: PITCHES.slider, guessed: 'fastball', committedAtMs: 50 });
  ok('a near-miss read on a similar speed is weak contact, not a whiff',
    near.outcome === 'weak_contact', near.outcome);

  ok('BEING RIGHT MATTERS MORE THAN BEING ON TIME',
    pa({ pitch: PITCHES.curveball, guessed: 'curveball', committedAtMs: 400 }).quality
    > pa({ pitch: PITCHES.curveball, guessed: 'fastball', committedAtMs: 50 }).quality,
    'which is exactly what a timing bar cannot express');
}
{
  const s = new PitchSelector(new Rng(4), 0.6);
  const thrown: PitchType[] = [];
  for (let i = 0; i < 30; i++) thrown.push(s.next().id);
  ok('the pitcher never throws the same pitch three times running',
    !thrown.some((p, i) => i >= 2 && p === thrown[i - 1] && p === thrown[i - 2]));
  ok('and mixes all four', new Set(thrown).size === 4);

  const s2 = new PitchSelector(new Rng(5), 0.8);
  for (let i = 0; i < 4; i++) s2.observeGuess('fastball');
  const after: PitchType[] = [];
  for (let i = 0; i < 40; i++) after.push(s2.next().id);
  const fbRate = after.filter((p) => p === 'fastball').length / after.length;
  ok('A HITTER SITTING FASTBALL GETS FED OFF-SPEED — the same read/be-read '
    + 'loop as the basketball defender', fbRate < 0.2, `${(fbRate * 100).toFixed(0)}%`);
}
{
  const run = () => {
    const s = new PitchSelector(new Rng(777), 0.5);
    return Array.from({ length: 40 }, () => s.next().id).join();
  };
  ok('pitch selection is deterministic — a replayed at-bat is the same at-bat',
    run() === run());
}
ok('no hitting advice from a small sample',
  hittingCoaching({ swings: 3, whiffs: 3, chased: 3, misreads: 0, barrelled: 0 }) === null);
ok('chasing is named', /chasing/.test(hittingCoaching({ swings: 10, whiffs: 4, chased: 5, misreads: 1, barrelled: 1 }) ?? ''));
ok('sitting fastball is named',
  /sitting fastball/.test(hittingCoaching({ swings: 10, whiffs: 2, chased: 1, misreads: 6, barrelled: 1 }) ?? ''));
ok('good hitting is recognised, not lectured',
  /whole skill/.test(hittingCoaching({ swings: 10, whiffs: 1, chased: 1, misreads: 1, barrelled: 6 }) ?? ''));

// ══ RALLY ════════════════════════════════════════════════════════════════
{
  ok('a fresh player is set', FRESH.recovery === 1 && FRESH.pressure === 0);
  ok('court distance weights depth less than width',
    courtDistance({ x: 0, depth: 0 }, { x: 1, depth: 0 })
    > courtDistance({ x: 0, depth: 0 }, { x: 0, depth: 1 }));
}
{
  const easy = movementCost(FRESH, { x: 0.1, depth: 0.8 }, 1.2);
  const hard = movementCost(FRESH, { x: -0.95, depth: 0.95 }, 0.6);
  ok('a ball hit near them costs nothing', easy === 0);
  ok('a ball hit into the far corner costs recovery', hard > 0.3, `${hard}`);
  ok('more time to reach it costs less',
    movementCost(FRESH, { x: -0.9, depth: 0.9 }, 1.5) < hard);
}
{
  // THE LOOP: work them, and the ball they give back is worse.
  let s: PlayerCourtState = FRESH;
  const before = shotQualityUnderPressure(s);
  s = receiveShot(s, { x: -0.9, depth: 0.9 }, 0.6);
  s = receiveShot(s, { x: 0.9, depth: 0.9 }, 0.6);
  const after = shotQualityUnderPressure(s);
  ok('THE RALLY LOOP: two demanding shots degrade the reply', after < before, `${before} → ${after}`);
  ok('pressure accumulated', s.pressure > 0.4, `${s.pressure}`);

  const easy = receiveShot(s, { x: s.x, depth: s.depth }, 1.5);
  ok('and a loose ball lets them reset', easy.pressure < s.pressure);
  ok('but pressure sheds slower than it builds — one loose ball does not undo '
    + 'the work', easy.pressure > 0);
}
{
  const stretched: PlayerCourtState = { x: 0.9, depth: 0.9, recovery: 0.2, pressure: 0.8 };
  const aim = { x: -0.9, depth: 0.9 };
  const got = degradePlacement(aim, shotQualityUnderPressure(stretched));
  ok('a stretched player cannot hit where they aimed',
    Math.abs(got.x) < Math.abs(aim.x));
  ok('THE DEGRADATION IS TOWARD THE MIDDLE AND SHORT, not random — random '
    + 'error feels unfair, a readable weak reply is a mechanic',
    Math.abs(got.x) < Math.abs(aim.x) && got.depth < aim.depth);
  const set = degradePlacement(aim, shotQualityUnderPressure(FRESH));
  ok('a set player hits close to their aim', Math.abs(set.x - aim.x) < 0.15);
}
{
  const centred: PlayerCourtState = { ...FRESH, x: 0 };
  ok('a ball to the corner demands more than one to the middle',
    shotDemand({ x: -0.9, depth: 0.9 }, centred) > shotDemand({ x: 0, depth: 0.5 }, centred));
  ok('THE SAME TARGET IS A WINNER OR A GIFT DEPENDING ON WHERE THEY ARE',
    shotDemand({ x: -0.9, depth: 0.9 }, { ...FRESH, x: 0.9 })
    > shotDemand({ x: -0.9, depth: 0.9 }, { ...FRESH, x: -0.9 }),
    'which is the property that makes rallies build');
  ok('an unreachable ball is unreachable', !isReachable(FRESH, { x: -1, depth: 1 }, 0.1));
  ok('a reachable one is reachable', isReachable(FRESH, { x: 0.2, depth: 0.8 }, 1.0));
  // Grounded in the real court, because the first draft was not: it had a
  // player crossing a full singles court in 0.83s, so nothing ever cost
  // anything and the pressure model was inert.
  ok('comfortable movement is ~2.7 m/s on a 4.1m half-width',
    Math.abs(COMFORTABLE_UNITS_PER_SEC * 4.1 - 2.7) < 0.2);
  ok('a full sprint is ~4.7 m/s, not superhuman',
    MAX_UNITS_PER_SEC * 4.1 > 4 && MAX_UNITS_PER_SEC * 4.1 < 5.5);
  ok('crossing the full court takes over a second',
    2 / MAX_UNITS_PER_SEC > 1.5, `${(2 / MAX_UNITS_PER_SEC).toFixed(2)}s`);
}
{
  const stretched: PlayerCourtState = { x: 0.9, depth: 0.9, recovery: 0.3, pressure: 0.7 };
  const a = chooseTarget(stretched, 0.6);
  ok('a stretched opponent gets attacked', a.intent === 'attack');
  ok('into the open court', Math.sign(a.target.x) !== Math.sign(stretched.x));

  const set: PlayerCourtState = { ...FRESH };
  const b = chooseTarget(set, 0.6);
  ok('BUILDING, NOT WINNER-HUNTING, AGAINST A SET OPPONENT', b.intent === 'build');
  ok('and the build shot is less extreme than the attack',
    Math.abs(b.target.x) < Math.abs(a.target.x),
    'going for a winner off a neutral ball is how club players lose points');
  ok('a passive player resets deep and central',
    chooseTarget(set, 0.1).intent === 'reset');
}
ok('no rally note from a short point', rallyNote([{ demand: 0.9, pressureAfter: 0.9 }]) === null);
ok('a point lost to accumulated pressure is explained',
  /before the last ball/.test(rallyNote([
    { demand: 0.7, pressureAfter: 0.4 },
    { demand: 0.8, pressureAfter: 0.7 },
    { demand: 0.6, pressureAfter: 0.85 },
  ]) ?? ''));
ok('a flat rally is named as one',
  /never ends/.test(rallyNote([
    { demand: 0.1, pressureAfter: 0 },
    { demand: 0.2, pressureAfter: 0 },
    { demand: 0.1, pressureAfter: 0 },
  ]) ?? ''));

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
