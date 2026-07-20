// M32 shared types + tuning tables (single edit point).

// ── Mastery ─────────────────────────────────────────────────────────────────
export type MasteryTier = 'none' | 'bronze' | 'silver' | 'gold' | 'platinum' | 'legend';

export const MASTERY_THRESHOLDS: [MasteryTier, number][] = [
  ['bronze', 500], ['silver', 2500], ['gold', 8000], ['platinum', 20000], ['legend', 50000],
];

export interface ModeMastery {
  modeId: string;
  points: number;              // cumulative session scores (server-accrued)
  tier: MasteryTier;
}

export function tierFor(points: number): MasteryTier {
  let tier: MasteryTier = 'none';
  for (const [t, at] of MASTERY_THRESHOLDS) if (points >= at) tier = t;
  return tier;
}

// ── Daily contracts ─────────────────────────────────────────────────────────
export interface ContractDef {
  id: string;
  label: string;
  /** SessionResult stat key it watches, optionally scoped to a mode. */
  statKey: string;
  modeId?: string;
  target: number;
  rewardCoins: number;
  rewardSeasonXp: number;
}

/** Pool the daily rotation draws from (seeded by date — same 3 for everyone). */
export const CONTRACT_POOL: ContractDef[] = [
  { id: 'c_evade', label: 'Evade 10 defenders', statKey: 'evaded', modeId: 'football', target: 10, rewardCoins: 120, rewardSeasonXp: 150 },
  { id: 'c_eastbay', label: 'Land 2 signature dunks', statKey: 'sigDunks', modeId: 'dunk', target: 2, rewardCoins: 150, rewardSeasonXp: 180 },
  { id: 'c_kos', label: 'Score 12 KOs in the dojo', statKey: 'kos', modeId: 'karate', target: 12, rewardCoins: 120, rewardSeasonXp: 150 },
  { id: 'c_coins', label: 'Collect 40 coins on any course', statKey: 'coinsCollected', target: 40, rewardCoins: 100, rewardSeasonXp: 120 },
  { id: 'c_combo', label: 'Hold a 10+ combo on a board', statKey: 'combo', target: 10, rewardCoins: 130, rewardSeasonXp: 160 },
  { id: 'c_hits', label: 'Hit 5 clean returns in tennis', statKey: 'hits', modeId: 'tennis', target: 5, rewardCoins: 100, rewardSeasonXp: 120 },
  { id: 'c_yards', label: 'Rush for 60 total yards', statKey: 'yards', modeId: 'football', target: 60, rewardCoins: 120, rewardSeasonXp: 150 },
  { id: 'c_waves', label: 'Clear 4 dojo waves', statKey: 'wave', modeId: 'karate', target: 4, rewardCoins: 110, rewardSeasonXp: 140 },
  { id: 'c_sessions', label: 'Finish 3 sessions in any modes', statKey: '_sessions', target: 3, rewardCoins: 90, rewardSeasonXp: 110 },
];

export interface DailyContractState {
  contractId: string;
  progress: number;
  target: number;
  claimed: boolean;
}

// ── King of the Court ───────────────────────────────────────────────────────
export interface KotcTier { defense: number; speedMul: number; accuracyMul: number; note: string }
export const KOTC_ESCALATION: KotcTier[] = [
  { defense: 1, speedMul: 1.00, accuracyMul: 1.00, note: 'locals' },
  { defense: 2, speedMul: 1.06, accuracyMul: 1.05, note: 'regulars' },
  { defense: 3, speedMul: 1.12, accuracyMul: 1.12, note: 'hoopers' },
  { defense: 4, speedMul: 1.18, accuracyMul: 1.18, note: 'problems' },
  { defense: 5, speedMul: 1.25, accuracyMul: 1.25, note: 'legends' },  // clamps after
];
export const KOTC_CROWN_STREAK = 5;
export const KOTC_CROWN_MASTERY_BONUS = 500;

// ── Rivalry ladder ──────────────────────────────────────────────────────────
export interface Rival {
  id: string;
  name: string;
  tagline: string;
  /** applied to the existing 1v1 AI profile */
  profile: { speed: number; shotAccuracy: number; stealAggression: number; blockRate: number };
  signatureMoveId: string;       // unlocked for the PLAYER on defeat
  signatureMoveLabel: string;
  winLine: string;               // rival wins
  lossLine: string;              // rival loses
}

export const RIVALS: Rival[] = [
  { id: 'r1', name: 'Swift', tagline: 'First step you never see', profile: { speed: 1.05, shotAccuracy: 0.48, stealAggression: 0.3, blockRate: 0.1 }, signatureMoveId: 'move_hesi_burst', signatureMoveLabel: 'Hesi Burst', winLine: 'Blink and it’s over. Run it back when your feet wake up.', lossLine: 'Okay… you can move. Tell the next one I said good luck.' },
  { id: 'r2', name: 'Brick Wall', tagline: 'Nothing easy at the rim', profile: { speed: 0.95, shotAccuracy: 0.5, stealAggression: 0.2, blockRate: 0.35 }, signatureMoveId: 'move_chase_block', signatureMoveLabel: 'Chasedown Block', winLine: 'The rim is closed. Come back with a jumper.', lossLine: 'You went THROUGH me. Respect. Take the block — you earned it.' },
  { id: 'r3', name: 'Rainmaker', tagline: 'Water from thirty feet', profile: { speed: 0.98, shotAccuracy: 0.62, stealAggression: 0.25, blockRate: 0.12 }, signatureMoveId: 'move_deep_range', signatureMoveLabel: 'Deep Range', winLine: 'Splash. Count it and count your losses.', lossLine: 'You out-shot ME? Fine. The range is yours.' },
  { id: 'r4', name: 'Pickpocket', tagline: 'Your handle is my handle', profile: { speed: 1.02, shotAccuracy: 0.55, stealAggression: 0.5, blockRate: 0.15 }, signatureMoveId: 'move_strip_steal', signatureMoveLabel: 'Strip Steal', winLine: 'I had that ball before you did.', lossLine: 'Couldn’t touch it. Couldn’t TOUCH it. Take the pick.' },
  { id: 'r5', name: 'The Closer', tagline: 'Owns the last three points', profile: { speed: 1.08, shotAccuracy: 0.66, stealAggression: 0.4, blockRate: 0.25 }, signatureMoveId: 'move_clutch_gene', signatureMoveLabel: 'Clutch Gene', winLine: 'Game. That’s why they call me the Closer.', lossLine: 'You closed ME. The ladder’s yours — wear it well.' },
];

// ── SKATE vs ghost ──────────────────────────────────────────────────────────
export interface GhostTrick {
  trickId: string;               // 'skate_kickflip'…
  atMs: number;
  scoreValue: number;
  /** feature it was landed on, for match validation */
  featureId?: string;
}
export interface GhostRun {
  id: string;
  ownerId: string;
  modeId: string;                // 'skateboard'
  tricks: GhostTrick[];
  inputStream?: string;          // compressed input log for full replay
  createdAt: string;
}
export type SkateLetters = '' | 'S' | 'SK' | 'SKA' | 'SKAT' | 'SKATE';
export const NEXT_LETTER: Record<SkateLetters, SkateLetters> =
  { '': 'S', S: 'SK', SK: 'SKA', SKA: 'SKAT', SKAT: 'SKATE', SKATE: 'SKATE' };
