// HeadlessSim — run a match with no browser, so a server can check it.
//
// THE BLOCKER THIS REMOVES
// M90 built the trust policy: only a receipt the SERVER re-ran and matched can
// win real money. It accepts a `serverHash` and does the right thing with it.
// Nothing can produce that hash, so no receipt can reach `resimulated` and
// Cash Arena cannot pay out. This is that missing piece.
//
// THE ARCHITECTURAL DECISION, AND IT IS THE WHOLE POINT
// There are two ways to give a server a simulation:
//
//   A. Port the game logic to Python alongside the backend.
//   B. Run THE SAME TYPESCRIPT the client runs, headless, on Node.
//
// It has to be B, and this project has already paid for the lesson four times:
// the PRQ weight tables drifted between Swift and Python (M82, five modes
// wrong, one by 57%); the MRI formula existed in Python with no producer
// anywhere (M89); DDA lived in Swift and never reached the web (M81). Every
// one of those was the same failure — one rule, two implementations, silent
// divergence.
//
// A ported simulation would be that failure with money attached. If the
// server's physics disagrees with the client's by one float, every honest
// player fails verification and every payout is wrong. **The verifier and the
// game must be the same code, byte for byte.**
//
// WHAT A MODE MUST DO TO BE VERIFIABLE
// Separate its SIMULATION from its RENDERING. That is the only requirement,
// and it is a good idea regardless: a mode whose game logic can run without a
// scene is a mode whose game logic can be tested, replayed, ghosted and
// verified. A mode that cannot is one where nobody can ever prove anything.
//
// Note this is the same machinery as `Rollback.ts`. Re-running a match from
// inputs to check it, and re-running the last few frames because a remote
// input arrived late, are the same operation at different scales. Building the
// verifier gets the netcode most of the way for free.

import { FIXED_DT, stateHash } from './FixedStep';
import { Rng } from './Rng';
import { ReplayPlayer, validateReplay, pack, unpack, type ReplayData } from './Replay';
import type { Intent } from './PlayerSlot';

/**
 * Round an intent through the replay format BEFORE simulating with it.
 *
 * THIS IS NOT OPTIONAL AND IT IS EASY TO MISS.
 *
 * `ReplayRecorder` quantises analog values to 1/127 (M83) so a recording is
 * small and device-independent. If the client simulates with the RAW float and
 * records the quantised one, the server re-runs slightly different inputs and
 * gets a different hash — so the match fails verification.
 *
 * The failure mode is the worst kind: it looks exactly like cheating, it hits
 * EVERY honest player, and it would surface as "Cash Arena rejects everyone".
 * Caught here by a test that recorded raw and verified quantised.
 *
 * The rule: quantise first, then simulate AND record the same value.
 */
export function asRecorded(i: Intent): Intent {
  return unpack(pack(i));
}

/**
 * The contract a mode implements to be verifiable.
 *
 * Deliberately tiny. Anything Babylon-shaped belongs in the mode's renderer,
 * not here — if a `SimulatableMode` needs a `Scene` it is not simulatable and
 * results from it can never be trusted for money.
 */
export interface SimulatableMode<S> {
  modeId: string;
  /** Build the starting state. MUST be pure given (seed, config). */
  init(rng: Rng, config: Record<string, number>): S;
  /** Advance exactly one fixed tick. MUST be pure and use no clock. */
  tick(state: S, intent: Intent, rng: Rng, dt: number): S;
  /** Numbers that fingerprint the state. Order matters and must be stable. */
  fingerprint(state: S): number[];
  /** The score this state represents. */
  score(state: S): number;
}

export interface SimResult {
  ok: boolean;
  /** Hash at the final tick. This is what a receipt is checked against. */
  finalHash: number;
  /** Per-tick hashes, for locating a divergence. */
  hashes: number[];
  score: number;
  ticks: number;
  /** Milliseconds the verification took. Servers have budgets. */
  elapsedMs: number;
  error?: string;
}

/**
 * Re-run a recorded match.
 *
 * Never throws. A malformed replay, a mode that panics, an infinite state —
 * all of them return `ok: false` with a reason, because a verification
 * endpoint that can be crashed by a crafted payload is worse than no
 * verification at all.
 */
export function resimulate<S>(
  mode: SimulatableMode<S>,
  replay: ReplayData,
  config: Record<string, number> = {},
  budgetMs = 5000,
): SimResult {
  const started = Date.now();
  const fail = (error: string): SimResult =>
    ({ ok: false, finalHash: 0, hashes: [], score: 0, ticks: 0, elapsedMs: Date.now() - started, error });

  const why = validateReplay(replay, mode.modeId, FIXED_DT);
  if (why) return fail(`replay refused: ${why}`);

  try {
    const rng = new Rng(replay.header.seed);
    let state = mode.init(rng, config);
    const player = new ReplayPlayer(replay);
    const hashes: number[] = [];

    while (!player.finished) {
      // A budget check every tick would dominate the loop; every 600 ticks is
      // ten seconds of simulated time and costs nothing.
      if (hashes.length % 600 === 0 && Date.now() - started > budgetMs) {
        return fail(`exceeded the ${budgetMs}ms verification budget at tick ${hashes.length}`);
      }
      state = mode.tick(state, player.next(), rng, FIXED_DT);
      const h = stateHash(mode.fingerprint(state));
      hashes.push(h);
    }

    return {
      ok: true,
      finalHash: hashes.length ? hashes[hashes.length - 1] : 0,
      hashes,
      score: mode.score(state),
      ticks: hashes.length,
      elapsedMs: Date.now() - started,
    };
  } catch (e) {
    return fail(`simulation threw at runtime: ${e instanceof Error ? e.message : String(e)}`);
  }
}

