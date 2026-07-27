// Progression — the reason to come back tomorrow.
//
// WHAT EXISTS
// `economy_engine.py` computes XP and shards per session, server-side, from a
// receipt. `constants.py` has `XP_MIN_PER_SESSION`, `XP_CAP_PER_SESSION` and
// `XP_SCORE_DIVISOR`.
//
// WHAT DOES NOT
// Anything that XP goes INTO. There is no level curve, no season, no
// objectives, no reward track. XP is a number that accumulates and never
// arrives anywhere — so `docs/FEL-VISION.md` describes a Season Pass ticking in
// the background that has no implementation on either side.
//
// A per-session reward with no destination is a scoreboard. The destination is
// what turns twenty-five modes into a reason to open the app on a Tuesday.
//
// THE THREE RULES THIS IS BUILT ON
//
//   1. NOTHING BEHIND THE PAYWALL AFFECTS GAMEPLAY. Same rule as
//      `CreatorLoop.assertCosmetic` and for the same reason: the moment money
//      buys advantage, the competitive layer and the Cash Arena are both
//      compromised. Premium buys cosmetics, currency and creator tools.
//   2. OBJECTIVES POINT AT MODES YOU HAVE NOT PLAYED. A daily that says "score
//      500 in the mode you already play" is a tax on habit. One that says "try
//      Surf" is a tour of a product most players will otherwise see a fifth of.
//   3. A SEASON MUST BE COMPLETABLE BY A NORMAL PLAYER. If the full track needs
//      more time than a person has, the track is an advertisement for a
//      purchase rather than a reward for playing. That is a design constraint
//      and it is asserted by test.

/** Server-authoritative, mirrored here so the client can show a live bar. */
export const XP_MIN_PER_SESSION = 10;
export const XP_CAP_PER_SESSION = 500;
export const XP_SCORE_DIVISOR = 5;

/** Mirrors `calculate_xp` in backend/app/utils/formulas.py. */
export function sessionXp(score: number): number {
  return Math.min(XP_CAP_PER_SESSION, Math.max(XP_MIN_PER_SESSION, Math.floor(score / XP_SCORE_DIVISOR)));
}

/**
 * XP needed to go from `level` to `level + 1`.
 *
 * Gently superlinear. A flat curve makes level 40 feel identical to level 4; a
 * steep one turns the back half into a wall that only the people who least
 * need motivating ever climb. This lands a committed player around level 50
 * in a season and a casual one around 20 — both of which are a real journey.
 */
export const MAX_LEVEL = 999;

export function xpForLevel(level: number): number {
  if (level < 1) return 0;
  // The quadratic coefficient is small ON PURPOSE. A first draft used 6 and
  // level 50 cost FIFTY TIMES level 1 — the quadratic term swamped everything
  // and the back half of the curve became a wall only the people who least
  // need motivating ever climb. At 0.8 the same level costs about 11x, which
  // is a real journey rather than a barrier. Asserted by test.
  return Math.round(400 + level * 50 + level * level * 0.8);
}

/** Cumulative XP to reach a level from zero. */
export function totalXpForLevel(level: number): number {
  let sum = 0;
  for (let l = 1; l < level; l++) sum += xpForLevel(l);
  return sum;
}

export interface LevelState {
  level: number;
  /** XP into the current level. */
  into: number;
  /** XP the current level requires. */
  needed: number;
  progress: number;
}

export function levelFromXp(totalXp: number): LevelState {
  let level = 1;
  let remaining = Math.max(0, totalXp);
  while (level < MAX_LEVEL && remaining >= xpForLevel(level)) {
    remaining -= xpForLevel(level);
    level++;
  }
  const needed = xpForLevel(level);
  return { level, into: remaining, needed, progress: needed > 0 ? remaining / needed : 0 };
}

// ── the season ───────────────────────────────────────────────────────────

export type RewardKind = 'shards' | 'coins' | 'skin' | 'emote' | 'track' | 'title' | 'creator_tool';

export interface Reward {
  kind: RewardKind;
  amount?: number;
  id?: string;
  label: string;
}

/**
 * REWARDS THAT MAY NEVER APPEAR ON A PAID TRACK.
 *
 * There are none that affect gameplay, by construction — every `RewardKind`
 * above is cosmetic, currency, or a creator tool. This function is the guard
 * that keeps it that way when someone adds `RewardKind = 'stat_boost'` in six
 * months, and it throws rather than warns for the same reason
 * `assertCosmetic` does.
 */
export const GAMEPLAY_REWARD_KINDS = ['stat_boost', 'multiplier', 'unlock_mode', 'advantage'];

export class PayToWinError extends Error {}

export function assertNotPayToWin(reward: Reward, track: 'free' | 'premium'): void {
  if (GAMEPLAY_REWARD_KINDS.includes(reward.kind as string)) {
    throw new PayToWinError(
      `"${reward.kind}" affects gameplay and cannot be a season reward on either track. `
      + 'Premium buys expression and currency, never advantage — the moment it buys '
      + 'advantage, ranked play and the Cash Arena are both compromised.',
    );
  }
  if (track === 'premium' && reward.kind === 'creator_tool') return;   // tools are fine
}

export interface SeasonTier {
  tier: number;
  xpRequired: number;
  free: Reward | null;
  premium: Reward | null;
}

export const TIERS_PER_SEASON = 50;
/** XP for one tier. A committed player clears the track; a casual one gets
 *  most of the way. Asserted by test — see rule 3. */
export const XP_PER_TIER = 2200;

/**
 * Build a season track.
 *
 * The FREE track is deliberately never empty for long — a track where the free
 * lane is blank for ten tiers is a paywall wearing a progress bar, and players
 * read it exactly that way.
 */
