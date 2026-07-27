// ReceiptIntegrity — what makes a score believable.
//
// THE GAP, STATED PRECISELY
// `backend/app/schemas/session_receipt.py` says:
//
//     "Economy fields are recomputed server-side; the client never supplies
//      rewards."
//
// That is TRUE, and it is not the same as integrity. The client never supplies
// XP or shards — but it does supply `score`, `outcome`, `combo_count`,
// `critical_count`, `duration_seconds` and `completed`. The server recomputes
// rewards *from those*.
//
//     POST /api/games/session {"score": 999999, "outcome": "win"}
//
// is a fully-formed, correctly-authenticated, server-computed reward. Nothing
// in the pipeline asks whether that score was possible.
//
// For XP and shards that is a leaderboard problem. For **Cash Dunk Arena**,
// which pays real prize pools, it is the whole product — an arena that cannot
// tell a real result from a POST cannot pay out, and no amount of UI makes
// that acceptable.
//
// WHAT M83 ALREADY GAVE US
// A recorded match is an input stream plus a seed, and a server that replays
// those inputs through the same deterministic simulation gets the same answer
// or catches a lie. `SimLoop.finish()` already stamps a `finalHash`. This file
// is the policy layer on top: how much trust each kind of evidence earns, and
// what each level of trust is allowed to be paid.
//
// THE PRINCIPLE
// Trust is EARNED BY EVIDENCE, not asserted by a flag. And the payout ceiling
// follows the evidence — a session with no evidence still earns XP, because
// refusing to score an ordinary player's ordinary game would be absurd. It
// simply cannot win money.

export type TrustLevel =
  /** No supporting evidence. A plain client claim. */
  | 'unverified'
  /** Passes plausibility bounds for the mode. Still just a claim. */
  | 'plausible'
  /** Carries a replay whose header is internally consistent. */
  | 'attested'
  /** The server re-ran the replay and got the same hash. */
  | 'resimulated';

export const TRUST_ORDER: TrustLevel[] = ['unverified', 'plausible', 'attested', 'resimulated'];

export function atLeast(actual: TrustLevel, required: TrustLevel): boolean {
  return TRUST_ORDER.indexOf(actual) >= TRUST_ORDER.indexOf(required);
}

/**
 * What each trust level may be paid.
 *
 * The important row is the last one. Real money requires the server to have
 * re-run the match itself — not a signature, not a checksum, not a
 * "verified" boolean the client set. Anything less is trusting the thing you
 * are trying to verify.
 */
export interface PayoutPolicy {
  xp: boolean;
  shards: boolean;
  prq: boolean;
  leaderboard: boolean;
  /** Ranked ladder placement. */
  ranked: boolean;
  /** Real-money prize pools. */
  cashArena: boolean;
}

export const PAYOUT_BY_TRUST: Record<TrustLevel, PayoutPolicy> = {
  unverified:  { xp: true, shards: false, prq: false, leaderboard: false, ranked: false, cashArena: false },
  plausible:   { xp: true, shards: true,  prq: true,  leaderboard: false, ranked: false, cashArena: false },
  attested:    { xp: true, shards: true,  prq: true,  leaderboard: true,  ranked: true,  cashArena: false },
  resimulated: { xp: true, shards: true,  prq: true,  leaderboard: true,  ranked: true,  cashArena: true },
};

/**
 * Per-mode plausibility envelope.
 *
 * NOT anti-cheat — a determined cheat submits a plausible score. This catches
 * the lazy 99% and, more usefully, catches OUR OWN BUGS: a scoring change that
 * makes 40,000 points reachable in a 30-second dunk run shows up here first.
 * Treating it as a bug detector rather than a security boundary is the honest
 * framing, and it is why exceeding it is a flag rather than a rejection.
 */
export interface ModeBounds {
  /** Highest defensible score per second of play. */
  maxScorePerSec: number;
  /** Ceiling regardless of duration. */
  absoluteMax: number;
  /** Shortest session that can be a real completed game. */
  minDurationSec: number;
  /** Longest before it is a session someone walked away from. */
  maxDurationSec: number;
  maxCombo: number;
}

const DEFAULT_BOUNDS: ModeBounds = {
  maxScorePerSec: 40, absoluteMax: 20000, minDurationSec: 5, maxDurationSec: 3600, maxCombo: 100,
};

