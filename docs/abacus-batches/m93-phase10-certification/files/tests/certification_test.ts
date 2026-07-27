// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/certification_test.ts
//
// Phase 10. One claim, and it is uncomfortable:
//
//   A certification pass that reports success off the back of green unit tests
//   is worse than no certification at all. BUILT must not be able to
//   masquerade as PASS.
//
// So most of these tests exist to prove the scorecard CANNOT flatter us.

import {
  CRITERIA, MANDATORY, counts, certify, certifyFleet, baselineToday, leverage,
  type ModeCertification, type CriterionState,
} from '../core/Certification.ts';
import { loadBearingTells } from '../../../m92-phase9-presentation/files/core/Legibility.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// ── the bar ──────────────────────────────────────────────────────────────
ok('there are twelve criteria', CRITERIA.length === 12);
ok('nine are mandatory', MANDATORY.length === 9);
ok('every criterion says how it is checked',
  CRITERIA.every((c) => c.evidence.length > 0),
  'a criterion with no evidence method cannot be certified, only asserted');
ok('criterion ids are unique', new Set(CRITERIA.map((c) => c.id)).size === 12);
ok('"fun" is not mandatory — only the founder can score it',
  !CRITERIA.find((c) => c.id === 'fun').mandatory);

// ── ONLY PASS COUNTS ─────────────────────────────────────────────────────
ok('PASS counts', counts('PASS'));
ok('BUILT DOES NOT — this is the whole point of the file', !counts('BUILT'));
ok('nor SPECIFIED', !counts('SPECIFIED'));
ok('nor UNKNOWN', !counts('UNKNOWN'));
ok('nor FAIL', !counts('FAIL'));

const cert = (states: Partial<Record<string, CriterionState>>, tells = 0, drawn = 0): ModeCertification => ({
  modeId: 'test',
  tellsRequired: tells,
  tellsDrawn: drawn,
  states: Object.fromEntries(CRITERIA.map((c) => [c.id, (states[c.id] ?? 'UNKNOWN')])) as Record<string, CriterionState>,
});

{
  const allBuilt = cert(Object.fromEntries(CRITERIA.map((c) => [c.id, 'BUILT'])));
  const v = certify(allBuilt);
  ok('A MODE WITH EVERY CRITERION "BUILT" IS NOT SHIPPABLE', !v.shippable);
  ok('and zero are counted as passed', v.passed === 0);
  ok('all nine mandatory criteria block it', v.blocking.length === 9);
  ok('and the summary refuses to flatter — it names BUILT as not-integrated',
    /BUILT is not a soft PASS/.test(v.summary), v.summary);
}
{
  const allPass = cert(Object.fromEntries(CRITERIA.map((c) => [c.id, 'PASS'])));
  const v = certify(allPass);
  ok('a mode with everything demonstrated IS shippable', v.shippable);
  ok('with nothing blocking', v.blocking.length === 0);
  ok('and says so plainly', /Shippable/.test(v.summary));
}
{
  // One missing mandatory criterion is enough.
  const nearly = cert({
    ...Object.fromEntries(CRITERIA.map((c) => [c.id, 'PASS'])),
    lifecycle: 'BUILT',
  });
  const v = certify(nearly);
  ok('ONE missing mandatory criterion blocks the mode', !v.shippable);
  ok('and it is named', v.blocking.includes('lifecycle'));
  ok('while eleven passes are still counted honestly', v.passed === 11);
}
{
  // Non-mandatory criteria do not block.
  const noFun = cert({
    ...Object.fromEntries(CRITERIA.map((c) => [c.id, 'PASS'])),
    fun: 'UNKNOWN',
  });
  ok('an unscored "fun" does not block shipping', certify(noFun).shippable);
}

// ── LEGIBILITY IS A GATE, NOT A NICE-TO-HAVE ─────────────────────────────
{
  const allPass = Object.fromEntries(CRITERIA.map((c) => [c.id, 'PASS' as CriterionState]));
  const invisible = certify(cert(allPass, 4, 0));
  ok('A MODE WITH EVERY CRITERION PASSED BUT NO TELLS DRAWN IS NOT SHIPPABLE',
    !invisible.shippable,
    'its mechanics are unreachable however green the tests are');
  ok('and legibility is named as the blocker', invisible.blocking.includes('legibility'));
  ok('drawing them unblocks it', certify(cert(allPass, 4, 4)).shippable);
  ok('a mode with no tells to draw is not penalised', certify(cert(allPass, 0, 0)).shippable);
}

// ── THE BASELINE: where the product actually is ──────────────────────────
{
  const b = baselineToday('dunk', 1);
  const v = certify(b);
  ok('TODAY: no mode is shippable', !v.shippable);
  ok('and almost everything is BUILT rather than PASS', v.built >= 7, `${v.built} built`);
  ok('only the two things that were always true PASS', v.passed === 2, `${v.passed}`);
  ok('and those are "procedural" and "tested"',
    b.states.procedural === 'PASS' && b.states.tested === 'PASS');
  ok('boot time is honestly UNKNOWN, not assumed', b.states.boot === 'UNKNOWN');
  ok('fun is UNKNOWN — nobody has played it', b.states.fun === 'UNKNOWN');
  ok('the canvas fix is SPECIFIED, not BUILT — CSS written, never verified',
    b.states.canvas === 'SPECIFIED');
}

// ── the fleet ────────────────────────────────────────────────────────────
{
  const modes = ['dunk', 'onevone', 'karate-vs', 'baseball', 'football', 'tennis',
    'skateboard', 'snowboard', 'surf', 'brain_brawl'];
  const fleet = certifyFleet(modes.map((m) => baselineToday(m, loadBearingTells(m).length)));

  ok('nothing in the fleet is shippable today', fleet.shippable === 0);
  ok('the report counts every mode', fleet.total === modes.length);
  ok('THE USEFUL OUTPUT: blockers are ranked by how many modes they hold back',
    fleet.topBlockers.length > 0
    && fleet.topBlockers.every((b, i, a) => i === 0 || a[i - 1].modes >= b.modes));
  ok('the worst blocker holds back most of the fleet',
    fleet.topBlockers[0].modes >= modes.length * 0.8, `${fleet.topBlockers[0].modes}`);
  ok('and the summary points at fixing one thing once rather than certifying '
    + 'modes one at a time', /one thing once/.test(fleet.summary), fleet.summary);
  ok('each blocker carries the bar text, not just an id',
    fleet.topBlockers.every((b) => b.bar.length > 5));
}
{
  const modes = ['dunk', 'onevone', 'karate-vs'].map((m) => baselineToday(m, 1));
  const shared = leverage('lifecycle', modes);
  const perMode = leverage('fun', modes);
  ok('a shared-layer blocker is identified as shared', shared.shared);
  ok('and says integrating once fixes all of them',
    /once fixes 3 mode/.test(shared.note), shared.note);
  ok('a per-mode blocker is identified as per-mode', !perMode.shared);
  ok('and says it needs separate work each time',
    /3 separate piece/.test(perMode.note), perMode.note);
  ok('CONFUSING THE TWO IS HOW A ROADMAP SPENDS A MONTH ON THE WRONG THING',
    shared.shared !== perMode.shared);
}

// ── the scorecard must be able to report failure ─────────────────────────
{
  const failing = cert({ ...Object.fromEntries(CRITERIA.map((c) => [c.id, 'PASS'])), response: 'FAIL' });
  const v = certify(failing);
  ok('an outright FAIL blocks', !v.shippable && v.blocking.includes('response'));
  ok('and is not counted as a pass', v.passed === 11);
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
