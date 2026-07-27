// DunkTiers — the bridge from your real vertical to what you can do in the game.
//
// THIS IS THE PRODUCT THESIS, AND IT WAS MISSING.
//
// Two halves of it have existed for months and were never connected:
//
//   · `irl/irlDunkJudging.ts` (M33) MEASURES `jumpHeightCm` and `hangTimeMs`
//     from phone video, with calibration against real stature.
//   · `modes/DunkMode.ts` (M63) scores a dunk on difficulty, execution and
//     style with a three-judge card.
//
// Nothing joins them. Your actual athleticism has ZERO effect on what you can
// do in the 3-D dunk contest. Strip that out and FEL's flagship mode is a
// timing minigame that any studio could ship — the whole differentiator is
// that this one knows your vertical.
//
// THE PHYSICS, WHICH IS REAL AND WORTH GETTING RIGHT
// A dunk needs two different things, and conflating them is why arcade
// basketball games feel arbitrary:
//
//   CLEARANCE — how far your hand gets above the rim. Sets whether the ball
//               can be brought down through the hoop at all.
//   HANG TIME — how long you are airborne. Sets whether there is TIME to
//               complete the motion. A 360 does not need more height than a
//               two-hander; it needs more air.
//
// A tall player with a modest vertical has clearance and no hang. A shorter
// explosive player has hang and little clearance. They unlock DIFFERENT dunks,
// which is both true to the sport and more interesting than one number.
//
// THE PRODUCT RISK, HANDLED RATHER THAN IGNORED
// An average adult cannot dunk. If real gating were the only mode, FEL's
// flagship would be unplayable for most of the people who install it — which
// is a fast way to kill a flagship. So gating has three settings, and the
// DEFAULT is the inclusive one:
//
//   'arcade'  everyone can attempt everything; your vertical raises your
//             SCORING CEILING instead of restricting access.  ← default
//   'assisted' locks only the top tier until you are close to it.
//   'true'    honest gating. This is the mode that means something, and it is
//             opt-in because being told you cannot dunk is a choice a player
//             should make deliberately.
//
// And the loop that makes the health data matter: train, your vertical rises,
// new dunks unlock. That is the only reason a fitness number belongs in a game
// at all — not as a badge, as a key.

/** Standard rim height. */
export const RIM_HEIGHT_CM = 305;

/**
 * Clearance above the rim needed to control the ball through the hoop.
 *
 * Not a fudge factor: you cannot dunk with your hand exactly level with the
 * rim, because the ball itself is ~24cm and has to clear. 15cm of hand-above-
 * rim is the practical floor for a controlled one-hander.
 */
export const MIN_CONTROL_CLEARANCE_CM = 15;

/**
 * Standing reach from height.
 *
 * Reach is about 1.31–1.34× height for typical proportions. This is an
 * estimate and is used ONLY when a real reach has not been measured —
 * `AthleteProfile.standingReachCm` always wins, because a long-armed player
 * is badly served by an average.
 */
export function estimateStandingReach(heightCm: number): number {
  return Math.round(heightCm * 1.325);
}

export interface AthleteProfile {
  heightCm: number;
  /** Measured vertical leap. From `extractIrlMetrics().jumpHeightCm`. */
  verticalCm: number;
  /** Measured airborne time. From `extractIrlMetrics().hangTimeMs`. */
  hangTimeMs: number;
  /** Measured standing reach, if the player has entered one. */
  standingReachCm?: number;
}

/** How high above the rim this athlete's hand reaches, in cm. Negative means
 *  below the rim. */
export function rimClearanceCm(p: AthleteProfile): number {
  const reach = p.standingReachCm ?? estimateStandingReach(p.heightCm);
  return reach + p.verticalCm - RIM_HEIGHT_CM;
}

export type DunkTier =
  | 'no_rim'      // cannot reach
  | 'rim_touch'   // can touch, cannot dunk
  | 'one_hand'
  | 'two_hand'
  | 'power'
  | 'aerial'      // windmill, tomahawk — needs air, not just height
  | 'elite';      // 360, between-the-legs

export const TIER_ORDER: DunkTier[] = [
  'no_rim', 'rim_touch', 'one_hand', 'two_hand', 'power', 'aerial', 'elite',
];