export function buildSeason(seasonId: string): SeasonTier[] {
  return Array.from({ length: TIERS_PER_SEASON }, (_, i) => {
    const tier = i + 1;
    const isMilestone = tier % 10 === 0;
    const freeEvery = tier % 3 === 0 || isMilestone;

    const free: Reward | null = freeEvery
      ? isMilestone
        ? { kind: 'skin', id: `${seasonId}_free_${tier}`, label: `Season ${seasonId} court skin` }
        : { kind: 'shards', amount: 50 + tier * 5, label: `${50 + tier * 5} shards` }
      : null;

    const premium: Reward = isMilestone
      ? { kind: 'creator_tool', id: `${seasonId}_tool_${tier}`, label: 'Creator tool unlock' }
      : tier % 5 === 0
        ? { kind: 'emote', id: `${seasonId}_emote_${tier}`, label: 'Victory emote' }
        : { kind: 'coins', amount: 100 + tier * 10, label: `${100 + tier * 10} coins` };

    return { tier, xpRequired: tier * XP_PER_TIER, free, premium };
  });
}

export interface SeasonProgress {
  seasonXp: number;
  premium: boolean;
}

export function tierFromSeasonXp(seasonXp: number): number {
  return Math.min(TIERS_PER_SEASON, Math.floor(seasonXp / XP_PER_TIER));
}

/** Everything earned so far. Free rewards always count; premium only if owned. */
export function claimable(season: SeasonTier[], p: SeasonProgress): Reward[] {
  const tier = tierFromSeasonXp(p.seasonXp);
  const out: Reward[] = [];
  for (const t of season) {
    if (t.tier > tier) break;
    if (t.free) out.push(t.free);
    if (p.premium && t.premium) out.push(t.premium);
  }
  return out;
}

/**
 * Buying premium mid-season grants everything already passed.
 *
 * The alternative — premium only paying forward — silently punishes the player
 * who tried the game first, which is exactly the player you most want to
 * convert. It also makes buying early strictly better than buying late, which
 * is a pressure nobody enjoys.
 */
export function retroactiveGrant(season: SeasonTier[], seasonXp: number): Reward[] {
  const tier = tierFromSeasonXp(seasonXp);
  return season.filter((t) => t.tier <= tier && t.premium).map((t) => t.premium as Reward);
}

// ── objectives ───────────────────────────────────────────────────────────

export type ObjectiveScope = 'daily' | 'weekly' | 'season';

export interface Objective {
  id: string;
  scope: ObjectiveScope;
  description: string;
  /** Mode this points at, or null for any. */
  modeId: string | null;
  target: number;
  xp: number;
}

export const OBJECTIVE_XP: Record<ObjectiveScope, number> = {
  daily: 400, weekly: 1800, season: 6000,
};

/**
 * Pick objectives that point at modes the player has NOT been playing.
 *
 * Rule 2, implemented. `recentModes` is what they already play; those are
 * ranked last. Most players will otherwise see a fifth of a twenty-five-mode
 * product, and a daily objective is the cheapest tour available.
 *
 * The `rng` is injected so a day's objectives are reproducible from a date
 * seed — a player and the server must agree on what today's objectives are
 * without a round trip.
 */
export function pickObjectives(
  allModes: string[], recentModes: string[], scope: ObjectiveScope,
  count: number, rng: { int(a: number, b: number): number; shuffle<T>(x: readonly T[]): T[] },
): Objective[] {
  const unplayed = allModes.filter((m) => !recentModes.includes(m));
  const played = allModes.filter((m) => recentModes.includes(m));
  const ordered = [...rng.shuffle(unplayed), ...rng.shuffle(played)];

  return ordered.slice(0, count).map((modeId, i) => ({
    id: `${scope}_${modeId}_${i}`,
    scope,
    modeId,
    description: recentModes.includes(modeId)
      ? `Beat your best in ${modeId}`
      : `Play a session of ${modeId}`,
    target: 1,
    xp: OBJECTIVE_XP[scope],
  }));
}

/**
 * Can a normal player finish the season?
 *
 * Rule 3, made checkable. Returns the days required at a given daily play
 * pattern. If a full track needs more days than the season lasts, the track is
 * an advertisement rather than a reward, and the constants are wrong.
 */
export function seasonFeasibility(
  sessionsPerDay: number, avgSessionXp: number, dailiesPerDay: number, seasonDays: number,
): { daysNeeded: number; completable: boolean; note: string } {
  const perDay = sessionsPerDay * avgSessionXp + dailiesPerDay * OBJECTIVE_XP.daily;
  const total = TIERS_PER_SEASON * XP_PER_TIER;
  const daysNeeded = perDay > 0 ? Math.ceil(total / perDay) : Infinity;
  const completable = daysNeeded <= seasonDays;
  return {
    daysNeeded,
    completable,
    note: completable
      ? `${daysNeeded} days of that pattern clears the track, inside a ${seasonDays}-day season.`
      : `${daysNeeded} days needed but the season is ${seasonDays}. The track is not completable `
        + 'at this pattern — that makes it an advertisement, not a reward.',
  };
}

/**
 * What to show the player right now.
 *
 * One thing, not a dashboard. The nearest reward is the one that motivates;
 * a wall of twelve progress bars motivates nobody.
 */
export function nextMilestone(season: SeasonTier[], p: SeasonProgress): { tier: SeasonTier; xpAway: number; reward: Reward } | null {
  const current = tierFromSeasonXp(p.seasonXp);
  const next = season.find((t) => t.tier > current && (p.premium ? (t.premium ?? t.free) : t.free));
  if (!next) return null;
  const reward = (p.premium ? next.premium ?? next.free : next.free) as Reward;
  return { tier: next, xpAway: next.xpRequired - p.seasonXp, reward };
}
