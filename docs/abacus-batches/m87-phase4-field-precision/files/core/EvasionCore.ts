// EvasionCore — football evades as a READ, not a dodge button.
//
// WHAT FOOTBALL HAS TODAY
// `FootballRushMode` gives juke, spin, hurdle and truck. Each grants
// invincibility frames on a cooldown, plus a style bonus for chaining
// different types. It is a competent arcade system and it has one problem:
//
//   THE EVADE DOES NOT CARE WHERE THE DEFENDER IS.
//
// Press the button inside the window and you are untouchable. Press it outside
// and you are not. The defender's pursuit angle is irrelevant, so there is
// nothing to read — the skill is reaction time and nothing else. The optimal
// strategy is to mash an evade whenever anyone is close, and once a player
// notices that, the mode is solved.
//
// Football carries the highest PRQ weight in the product (1.5). It should be
// the deepest mode, not the most reflexive one.
//
// THE FIX, WHICH IS THE SAME INSIGHT AS PHASES 2 AND 3
//   Phase 2: the defender COMMITS to a side, so a crossover can beat it.
//   Phase 3: an attack COMMITS to recovery frames, so a whiff can be punished.
//   Phase 4: an evade COMMITS to a direction, so it can be wrong.
//
// A juke left against a defender already flowing left is a tackle. The same
// juke against a defender flowing right is six yards. Same input, same timing,
// opposite outcome — because now you are reading a person instead of a clock.
//
// That single change turns four buttons into a rock-paper-scissors with
// spatial information, which is what makes the genre's best open-field running
// feel like a conversation rather than a reflex test.

import { Rng } from './Rng';

export type EvadeType = 'juke' | 'spin' | 'hurdle' | 'truck';

export interface EvadeDef {
  id: EvadeType;
  label: string;
  /** Frames before the evade takes effect. You commit here. */
  startup: number;
  /** Frames the evade is doing its work. */
  active: number;
  /** Frames after, during which you cannot evade again and are slow. */
  recovery: number;
  /**
   * How wrong the defender's pursuit angle must be for this to work, in
   * degrees. A wider tolerance is more forgiving and yields less.
   */
  toleranceDeg: number;
  /** Speed multiplier while active. Some evades cost momentum. */
  speedMul: number;
  /** Yards of lateral displacement on success. */
  lateralYards: number;
  /** Base style points. Harder reads pay more. */
  style: number;
  clipId: string;
}

/**
 * The four evades, each answering a different pursuit.
 *
 * The design rule: **no evade beats everything.** A juke is fast and cheap but
 * demands the defender be genuinely committed elsewhere. A truck is the answer
 * to a defender square in front of you — the one situation where finesse
 * fails. If any single evade were correct against every angle, the other three
 * would be decoration.
 */
export const EVADES: Record<EvadeType, EvadeDef> = {
  juke:   { id: 'juke',   label: 'JUKE',   startup: 5,  active: 8,  recovery: 10, toleranceDeg: 35, speedMul: 0.85, lateralYards: 1.8, style: 10, clipId: 'football_juke_left' },
  spin:   { id: 'spin',   label: 'SPIN',   startup: 8,  active: 12, recovery: 16, toleranceDeg: 60, speedMul: 0.7,  lateralYards: 1.2, style: 18, clipId: 'football_spin_move' },
  hurdle: { id: 'hurdle', label: 'HURDLE', startup: 7,  active: 10, recovery: 14, toleranceDeg: 25, speedMul: 1.0,  lateralYards: 0.3, style: 15, clipId: 'football_hurdle' },
  truck:  { id: 'truck',  label: 'TRUCK',  startup: 10, active: 6,  recovery: 22, toleranceDeg: 20, speedMul: 0.6,  lateralYards: 0.2, style: 12, clipId: 'football_truck' },
};

/** Where the defender is coming from, relative to the runner's facing. */
export interface Pursuit {
  /** Degrees off the runner's forward axis. 0 = head-on, ±90 = pure lateral. */
  angleDeg: number;
  /** Metres. */
  distance: number;
  /** Closing speed, m/s. */
  closingSpeed: number;
  /** True if the defender has already committed to a direction (Phase 2's
   *  DefenseRead exposes this) — a committed defender is far easier to beat. */
  committed: boolean;
}

export type EvadeOutcome = 'clean' | 'grazed' | 'tackled' | 'no_contact';

export interface EvadeResult {
  outcome: EvadeOutcome;
  /** Yards gained or lost by the attempt. */
  yards: number;
  style: number;
  /** Why it went that way. The mode shows this; the player learns from it. */
  reason: string;
}

/**
 * Does this evade beat this pursuit?
 *
 * The whole model in one function. Each evade wants a different angle:
 *
 *   JUKE    beats a defender coming at an ANGLE — you step off their line.
 *           Useless head-on, because there is no line to step off.
 *   SPIN    beats contact from the SIDE, and is the most forgiving.
 *   HURDLE  beats a LOW head-on tackle specifically. Narrow but real.
 *   TRUCK   beats a defender SQUARE IN FRONT. The power answer, and the only
 *           thing that works when there is nowhere to go.
 *
 * `evadeDirection` is the side the runner committed to. Against an angled
 * pursuit, committing the WRONG way runs you straight into them — which is the
 * entire point of the batch.
 */
