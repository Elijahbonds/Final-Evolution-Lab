// node --experimental-strip-types tests/prq_weights_test.ts
//
// THE CROSS-LANGUAGE DRIFT GUARD.
//
// This does not test a mock. It reads the REAL
// `FinalEvolutionLab/Utilities/PRQScoring.swift` and the REAL
// `backend/routers/games.py` off disk, parses their weight tables, and fails
// if either disagrees with `config/prqWeights.json`.
//
// That is the only kind of test that could have caught the actual bug. Two
// tables drifted apart across two languages over months, and no test in either
// language could see the other one. The same session scored differently
// depending on which platform ran it — who_scene_it by 57%.
//
// If the source files are not reachable (this batch integrated into the web
// app, away from the monorepo), the parity checks SKIP and say so. A skipped
// check that announces itself is honest; one that silently passes is how the
// divergence lasted this long.

import { readFile } from 'node:fs/promises';
import path from 'node:path';
import {
  PRQ_WEIGHTS, PRQ_WEIGHT_DEFAULT, prqWeight, estimatePrqDelta, scoresPrq, weightRanking,
} from '../core/prqWeights.ts';

let pass = 0, fail = 0, skip = 0;
const ok = (n: string, c: boolean, x = '') => { c ? (pass++, console.log(`  ok   ${n}`)) : (fail++, console.log(`  FAIL ${n} ${x}`)); };
const skipped = (n: string, why: string) => { skip++; console.log(`  SKIP ${n} — ${why}`); };
const near = (a: number, b: number, eps = 1e-9) => Math.abs(a - b) < eps;

// ── the table itself ─────────────────────────────────────────────────────
ok('every weight is a finite number',
  Object.values(PRQ_WEIGHTS).every((w) => Number.isFinite(w)));
ok('no weight is negative', Object.values(PRQ_WEIGHTS).every((w) => w >= 0));
ok('no weight is absurd', Object.values(PRQ_WEIGHTS).every((w) => w <= 3));
ok('football is the highest-weighted mode', weightRanking()[0].modeId === 'football');
ok('the default is 1.0', PRQ_WEIGHT_DEFAULT === 1.0);

ok('an unknown mode falls back rather than scoring zero',
  prqWeight('mode_that_does_not_exist') === PRQ_WEIGHT_DEFAULT);
ok('market_browse is exactly zero — a shop must never mint PRQ',
  PRQ_WEIGHTS.market_browse === 0);
ok('scoresPrq(market_browse) is false', scoresPrq('market_browse') === false);
ok('scoresPrq(football) is true', scoresPrq('football') === true);
ok('a zero weight is NOT treated as missing',
  prqWeight('market_browse') === 0, 'a falsy-check bug would return 1.0 here');
ok('weightRanking excludes non-scoring modes',
  !weightRanking().some((r) => r.modeId === 'market_browse'));
ok('weightRanking is sorted descending',
  weightRanking().every((r, i, a) => i === 0 || a[i - 1].weight >= r.weight));

// ── the delta mirror, against the real Python formula ────────────────────
ok('delta mirrors the backend for a completed 60s session',
  near(estimatePrqDelta('football', 100, 60, true), Math.round(100 * 0.1 * 1.5 * 1.25 * 1 * 100) / 100));
ok('an incomplete session is penalised',
  estimatePrqDelta('football', 100, 60, false) < estimatePrqDelta('football', 100, 60, true));
ok('a short session is time-scaled',
  near(estimatePrqDelta('golf', 100, 30, true), Math.round(100 * 0.1 * 0.9 * 1.25 * 0.5 * 100) / 100));
ok('zero duration uses the 0.5 fallback, not a divide-by-zero',
  Number.isFinite(estimatePrqDelta('golf', 100, 0, true)));
ok('market_browse earns exactly nothing', estimatePrqDelta('market_browse', 999, 600, true) === 0);
ok('a zero score earns nothing', estimatePrqDelta('football', 0, 60, true) === 0);

// ── PARITY: the real Swift source ────────────────────────────────────────
// Swift enum case → canonical mode id. Both dunk cases map to basketball_dunk.
const SWIFT_CASE_TO_ID: Record<string, string> = {
  basketballHeadToHead: 'basketball_h2h',
  venicePickup: 'venice_pickup',
  basketballDunkContestIRL: 'basketball_dunk',
  basketballDunkContest3D: 'basketball_dunk',
  basketball3v3: 'basketball_3v3',
  karate: 'karate_h2h',
  karateEndless: 'karate_endless',
  baseball: 'baseball', football: 'football', soccer: 'soccer', golf: 'golf',
  tennis: 'tennis', volleyball: 'volleyball', gymnastics: 'gymnastics',
  surfing: 'surfing', skateboarding: 'skateboarding', snowboarding: 'snowboarding',
  brainBrawl: 'brain_brawl', whoSceneIt: 'who_scene_it',
  courtCarnival: 'court_carnival', marketBrowse: 'market_browse',
};