export interface DunkDef {
  id: string;
  name: string;
  tier: DunkTier;
  /** Hand-above-rim required, cm. */
  clearanceCm: number;
  /** Airborne time required to complete the motion, ms. */
  hangMs: number;
  /** Judge difficulty, 0-10. Feeds DunkMode's scorecard. */
  difficulty: number;
  /** Clip id — see anim/clipManifest.ts. */
  clipId: string;
}

/**
 * The dunk library, ordered by demand.
 *
 * Note `dunk_360` needs LESS clearance than `dunk_windmill` but far more hang.
 * That is not a typo: a 360 is a rotation problem, a windmill is a reach
 * problem. Modelling them as one difficulty axis is what makes arcade
 * basketball feel like it is guessing.
 */
export const DUNK_LIBRARY: DunkDef[] = [
  { id: 'layup', name: 'Layup', tier: 'rim_touch', clearanceCm: -25, hangMs: 250, difficulty: 1, clipId: 'layup' },
  { id: 'finger_roll', name: 'Finger Roll', tier: 'rim_touch', clearanceCm: -10, hangMs: 300, difficulty: 2, clipId: 'finger_roll' },
  { id: 'dunk_one_hand', name: 'One-Hand Jam', tier: 'one_hand', clearanceCm: 15, hangMs: 350, difficulty: 3.5, clipId: 'dunk_one_hand' },
  { id: 'dunk_two_hand', name: 'Two-Hand Jam', tier: 'two_hand', clearanceCm: 22, hangMs: 400, difficulty: 4.5, clipId: 'dunk_two_hand' },
  { id: 'dunk_power', name: 'Power Slam', tier: 'power', clearanceCm: 30, hangMs: 450, difficulty: 6, clipId: 'dunk_power' },
  { id: 'dunk_tomahawk', name: 'Tomahawk', tier: 'aerial', clearanceCm: 32, hangMs: 560, difficulty: 7, clipId: 'dunk_tomahawk' },
  { id: 'dunk_windmill', name: 'Windmill', tier: 'aerial', clearanceCm: 36, hangMs: 620, difficulty: 8, clipId: 'dunk_windmill' },
  { id: 'dunk_360', name: '360', tier: 'elite', clearanceCm: 28, hangMs: 720, difficulty: 8.5, clipId: 'dunk_360_eastbay' },
  { id: 'dunk_eastbay', name: 'Between The Legs', tier: 'elite', clearanceCm: 34, hangMs: 780, difficulty: 10, clipId: 'dunk_eastbay' },
];

export type GateMode = 'arcade' | 'assisted' | 'true';

/** Inclusive by default. See the header — a flagship most people cannot play
 *  is not a flagship. */
export const DEFAULT_GATE: GateMode = 'arcade';

/** The highest tier this athlete's body actually supports. */
export function physicalTier(p: AthleteProfile): DunkTier {
  const clearance = rimClearanceCm(p);
  let best: DunkTier = 'no_rim';
  if (clearance >= -30) best = 'rim_touch';
  for (const d of DUNK_LIBRARY) {
    if (clearance >= d.clearanceCm && p.hangTimeMs >= d.hangMs) {
      if (TIER_ORDER.indexOf(d.tier) > TIER_ORDER.indexOf(best)) best = d.tier;
    }
  }
  return best;
}

/**
 * Which dunks the player may ATTEMPT, given the gate mode.
 *
 * In 'arcade' this is everything — access is never the lever. In 'true' it is
 * only what the body supports. 'assisted' sits between: it hides the elite
 * tier until you are within 5cm and 100ms of it, so there is something visible
 * to train toward rather than a wall.
 */
export function availableDunks(p: AthleteProfile, gate: GateMode = DEFAULT_GATE): DunkDef[] {
  if (gate === 'arcade') return [...DUNK_LIBRARY];
  const clearance = rimClearanceCm(p);
  if (gate === 'assisted') {
    return DUNK_LIBRARY.filter(
      (d) => d.tier !== 'elite' || (clearance >= d.clearanceCm - 5 && p.hangTimeMs >= d.hangMs - 100),
    );
  }
  return DUNK_LIBRARY.filter((d) => clearance >= d.clearanceCm && p.hangTimeMs >= d.hangMs);
}

/**
 * Scoring ceiling multiplier, 0.7–1.15.
 *
 * This is how 'arcade' stays honest. Everyone can throw down a windmill, but a
 * player whose body genuinely supports it scores it higher — so real
 * athleticism is rewarded without locking anyone out. Attempting far beyond
 * your tier is not a fail state, it just does not score like the real thing.
 */