export const MODE_BOUNDS: Record<string, ModeBounds> = {
  dunk:        { maxScorePerSec: 12, absoluteMax: 400,  minDurationSec: 20, maxDurationSec: 900,  maxCombo: 20 },
  dunkduel:    { maxScorePerSec: 12, absoluteMax: 400,  minDurationSec: 20, maxDurationSec: 900,  maxCombo: 20 },
  onevone:     { maxScorePerSec: 1,  absoluteMax: 21,   minDurationSec: 30, maxDurationSec: 1800, maxCombo: 12 },
  threevthree: { maxScorePerSec: 1,  absoluteMax: 21,   minDurationSec: 45, maxDurationSec: 1800, maxCombo: 12 },
  karate:      { maxScorePerSec: 20, absoluteMax: 9999, minDurationSec: 15, maxDurationSec: 1800, maxCombo: 60 },
  'karate-vs': { maxScorePerSec: 2,  absoluteMax: 10,   minDurationSec: 20, maxDurationSec: 600,  maxCombo: 40 },
  football:    { maxScorePerSec: 30, absoluteMax: 5000, minDurationSec: 20, maxDurationSec: 600,  maxCombo: 30 },
  skateboard:  { maxScorePerSec: 90, absoluteMax: 60000, minDurationSec: 20, maxDurationSec: 600, maxCombo: 40 },
  snowboard:   { maxScorePerSec: 60, absoluteMax: 40000, minDurationSec: 20, maxDurationSec: 600, maxCombo: 30 },
  surf:        { maxScorePerSec: 45, absoluteMax: 30000, minDurationSec: 15, maxDurationSec: 600, maxCombo: 25 },
  brain_brawl: { maxScorePerSec: 8,  absoluteMax: 500,  minDurationSec: 20, maxDurationSec: 900,  maxCombo: 20 },
  who_scene_it:{ maxScorePerSec: 8,  absoluteMax: 500,  minDurationSec: 20, maxDurationSec: 900,  maxCombo: 20 },
  irl:         { maxScorePerSec: 6,  absoluteMax: 200,  minDurationSec: 10, maxDurationSec: 600,  maxCombo: 10 },
  market_browse:{ maxScorePerSec: 0, absoluteMax: 0,    minDurationSec: 0,  maxDurationSec: 7200, maxCombo: 0 },
};

export function boundsFor(modeId: string): ModeBounds {
  return MODE_BOUNDS[modeId] ?? DEFAULT_BOUNDS;
}

export interface ClaimedReceipt {
  modeId: string;
  score: number;
  outcome: 'win' | 'draw' | 'loss';
  durationSeconds: number;
  completed: boolean;
  comboCount: number;
  criticalCount: number;
  /** Present when the client recorded the match (M83 SimLoop). */
  replay?: {
    seed: number;
    totalTicks: number;
    dt: number;
    finalHash?: number;
    /** Score the recording itself claims. */
    score: number;
  };
}

export interface IntegrityVerdict {
  trust: TrustLevel;
  /** Every reason the claim fell short. Empty at 'resimulated'. */
  flags: string[];
  payout: PayoutPolicy;
  /** One line for a moderation queue. */
  summary: string;
}

/**
 * Check a claim against its mode's envelope.
 *
 * Returns reasons, not a boolean, because "score too high" and "duration
 * impossible" want different follow-ups — and because a list of specific
 * reasons is reviewable by a human where a rejected flag is not.
 */
export function plausibilityFlags(r: ClaimedReceipt): string[] {
  const b = boundsFor(r.modeId);
  const flags: string[] = [];

  if (r.score < 0) flags.push('negative score');
  if (r.score > b.absoluteMax) {
    flags.push(`score ${r.score} exceeds the ceiling of ${b.absoluteMax} for ${r.modeId}`);
  }
  if (r.durationSeconds > 0 && r.score / r.durationSeconds > b.maxScorePerSec) {
    flags.push(`${(r.score / r.durationSeconds).toFixed(1)} points/sec exceeds `
      + `${b.maxScorePerSec} for ${r.modeId}`);
  }
  if (r.durationSeconds < b.minDurationSec && r.completed) {
    flags.push(`${r.durationSeconds}s is shorter than a completed ${r.modeId} session (${b.minDurationSec}s)`);
  }
  if (r.durationSeconds > b.maxDurationSec) {
    flags.push(`${r.durationSeconds}s exceeds the ${b.maxDurationSec}s session cap`);
  }
  if (r.comboCount > b.maxCombo) {
    flags.push(`combo ${r.comboCount} exceeds ${b.maxCombo}`);
  }
  if (r.criticalCount > r.comboCount + 10) {
    flags.push('critical count is disproportionate to combo count');
  }
  // Zero-duration completed sessions: the classic replay-a-POST signature.
  if (r.completed && r.durationSeconds === 0 && r.score > 0) {
    flags.push('a completed session of zero duration scored points');
  }
  return flags;
}

