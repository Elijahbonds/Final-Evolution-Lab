// RallyPressure — a rally as a duel, not a timing exchange.
//
// WHAT RALLY SPORTS HAVE TODAY
// `RallyCore` (M74) is solid: swing timing bands, ballistic shot planning, net
// clearance, faults, tennis and volleyball scoring. Thirty-seven tests. It
// serves tennis and volleyball from one core, which was the right call.
//
// What it does not have is a REASON TO AIM. `planShot()` takes a target, but
// nothing in the model makes one target better than another. Hit it back, hit
// it back, hit it back — the rally ends when someone mistimes a swing. That
// makes both modes a timing exchange with a net in the middle, and it is why
// arcade tennis usually feels like Pong with animation.
//
// WHAT A RALLY ACTUALLY IS
// You are not trying to hit a winner. You are trying to make the NEXT ball
// harder for them than the last one — pushing them wide, deep, off balance —
// until the ball they give back is one you can end. Pressure accumulates. The
// winner is usually struck two shots after the shot that actually won the
// point.
//
// So: placement moves an opponent, movement costs recovery, and an opponent
// who has not recovered hits a worse ball. That single loop turns a timing
// exchange into a duel, and it costs one number — `pressure` — to model.

export interface Court {
  /** Half-width in metres, from the centre line. */
  halfWidth: number;
  /** Baseline depth from the net. */
  depth: number;
}

export const TENNIS_COURT: Court = { halfWidth: 4.1, depth: 11.9 };

/**
 * Movement speed in COURT UNITS per second, where 1 unit = a half-width.
 *
 * Calibrated against reality rather than guessed, because the first draft was
 * not: it used 2.4 units/sec, which has a player crossing a full singles court
 * (8.23m) in 0.83 seconds. Nothing was ever out of position, so no shot ever
 * cost anything and pressure never accumulated — the whole model was inert and
 * the tests caught it.
 *
 * A singles half-width is 4.1m. A good player covers that comfortably in about
 * 1.5s (≈2.7 m/s) and at a full stretching sprint in about 0.9s (≈4.5 m/s).
 */
export const COMFORTABLE_UNITS_PER_SEC = 0.66;
export const MAX_UNITS_PER_SEC = 1.15;
export const VOLLEY_COURT: Court = { halfWidth: 4.5, depth: 9.0 };

export interface Placement {
  /** -1 (far left) .. 1 (far right), relative to the receiver's court. */
  x: number;
  /** 0 (at the net) .. 1 (on the baseline). */
  depth: number;
}

export interface PlayerCourtState {
  /** Where they are standing, in the same -1..1 / 0..1 space. */
  x: number;
  depth: number;
  /**
   * Recovery, 0..1. 1 is set and balanced; 0 is still moving and reaching.
   *
   * THE LOAD-BEARING NUMBER. Everything else is arithmetic around it.
   */
  recovery: number;
  /** Accumulated pressure, 0..1. Rises as they are worked, decays when not. */
  pressure: number;
}

export const FRESH: PlayerCourtState = { x: 0, depth: 0.8, recovery: 1, pressure: 0 };

/** Court-normalised distance between two positions. */
export function courtDistance(a: { x: number; depth: number }, b: { x: number; depth: number }): number {
  return Math.hypot(a.x - b.x, (a.depth - b.depth) * 0.8);
}

/**
 * How far the receiver must travel, and what it costs them.
 *
 * Recovery is spent by distance and returned by time. The trade is the whole
 * mechanic: a shot to the open court costs them recovery they may not get back
 * before the next ball arrives.
 */
export function movementCost(from: PlayerCourtState, to: Placement, timeToArriveSec: number): number {
  const dist = courtDistance(from, to);
  const comfortable = timeToArriveSec * COMFORTABLE_UNITS_PER_SEC;
  return Math.min(1, Math.max(0, (dist - comfortable) / 1.2));
}

/**
 * Advance a player's state after being made to move.
 *
 * Pressure rises with what the shot cost them and decays otherwise — a rally
 * that stops testing someone lets them reset, which is why a neutral rally can
 * go twenty balls and a good one ends in six.
 */