export function scoreCeiling(p: AthleteProfile, dunk: DunkDef): number {
  const clearance = rimClearanceCm(p);
  const clearGap = clearance - dunk.clearanceCm;
  const hangGap = p.hangTimeMs - dunk.hangMs;
  // Normalised shortfall: 20cm and 250ms are each "a full tier away".
  const shortfall = Math.max(0, -clearGap / 20) + Math.max(0, -hangGap / 250);
  const surplus = Math.min(1, Math.max(0, clearGap / 20) * 0.5 + Math.max(0, hangGap / 250) * 0.5);
  return Math.max(0.7, Math.min(1.15, 1 + surplus * 0.15 - shortfall * 0.15));
}

/**
 * The next thing to train for, and exactly how far away it is.
 *
 * The retention loop in one function. "Windmill: 4cm of vertical away" is a
 * reason to train tomorrow. "Locked" is a reason to stop playing. Returns null
 * only when everything is already unlocked.
 */
export function nextUnlock(p: AthleteProfile): {
  dunk: DunkDef; needCm: number; needMs: number; summary: string;
} | null {
  const clearance = rimClearanceCm(p);
  const locked = DUNK_LIBRARY
    .filter((d) => clearance < d.clearanceCm || p.hangTimeMs < d.hangMs)
    .sort((a, b) => a.difficulty - b.difficulty);
  const d = locked[0];
  if (!d) return null;

  const needCm = Math.max(0, Math.ceil(d.clearanceCm - clearance));
  const needMs = Math.max(0, Math.ceil(d.hangMs - p.hangTimeMs));
  const parts: string[] = [];
  if (needCm > 0) parts.push(`${needCm}cm more vertical`);
  if (needMs > 0) parts.push(`${needMs}ms more hang time`);
  return { dunk: d, needCm, needMs, summary: `${d.name}: ${parts.join(' and ')}` };
}

/**
 * A plain-language read on where this athlete stands.
 *
 * Shown once, on the dunk contest's ready screen. It has to be honest without
 * being discouraging — telling someone they cannot dunk is a real thing to say
 * to a person, and it is said here alongside what would change it.
 */
export function athleteSummary(p: AthleteProfile): string {
  const clearance = Math.round(rimClearanceCm(p));
  const tier = physicalTier(p);
  if (tier === 'no_rim') {
    return `Your reach plus a ${Math.round(p.verticalCm)}cm vertical puts you `
      + `${Math.abs(clearance)}cm below the rim. In Arcade you can still throw down anything — `
      + 'True Vertical unlocks as you train.';
  }
  if (tier === 'rim_touch') {
    // The reassurance belongs in BOTH non-dunking cases. An earlier draft only
    // put it in `no_rim`, so the player who is closest to dunking — and
    // therefore most likely to keep training — got the bluntest message with
    // no way forward. That is precisely backwards.
    const gap = Math.max(0, MIN_CONTROL_CLEARANCE_CM - clearance);
    return `You get a hand on the rim, ${Math.abs(clearance)}cm below the rim for control. `
      + `About ${Math.round(gap)}cm of vertical from a one-hander — `
      + 'and Arcade lets you throw down anything meanwhile.';
  }
  return `${clearance}cm of hand above the rim and ${Math.round(p.hangTimeMs)}ms of hang. `
    + `That is a real ${tier.replace('_', '-')} dunker.`;
}

/**
 * Build a profile from what the IRL judge measured.
 *
 * Both measurements can come back null — a bad camera angle, a partial pose,
 * poor light. Falling back to a modest default is deliberate: an unmeasured
 * player should meet the arcade experience, never a zero that reports them as
 * unable to leave the ground.
 */
export function profileFromIrl(
  m: { jumpHeightCm: number | null; hangTimeMs: number | null; confidence: number },
  heightCm: number,
  standingReachCm?: number,
): AthleteProfile {
  const trusted = m.confidence >= 0.55;
  return {
    heightCm,
    standingReachCm,
    verticalCm: trusted && m.jumpHeightCm !== null ? m.jumpHeightCm : 45,
    hangTimeMs: trusted && m.hangTimeMs !== null ? m.hangTimeMs : 450,
  };
}
