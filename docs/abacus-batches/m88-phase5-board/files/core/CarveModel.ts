// CarveModel — speed comes from a good line, not from a button.
//
// WHAT SNOWBOARD HAS TODAY
// `SnowboardSlalomMode` steers laterally and gates a boost. Speed is something
// you hold a button for. Turning is free — it costs nothing and buys nothing,
// so the only decision is when to press boost, and the fastest line is a
// straight one with the button held.
//
// WHAT SNOWBOARDING ACTUALLY IS
// A board has a SIDECUT: the edges are arcs, not straight lines. Tip the board
// on edge and it bends into the snow and traces a circle whose radius is set by
// how far you tipped it. That is a carve, and it is the whole sport:
//
//   R = sidecutRadius x cos(edgeAngle)
//
// Real geometry, not invented. A 9m board at 45° carves a 6.4m arc; at 70° it
// carves 3.1m. You steer by choosing an edge angle, and the turn shape follows.
//
// THE TRADE THAT MAKES IT A GAME
//   · CARVING (a clean edge) barely scrubs speed. The board goes where it is
//     pointed and you keep almost everything.
//   · SKIDDING (too much angle for your speed, or a late edge) washes the tail
//     and dumps speed hard.
//   · THE FALL LINE is where the free speed is — but it is also where you have
//     the least control and where gates get missed.
//
// So the fast line is not the straight one and it is not the safe one. It is
// the one that spends the least speed getting where the gates are, and finding
// it is a skill rather than a button. That is what "better than the benchmark"
// means for a snowboarding mode.

/** Gravity. */
export const G = 9.81;

export interface BoardSpec {
  /** Sidecut radius in metres — the arc the edges describe. A slalom board is
   *  short and tight; a freeride board is long and stable. */
  sidecutRadius: number;
  /** Base friction on flat snow, 0..1. */
  friction: number;
  /** How much speed a skid scrubs, per second at full skid. */
  skidScrub: number;
}

export const SLALOM_BOARD: BoardSpec = { sidecutRadius: 11, friction: 0.04, skidScrub: 9 };
export const FREERIDE_BOARD: BoardSpec = { sidecutRadius: 16, friction: 0.035, skidScrub: 7 };

/**
 * Peak lateral grip, in g.
 *
 * A carving snowboarder on hard snow pulls somewhere around 2-2.6g through the
 * apex of a race turn. The first version of this model capped at 1.4g with an
 * 8m sidecut, which produced carve limits of 6-8 m/s — about 25 km/h. Every
 * realistic riding speed was therefore a SKID, so the carve state was
 * unreachable and the whole mechanic was dead. Same failure mode as Phase 4's
 * court speed: a merely-wrong constant, not a missing one.
 */
export const PEAK_GRIP_G = 2.6;

/**
 * Turn radius from edge angle — the real sidecut relationship.
 *
 * Clamped at 80°: past that a board is on its side and the model stops being
 * physical, so the game should stop pretending it is.
 */
export function turnRadius(board: BoardSpec, edgeAngleDeg: number): number {
  const a = Math.min(80, Math.max(0, edgeAngleDeg));
  return board.sidecutRadius * Math.cos((a * Math.PI) / 180);
}

/**
 * The speed above which this edge angle CANNOT hold — it washes into a skid.
 *
 * From v² = a·R with the lateral grip a board can generate. Grip rises with
 * edge angle (more edge bites more snow) but the required centripetal force
 * rises with v², so every edge angle has a speed it cannot hold. That ceiling
 * is why you cannot just lay it over and go fast: the tighter the turn you
 * ask for, the sooner it lets go.
 */
export function carveSpeedLimit(board: BoardSpec, edgeAngleDeg: number, gripMul = 1): number {
  const a = Math.min(80, Math.max(0, edgeAngleDeg));
  // Grip rises with edge angle and then SATURATES — an edge can only bite so
  // hard. Because grip saturates while the radius keeps shrinking, the speed
  // limit peaks around 45° and falls away either side. That is not a tuned
  // curve, it falls out of the physics, and it happens to match the real
  // "best carving angle" riders talk about.
  const grip = Math.min(PEAK_GRIP_G, 0.8 + Math.sin((a * Math.PI) / 180) * 1.4) * G * gripMul;
  const R = Math.max(0.8, turnRadius(board, a));
  return Math.sqrt(grip * R);
}

export type EdgeState = 'flat' | 'carving' | 'skidding';

export interface RideState {
  /** m/s along the board's direction of travel. */
  speed: number;
  /** Heading in degrees, where 0 is straight down the fall line. */
  headingDeg: number;
  /** Current edge angle, degrees. */
  edgeDeg: number;
  edge: EdgeState;
  /** Energy stored by unweighting through a transition, 0..1. */
  pump: number;
}

export const START_RIDE: RideState = {
  speed: 4, headingDeg: 0, edgeDeg: 0, edge: 'flat', pump: 0,
};

/**
 * Acceleration down the fall line, m/s².
 *
 * Only the component of gravity along your direction of travel. Traverse
 * across the hill at 80° off the fall line and you get almost nothing — which
 * is the cost of a safe, wide line, and it is a cost the player can feel.
 */
