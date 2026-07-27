// PitchRecognition — baseball where the skill is IDENTIFYING, not timing.
//
// WHAT BASEBALL HAS TODAY
// `DerbyMode` throws ten pitches and asks you to "STRIKE on time". The pitch
// is a moving object and the input is a timing window. That is a rhythm game
// wearing a baseball uniform — and it is what almost every arcade baseball
// mode ships, because it is easy to build and shallow enough to be readable in
// one screenshot.
//
// WHAT HITTING ACTUALLY IS
// A major-league fastball reaches the plate in about 400ms. Human reaction to
// a simple stimulus is around 200ms, and a swing takes roughly 150ms to
// execute. There is essentially no time to watch the ball and then decide.
//
// So real hitters do not track the ball to the plate. They read RELEASE and
// EARLY FLIGHT — arm slot, spin, the first few metres of trajectory — and
// commit to a swing based on what they think it is. Hitting is a
// classification problem solved under a deadline. The timing is the easy part.
//
// That is a far better game than a timing bar, it is genuinely what the sport
// is, and nothing in FEL models it.
//
// THIS ALSO MAKES BASEBALL A COGNITIVE MODE, which matters for the product:
// the Mental Resiliency thesis wants perception under pressure, and pitch
// recognition is exactly that. It is the same skill Brain Brawl tests, wearing
// a different uniform — and unlike a timing bar, it is a skill that transfers.

import { Rng } from './Rng';

export type PitchType = 'fastball' | 'changeup' | 'curveball' | 'slider';

export interface PitchDef {
  id: PitchType;
  label: string;
  /** Plate speed, km/h. */
  speedKph: number;
  /** Vertical break in cm. Negative drops. */
  vBreakCm: number;
  /** Horizontal break in cm. Negative moves to the left-hand batter's side. */
  hBreakCm: number;
  /**
   * The tell — what a hitter can actually see in the first few metres.
   *
   * These are real recognition cues, not invented ones: spin axis and its
   * visible signature (the "red dot" on a slider), release height, and how
   * fast the ball appears to be moving out of the hand.
   */
  tell: {
    /** Apparent spin, 0..1 — high on a four-seam, low on a changeup. */
    spinRate: number;
    /** Release height relative to the pitcher's slot, cm. */
    releaseOffsetCm: number;
    /** Early velocity as a fraction of a fastball's. THE hardest cue: a good
     *  changeup looks like a fastball out of the hand. */
    apparentSpeed: number;
  };
  /** How hard this is to identify, 0..1. Drives the recognition window. */
  deception: number;
}

export const PITCHES: Record<PitchType, PitchDef> = {
  fastball:  { id: 'fastball',  label: 'FASTBALL',  speedKph: 150, vBreakCm: 4,   hBreakCm: 2,   deception: 0.15,
    tell: { spinRate: 0.95, releaseOffsetCm: 0,  apparentSpeed: 1.0 } },
  changeup:  { id: 'changeup',  label: 'CHANGEUP',  speedKph: 128, vBreakCm: -14, hBreakCm: 6,   deception: 0.85,
    tell: { spinRate: 0.55, releaseOffsetCm: 1,  apparentSpeed: 0.96 } },
  curveball: { id: 'curveball', label: 'CURVEBALL', speedKph: 122, vBreakCm: -38, hBreakCm: -4,  deception: 0.35,
    tell: { spinRate: 0.85, releaseOffsetCm: 6,  apparentSpeed: 0.78 } },
  slider:    { id: 'slider',    label: 'SLIDER',    speedKph: 138, vBreakCm: -12, hBreakCm: -22, deception: 0.55,
    tell: { spinRate: 0.90, releaseOffsetCm: 2,  apparentSpeed: 0.90 } },
};

/** Flight time to the plate, ms. This is the entire budget for everything. */
export function flightTimeMs(p: PitchDef, distanceM = 18.44): number {
  return Math.round((distanceM / (p.speedKph / 3.6)) * 1000);
}

