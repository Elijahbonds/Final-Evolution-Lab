// DefenseRead — a defender that guesses, commits, and can be beaten.
//
// WHAT IS THERE NOW
// `BasketballCore.DefenderBrain` lerps toward a point 35% of the way from the
// ball to the hoop, and pokes for a steal with `Math.random() < aggression *
// 0.02` per frame. That is a chase, not a defender. Three consequences:
//
//   · YOU CANNOT BEAT IT WITH A MOVE, only with speed. There is nothing to
//     fake because it never commits to anything.
//   · IT NEVER PUNISHES YOU. Drive right nine times and the tenth is
//     identical. The mode has no memory, so it has no read.
//   · IT BREAKS REPLAYS. `Math.random()` per frame means M83's ghosts cannot
//     reproduce a possession, and Cash Arena cannot audit one.
//
// WHAT A DEFENDER ACTUALLY DOES
// It watches your hips, guesses a direction, and COMMITS — for a beat, during
// which it is fast in the guessed direction and slow the other way. A good
// crossover beats it because the commitment is real. A predictable player gets
// read, because the guess is informed by what they have already done.
//
// That is the whole design, and it is the difference between "the defender is
// hard" and "the defender is *reading* me".

import { Rng } from './Rng';

export type DefensiveStance = 'contain' | 'commit_left' | 'commit_right' | 'recover' | 'contest';

/** How long a commitment lasts. Long enough to be exploitable, short enough
 *  not to feel broken when you guess wrong as the defender. */
export const COMMIT_MS = 420;
/** After a beaten commitment, this long at reduced speed. The punish window. */
export const RECOVER_MS = 380;
/** Lateral speed multiplier toward the committed side, and away from it. */
export const COMMIT_WITH = 1.35;
export const COMMIT_AGAINST = 0.55;
/** Recovery speed. Beating a defender must actually buy you something. */
export const RECOVER_SPEED = 0.6;

/**
 * A rolling record of which way the ball-handler goes.
 *
 * Small on purpose. Eight possessions is enough to read a habit and short
 * enough that changing it up works within one game — a defender that
 * remembers forever is not reading you, it is holding a grudge.
 */
export class TendencyTracker {
  private history: Array<-1 | 1> = [];
  private readonly window: number;

  constructor(window = 8) { this.window = window; }

  /** -1 for a left drive, +1 for right. */
  record(direction: -1 | 1): void {
    this.history.push(direction);
    if (this.history.length > this.window) this.history.shift();
  }

  get samples(): number { return this.history.length; }

  /**
   * Bias toward the player's habit, -1..1. Zero when there is no read.
   *
   * Deliberately returns 0 until there are 3 samples. Reading a habit off one
   * drive is not a read, it is a coin flip that feels unfair — and unfairness
   * that arrives in the first ten seconds is what makes people quit a mode.
   */
  get bias(): number {
    if (this.history.length < 3) return 0;
    const sum = this.history.reduce<number>((a, b) => a + b, 0);
    return sum / this.history.length;
  }

  /** True if the player is heavily one-sided — the HUD can warn them, which
   *  turns being read into a lesson instead of a mystery. */
  get isPredictable(): boolean { return Math.abs(this.bias) > 0.6; }

  reset(): void { this.history = []; }
}

export interface DefenderConfig {
  /** 0..1. From DDA — PRQ makes this defender read you better. */
  aggression: number;
  /** Seconds before it reacts to a change. From `dda.aiReactionSpeed()`. */
  reactionSec: number;
  /** 0..1 chance a commitment is correct on top of the tendency read. Higher
   *  tiers guess better. */
  readSkill: number;
}

export interface HandlerState {
  /** Lateral position relative to the defender, metres. Negative is left. */
  lateralOffset: number;
  /** Lateral velocity, m/s. The hips — this is what a defender actually reads. */
  lateralVelocity: number;
  /** Distance to the hoop, metres. */
  hoopDistance: number;
  /** True on the frame a crossover fires. */
  crossover: boolean;
  /** True while the handler is airborne on a shot. */
  shooting: boolean;
}