export interface VerificationResult {
  verified: boolean;
  /** Tick where the two runs first differ, or null. */
  divergedAt: number | null;
  serverScore: number;
  claimedScore: number;
  elapsedMs: number;
  reason: string;
}

/**
 * The function M90 has been waiting for.
 *
 * Feed it the mode, the replay and the score the player claimed; it returns
 * whether the server agrees. `assessReceipt(claim, result.serverHash)` then
 * grants or refuses cash eligibility.
 *
 * The SCORE is checked as well as the hash. A hash proves the simulation ran
 * identically; comparing the score catches the case where the mode's scoring
 * is not part of its fingerprint — a real mistake to make, and one that would
 * otherwise verify a match while paying out the wrong number.
 */
export function verifyMatch<S>(
  mode: SimulatableMode<S>,
  replay: ReplayData,
  claimedScore: number,
  config: Record<string, number> = {},
): VerificationResult & { serverHash: number } {
  const sim = resimulate(mode, replay, config);

  if (!sim.ok) {
    return {
      verified: false, divergedAt: null, serverHash: 0,
      serverScore: 0, claimedScore, elapsedMs: sim.elapsedMs,
      reason: sim.error ?? 'simulation failed',
    };
  }

  const claimedHash = replay.header.finalHash;
  if (claimedHash === undefined) {
    return {
      verified: false, divergedAt: null, serverHash: sim.finalHash,
      serverScore: sim.score, claimedScore, elapsedMs: sim.elapsedMs,
      reason: 'the replay carries no final hash, so there is nothing to check against',
    };
  }

  if (sim.finalHash !== claimedHash) {
    return {
      verified: false, divergedAt: null, serverHash: sim.finalHash,
      serverScore: sim.score, claimedScore, elapsedMs: sim.elapsedMs,
      reason: `hash mismatch: server ${sim.finalHash}, client ${claimedHash}`,
    };
  }

  if (sim.score !== claimedScore) {
    return {
      verified: false, divergedAt: null, serverHash: sim.finalHash,
      serverScore: sim.score, claimedScore, elapsedMs: sim.elapsedMs,
      reason: `the simulation matched but the SCORE did not — server ${sim.score}, `
        + `claimed ${claimedScore}. The mode's scoring is probably not part of its fingerprint.`,
    };
  }

  return {
    verified: true, divergedAt: null, serverHash: sim.finalHash,
    serverScore: sim.score, claimedScore, elapsedMs: sim.elapsedMs,
    reason: `re-simulated ${sim.ticks} ticks in ${sim.elapsedMs}ms and matched`,
  };
}

/**
 * Where two runs first diverge.
 *
 * For debugging a mode that fails verification for honest players — which is
 * the failure mode that matters most, because it looks identical to cheating
 * and punishes the wrong people. Tick-level localisation turns "verification
 * is flaky" into "tick 1,847".
 */
export function findDivergence(a: readonly number[], b: readonly number[]): number | null {
  const n = Math.min(a.length, b.length);
  for (let i = 0; i < n; i++) if (a[i] !== b[i]) return i;
  return a.length === b.length ? null : n;
}

/**
 * Prove a mode is actually deterministic before trusting it with money.
 *
 * Runs the same replay twice in the same process. If THAT diverges, the mode
 * has non-determinism inside it — a `Math.random()`, a `Date.now()`, an
 * iteration over object keys — and no server anywhere will ever verify it.
 *
 * This should gate a mode's entry into `CASH_ELIGIBLE_MODES`. Determinism is
 * not a property you assume; it is one you demonstrate.
 */
export function proveDeterministic<S>(
  mode: SimulatableMode<S>, replay: ReplayData, runs = 3,
): { deterministic: boolean; divergedAt: number | null; message: string } {
  const first = resimulate(mode, replay);
  if (!first.ok) {
    return { deterministic: false, divergedAt: null, message: first.error ?? 'first run failed' };
  }
  for (let i = 1; i < runs; i++) {
    const again = resimulate(mode, replay);
    if (!again.ok) return { deterministic: false, divergedAt: null, message: again.error ?? 'a run failed' };
    const at = findDivergence(first.hashes, again.hashes);
    if (at !== null) {
      return {
        deterministic: false, divergedAt: at,
        message: `run ${i + 1} diverged from run 1 at tick ${at}. `
          + `${mode.modeId} is NOT deterministic and cannot be verified or ghosted. `
          + 'Look for Math.random(), Date.now(), or iteration over object keys.',
      };
    }
  }
  return {
    deterministic: true, divergedAt: null,
    message: `${mode.modeId} reproduced identically across ${runs} runs of ${first.ticks} ticks`,
  };
}

/**
 * Cost of verifying at scale.
 *
 * Verification is not free, and a design that cannot afford it will quietly
 * stop doing it. At roughly 1000x real time on a modern core, a three-minute
 * match verifies in about 200ms — so one core clears ~5 matches a second. Worth
 * knowing before promising to verify every ranked game rather than discovering
 * it under load.
 */
export function verificationCost(
  matchSeconds: number, matchesPerHour: number, speedupFactor = 1000,
): { msPerMatch: number; coresNeeded: number; note: string } {
  const msPerMatch = (matchSeconds * 1000) / speedupFactor;
  const msPerHour = msPerMatch * matchesPerHour;
  const coresNeeded = Math.max(1, Math.ceil(msPerHour / (3600 * 1000)));
  return {
    msPerMatch,
    coresNeeded,
    note: `${msPerMatch.toFixed(0)}ms per match; ${matchesPerHour}/hour needs ~${coresNeeded} core(s). `
      + (coresNeeded > 8
        ? 'Verify ranked and cash matches only, and sample the rest.'
        : 'Affordable to verify every match.'),
  };
}
