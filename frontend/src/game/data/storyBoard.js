/**
 * Story board data — ported verbatim from the C++ donor spec
 * (app/gameplay story_mode.h: kBoardSpaces + kZoneBosses).
 * 20 spaces looping the expanded Venice Beach court across 5 zones.
 */

export const SpaceType = Object.freeze({
  CARNIVAL: 'carnival',   // shard bonus + extra roll
  RAIL: 'rail',           // grind bonus (v1: score bonus; full rail section later)
  FLIGHT: 'flight',       // flight bonus (v1: score bonus; full flight section later)
  BOSS: 'boss',           // boss fight in this zone
  BONUS: 'bonus',         // flat shard bonus
  OBSTACLE: 'obstacle',   // HP damage
});

export const Zone = Object.freeze({
  BOARDWALK: 'boardwalk',
  COURT_FLOOR: 'courtFloor',
  SKATE_APRON: 'skateApron',
  BEACH_ACCESS: 'beachAccess',
  ROOFTOP_ROW: 'rooftopRow',
});

/** { type, pos:{x,y,z}, zone, bonus } — donor values, do not retune casually */
export const BOARD_SPACES = [
  // Boardwalk (0–4)
  { type: SpaceType.CARNIVAL, pos: { x: 0, y: 0, z: -9 }, zone: Zone.BOARDWALK, bonus: 20 },
  { type: SpaceType.RAIL, pos: { x: -6, y: 1.2, z: -9.5 }, zone: Zone.BOARDWALK, bonus: 15 },
  { type: SpaceType.BONUS, pos: { x: -12, y: 0, z: -6 }, zone: Zone.BOARDWALK, bonus: 30 },
  { type: SpaceType.RAIL, pos: { x: -12, y: 1.2, z: 0 }, zone: Zone.BOARDWALK, bonus: 15 },
  { type: SpaceType.OBSTACLE, pos: { x: -12, y: 0, z: 6 }, zone: Zone.BOARDWALK, bonus: 10 },
  // Court Floor (5–8)
  { type: SpaceType.CARNIVAL, pos: { x: 0, y: 0, z: 7.8 }, zone: Zone.COURT_FLOOR, bonus: 20 },
  { type: SpaceType.BOSS, pos: { x: 0, y: 0, z: 0 }, zone: Zone.COURT_FLOOR, bonus: 0 },
  { type: SpaceType.BONUS, pos: { x: 7.8, y: 0, z: 0 }, zone: Zone.COURT_FLOOR, bonus: 25 },
  { type: SpaceType.OBSTACLE, pos: { x: 7.8, y: 0, z: -7.5 }, zone: Zone.COURT_FLOOR, bonus: 15 },
  // Skate Apron (9–12)
  { type: SpaceType.RAIL, pos: { x: 8.5, y: 0, z: -4 }, zone: Zone.SKATE_APRON, bonus: 15 },
  { type: SpaceType.FLIGHT, pos: { x: 8.5, y: 0.6, z: 4.5 }, zone: Zone.SKATE_APRON, bonus: 20 },
  { type: SpaceType.BOSS, pos: { x: 0, y: 0, z: 8 }, zone: Zone.SKATE_APRON, bonus: 0 },
  { type: SpaceType.BONUS, pos: { x: -8.5, y: 0, z: 4.5 }, zone: Zone.SKATE_APRON, bonus: 25 },
  // Beach Access (13–16)
  { type: SpaceType.FLIGHT, pos: { x: -9.5, y: 0, z: 8.5 }, zone: Zone.BEACH_ACCESS, bonus: 20 },
  { type: SpaceType.CARNIVAL, pos: { x: -6, y: 0, z: 11 }, zone: Zone.BEACH_ACCESS, bonus: 20 },
  { type: SpaceType.BOSS, pos: { x: 0, y: 0, z: 12 }, zone: Zone.BEACH_ACCESS, bonus: 0 },
  { type: SpaceType.OBSTACLE, pos: { x: 6, y: 0, z: 11 }, zone: Zone.BEACH_ACCESS, bonus: 12 },
  // Rooftop Row (17–19)
  { type: SpaceType.RAIL, pos: { x: 6, y: 5.5, z: 0 }, zone: Zone.ROOFTOP_ROW, bonus: 15 },
  { type: SpaceType.FLIGHT, pos: { x: 0, y: 6.5, z: 0 }, zone: Zone.ROOFTOP_ROW, bonus: 25 },
  { type: SpaceType.BOSS, pos: { x: -6, y: 5.5, z: 0 }, zone: Zone.ROOFTOP_ROW, bonus: 0 },
];

/** Donor kZoneBosses (boardwalk entry unused — no boss tile in that zone). */
export const ZONE_BOSSES = {
  [Zone.COURT_FLOOR]: { name: 'The Lockdown', maxHp: 80, aggression: 0.8, shard: 'shard_lockdown_key' },
  [Zone.SKATE_APRON]: { name: 'Grind King', maxHp: 70, aggression: 0.75, shard: 'shard_grind_crown' },
  [Zone.BEACH_ACCESS]: { name: 'Sunset Sentinel', maxHp: 90, aggression: 0.85, shard: 'shard_sunset_seal' },
  [Zone.ROOFTOP_ROW]: { name: 'The Architect', maxHp: 120, aggression: 0.95, shard: 'shard_architect_core', final: true },
};

export const SPACE_COLORS = {
  [SpaceType.CARNIVAL]: '#F2A65A',
  [SpaceType.RAIL]: '#7FB5D6',
  [SpaceType.FLIGHT]: '#B48BD8',
  [SpaceType.BOSS]: '#C94C4C',
  [SpaceType.BONUS]: '#8FD68A',
  [SpaceType.OBSTACLE]: '#6E6E7E',
};