export function fallLineAccel(slopeDeg: number, headingDeg: number): number {
  const along = Math.cos((headingDeg * Math.PI) / 180);
  return G * Math.sin((slopeDeg * Math.PI) / 180) * along;
}

export interface CarveInput {
  /** Commanded edge angle, degrees. This IS the steering input. */
  edgeDeg: number;
  /** -1 or 1 — which edge. */
  direction: -1 | 1;
  /** True on the frame the rider unweights through a transition. */
  pumping: boolean;
  slopeDeg: number;
}

/**
 * Advance one FIXED tick.
 *
 * The heart of it: ask for more turn than your speed can hold and the edge
 * washes. Skidding scrubs speed hard and turns you MORE than you asked for,
 * which is exactly what happens and exactly what makes over-committing feel
 * bad in the right way.
 */
export function stepRide(
  s: RideState, input: CarveInput, dt: number, board: BoardSpec = SLALOM_BOARD,
): RideState {
  const edgeDeg = Math.min(80, Math.max(0, input.edgeDeg));
  const limit = carveSpeedLimit(board, edgeDeg);
  const holding = edgeDeg < 3 ? true : s.speed <= limit;

  const edge: EdgeState = edgeDeg < 3 ? 'flat' : holding ? 'carving' : 'skidding';

  // Turn rate. A carve follows the sidecut; a skid over-rotates and scrubs.
  const R = Math.max(0.8, turnRadius(board, edgeDeg));
  const carveRate = edgeDeg < 3 ? 0 : (s.speed / R) * (180 / Math.PI);
  const turnRate = edge === 'skidding' ? carveRate * 1.45 : carveRate;
  const headingDeg = s.headingDeg + turnRate * input.direction * dt;

  // Speed.
  let accel = fallLineAccel(input.slopeDeg, headingDeg);
  accel -= board.friction * G;                                  // base drag
  if (edge === 'skidding') {
    // How far past the limit you are decides how badly it bites.
    const over = (s.speed - limit) / Math.max(1, limit);
    accel -= board.skidScrub * Math.min(1.5, over + 0.35);
  } else if (edge === 'carving') {
    // A clean carve costs a little — an edge in snow is not free — but an
    // order of magnitude less than a skid. That gap IS the skill reward.
    accel -= 0.35;
  }

  // Pumping: unweighting through the transition converts stored load into
  // speed. Small per pump and it needs correct timing, so it rewards rhythm
  // rather than mashing.
  let pump = Math.max(0, s.pump - dt * 0.6);
  if (input.pumping && edge === 'carving' && edgeDeg > 25) {
    pump = Math.min(1, pump + 0.5);
    accel += 2.2 * pump;
  }

  return {
    speed: Math.max(0, s.speed + accel * dt),
    headingDeg,
    edgeDeg,
    edge,
    pump,
  };
}

/**
 * The best edge angle for a target turn radius at the current speed.
 *
 * Used by the AI and by a training overlay. Returns null when the turn is not
 * carvable at this speed at all — a genuinely useful thing to show a player,
 * because it says "you are going too fast for that line" rather than just
 * letting them wash out and wonder why.
 */
export function edgeForRadius(board: BoardSpec, targetRadius: number, speed: number): number | null {
  for (let a = 5; a <= 80; a += 1) {
    if (turnRadius(board, a) <= targetRadius && speed <= carveSpeedLimit(board, a)) return a;
  }
  return null;
}

export interface Gate {
  /** Metres across the hill from the centre line. */
  x: number;
  /** Metres down the hill. */
  z: number;
  /** Which side must be passed. */
  side: -1 | 1;
}

/**
 * The fastest edge angle that still makes the next gate.
 *
 * This is the line-finding problem in one function, and it is what the mode is
 * actually about. Too little edge and you miss wide; too much and you wash out
 * and lose everything you had.
 */
export function gateSolution(
  board: BoardSpec, s: RideState, gate: Gate, riderX: number, riderZ: number,
): { edgeDeg: number; feasible: boolean; note: string } {
  const dx = gate.x - riderX;
  const dz = Math.max(0.5, gate.z - riderZ);
  // Radius of the circle through the rider that reaches the gate.
  const required = (dx * dx + dz * dz) / (2 * Math.abs(dx) || 0.001);

  const edge = edgeForRadius(board, required, s.speed);
  if (edge === null) {
    return {
      edgeDeg: 80, feasible: false,
      note: `too fast to make that gate — needs a ${required.toFixed(0)}m arc at ${s.speed.toFixed(0)}m/s`,
    };
  }
  return { edgeDeg: edge, feasible: true, note: `${edge}° of edge makes it clean` };
}

/** One coaching line after a run. */
export function carveCoaching(stats: {
  skidSec: number; carveSec: number; gatesMissed: number; topSpeed: number;
}): string | null {
  const total = stats.skidSec + stats.carveSec;
  if (total < 8) return null;
  if (stats.skidSec / total > 0.4) {
    return 'You are skidding through the turns, and a skid dumps speed. Set the edge earlier and let the board come round.';
  }
  if (stats.gatesMissed > 2 && stats.skidSec / total < 0.15) {
    return 'Clean edges, but you are carrying too much speed into the turn. Start it higher on the hill.';
  }
  if (stats.carveSec / total > 0.75) {
    return 'That was carved almost the whole way down. That is the line.';
  }
  return null;
}
