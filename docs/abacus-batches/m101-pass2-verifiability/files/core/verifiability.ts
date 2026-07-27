// verifiability — which modes could be played for prize money, measured.
//
// M91 built server-side re-simulation. M94 made `dunk` implement
// `SimulatableMode` and proved it deterministic **in the repo**. Neither says
// anything about the mode a player is actually running.
//
// MEASURED ON THE DEPLOYED BUILD, 2026-07-28, by hooking `Math.random` before
// any page script and recording the stack of EVERY call during play:
//
//   mode          calls   verdict                    disqualifying site
//   dunk           2412   VERIFIABLE (cosmetic only) —
//   onevone        2246   UNVERIFIABLE               e4.decide < er.poll
//   threevthree    3028   UNVERIFIABLE               e4.decide < er.poll
//   tennis          467   UNVERIFIABLE               <chunk> < Object.up
//   karate-vs     81200   UNVERIFIABLE               tm.decide < Object.update
//
// **`dunk` is clean.** Every one of 24,558 calls over a full contest resolved
// to Babylon's particle system. That corrects an assumption I had carried into
// M94: its README says M63 rolled the rival with `Math.random()`, and the
// DEPLOYED dunk contest does not.
//
// The other four roll the AI's decision, or a shot on key-up. Those are
// gameplay decisions a server cannot reproduce.
//
// THE RULE, AND WHY A THRESHOLD IS WRONG
// `onevone` makes 107 AI-decision calls against 13,794 particle calls — a 0.9%
// share. The first version of the probe used a 20% threshold and passed it.
// **One unreproducible decision invalidates the whole match.** Share is the
// wrong metric, and a threshold would have cleared exactly the mode that fails.

export type Verdict =
  /** No random call at all during play. */
  | 'verifiable'
  /** Random calls, all provably cosmetic — particles, audio, noise textures. */
  | 'cosmetic-only'
  /** At least one gameplay decision the server cannot reproduce. */
  | 'unverifiable'
  /** Call volume forced sampling; absence of evidence, not evidence of absence. */
  | 'inconclusive';

export interface ModeVerifiability {
  mode: string;
  randomCalls: number;
  /** Non-cosmetic call sites, with counts. Empty when clean. */
  disqualifying: { site: string; calls: number }[];
  /** True when every call was stack-captured rather than sampled. */
  complete: boolean;
  verdict: Verdict;
}

/**
 * A call site is cosmetic when ANY frame in its stack is a particle, audio or
 * noise call. Those cannot change a score, so they cannot change a result.
 *
 * Tested frame by frame, not against the joined string: `s < m0._update <
 * m0.animate` is the particle system, and an anchored `_update$` never matched
 * it — which put `dunk` in the wrong bucket twice before this was fixed.
 */
export const COSMETIC_FRAME =
  /startPositionFunction|startDirectionFunction|ParticleSystem|recycleParticle|noiseBuffer|\bnoise\b|Sound|Audio|\._update\b|\.animate\b/i;

export function isCosmeticSite(site: string): boolean {
  return site.split(' < ').some((frame) => COSMETIC_FRAME.test(frame));
}

/**
 * The verdict for one mode.
 *
 * `complete` matters: a mode whose call volume forced sampling can only ever be
 * `inconclusive` when it looks clean, because the thing being looked for — an
 * AI roll four times a match — is exactly what sampling misses.
 */
export function verdictFor(
  sites: { site: string; calls: number }[],
  complete: boolean,
): { verdict: Verdict; disqualifying: { site: string; calls: number }[] } {
  const disqualifying = sites.filter((s) => !isCosmeticSite(s.site));
  if (disqualifying.length > 0) return { verdict: 'unverifiable', disqualifying };
  if (sites.length === 0) return { verdict: 'verifiable', disqualifying };
  return { verdict: complete ? 'cosmetic-only' : 'inconclusive', disqualifying };
}

/** What the deployed build measured on 2026-07-28. */
export const MEASURED: ModeVerifiability[] = [
  { mode: 'dunk', randomCalls: 2412, disqualifying: [], complete: true, verdict: 'cosmetic-only' },
  {
    mode: 'onevone', randomCalls: 2246, complete: true, verdict: 'unverifiable',
    disqualifying: [{ site: 'e4.decide < er.poll < es.poll', calls: 107 }],
  },
  {
    mode: 'threevthree', randomCalls: 3028, complete: true, verdict: 'unverifiable',
    disqualifying: [{ site: 'e4.decide < er.poll < es.poll', calls: 85 }],
  },
  {
    mode: 'tennis', randomCalls: 467, complete: true, verdict: 'unverifiable',
    disqualifying: [{ site: '<chunk>:149097 < Object.up', calls: 25 }],
  },
  {
    mode: 'karate-vs', randomCalls: 81200, complete: false, verdict: 'unverifiable',
    disqualifying: [
      { site: 'tm.decide < Object.update', calls: 15 },
      { site: 's.callback < n.notifyObservers < k.render', calls: 41 },
    ],
  },
];

/** Modes that could carry prize money today. */
export function cashEligible(): string[] {
  return MEASURED.filter((m) => m.verdict === 'cosmetic-only' || m.verdict === 'verifiable')
    .map((m) => m.mode);
}

/**
 * What each blocked mode needs, named rather than described.
 *
 * The fix is always the same shape — route the call through M83's seeded `Rng`
 * and record the seed with the replay — but naming the site is what turns a
 * finding into a ticket.
 */
export function remediation(): { mode: string; site: string; fix: string }[] {
  return MEASURED
    .filter((m) => m.verdict === 'unverifiable')
    .flatMap((m) => m.disqualifying.map((d) => ({
      mode: m.mode,
      site: d.site,
      fix: /decide/i.test(d.site)
        ? 'the AI decision must draw from the session Rng (M83), not Math.random'
        : 'this input-time roll must draw from the session Rng (M83), not Math.random',
    })));
}
