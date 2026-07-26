// DDA — PRQ as an INPUT to gameplay, not just an output of it.
//
// THE GAP THIS CLOSES
// Every Babylon mode reports outward: SessionResult → PRQ delta → the number
// goes up. Nothing reads PRQ before a match. So the number the entire product
// is built around — the player's athletic identity, the thing that is supposed
// to travel with them through every mode — currently affects ZERO FRAMES of
// gameplay in the shipping web app.
//
// The logic that makes PRQ mean something already exists. It is
// `PRQDrivenDDA` and `DynamicDifficulty` in
// `FinalEvolutionLab/Models/DynamicDifficulty.swift`, and it is stranded in
// the iOS app that is no longer the product. This is a faithful port: same
// constants, same curves, same clamps. Two platforms that disagree about
// difficulty would be worse than one platform without it.
//
// WHERE THE PRODUCT DIFFERENTIATES. A commercial sports game cannot do this,
// because it does not know your readiness today. FEL does. High PRQ means the
// opponent presses harder, reacts faster and needs a tighter counter — not
// because you picked "Hard", but because you showed up ready.

/** Neutral PRQ. Matches `PRQ.default` on the Swift side. */
export const PRQ_DEFAULT = 75;

export type DifficultyTier = 'ROOKIE' | 'DEVELOPING' | 'COMPETITIVE' | 'ELITE' | 'LEGENDARY';

const clamp01 = (v: number) => Math.min(1, Math.max(0, v));

// ── DynamicDifficulty: score-gap based, PRQ-independent ──────────────────

export const MAX_AGGRESSION = 1.4;
export const MIN_AGGRESSION = 0.6;

/**
 * Aggression from the score gap alone.
 *
 * Ahead by 5+ → the opponent goes to maximum. Behind by 5+ → it eases off.
 * Linear in between. This is the "keep the match close" layer and it knows
 * nothing about the player.
 */
export function aggression(playerScore: number, aiScore: number): number {
  const gap = playerScore - aiScore;
  if (gap >= 5) return MAX_AGGRESSION;
  if (gap <= -5) return MIN_AGGRESSION;
  return MIN_AGGRESSION + ((gap + 5) / 10) * (MAX_AGGRESSION - MIN_AGGRESSION);
}

/** Seconds before the AI acts. Higher aggression → quicker. Floored at 0.2s so
 *  it never becomes literally unreactable. */
export function aiResponseDelay(playerScore: number, aiScore: number): number {
  return Math.max(0.2, 0.8 - (aggression(playerScore, aiScore) - 1.0) * 0.5);
}

/**
 * Timing-window scale from how far apart the two are, as a fraction of the
 * target score.
 *
 * Losing badly widens your windows; winning easily tightens them. Note this
 * keys on PROGRESS, not raw points, so it behaves the same in a race to 3 and
 * a race to 21.
 */
export function ddaWindowScale(playerScore: number, aiScore: number, targetScore: number): number {
  if (targetScore <= 0) return 1.0;
  const gap = aiScore / targetScore - playerScore / targetScore;
  if (gap > 0.25) return 1.35;
  if (gap > 0.1) return 1.15;
  if (gap < -0.25) return 0.75;
  if (gap < -0.1) return 0.9;
  return 1.0;
}

/** Catch-up assist for the trailing side. */
export function rubberBandFactor(playerScore: number, aiScore: number, targetScore: number): number {
  if (targetScore <= 0) return 1.0;
  const progressGap = playerScore / targetScore - aiScore / targetScore;
  if (progressGap > 0.3) return 1.3;
  if (progressGap < -0.3) return 0.7;
  return 1.0;
}

/** Reward for a win streak: up to +40% at five straight. */
export function momentumBonus(consecutiveWins: number): number {
  return 1.0 + Math.min(consecutiveWins, 5) * 0.08;
}

// ── Per-mode tuning, ported from the Swift switch ────────────────────────
// Keyed by WEB modeId (see core/modeRegistry.ts), not the Swift enum. The two
// naming schemes have diverged before and cost an audit cycle.

const WINDOW_MODE_ADJUST: Record<string, number> = {
  baseball: 1.1, golf: 0.9, football: 1.2, soccer: 1.0,
  tennis: 1.0, volleyball: 1.05,
};

const MAX_POINTS_MODE_SCALE: Record<string, number> = {
  onevone: 1.0, threevthree: 1.0, carnival: 1.0, volleyball: 1.0,
  dunk: 0.8, dunkduel: 0.8, irl: 0.8, gymnastics: 0.8,
  karate: 1.2, 'karate-vs': 1.2, mixedcombat: 1.2,
  baseball: 0.7, football: 1.5, soccer: 0.9, golf: 0.6, tennis: 0.9,
  surf: 0.95, skateboard: 0.95, snowboard: 0.95,
  brain_brawl: 0.85, who_scene_it: 0.85,
};

/** A timing window scaled by both the score gap and the mode's own feel. */
export function scaledSuccessWindow(
  baseWindow: number, playerScore: number, aiScore: number, targetScore: number, modeId: string,
): number {
  return baseWindow
    * ddaWindowScale(playerScore, aiScore, targetScore)
    * (WINDOW_MODE_ADJUST[modeId] ?? 1.0);
}

// ── PRQDrivenDDA: this is where PRQ enters gameplay ──────────────────────

export interface DDAInputs {
  /** 0-100. Fetch from /api/prq/metrics at mode boot. */
  playerPRQ: number;
  /** 0-100 neural drive / readiness. Defaults to PRQ when unknown. */
  neuralDrive?: number;
  modeId: string;
}