export interface DefenseOutput {
  stance: DefensiveStance;
  /** -1..1 lateral movement the defender wants. */
  moveLateral: number;
  /** 0..1 how hard it closes the gap. */
  pressure: number;
  /** True on the frame it contests a shot. */
  contest: boolean;
  /** True when the handler has genuinely beaten it — the drive is open. */
  beaten: boolean;
  /** For the HUD: why it did that. Debuggable AI is maintainable AI. */
  reason: string;
}

/**
 * The defender.
 *
 * Deterministic: every random draw comes from an injected `Rng`, so a
 * possession replays exactly and a ghost is reproducible. That is not a
 * nicety — Cash Arena cannot pay out on a match nobody can re-run.
 */
export class DefenseRead {
  private stance: DefensiveStance = 'contain';
  private stanceMs = 0;
  private committedTo: -1 | 1 = 1;
  private reactionDebt = 0;
  private lastLateralSign: -1 | 1 = 1;
  readonly tendencies = new TendencyTracker();

  private rng: Rng;
  private cfg: DefenderConfig;

  constructor(rng: Rng, cfg: DefenderConfig) {
    this.rng = rng;
    this.cfg = cfg;
  }

  /** DDA changes mid-match as the score moves. */
  configure(cfg: Partial<DefenderConfig>): void {
    this.cfg = { ...this.cfg, ...cfg };
  }

  /** Advance one FIXED tick. */
  update(h: HandlerState, dt: number): DefenseOutput {
    this.stanceMs += dt * 1000;

    // Reaction debt: the defender cannot respond to a change instantly. This
    // is where PRQ enters — a high-readiness player faces a defender whose
    // debt is smaller, so their moves have less time to work.
    if (this.reactionDebt > 0) this.reactionDebt = Math.max(0, this.reactionDebt - dt);

    const sign: -1 | 1 = h.lateralVelocity < 0 ? -1 : 1;
    if (sign !== this.lastLateralSign) {
      this.lastLateralSign = sign;
      this.reactionDebt = this.cfg.reactionSec;
    }

    if (h.shooting) return this.contestShot(h);

    switch (this.stance) {
      case 'commit_left':
      case 'commit_right':
        return this.holdCommitment(h);
      case 'recover':
        return this.recovering(h);
      default:
        return this.containing(h);
    }
  }

  private containing(h: HandlerState): DefenseOutput {
    // A committed guess only happens when the handler is actually threatening
    // — committing against a stationary player is how an AI looks broken.
    const threatening = Math.abs(h.lateralVelocity) > 1.2 || h.crossover;
    if (threatening && this.reactionDebt <= 0) {
      this.commit(h);
      return this.holdCommitment(h);
    }
    // Mirror, imperfectly. The lag is what makes a first step work.
    return {
      stance: 'contain',
      moveLateral: Math.max(-1, Math.min(1, h.lateralOffset * 0.8)),
      pressure: h.hoopDistance < 6 ? 0.8 : 0.5,
      contest: false,
      beaten: false,
      reason: this.reactionDebt > 0 ? 'reacting to the change' : 'containing',
    };
  }

  /**
   * Pick a side and commit.
   *
   * Three inputs, in order of weight: the handler's CURRENT direction (what a
   * defender can see), their TENDENCY (what it has learned), and a random
   * element scaled by how skilled this defender is. A perfect read every time
   * would be unbeatable and therefore not a game.
   */
  private commit(h: HandlerState): void {
    const observed = h.lateralVelocity < 0 ? -1 : 1;
    const tendency = this.tendencies.bias;
    // Confidence blends what it sees with what it knows.
    const confidence = 0.55 * this.cfg.readSkill
      + 0.25 * Math.abs(tendency)
      + 0.20 * Math.min(1, Math.abs(h.lateralVelocity) / 3);
    const guessRight = this.rng.chance(Math.min(0.92, confidence));

    // A crossover is a lie about direction — if it lands during the reaction
    // window, the guess is inverted. That is the mechanic: a fake works
    // because the defender genuinely committed to the wrong thing.
    const truth = h.crossover ? (observed === 1 ? -1 : 1) : observed;
    this.committedTo = guessRight ? truth : (truth === 1 ? -1 : 1);
    this.stance = this.committedTo === -1 ? 'commit_left' : 'commit_right';
    this.stanceMs = 0;
  }

