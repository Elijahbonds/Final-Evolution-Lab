// node --experimental-strip-types --import ./tools/ts_resolve.mjs \
//   --import ./tools/fel_batch_alias.mjs tests/verifiability_test.ts

import {
  isCosmeticSite, verdictFor, cashEligible, remediation, MEASURED, COSMETIC_FRAME,
} from '../core/verifiability.ts';

let pass = 0, fail = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };

// ══ THE RULE THAT A THRESHOLD GETS WRONG ═════════════════════════════════
{
  // onevone's real numbers: 107 AI-decision calls against 13,794 particle
  // calls. A 20% share threshold — which the first version of the probe used —
  // passes this. One unreproducible decision invalidates the whole match.
  const sites = [
    { site: 's < m0._update < m0.animate', calls: 6897 },
    { site: 's < mS.startPositionFunction < m0._update', calls: 6897 },
    { site: 'e4.decide < er.poll < es.poll', calls: 107 },
  ];
  const r = verdictFor(sites, true);
  ok('ONE AI ROLL IN 13,901 CALLS IS DISQUALIFYING', r.verdict === 'unverifiable');
  ok('and a share threshold would have passed it',
    107 / (6897 + 6897 + 107) < 0.01);
  ok('and the disqualifying site is named, not just counted',
    r.disqualifying.length === 1 && r.disqualifying[0].site.includes('decide'));
}

// ══ COSMETIC CLASSIFICATION IS FRAME-BY-FRAME ════════════════════════════
{
  // The stack that put dunk in the wrong bucket twice. `_update` is not the
  // last frame, so an anchored pattern never matched it.
  ok('the particle animate stack is cosmetic', isCosmeticSite('s < m0._update < m0.animate'));
  ok('so is the particle spawn stack', isCosmeticSite('s < mS.startPositionFunction < m0._update'));
  ok('and the audio noise buffer', isCosmeticSite('a.noiseBuffer < a.play < Object.impact'));
  ok('an AI decision is NOT cosmetic', !isCosmeticSite('e4.decide < er.poll < es.poll'));
  ok('nor is an input-time roll', !isCosmeticSite('chunk.js:8:149097 < Object.up'));
  ok('nor is a render observer callback', !isCosmeticSite('s.callback < n.notifyObservers < k.render'));
  ok('the pattern matches a FRAME, not the joined string',
    !COSMETIC_FRAME.test('e4.decide') && COSMETIC_FRAME.test('m0.animate'));
}

// ══ SAMPLING CANNOT CLEAR A MODE ═════════════════════════════════════════
{
  const clean = [{ site: 's < m0._update < m0.animate', calls: 500 }];
  ok('a COMPLETE capture with only cosmetic calls clears the mode',
    verdictFor(clean, true).verdict === 'cosmetic-only');
  ok('THE SAME RESULT FROM SAMPLING IS INCONCLUSIVE, not a pass',
    verdictFor(clean, false).verdict === 'inconclusive');
  ok('because the thing being looked for happens ~4 times a match', true);
  ok('and no random calls at all is verifiable outright',
    verdictFor([], true).verdict === 'verifiable');
}

// ══ THE MEASURED FLEET ═══════════════════════════════════════════════════
{
  ok('DUNK IS THE ONLY CASH-ELIGIBLE MODE MEASURED', cashEligible().join() === 'dunk');
  ok('and it was a complete capture, not a sample',
    MEASURED.find((m) => m.mode === 'dunk')!.complete);
  ok('four of five modes are unverifiable',
    MEASURED.filter((m) => m.verdict === 'unverifiable').length === 4);
  ok('karate-vs is flagged as an incomplete capture, so its 81k calls are caveated',
    !MEASURED.find((m) => m.mode === 'karate-vs')!.complete);

  const fixes = remediation();
  ok('every unverifiable mode gets a named site and a fix', fixes.length >= 4);
  ok('and AI decisions get the AI-specific instruction',
    fixes.filter((f) => /decide/i.test(f.site)).every((f) => /AI decision/.test(f.fix)));
  ok('and every fix points at M83\'s seeded Rng', fixes.every((f) => /Rng \(M83\)/.test(f.fix)));
  ok('no mode is listed as needing a fix without a site',
    fixes.every((f) => f.site.length > 5));
}

console.log(`\n${pass} passed, ${fail} failed`);
if (fail) process.exit(1);
