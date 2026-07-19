// Retargeter: the athlete's own PoseFrame timeline → a canonical-rig animation clip.
// Powers the "your scan" replay — their real movement, on their mini avatar, playable
// side-by-side with the target-form exercise clip.
//
// Approach: per frame, build direction vectors for each bone segment from world
// landmarks, convert to quaternion rotations relative to the canonical rig's rest
// pose directions. Deliberately simple swing-only retarget (no twist solve) — right
// for stylized mini-avatars; do not add IK polish here.

import type { PoseFrame, RetargetedFrame, ScanReplayClip } from './contracts';

const LM = {
  L_SHOULDER: 11, R_SHOULDER: 12, L_ELBOW: 13, R_ELBOW: 14,
  L_WRIST: 15, R_WRIST: 16, L_HIP: 23, R_HIP: 24,
  L_KNEE: 25, R_KNEE: 26, L_ANKLE: 27, R_ANKLE: 28,
} as const;

type V3 = [number, number, number];
type Q4 = [number, number, number, number];

const sub = (a: V3, b: V3): V3 => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const norm = (a: V3): V3 => {
  const l = Math.hypot(a[0], a[1], a[2]) || 1e-9;
  return [a[0] / l, a[1] / l, a[2] / l];
};
const cross = (a: V3, b: V3): V3 => [
  a[1] * b[2] - a[2] * b[1],
  a[2] * b[0] - a[0] * b[2],
  a[0] * b[1] - a[1] * b[0],
];
const dot = (a: V3, b: V3) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];

/** Quaternion rotating unit vector `from` onto unit vector `to` (shortest arc). */
function quatFromTo(from: V3, to: V3): Q4 {
  const d = dot(from, to);
  if (d > 0.9999) return [0, 0, 0, 1];
  if (d < -0.9999) {
    // 180° — pick any orthogonal axis
    const axis = norm(Math.abs(from[0]) < 0.9 ? cross(from, [1, 0, 0]) : cross(from, [0, 1, 0]));
    return [axis[0], axis[1], axis[2], 0];
  }
  const axis = cross(from, to);
  const q: Q4 = [axis[0], axis[1], axis[2], 1 + d];
  const l = Math.hypot(...q) || 1e-9;
  return [q[0] / l, q[1] / l, q[2] / l, q[3] / l];
}

/**
 * Canonical rig rest-pose direction per bone (Mixamo A-pose approximated as:
 * spine up, arms down-out ~15°, legs down). Bone rotates its rest direction onto
 * the measured segment direction each frame.
 */
const REST: Record<string, { a: keyof typeof LM; b: keyof typeof LM; rest: V3 }> = {
  'mixamorig:LeftArm':     { a: 'L_SHOULDER', b: 'L_ELBOW', rest: norm([ 0.26, -0.96, 0]) },
  'mixamorig:RightArm':    { a: 'R_SHOULDER', b: 'R_ELBOW', rest: norm([-0.26, -0.96, 0]) },
  'mixamorig:LeftForeArm': { a: 'L_ELBOW',    b: 'L_WRIST', rest: norm([ 0.26, -0.96, 0]) },
  'mixamorig:RightForeArm':{ a: 'R_ELBOW',    b: 'R_WRIST', rest: norm([-0.26, -0.96, 0]) },
  'mixamorig:LeftUpLeg':   { a: 'L_HIP',      b: 'L_KNEE',  rest: [0, -1, 0] },
  'mixamorig:RightUpLeg':  { a: 'R_HIP',      b: 'R_KNEE',  rest: [0, -1, 0] },
  'mixamorig:LeftLeg':     { a: 'L_KNEE',     b: 'L_ANKLE', rest: [0, -1, 0] },
  'mixamorig:RightLeg':    { a: 'R_KNEE',     b: 'R_ANKLE', rest: [0, -1, 0] },
};

function lm(f: PoseFrame, key: keyof typeof LM): V3 {
  const l = f.landmarks[LM[key]];
  // MediaPipe world: x right, y DOWN, z toward camera → engine: y UP, z forward
  return [l.x, -l.y, -l.z];
}

function retargetFrame(f: PoseFrame): RetargetedFrame {
  const rotations: Record<string, Q4> = {};

  // Spine from hip-mid → shoulder-mid
  const hipMid: V3 = norm(sub(lm(f, 'L_HIP'), lm(f, 'R_HIP'))).map((_, i) =>
    (lm(f, 'L_HIP')[i] + lm(f, 'R_HIP')[i]) / 2) as V3;
  const shMid: V3 = [0, 1, 2].map((i) =>
    (lm(f, 'L_SHOULDER')[i] + lm(f, 'R_SHOULDER')[i]) / 2) as V3;
  rotations['mixamorig:Spine'] = quatFromTo([0, 1, 0], norm(sub(shMid, hipMid)));

  // Hips yaw from pelvis line (L→R hip), rest = +X
  const pelvis = norm(sub(lm(f, 'R_HIP'), lm(f, 'L_HIP')));
  rotations['mixamorig:Hips'] = quatFromTo([1, 0, 0], pelvis);

  for (const [bone, def] of Object.entries(REST)) {
    const dir = norm(sub(lm(f, def.b), lm(f, def.a)));
    rotations[bone] = quatFromTo(def.rest, dir);
  }

  return { tMs: f.tMs, rotations, rootPos: hipMid };
}

/** Simple quaternion slerp-free smoothing: EMA on components + renormalize. */
function smooth(frames: RetargetedFrame[], alpha = 0.35): RetargetedFrame[] {
  for (let i = 1; i < frames.length; i++) {
    for (const bone of Object.keys(frames[i].rotations)) {
      const prev = frames[i - 1].rotations[bone];
      const cur = frames[i].rotations[bone];
      if (!prev) continue;
      // Hemisphere check so EMA doesn't blend across the double-cover
      const sign = prev[0]*cur[0] + prev[1]*cur[1] + prev[2]*cur[2] + prev[3]*cur[3] < 0 ? -1 : 1;
      const q = cur.map((c, k) => alpha * c * sign + (1 - alpha) * prev[k]) as Q4;
      const l = Math.hypot(...q) || 1e-9;
      frames[i].rotations[bone] = [q[0]/l, q[1]/l, q[2]/l, q[3]/l];
    }
  }
  return frames;
}

export function retargetScan(scanId: string, frames: PoseFrame[]): ScanReplayClip {
  const usable = frames.filter(
    (f) => f.landmarks.reduce((s, l) => s + l.visibility, 0) / f.landmarks.length > 0.5,
  );
  return {
    scanId,
    clipName: `scan.${scanId}`,
    frames: smooth(usable.map(retargetFrame)),
  };
}
