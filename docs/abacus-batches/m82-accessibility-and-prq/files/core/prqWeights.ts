// prqWeights — one table, read by every platform.
//
// THE BUG THIS ENDS
// There were two PRQ weight tables and they had silently diverged:
//
//   mode            Swift   backend   difference
//   skateboarding   1.05    1.0       +5%
//   snowboarding    1.05    1.0       +5%
//   court_carnival  1.15    0.9       +28%
//   brain_brawl     1.1     0.8       +37%
//   who_scene_it    1.1     0.7       +57%
//   market_browse   0.0     (absent → 1.0)  a shop visit scored like a match
//
// The same session earned a different PRQ delta depending on which platform
// scored it. Nothing checked. Nothing could — there was no third thing to
// check against. `config/prqWeights.json` is that third thing, and
// `tests/prq_weights_test.ts` parses the real Swift and Python sources and
// fails if either drifts from it.
//
// The web app also had a third problem, worse than divergence: it had no
// table at all. It posted a raw SessionResult and let the server decide, so a
// mode could not tell the player what a win was worth before they played.

// WHY THE VALUES ARE LITERAL HERE AND NOT IMPORTED FROM THE JSON
// `import w from '../config/prqWeights.json'` needs either `resolveJsonModule`
// or an import attribute, and which of those works depends on the bundler
// version — which this repo cannot see. A runtime failure in the scoring path
// is a far worse outcome than a mirrored table, so the table is mirrored and
// `tests/prq_weights_test.ts` enforces FOUR-WAY parity: this file, the JSON,
// the Swift source, and the Python source. Same pattern as anim/boneNames.ts
// and tools/clip_check.mjs. Edit the JSON; the test will tell you to update
// this.

export const PRQ_WEIGHTS_VERSION = 1;
export const PRQ_WEIGHT_DEFAULT = 1.0;

export const PRQ_WEIGHTS: Readonly<Record<string, number>> = Object.freeze({
  basketball_h2h: 1.2,
  basketball_dunk: 1.0,
  basketball_3v3: 1.3,
  venice_pickup: 1.2,
  court_carnival: 1.15,
  karate_h2h: 1.4,
  karate_endless: 1.4,
  baseball: 1.0,
  football: 1.5,
  soccer: 1.1,
  golf: 0.9,
  tennis: 1.1,
  volleyball: 1.2,
  gymnastics: 1.0,
  surfing: 1.05,
  skateboarding: 1.05,
  snowboarding: 1.05,
  brain_brawl: 1.1,
  who_scene_it: 1.1,
  market_browse: 0.0,
});

/**
 * Weight for a mode.
 *
 * Never throws. An unrecognised mode falls back to the default rather than
 * scoring zero — a new mode that silently pays nothing is a bug players feel
 * long before anyone reads a log.
 */
export function prqWeight(modeId: string): number {
  const w = PRQ_WEIGHTS[modeId];
  if (w === undefined) {
    console.warn(`[FEL-PRQ] no weight for "${modeId}"; using default ${PRQ_WEIGHT_DEFAULT}. `
      + 'Add it to config/prqWeights.json.');
    return PRQ_WEIGHT_DEFAULT;
  }
  return w;
}

/**
 * The backend's delta formula, mirrored so a mode can show the player what a
 * result is worth BEFORE the receipt comes back.
 *
 * Deliberately a mirror, not an authority: the server's number is the one that
 * counts. This exists so the HUD can be honest in the same frame the whistle
 * blows instead of a round-trip later. `tests/prq_weights_test.ts` checks it
 * against the real Python.
 */
export function estimatePrqDelta(
  modeId: string, score: number, durationSec: number, completed: boolean,
): number {
  const base = score * 0.1;
  const completionBonus = completed ? 1.25 : 0.75;
  const timeFactor = durationSec > 0 ? Math.min(1, durationSec / 60) : 0.5;
  return Math.round(base * prqWeight(modeId) * completionBonus * timeFactor * 100) / 100;
}

/**
 * Modes that must never mint PRQ.
 *
 * `market_browse` is a shop. The backend omitted it from its table, so it fell
 * through to the 1.0 default and browsing scored like playing a match. A
 * weight of exactly 0 is a statement, not an oversight, and this predicate is
 * how the intent survives the next edit.
 */
export function scoresPrq(modeId: string): boolean {
  return prqWeight(modeId) > 0;
}

/** Ordered by weight — what a session is actually worth, for a mode picker. */
export function weightRanking(): Array<{ modeId: string; weight: number }> {
  return Object.entries(PRQ_WEIGHTS)
    .filter(([, w]) => w > 0)
    .map(([modeId, weight]) => ({ modeId, weight }))
    .sort((a, b) => b.weight - a.weight || a.modeId.localeCompare(b.modeId));
}