export function receiveShot(
  s: PlayerCourtState, to: Placement, timeToArriveSec: number,
): PlayerCourtState {
  const cost = movementCost(s, to, timeToArriveSec);
  const recovery = Math.min(1, Math.max(0, 1 - cost));
  // Pressure is sticky: it accumulates faster than it sheds, so a sequence of
  // demanding shots compounds while one loose ball does not undo the work.
  const pressure = cost > 0.1
    ? Math.min(1, s.pressure + cost * 0.6)
    : Math.max(0, s.pressure - 0.25);
  return { x: to.x, depth: to.depth, recovery, pressure };
}

/**
 * Quality multiplier on the shot a player under pressure gives back, 0.35..1.
 *
 * This is where pressure becomes real. A stretched player cannot hit the ball
 * they wanted; they hit a shorter, more central one — which hands the
 * initiative over. That handover is what a rally IS.
 */
export function shotQualityUnderPressure(s: PlayerCourtState): number {
  return Math.max(0.35, Math.min(1, s.recovery * 0.7 + (1 - s.pressure) * 0.3));
}

/**
 * Where a pressured player's shot actually lands, versus where they aimed.
 *
 * Deliberately biased toward the CENTRE and SHORT rather than randomly
 * scattered. Random error feels unfair; the centre-and-short bias is what
 * really happens when someone is stretched, and it is readable — the attacker
 * can anticipate the weak reply and step in. Predictable degradation is a
 * mechanic; random degradation is noise.
 */
export function degradePlacement(aim: Placement, quality: number): Placement {
  const slip = 1 - quality;
  return {
    x: aim.x * (1 - slip * 0.75),
    depth: Math.max(0, aim.depth - slip * 0.45),
  };
}

/**
 * How much this placement demands of the receiver, 0..1.
 *
 * For AI shot selection and for a HUD "shot value" readout. Wide and deep is
 * demanding; a ball hit to where they already are is not. Note it depends on
 * WHERE THEY ARE — the same target is a winner or a gift depending on the
 * previous shot, which is exactly the property that makes rallies build.
 */
export function shotDemand(target: Placement, receiver: PlayerCourtState): number {
  const dist = courtDistance(receiver, target);
  const depthValue = target.depth * 0.35;
  const cornerValue = Math.abs(target.x) * 0.3;
  return Math.min(1, dist * 0.45 + depthValue + cornerValue);
}

/** Is this ball actually reachable? Beyond this they cannot get there at all. */
export function isReachable(from: PlayerCourtState, to: Placement, timeSec: number): boolean {
  return courtDistance(from, to) <= timeSec * MAX_UNITS_PER_SEC + 0.15;
}

/**
 * Choose where to hit.
 *
 * Not "aim at the biggest gap". A rally is built: against a set opponent you
 * work them, and only when they are stretched do you go for the line. Going
 * for a winner off a neutral ball is the single most common way club players
 * lose points, and an AI that models that is both more beatable and more
 * instructive than one that aims perfectly.
 */
export function chooseTarget(
  opponent: PlayerCourtState, aggression: number, court: Court = TENNIS_COURT,
): { target: Placement; intent: 'build' | 'attack' | 'reset' } {
  // Stretched and under pressure — end it.
  if (opponent.recovery < 0.5 && opponent.pressure > 0.5) {
    return {
      target: { x: opponent.x > 0 ? -0.85 : 0.85, depth: 0.75 },
      intent: 'attack',
    };
  }
  // Under real pressure yourself — hit deep and central, buy time, reset.
  if (opponent.pressure < 0.2 && aggression < 0.3) {
    return { target: { x: 0, depth: 0.95 }, intent: 'reset' };
  }
  // Build: hit away from them without going for the line.
  const away = opponent.x > 0 ? -1 : 1;
  return {
    target: { x: away * (0.35 + aggression * 0.35), depth: 0.7 + aggression * 0.2 },
    intent: 'build',
  };
}

/**
 * A one-line read on how a point was won or lost.
 *
 * Rally depth is invisible without it. "You were pushed wide three balls in a
 * row" is a lesson; a lost point with no explanation is a coin flip.
 */
export function rallyNote(shots: Array<{ demand: number; pressureAfter: number }>): string | null {
  if (shots.length < 3) return null;
  const built = shots.filter((s) => s.demand > 0.5).length;
  const last = shots[shots.length - 1];
  if (last.pressureAfter > 0.7 && built >= 2) {
    return `Worked out of position over ${built} shots — the point was lost before the last ball.`;
  }
  if (built === 0) {
    return 'Every ball came back to the middle. Move them, or the rally never ends.';
  }
  return null;
}