  private holdCommitment(h: HandlerState): DefenseOutput {
    const handlerSide: -1 | 1 = h.lateralOffset < 0 ? -1 : 1;
    const wrong = handlerSide !== this.committedTo && Math.abs(h.lateralOffset) > 0.4;

    if (wrong) {
      this.stance = 'recover';
      this.stanceMs = 0;
      this.tendencies.record(handlerSide);
      return {
        stance: 'recover', moveLateral: handlerSide * RECOVER_SPEED,
        pressure: 0.3, contest: false, beaten: true,
        reason: 'committed the wrong way — beaten',
      };
    }

    if (this.stanceMs >= COMMIT_MS) {
      this.stance = 'contain';
      this.stanceMs = 0;
      this.tendencies.record(handlerSide);
    }

    // Fast toward the guess, slow away from it. Being right is rewarded and
    // being wrong is punished, which is what makes the commitment a decision.
    const withGuess = handlerSide === this.committedTo;
    return {
      stance: this.stance,
      moveLateral: handlerSide * (withGuess ? COMMIT_WITH : COMMIT_AGAINST),
      pressure: withGuess ? 1 : 0.5,
      contest: false,
      beaten: false,
      reason: withGuess ? 'read it — cutting off the drive' : 'committed, still closing',
    };
  }

  private recovering(h: HandlerState): DefenseOutput {
    if (this.stanceMs >= RECOVER_MS) {
      this.stance = 'contain';
      this.stanceMs = 0;
    }
    const handlerSide: -1 | 1 = h.lateralOffset < 0 ? -1 : 1;
    return {
      stance: 'recover',
      moveLateral: handlerSide * RECOVER_SPEED,
      pressure: 0.35,
      contest: false,
      beaten: this.stanceMs < RECOVER_MS * 0.5,
      reason: 'recovering',
    };
  }

  private contestShot(h: HandlerState): DefenseOutput {
    // Contest quality falls off with distance, and aggression from DDA
    // decides how hard it goes for the block versus staying grounded.
    const close = Math.max(0, 1 - Math.abs(h.lateralOffset) / 2.2);
    return {
      stance: 'contest',
      moveLateral: Math.max(-1, Math.min(1, h.lateralOffset)),
      pressure: close,
      contest: close > 0.4 && this.stance !== 'recover',
      beaten: this.stance === 'recover',
      reason: this.stance === 'recover' ? 'too late to contest' : 'contesting',
    };
  }

  /** For the HUD. Turning "the defender keeps reading me" into a lesson. */
  get scoutingReport(): string | null {
    if (!this.tendencies.isPredictable) return null;
    return this.tendencies.bias > 0
      ? 'The defender has your right hand. Go left.'
      : 'The defender has your left hand. Go right.';
  }

  reset(): void {
    this.stance = 'contain';
    this.stanceMs = 0;
    this.reactionDebt = 0;
    this.tendencies.reset();
  }
}

/**
 * Build a defender from the DDA.
 *
 * This is where PRQ reaches the court: a high-readiness player gets a defender
 * that reacts faster and reads better. Not because they picked "Hard" —
 * because they showed up ready.
 */
export function defenderFor(
  rng: Rng,
  dda: { aiBlockChance(p: number, a: number): number; aiReactionSpeed(p: number, a: number): number; prqNormalized: number },
  playerScore = 0,
  aiScore = 0,
): DefenseRead {
  return new DefenseRead(rng, {
    aggression: dda.aiBlockChance(playerScore, aiScore),
    reactionSec: dda.aiReactionSpeed(playerScore, aiScore),
    readSkill: 0.35 + dda.prqNormalized * 0.45,
  });
}
