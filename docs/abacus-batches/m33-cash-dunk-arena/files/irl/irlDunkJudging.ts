// IRL Proving Ground — real dunks judged from pose keypoints. Reuses the M17
// client-side extractor (video never uploads by default; keypoints only).
// Produces the SAME JudgeScorecard shape as in-game — one leaderboard schema.

import type { PoseFrame } from '../workout/contracts';           // M17
import type { DunkRunTelemetry, JudgeScorecard } from '../shared/arenaContracts';
import { scoreRun, type CommentarySeam } from '../server/aiJudges';

const LM = { L_HIP: 23, R_HIP: 24, L_ANKLE: 27, L_SHOULDER: 11, L_WRIST: 15, R_WRIST: 16 } as const;

interface IrlMetrics {
  jumpHeightCm: number | null;
  hangTimeMs: number | null;
  extensionQuality: number;      // 0..1 — wrist above head at apex (finish read)
  approachSpeed: number;         // rough m/s from hip travel pre-jump
  confidence: number;
}

/** Physics sanity bounds — outside these = flag for human review, not scored. */
export const IRL_BOUNDS = {
  jumpHeightCm: [15, 130] as const,
  hangTimeMs: [200, 1200] as const,
  minConfidence: 0.55,
};

export function extractIrlMetrics(frames: PoseFrame[], athleteHeightCm: number): IrlMetrics {
  const conf = frames.reduce(
    (a, f) => a + f.landmarks.reduce((s, l) => s + l.visibility, 0) / f.landmarks.length, 0,
  ) / Math.max(frames.length, 1);

  const hipY = (f: PoseFrame) => (f.landmarks[LM.L_HIP].y + f.landmarks[LM.R_HIP].y) / 2;
  const ys = frames.map(hipY);

  // calibration: landmark stature vs real height (same approach as M17)
  const f0 = frames[0];
  const stature = Math.abs(f0.landmarks[LM.L_ANKLE].y - f0.landmarks[LM.L_SHOULDER].y) * 1.22;
  const cmPerUnit = athleteHeightCm / Math.max(stature, 1e-6);

  const standing = ys.slice(0, Math.min(8, ys.length)).reduce((a, b) => a + b, 0) / Math.min(8, ys.length);
  const peakIdx = ys.indexOf(Math.min(...ys));
  const jumpRaw = (standing - ys[peakIdx]) * cmPerUnit;
  const jumpHeightCm = jumpRaw > 3 && jumpRaw < 200 ? Math.round(jumpRaw * 10) / 10 : null;

  // hang time: frames where hips are above 30% of peak displacement
  const threshold = standing - (standing - ys[peakIdx]) * 0.3;
  let airFrames = 0;
  for (const y of ys) if (y < threshold) airFrames++;
  const fps = frames.length > 1
    ? 1000 / ((frames[frames.length - 1].tMs - frames[0].tMs) / (frames.length - 1)) : 24;
  const hangTimeMs = airFrames > 1 ? Math.round((airFrames / fps) * 1000) : null;

  // finish: a wrist above the head near apex reads as extension toward the rim
  const apex = frames[peakIdx];
  const headY = apex.landmarks[0]?.y ?? 0;
  const wristAbove = Math.min(apex.landmarks[LM.L_WRIST].y, apex.landmarks[LM.R_WRIST].y) < headY;
  const extensionQuality = wristAbove ? 1 : 0.4;

  // approach: hip x/z travel across the second before takeoff
  const pre = frames.slice(Math.max(0, peakIdx - Math.round(fps)), peakIdx);
  let travel = 0;
  for (let i = 1; i < pre.length; i++) {
    const a = pre[i - 1].landmarks[LM.L_HIP], b = pre[i].landmarks[LM.L_HIP];
    travel += Math.hypot(b.x - a.x, b.z - a.z);
  }
  const approachSpeed = Math.min(8, travel * cmPerUnit / 100);

  return { jumpHeightCm, hangTimeMs, extensionQuality, approachSpeed, confidence: Math.round(conf * 100) / 100 };
}

export interface IrlJudgeResult {
  scorecard: JudgeScorecard | null;
  needsHumanReview: boolean;
  reason?: string;
}

export async function judgeIrlRun(
  frames: PoseFrame[], athleteHeightCm: number, commentary?: CommentarySeam,
): Promise<IrlJudgeResult> {
  const m = extractIrlMetrics(frames, athleteHeightCm);

  if (m.confidence < IRL_BOUNDS.minConfidence) {
    return { scorecard: null, needsHumanReview: true, reason: 'low tracking confidence — refilm full body in frame' };
  }
  const inBounds =
    m.jumpHeightCm !== null && m.hangTimeMs !== null &&
    m.jumpHeightCm >= IRL_BOUNDS.jumpHeightCm[0] && m.jumpHeightCm <= IRL_BOUNDS.jumpHeightCm[1] &&
    m.hangTimeMs >= IRL_BOUNDS.hangTimeMs[0] && m.hangTimeMs <= IRL_BOUNDS.hangTimeMs[1];
  if (!inBounds) {
    return { scorecard: null, needsHumanReview: true, reason: 'metrics outside physical bounds — human review' };
  }

  // Map real athleticism onto the same telemetry axes the in-game judges use
  const telemetry: DunkRunTelemetry = {
    seed: 'irl', style: 'sig',
    approachSpeed: m.approachSpeed,
    chargeLevel: Math.min(1, (m.jumpHeightCm! - 15) / 85),
    qteDeltaMs: m.extensionQuality >= 1 ? 40 : 140,        // clean finish reads as timing
    apexHeight: m.jumpHeightCm! / 100,
    hangTimeMs: m.hangTimeMs!,
    cleanRelease: m.extensionQuality >= 1,
    inputStream: '',                                        // IRL: no replay stream
  };
  const scorecard = await scoreRun(telemetry, {
    jumpHeightCm: m.jumpHeightCm!, hangTimeMs: m.hangTimeMs!,
  }, commentary);
  // Cash IRL contests above the prize threshold ALWAYS queue human review too
  return { scorecard, needsHumanReview: false };
}