export function evadeBeatsPursuit(
  evade: EvadeType, evadeDirection: -1 | 1, p: Pursuit,
): { beats: boolean; reason: string } {
  const a = Math.abs(p.angleDeg);
  const def = EVADES[evade];
  const pursuitSide: -1 | 1 = p.angleDeg < 0 ? -1 : 1;

  switch (evade) {
    case 'truck':
      // Wants them head-on. Anything wide and you are trucking air.
      return a <= def.toleranceDeg
        ? { beats: true, reason: 'ran through a defender square in front' }
        : { beats: false, reason: `trucking at ${Math.round(a)}° — nothing there to run through` };

    case 'hurdle':
      return a <= def.toleranceDeg
        ? { beats: true, reason: 'hurdled a low head-on tackle' }
        : { beats: false, reason: `hurdled at ${Math.round(a)}° — they were not in front of you` };

    case 'juke': {
      if (a < 15) return { beats: false, reason: 'juked a defender coming straight on — no line to step off' };
      // Step AWAY from where they are coming from. Toward them is a tackle,
      // and it is the mistake this mechanic exists to punish.
      if (evadeDirection === pursuitSide) {
        return { beats: false, reason: `juked INTO them — they were coming from your ${pursuitSide < 0 ? 'left' : 'right'}` };
      }
      return a <= def.toleranceDeg + 45
        ? { beats: true, reason: 'juked off their pursuit line' }
        : { beats: false, reason: 'juked too late — they had already crossed your face' };
    }

    case 'spin': {
      // The most forgiving: works over a wide band and does not care which way
      // you spin. It pays for that in startup, recovery and lost momentum.
      if (a < 20) return { beats: false, reason: 'spun against a head-on tackle — spin needs an angle' };
      return a <= def.toleranceDeg + 40
        ? { beats: true, reason: 'spun off the contact' }
        : { beats: false, reason: 'spun into empty air' };
    }
  }
}

/**
 * Resolve an evade attempt.
 *
 * `committed` matters: Phase 2's `DefenseRead` already models a defender that
 * commits to a side. A committed defender is beaten by a wider band, which is
 * how the two systems reward the same skill — baiting a commitment and then
 * going the other way.
 */
export function resolveEvade(
  evade: EvadeType, direction: -1 | 1, p: Pursuit, rng: Rng,
): EvadeResult {
  const def = EVADES[evade];

  if (p.distance > 2.5) {
    return {
      outcome: 'no_contact', yards: 0, style: 0,
      reason: `evaded ${p.distance.toFixed(1)}m early — nobody was there`,
    };
  }

  const { beats, reason } = evadeBeatsPursuit(evade, direction, p);
  // A committed defender has already picked a side and cannot correct: it
  // widens the band that works, so baiting is rewarded.
  const bonus = p.committed ? 0.25 : 0;

  if (beats) {
    return {
      outcome: 'clean',
      yards: def.lateralYards + (p.committed ? 1.5 : 0),
      style: Math.round(def.style * (p.committed ? 1.4 : 1)),
      reason: p.committed ? `${reason} — and they had already committed` : reason,
    };
  }

  // A near miss is a graze rather than a stop. Binary outcomes make a mode
  // feel arbitrary; a partial result tells you that you were close.
  const grazeChance = 0.25 + bonus + Math.max(0, (2.5 - p.distance) * 0.1);
  if (rng.chance(grazeChance)) {
    return {
      outcome: 'grazed',
      yards: def.lateralYards * 0.4,
      style: Math.round(def.style * 0.3),
      reason: `${reason} — but stayed up through the contact`,
    };
  }

  return {
    outcome: 'tackled',
    yards: -Math.min(2, p.closingSpeed * 0.3),
    style: 0,
    reason,
  };
}

/**
 * Which evade the situation actually calls for.
 *
 * For the tutorial and for the post-play coaching line. Naming the right
 * answer is what turns a tackle into a lesson — a player who is stopped and
 * not told why concludes it was random.
 */
export function correctEvade(p: Pursuit): { evade: EvadeType; direction: -1 | 1 } {
  const a = Math.abs(p.angleDeg);
  const away: -1 | 1 = p.angleDeg < 0 ? 1 : -1;
  if (a <= 20) return { evade: 'truck', direction: 1 };
  if (a <= 25) return { evade: 'hurdle', direction: 1 };
  if (a <= 60) return { evade: 'juke', direction: away };
  return { evade: 'spin', direction: away };
}

/**
 * The variety bonus, kept from the existing mode but made meaningful.
 *
 * The live version pays for using a NEW evade type per drive, which rewards
 * cycling buttons regardless of whether each was the right read. This version
 * only counts evades that actually WORKED, so variety is a consequence of
 * reading different situations rather than a checklist to tick.
 */
export class StyleChain {
  private used = new Set<EvadeType>();
  private consecutive = 0;

  record(evade: EvadeType, outcome: EvadeOutcome): number {
    if (outcome === 'tackled' || outcome === 'no_contact') {
      this.consecutive = 0;
      return 0;
    }
    let pts = 0;
    if (!this.used.has(evade)) { this.used.add(evade); pts += 25; }
    this.consecutive++;
    // Chaining successful reads compounds — up to 5, then it plateaus so a
    // single long run cannot outscore a whole game.
    pts += Math.min(this.consecutive, 5) * 5;
    return pts;
  }

  get variety(): number { return this.used.size; }
  get streak(): number { return this.consecutive; }
  reset(): void { this.used.clear(); this.consecutive = 0; }
}

/** One coaching line after a drive. Null when there is nothing worth saying. */
export function evasionCoaching(stats: {
  attempts: number; tackled: number; wrongWay: number; early: number;
}): string | null {
  if (stats.attempts < 5) return null;
  if (stats.wrongWay / stats.attempts > 0.35) {
    return 'You are juking INTO the tackle. Step away from where they are coming from, not toward it.';
  }
  if (stats.early / stats.attempts > 0.4) {
    return 'You are evading too early — let them commit first, then go the other way.';
  }
  if (stats.tackled / stats.attempts > 0.5) {
    return 'Head-on defenders beat finesse. When they are square in front of you, TRUCK.';
  }
  return null;
}