/** Pull `modeWeight(for:)`'s switch body out of the Swift source. */
export function parseSwiftWeights(src: string): Record<string, number> | null {
  const fn = src.indexOf('static func modeWeight(for mode: GameModeId) -> Double');
  if (fn < 0) return null;
  const nextFn = src.indexOf('\n    static func', fn + 10);
  const body = src.slice(fn, nextFn < 0 ? undefined : nextFn);
  const out: Record<string, number> = {};
  for (const m of body.matchAll(/^\s*case\s+([^:\n]+):\s*([\d.]+)\s*$/gm)) {
    const value = Number(m[2]);
    for (const raw of m[1].split(',')) {
      const name = raw.trim().replace(/^\./, '');
      const id = SWIFT_CASE_TO_ID[name];
      if (id) out[id] = value;
    }
  }
  return Object.keys(out).length ? out : null;
}

/** Pull `PRQ_MODE_WEIGHTS = { … }` out of the Python source. */
export function parsePythonWeights(src: string): Record<string, number> | null {
  const start = src.indexOf('PRQ_MODE_WEIGHTS');
  if (start < 0) return null;
  const open = src.indexOf('{', start);
  const close = src.indexOf('}', open);
  if (open < 0 || close < 0) return null;
  const out: Record<string, number> = {};
  for (const m of src.slice(open, close).matchAll(/"([a-z0-9_]+)"\s*:\s*([\d.]+)/g)) {
    out[m[1]] = Number(m[2]);
  }
  return Object.keys(out).length ? out : null;
}

/** Walk up looking for the monorepo root. Absent when integrated into the app. */
async function findSource(rel: string): Promise<string | null> {
  let dir = path.dirname(new URL(import.meta.url).pathname);
  for (let i = 0; i < 9; i++) {
    try { return await readFile(path.join(dir, rel), 'utf8'); } catch { dir = path.dirname(dir); }
  }
  return null;
}

const swiftSrc = await findSource('FinalEvolutionLab/Utilities/PRQScoring.swift');
if (!swiftSrc) {
  skipped('SWIFT PARITY', 'PRQScoring.swift not reachable from here (integrated build?)');
} else {
  const swift = parseSwiftWeights(swiftSrc);
  ok('the Swift table parses at all', swift !== null);
  if (swift) {
    ok('Swift parse found the whole table', Object.keys(swift).length >= 18,
      `${Object.keys(swift).length} entries`);
    const mismatches = Object.entries(swift)
      .filter(([id, w]) => PRQ_WEIGHTS[id] !== undefined && !near(PRQ_WEIGHTS[id], w))
      .map(([id, w]) => `${id}: swift ${w} vs canonical ${PRQ_WEIGHTS[id]}`);
    ok('SWIFT PARITY: PRQScoring.swift matches config/prqWeights.json',
      mismatches.length === 0, mismatches.join('; '));
    const missing = Object.keys(swift).filter((id) => PRQ_WEIGHTS[id] === undefined);
    ok('every mode Swift scores is in the canonical table', missing.length === 0, missing.join(','));
  }
}

const pySrc = await findSource('backend/routers/games.py');
if (!pySrc) {
  skipped('BACKEND PARITY', 'backend/routers/games.py not reachable from here');
} else {
  const py = parsePythonWeights(pySrc);
  ok('the Python table parses at all', py !== null);
  if (py) {
    ok('Python parse found the whole table', Object.keys(py).length >= 17,
      `${Object.keys(py).length} entries`);
    const mismatches = Object.entries(py)
      .filter(([id, w]) => PRQ_WEIGHTS[id] !== undefined && !near(PRQ_WEIGHTS[id], w))
      .map(([id, w]) => `${id}: backend ${w} vs canonical ${PRQ_WEIGHTS[id]}`);
    // EXPECTED RED until the backend adopts the canonical file. That is the
    // point: this is the check that would have caught the drift, and it must
    // stay red until someone fixes the SOURCE rather than the test.
    ok('BACKEND PARITY: games.py matches config/prqWeights.json',
      mismatches.length === 0,
      `\n         ${mismatches.join('\n         ')}\n         `
      + '→ apply config/prqWeights.json to backend/routers/games.py');
    const missing = Object.keys(PRQ_WEIGHTS)
      .filter((id) => py[id] === undefined && PRQ_WEIGHTS[id] > 0 && id !== 'venice_pickup');
    ok('every scoring mode has a backend weight', missing.length === 0,
      `absent from the backend, so they fall through to 1.0: ${missing.join(', ')}`);
  }
}

console.log(`\n${pass} passed, ${fail} failed, ${skip} skipped`);
if (fail) process.exit(1);