/** A swing takes this long to execute once committed. Non-negotiable time
 *  spent, which is why the decision has to be made early. */
export const SWING_DURATION_MS = 150;

/**
 * How long you actually have to decide, after subtracting the swing.
 *
 * On a 150kph fastball this is roughly 290ms — and human reaction to a *simple*
 * stimulus is ~200ms. Classifying between four pitch types is not a simple
 * stimulus. That gap is the whole game.
 */
export function decisionWindowMs(p: PitchDef, distanceM = 18.44): number {
  return flightTimeMs(p, distanceM) - SWING_DURATION_MS;
}

/**
 * How identifiable the pitch is at time `tMs` after release.
 *
 * Rises from 0 to 1 as the cues accumulate. A deceptive pitch reveals itself
 * later, so a changeup can be at 0.3 when the swing decision is already due.
 * That is why it is the hardest pitch in baseball and it falls out of the
 * model rather than being asserted.
 */
export function recognitionAt(p: PitchDef, tMs: number): number {
  const flight = flightTimeMs(p);
  const progress = Math.min(1, Math.max(0, tMs / flight));
  // Deception delays the reveal: a high-deception pitch stays ambiguous
  // through the window where you still had time to act.
  const revealPoint = 0.15 + p.deception * 0.45;
  if (progress <= revealPoint) return progress / revealPoint * 0.35;
  return Math.min(1, 0.35 + ((progress - revealPoint) / (1 - revealPoint)) * 0.65);
}

/**
 * How confident an identification is, given the hitter's skill and PRQ.
 *
 * Skill compresses the cue set: an experienced hitter reads spin out of the
 * hand where a novice waits for break. PRQ is the same lever DDA uses, applied
 * to perception rather than to opposition.
 */
export function identifyConfidence(
  p: PitchDef, tMs: number, hitterSkill: number,
): number {
  return Math.min(1, recognitionAt(p, tMs) * (0.55 + hitterSkill * 0.75));
}

export type SwingDecision = 'take' | 'swing';
export type PlateOutcome =
  | 'called_strike' | 'ball' | 'whiff' | 'foul'
  | 'weak_contact' | 'solid' | 'barrelled';

export interface PlateAppearance {
  pitch: PitchDef;
  /** What the hitter believed it was when they committed. */
  guessed: PitchType | null;
  decision: SwingDecision;
  /** ms after release when the swing was committed. */
  committedAtMs: number;
  /** Was the pitch actually in the zone? */
  inZone: boolean;
}

export interface PlateResult {
  outcome: PlateOutcome;
  /** Exit velocity as a fraction of maximum, 0..1. */
  quality: number;
  /** What the hitter should learn. */
  note: string;
}

/**
 * Resolve a plate appearance.
 *
 * The scoring principle, and the reason this is a better mode: **being right
 * about what it was matters more than being on time.** A hitter who identifies
 * a curveball and swings slightly late still squares it up. A hitter who
 * guesses fastball on a changeup is out in front no matter how good their
 * timing was — which is exactly what happens in the sport, and exactly what a
 * timing bar cannot express.
 */