export class PRQDrivenDDA {
  readonly playerPRQ: number;
  readonly neuralDrive: number;
  readonly modeId: string;

  constructor(i: DDAInputs) {
    this.playerPRQ = i.playerPRQ;
    this.modeId = i.modeId;
    this.neuralDrive = i.neuralDrive ?? i.playerPRQ;
  }

  /** Neutral difficulty, for a guest or before PRQ has loaded. Never block a
   *  mode on a network call — start neutral and let it adjust. */
  static neutral(modeId: string): PRQDrivenDDA {
    return new PRQDrivenDDA({ playerPRQ: PRQ_DEFAULT, modeId });
  }

  get prqNormalized(): number { return clamp01(this.playerPRQ / 100); }
  get neuralNormalized(): number { return clamp01(this.neuralDrive / 100); }

  /** The opponent never drops below this, however far ahead you are. */
  get aiAggressionFloor(): number { return 0.4 + this.prqNormalized * 0.3; }
  /** …and never above this, however far behind. */
  get aiAggressionCeiling(): number { return 1.0 + this.prqNormalized * 0.5; }

  /**
   * Score-gap aggression, scaled by PRQ and clamped into the player's band.
   *
   * A high-readiness player faces a floor that is already assertive; a
   * recovering player gets a ceiling that stays reachable. High neural drive
   * (>80) adds 15% on top — you brought your best, so does the opponent.
   */
  scaledAggression(playerScore: number, aiScore: number): number {
    const base = aggression(playerScore, aiScore);
    const prqScale = 0.7 + this.prqNormalized * 0.6;
    const neuralPressure = this.neuralNormalized > 0.8 ? 1.15 : 1.0;
    return Math.min(this.aiAggressionCeiling,
      Math.max(this.aiAggressionFloor, base * prqScale * neuralPressure));
  }

  /** Seconds. High PRQ shaves up to 0.3s off the opponent's reaction. */
  aiReactionSpeed(playerScore: number, aiScore: number): number {
    return Math.max(0.1, aiResponseDelay(playerScore, aiScore) - this.prqNormalized * 0.3);
  }

  /** High PRQ tightens your own windows by up to 15%. Being ready means the
   *  game asks more of you. */
  qteWindowScale(playerScore: number, aiScore: number, targetScore: number): number {
    return ddaWindowScale(playerScore, aiScore, targetScore) * (1.0 - this.prqNormalized * 0.15);
  }

  aiComboChance(playerScore: number, aiScore: number): number {
    return Math.min(0.6, (0.1 + this.prqNormalized * 0.25) * this.scaledAggression(playerScore, aiScore));
  }

  aiSpecialMeterRate(playerScore: number, aiScore: number): number {
    return 5.0 + this.scaledAggression(playerScore, aiScore) * 8.0 + this.prqNormalized * 4.0;
  }

  aiBlockChance(playerScore: number, aiScore: number): number {
    return Math.min(0.55, (0.15 + this.prqNormalized * 0.2) * this.scaledAggression(playerScore, aiScore));
  }

  /** How many points the opponent can take in one go. */
  opponentMaxPoints(maxPoints = 3): number {
    const scale = MAX_POINTS_MODE_SCALE[this.modeId] ?? 1.0;
    return Math.max(1, Math.round(maxPoints * scale * (0.6 + this.prqNormalized * 0.4)));
  }

  get tier(): DifficultyTier {
    const n = this.prqNormalized;
    if (n >= 0.9) return 'LEGENDARY';
    if (n >= 0.75) return 'ELITE';
    if (n >= 0.55) return 'COMPETITIVE';
    if (n >= 0.35) return 'DEVELOPING';
    return 'ROOKIE';
  }
}

export const TIER_PATTERN_COMPLEXITY: Record<DifficultyTier, number> = {
  ROOKIE: 1, DEVELOPING: 2, COMPETITIVE: 3, ELITE: 4, LEGENDARY: 5,
};

export const TIER_FEINT_CHANCE: Record<DifficultyTier, number> = {
  ROOKIE: 0.0, DEVELOPING: 0.1, COMPETITIVE: 0.2, ELITE: 0.35, LEGENDARY: 0.5,
};

export const TIER_COUNTER_WINDOW: Record<DifficultyTier, number> = {
  ROOKIE: 1.3, DEVELOPING: 1.15, COMPETITIVE: 1.0, ELITE: 0.85, LEGENDARY: 0.7,
};

/**
 * Fetch PRQ, never blocking the mode.
 *
 * A mode must be playable before this resolves and must survive it failing.
 * A guest with no account still gets a game; they get the neutral one.
 */
export async function loadDDA(modeId: string, fetchImpl = fetch): Promise<PRQDrivenDDA> {
  try {
    const res = await fetchImpl('/api/prq/metrics');
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const m = await res.json() as { overall_score?: number; mental?: number };
    const prq = typeof m.overall_score === 'number' ? m.overall_score : PRQ_DEFAULT;
    console.info(`[FEL-DDA] ${modeId}: PRQ ${prq.toFixed(0)} → ${new PRQDrivenDDA({ playerPRQ: prq, modeId }).tier}`);
    return new PRQDrivenDDA({ playerPRQ: prq, neuralDrive: m.mental, modeId });
  } catch (e) {
    console.warn(`[FEL-DDA] ${modeId}: PRQ unavailable (${e}); playing at neutral difficulty.`);
    return PRQDrivenDDA.neutral(modeId);
  }
}
