// Movement screen analyzer: PoseFrame timeline → MovementMetrics + ranked deficits.
// Isomorphic (no DOM) — runs client-side for instant feedback AND server-side for
// the authoritative result stored with the plan.

import type {
  PoseFrame, Landmark, MovementMetrics, ScreenResult, Deficit, ScanSubmission,
} from './contracts';

// MediaPipe BlazePose landmark indices
const LM = {
  L_SHOULDER: 11, R_SHOULDER: 12, L_HIP: 23, R_HIP: 24,
  L_KNEE: 25, R_KNEE: 26, L_ANKLE: 27, R_ANKLE: 28,
  L_HEEL: 29, R_HEEL: 30, L_TOE: 31, R_TOE: 32,
} as const;

const deg = (rad: number) => (rad * 180) / Math.PI;
const v = (a: Landmark, b: Landmark) => ({ x: b.x - a.x, y: b.y - a.y, z: b.z - a.z });
const len = (a: { x: number; y: number; z: number }) => Math.hypot(a.x, a.y, a.z);

/** Interior angle at joint b for chain a-b-c, degrees. */
function jointAngle(a: Landmark, b: Landmark, c: Landmark): number {
  const u = v(b, a), w = v(b, c);
  const cos = (u.x * w.x + u.y * w.y + u.z * w.z) / (len(u) * len(w) + 1e-9);
  return deg(Math.acos(Math.min(1, Math.max(-1, cos))));
}

function hipMidY(f: PoseFrame): number {
  return (f.landmarks[LM.L_HIP].y + f.landmarks[LM.R_HIP].y) / 2;
}

/** Smallest knee angle over the trial (deep squat position). */
function minKneeAngle(frames: PoseFrame[]): { angle: number; frameIdx: number } {
  let best = 180, idx = 0;
  frames.forEach((f, i) => {
    const l = jointAngle(f.landmarks[LM.L_HIP], f.landmarks[LM.L_KNEE], f.landmarks[LM.L_ANKLE]);
    const r = jointAngle(f.landmarks[LM.R_HIP], f.landmarks[LM.R_KNEE], f.landmarks[LM.R_ANKLE]);
    const a = Math.min(l, r);
    if (a < best) { best = a; idx = i; }
  });
  return { angle: best, frameIdx: idx };
}

/** Frontal-plane knee collapse at max load: knee X drift inside the ankle-hip line. */
function kneeValgus(f: PoseFrame): number {
  const worst = (hip: number, knee: number, ankle: number) => {
    const H = f.landmarks[hip], K = f.landmarks[knee], A = f.landmarks[ankle];
    // Angle between thigh (hip→knee) and shank (knee→ankle) projected to frontal plane
    const thigh = Math.atan2(K.x - H.x, H.y - K.y);
    const shank = Math.atan2(A.x - K.x, K.y - A.y);
    return Math.abs(deg(thigh - shank));
  };
  return Math.max(
    worst(LM.L_HIP, LM.L_KNEE, LM.L_ANKLE),
    worst(LM.R_HIP, LM.R_KNEE, LM.R_ANKLE),
  );
}

/**
 * Jump height from hip-center flight displacement, scaled to real meters via the
 * athlete's entered height (world landmarks are hip-relative, so we calibrate with
 * measured skeleton height in landmark space vs. actual cm).
 */
function jumpHeightCm(frames: PoseFrame[], athleteHeightCm: number): number | null {
  if (frames.length < 10) return null;
  // Landmark-space stature: ankle→shoulder span in a standing frame (first frame)
  const f0 = frames[0];
  const stature =
    Math.abs(f0.landmarks[LM.L_ANKLE].y - f0.landmarks[LM.L_SHOULDER].y) * 1.22; // + head est.
  const scale = athleteHeightCm / Math.max(stature, 1e-6);        // cm per landmark unit
  const ys = frames.map(hipMidY);
  const standing = ys.slice(0, Math.min(8, ys.length)).reduce((a, b) => a + b) / Math.min(8, ys.length);
  const peak = Math.min(...ys);                                    // y decreases upward in world space? — MediaPipe world y is up-negative; peak = min
  const raw = (standing - peak) * scale;
  return raw > 3 && raw < 130 ? Math.round(raw * 10) / 10 : null;  // sanity bounds
}