export function resolvePlateAppearance(pa: PlateAppearance): PlateResult {
  const { pitch, guessed, decision, committedAtMs, inZone } = pa;

  if (decision === 'take') {
    return inZone
      ? { outcome: 'called_strike', quality: 0,
          note: `${pitch.label} caught the zone — you had ${decisionWindowMs(pitch)}ms to decide` }
      : { outcome: 'ball', quality: 0, note: `laid off a ${pitch.label} out of the zone` };
  }

  if (!inZone) {
    return { outcome: 'whiff', quality: 0,
      note: `chased a ${pitch.label} out of the zone` };
  }

  const correct = guessed === pitch.id;
  const window = decisionWindowMs(pitch);
  // Late commitment costs quality even when the read was right — you have
  // less swing left to adjust with.
  const lateness = Math.max(0, committedAtMs - window) / SWING_DURATION_MS;
  const timing = Math.max(0, 1 - lateness);

  if (!correct) {
    // The signature failure: guessing fastball on off-speed. You are out in
    // front, and no amount of timing skill saves it.
    const speedError = Math.abs(
      (guessed ? PITCHES[guessed].speedKph : pitch.speedKph) - pitch.speedKph,
    );
    if (speedError > 15) {
      return { outcome: 'whiff', quality: 0,
        note: `sat ${guessed ? PITCHES[guessed].label : 'nothing'}, got ${pitch.label} — out in front` };
    }
    return { outcome: 'weak_contact', quality: 0.25 * timing,
      note: `misread the ${pitch.label} but stayed on it` };
  }

  // Right read. Now timing decides how well it is struck.
  if (timing > 0.85) {
    return { outcome: 'barrelled', quality: 0.9 + timing * 0.1,
      note: `read the ${pitch.label} and barrelled it` };
  }
  if (timing > 0.5) {
    return { outcome: 'solid', quality: 0.55 + timing * 0.3,
      note: `read the ${pitch.label}, a touch late` };
  }
  return { outcome: 'foul', quality: 0.2,
    note: `read the ${pitch.label} but committed too late` };
}

/**
 * Choose a pitch, with a memory.
 *
 * Sequencing is most of pitching. A pitcher who throws at random is easier to
 * hit than one who sets you up — so this avoids repeating the same pitch three
 * times and leans on off-speed once you have shown you sit on the fastball.
 * The batter's own tendencies come back at them, which is the same read/be-read
 * loop as Phase 2's `TendencyTracker`.
 */
export class PitchSelector {
  private history: PitchType[] = [];
  private hitterSatFastball = 0;
  private rng: Rng;
  private aggression: number;

  constructor(rng: Rng, aggression = 0.5) {
    this.rng = rng;
    this.aggression = aggression;
  }

  /** Tell the selector what the hitter guessed, so it can exploit a pattern. */
  observeGuess(guessed: PitchType | null): void {
    if (guessed === 'fastball') this.hitterSatFastball++;
    else if (guessed) this.hitterSatFastball = Math.max(0, this.hitterSatFastball - 1);
  }

  next(): PitchDef {
    const last = this.history[this.history.length - 1];
    const repeated = this.history.length >= 2
      && this.history[this.history.length - 1] === this.history[this.history.length - 2];

    let pool: PitchType[] = ['fastball', 'changeup', 'curveball', 'slider'];
    if (repeated && last) pool = pool.filter((p) => p !== last);

    // A hitter sitting fastball gets fed off-speed. Being predictable at the
    // plate is punished the same way it is on the court.
    if (this.hitterSatFastball >= 2 && this.rng.chance(0.6 + this.aggression * 0.3)) {
      pool = pool.filter((p) => p !== 'fastball');
    }

    const pick = pool[this.rng.int(0, pool.length - 1)];
    this.history.push(pick);
    if (this.history.length > 8) this.history.shift();
    return PITCHES[pick];
  }

  reset(): void { this.history = []; this.hitterSatFastball = 0; }
}

/** A coaching line for the results screen. */
export function hittingCoaching(stats: {
  swings: number; whiffs: number; chased: number; misreads: number; barrelled: number;
}): string | null {
  if (stats.swings < 6) return null;
  if (stats.chased / stats.swings > 0.35) {
    return 'You are chasing out of the zone. Recognise the location before you commit, not after.';
  }
  if (stats.misreads / stats.swings > 0.4) {
    return 'You are sitting fastball every pitch. Watch the release — a changeup leaves the hand slower.';
  }
  if (stats.barrelled / stats.swings > 0.4) {
    return 'You are reading the ball out of the hand. That is the whole skill.';
  }
  return null;
}