/** Internal consistency of an attached replay. Cheap; no simulation. */
export function replayFlags(r: ClaimedReceipt): string[] {
  const rep = r.replay;
  if (!rep) return ['no replay attached'];
  const flags: string[] = [];

  if (!Number.isFinite(rep.seed)) flags.push('replay has no seed');
  if (rep.totalTicks <= 0) flags.push('replay has no ticks');
  if (rep.dt <= 0) flags.push('replay has no timestep');

  // The recording's own duration must match the claim. This is the cheapest
  // real check available and it catches a claim stapled to somebody else's
  // replay.
  const replaySec = rep.totalTicks * rep.dt;
  if (Math.abs(replaySec - r.durationSeconds) > Math.max(3, r.durationSeconds * 0.1)) {
    flags.push(`replay covers ${replaySec.toFixed(0)}s but the claim says ${r.durationSeconds}s`);
  }
  if (rep.score !== r.score) {
    flags.push(`replay scored ${rep.score}, the claim says ${r.score}`);
  }
  if (rep.finalHash === undefined) flags.push('replay carries no final state hash');
  return flags;
}

/**
 * Assess a claim.
 *
 * `resimulated` is only ever reached by the SERVER passing
 * `serverHash` — a value it computed by re-running the replay itself. There is
 * deliberately no way for a client to reach the top level: the highest trust in
 * the system cannot be claimed, only earned by someone else doing the work.
 */
export function assessReceipt(r: ClaimedReceipt, serverHash?: number): IntegrityVerdict {
  const pFlags = plausibilityFlags(r);
  const rFlags = replayFlags(r);

  let trust: TrustLevel = 'unverified';
  if (pFlags.length === 0) trust = 'plausible';
  if (pFlags.length === 0 && rFlags.length === 0) trust = 'attested';
  if (
    trust === 'attested'
    && serverHash !== undefined
    && r.replay?.finalHash !== undefined
    && serverHash === r.replay.finalHash
  ) {
    trust = 'resimulated';
  }

  const flags = trust === 'resimulated' ? [] : [...pFlags, ...rFlags];
  if (
    serverHash !== undefined
    && r.replay?.finalHash !== undefined
    && serverHash !== r.replay.finalHash
  ) {
    // The most serious result in the file: the match did not happen as claimed.
    return {
      trust: 'unverified',
      flags: [`RE-SIMULATION MISMATCH: server ${serverHash} vs claimed ${r.replay.finalHash}`, ...pFlags],
      payout: PAYOUT_BY_TRUST.unverified,
      summary: 'The server replayed this match and got a different result. The claim is false.',
    };
  }

  return {
    trust,
    flags,
    payout: PAYOUT_BY_TRUST[trust],
    summary: summarise(trust, flags),
  };
}

function summarise(trust: TrustLevel, flags: string[]): string {
  switch (trust) {
    case 'resimulated': return 'Re-simulated by the server and matched. Eligible for prize pools.';
    case 'attested': return 'Replay attached and internally consistent. Ranked eligible; not cash eligible until re-simulated.';
    case 'plausible': return `Within the mode's envelope but unwitnessed. ${flags.length} note(s). Earns shards and PRQ, not leaderboard.`;
    default: return `Not credible: ${flags[0] ?? 'unknown'}. Earns XP only.`;
  }
}

/**
 * Whether a mode may be entered for real money at all.
 *
 * Deliberately narrow. Cash Arena should launch on the modes where a replay is
 * an exact reproduction — M83's `GHOST_FIDELITY` calls those 'exact', which is
 * the same property re-simulation needs. Continuous mutual-reaction modes
 * (1v1, karate) are excluded not because they are unfair but because
 * verification is harder there, and money should follow verification rather
 * than lead it.
 */
export const CASH_ELIGIBLE_MODES = [
  'dunk', 'dunkduel', 'skateboard', 'snowboard', 'surf', 'golf', 'irl', 'gymnastics',
];

export function cashEligible(modeId: string, verdict: IntegrityVerdict): { allowed: boolean; reason: string } {
  if (!CASH_ELIGIBLE_MODES.includes(modeId)) {
    return { allowed: false, reason: `${modeId} results cannot be re-simulated exactly enough for a prize pool` };
  }
  if (!verdict.payout.cashArena) {
    return { allowed: false, reason: `trust level "${verdict.trust}" — the server has not re-run this match` };
  }
  return { allowed: true, reason: 'server re-simulated and matched' };
}