/** Cadence (steps/min) from alternating ankle-Y oscillation while running. */
function cadenceSpm(frames: PoseFrame[]): number | null {
  if (frames.length < 24) return null;
  const ys = frames.map((f) => f.landmarks[LM.L_ANKLE].y);
  let crossings = 0;
  const mean = ys.reduce((a, b) => a + b) / ys.length;
  for (let i = 1; i < ys.length; i++)
    if ((ys[i - 1] - mean) * (ys[i] - mean) < 0) crossings++;
  const durS = (frames[frames.length - 1].tMs - frames[0].tMs) / 1000;
  const strideHz = crossings / 2 / durS;                           // L-ankle cycles
  const spm = Math.round(strideHz * 2 * 60);                       // both legs
  return spm >= 120 && spm <= 220 ? spm : null;
}

/** L/R loading asymmetry from mean knee flexion difference under load. */
function asymmetryPct(frames: PoseFrame[]): number | null {
  if (!frames.length) return null;
  let l = 0, r = 0;
  for (const f of frames) {
    l += jointAngle(f.landmarks[LM.L_HIP], f.landmarks[LM.L_KNEE], f.landmarks[LM.L_ANKLE]);
    r += jointAngle(f.landmarks[LM.R_HIP], f.landmarks[LM.R_KNEE], f.landmarks[LM.R_ANKLE]);
  }
  const diff = Math.abs(l - r) / frames.length;
  return Math.round(Math.min(100, (diff / 15) * 100));            // 15° mean diff ≡ 100%
}

function trunkLeanDeg(f: PoseFrame): number {
  const sh = f.landmarks[LM.L_SHOULDER], hip = f.landmarks[LM.L_HIP];
  return Math.abs(deg(Math.atan2(sh.z - hip.z, hip.y - sh.y)));
}

export function analyze(sub: ScanSubmission): ScreenResult {
  const { frames } = sub;
  const confidence =
    frames.reduce((a, f) => a + f.landmarks.reduce((s, l) => s + l.visibility, 0) / f.landmarks.length, 0) /
    Math.max(frames.length, 1);

  const squat = minKneeAngle(frames);
  const loaded = frames[squat.frameIdx];

  const metrics: MovementMetrics = {
    jumpHeightCm: ['jump', 'dunk', 'stress_test'].includes(sub.activity) || sub.kind === 'stress_test'
      ? jumpHeightCm(frames, sub.athleteHeightCm) : null,
    squatDepthDeg: squat.angle < 175 ? Math.round(squat.angle) : null,
    kneeValgusDeg: loaded ? Math.round(kneeValgus(loaded)) : null,
    hipHingeRatio: null, // reserved for hinge-specific screens
    asymmetryPct: asymmetryPct(frames),
    cadenceSpm: sub.activity === 'run' ? cadenceSpm(frames) : null,
    groundContactMs: null, // requires >60 fps capture; not derivable at 24 Hz
    trunkLeanDeg: loaded ? Math.round(trunkLeanDeg(loaded)) : null,
    confidence: Math.round(confidence * 100) / 100,
  };

  // ── Deficit ranking (thresholds = conventional screening cutoffs) ──
  const deficits: Deficit[] = [];
  const strengths: Deficit[] = [];
  const m = metrics;
  if (m.squatDepthDeg !== null) (m.squatDepthDeg > 100 ? deficits : strengths).push('hip_mobility');
  if (m.kneeValgusDeg !== null) (m.kneeValgusDeg > 12 ? deficits : strengths).push('knee_stability');
  if (m.asymmetryPct !== null) (m.asymmetryPct > 25 ? deficits : strengths).push('symmetry');
  if (m.trunkLeanDeg !== null) (m.trunkLeanDeg > 35 ? deficits : strengths).push('trunk_control');
  if (m.cadenceSpm !== null) (m.cadenceSpm < 160 ? deficits : strengths).push('sprint_mechanics');
  if (m.jumpHeightCm !== null) (m.jumpHeightCm < 35 ? deficits : strengths).push('reactive_power');
  if (!deficits.length) deficits.push('elastic_stiffness');       // always give the plan a focus

  const summary =
    `Screen confidence ${(confidence * 100) | 0}%. ` +
    (m.jumpHeightCm ? `Jump ${m.jumpHeightCm} cm. ` : '') +
    (m.squatDepthDeg ? `Depth ${m.squatDepthDeg}° knee. ` : '') +
    (m.kneeValgusDeg ? `Valgus ${m.kneeValgusDeg}°. ` : '') +
    (m.asymmetryPct !== null ? `Asymmetry ${m.asymmetryPct}%. ` : '') +
    `Primary focus: ${deficits.slice(0, 2).join(', ').replace(/_/g, ' ')}.`;

  return { scanId: sub.scanId, metrics, deficits: deficits.slice(0, 4), strengths, summary };
}
