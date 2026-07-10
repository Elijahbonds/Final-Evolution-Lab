/**
 * DanceAvatar — richer 2D dancer for Nexus Dance Mode (web-demo scope).
 *
 * A pure, presentational SVG stick/silhouette figure that keys off the active
 * clip name and the current beat value. Deliberately 2D — NO 3D rig, no external
 * libs — matching the web-demo scope constraint. Colors inherit the Dance Mode
 * theme via var(--dm-cyan)/var(--dm-purple), so drop it inside a .dm-root subtree.
 *
 *   <DanceAvatar clip="Two-Step" beat={12.3} playing pose={optional} />
 *
 * Props (all optional):
 *   clip     — active clip name; one of the SAMPLE_CLIPS names, or null (idle).
 *   beat     — current beat as a float; drives limb phase + backdrop pulse.
 *   playing  — whether playback is running (gates motion/backdrop pulse).
 *   pose     — force a specific pose regardless of clip (overrides clip mapping).
 *   size     — px height of the figure box (default 200).
 *   reactive — optional {lanes:[bool], combo:number} to tint/energize for the
 *              Performance stage (silhouette reacts to lane hits + combo).
 *
 * Everything is derived from `beat` (a deterministic float), so given the same
 * beat/clip the figure draws identically — replay-friendly.
 */
import React from 'react';
import './danceAvatar.css';

/* ── Pose library ───────────────────────────────────────────────────────────
   Each pose is a set of joint angles in DEGREES, measured clockwise from the
   downward vertical for limbs (0 = hanging straight down) and a few scalars for
   torso lean / hips / crouch. `swing` marks limbs the beat should oscillate so
   static pose tables still read as "dancing". Angles are intentionally coarse —
   readability over anatomical accuracy. */
const POSES = {
  idle: {
    lean: 0, crouch: 0, hip: 0,
    armL: 20, armR: -20, foreL: 10, foreR: -10,
    legL: 8, legR: -8, shinL: 4, shinR: -4,
    swing: { armL: 6, armR: 6, lean: 2 },
  },
  step: { // Two-Step: weight shifts side to side, arms pump
    lean: 4, crouch: 6, hip: 8,
    armL: 55, armR: -35, foreL: 40, foreR: -25,
    legL: 22, legR: -14, shinL: 10, shinR: -20,
    swing: { hip: 10, armL: 22, armR: 22, legL: 12, legR: 12 },
  },
  spin: { // Spin: arms out, torso twist (fake 3D via horizontal squash in CSS)
    lean: 0, crouch: 4, hip: 0,
    armL: 95, armR: -95, foreL: 75, foreR: -75,
    legL: 14, legR: -20, shinL: 6, shinR: -30,
    swing: { armL: 8, armR: 8 }, spin: true,
  },
  wave: { // Wave: one arm high & waving, hips relaxed
    lean: -4, crouch: 0, hip: -6,
    armL: 150, armR: -22, foreL: 40, foreR: -14,
    legL: 8, legR: -8, shinL: 4, shinR: -4,
    swing: { foreL: 28, lean: 3 },
  },
  jump: { // Jump: crouch->extend, arms thrown up, whole figure lifts on the beat
    lean: 0, crouch: -8, hip: 0,
    armL: 165, armR: -165, foreL: 12, foreR: -12,
    legL: 18, legR: -18, shinL: 30, shinR: -30,
    swing: { crouch: 6 }, lift: true,
  },
  pose: { // Freeze Pose: sharp asymmetric hold, minimal swing
    lean: 8, crouch: 2, hip: 12,
    armL: 120, armR: -30, foreL: 90, foreR: 60,
    legL: 30, legR: -6, shinL: 12, shinR: -2,
    swing: { lean: 1 },
  },
};

// Map SAMPLE_CLIPS names -> pose keys. Unknown/null clip falls back to idle.
const CLIP_TO_POSE = {
  'Idle Sway': 'idle',
  'Two-Step': 'step',
  'Spin': 'spin',
  'Wave': 'wave',
  'Jump': 'jump',
  'Freeze Pose': 'pose',
};

const DEG = Math.PI / 180;

// Rotate point (x,y) about origin (ox,oy) by `deg` degrees. Used to build limbs
// as chained segments so a forearm follows the upper arm's rotation.
function rot(ox, oy, len, deg) {
  const a = deg * DEG;
  return [ox + Math.sin(a) * len, oy + Math.cos(a) * len];
}

export default function DanceAvatar({
  clip = null,
  beat = 0,
  playing = false,
  pose = null,
  size = 200,
  reactive = null,
}) {
  const poseKey = pose || CLIP_TO_POSE[clip] || 'idle';
  const base = POSES[poseKey] || POSES.idle;

  // Beat phase: a smooth -1..1 oscillator + a 0..1 "downbeat" impulse. When not
  // playing we freeze at phase 0 so the figure holds a clean neutral pose.
  const phase = playing ? Math.sin(beat * Math.PI) : 0;          // -1..1
  const downbeat = playing ? Math.abs(Math.sin(beat * Math.PI)) : 0; // 0..1

  // Apply swing offsets to the base angles for this frame.
  const sw = base.swing || {};
  const a = {};
  for (const k of Object.keys(base)) {
    if (typeof base[k] === 'number') a[k] = base[k] + (sw[k] ? sw[k] * phase : 0);
  }
  a.lean = (base.lean || 0) + (sw.lean ? sw.lean * phase : 0);
  a.crouch = (base.crouch || 0) + (sw.crouch ? sw.crouch * downbeat : 0);
  a.hip = (base.hip || 0) + (sw.hip ? sw.hip * phase : 0);

  // Whole-body vertical lift (jump) and horizontal squash (spin fake-3D).
  const lift = base.lift ? -downbeat * 26 : 0;
  const spinScale = base.spin ? 0.55 + 0.45 * Math.abs(Math.cos(beat * Math.PI)) : 1;

  // ── Skeleton geometry in a 100x150 local space (scaled by viewBox) ──
  const cx = 50;
  const hipY = 92 + a.crouch;      // crouch raises/lowers the hips
  const shoulderY = 56 + a.crouch * 0.6;
  const neckY = 48 + a.crouch * 0.6;
  const headY = 34 + a.crouch * 0.6 + a.lean * 0.2;
  const leanX = a.lean * 0.6;       // torso lean shifts head/shoulders sideways

  // Torso as a slightly-leaning line.
  const hipX = cx + a.hip * 0.15;
  const shoulderX = cx + leanX;
  const headX = cx + leanX * 1.6;

  // Arms: upper arm from shoulder, forearm chained off the elbow.
  const upArm = 20, foreArm = 18;
  const [elbowLx, elbowLy] = rot(shoulderX - 8, shoulderY, upArm, a.armL);
  const [handLx, handLy] = rot(elbowLx, elbowLy, foreArm, a.armL + a.foreL);
  const [elbowRx, elbowRy] = rot(shoulderX + 8, shoulderY, upArm, a.armR);
  const [handRx, handRy] = rot(elbowRx, elbowRy, foreArm, a.armR + a.foreR);

  // Legs: thigh from hip, shin chained off the knee.
  const thigh = 24, shin = 22;
  const [kneeLx, kneeLy] = rot(hipX - 7, hipY, thigh, a.legL);
  const [footLx, footLy] = rot(kneeLx, kneeLy, shin, a.legL + a.shinL);
  const [kneeRx, kneeRy] = rot(hipX + 7, hipY, thigh, a.legR);
  const [footRx, footRy] = rot(kneeRx, kneeRy, shin, a.legR + a.shinR);

  // Backdrop pulse intensity (bigger on downbeat; boosted by combo in reactive).
  const comboBoost = reactive ? Math.min(1, (reactive.combo || 0) / 40) : 0;
  const pulse = playing ? 0.35 + downbeat * 0.65 + comboBoost * 0.4 : 0.15;
  const activeLanes = reactive ? (reactive.lanes || []).filter(Boolean).length : 0;

  return (
    <div
      className={`da-wrap ${playing ? 'is-playing' : ''} ${base.spin ? 'is-spin' : ''}`}
      style={{ '--da-pulse': pulse.toFixed(3), height: size, width: size * 0.75 }}
      role="img"
      aria-label={`Dance avatar${clip ? `, ${clip}` : ', idle'}`}
    >
      {/* Beat-reactive glow backdrop — scales/fades with the pulse variable. */}
      <div className="da-backdrop" aria-hidden="true">
        <span className="da-ring da-ring-1" />
        <span className="da-ring da-ring-2" />
      </div>

      <svg
        className="da-svg"
        viewBox="0 0 100 150"
        preserveAspectRatio="xMidYMid meet"
        aria-hidden="true"
        style={{
          transform: `translateY(${lift}px) scaleX(${spinScale.toFixed(3)})`,
        }}
      >
        <defs>
          <linearGradient id="da-limb" x1="0" y1="0" x2="1" y2="1">
            <stop offset="0%" stopColor="var(--dm-cyan)" />
            <stop offset="100%" stopColor="var(--dm-purple)" />
          </linearGradient>
          <radialGradient id="da-head" cx="40%" cy="35%" r="70%">
            <stop offset="0%" stopColor="var(--dm-cyan)" />
            <stop offset="100%" stopColor="var(--dm-purple)" />
          </radialGradient>
        </defs>

        {/* Ground shadow — squashes as the figure lifts. */}
        <ellipse
          cx={cx} cy={140} rx={22 - lift * 0.4} ry={4}
          fill="var(--dm-purple)" opacity={0.18 + downbeat * 0.12}
        />

        {/* Limbs as a single stroked group so the gradient reads consistently. */}
        <g
          stroke="url(#da-limb)"
          strokeWidth="6"
          strokeLinecap="round"
          strokeLinejoin="round"
          fill="none"
          className="da-figure"
        >
          {/* Legs */}
          <polyline points={`${hipX - 7},${hipY} ${kneeLx},${kneeLy} ${footLx},${footLy}`} />
          <polyline points={`${hipX + 7},${hipY} ${kneeRx},${kneeRy} ${footRx},${footRy}`} />
          {/* Torso */}
          <line x1={hipX} y1={hipY} x2={shoulderX} y2={shoulderY} strokeWidth="7" />
          {/* Arms */}
          <polyline points={`${shoulderX - 8},${shoulderY} ${elbowLx},${elbowLy} ${handLx},${handLy}`} />
          <polyline points={`${shoulderX + 8},${shoulderY} ${elbowRx},${elbowRy} ${handRx},${handRy}`} />
          {/* Shoulders + neck */}
          <line x1={shoulderX - 8} y1={shoulderY} x2={shoulderX + 8} y2={shoulderY} />
          <line x1={shoulderX} y1={shoulderY} x2={headX} y2={neckY} strokeWidth="5" />
        </g>

        {/* Head */}
        <circle cx={headX} cy={headY} r="10" fill="url(#da-head)" />
        {/* Hands as beat-lit dots (brighten on the downbeat) */}
        <circle cx={handLx} cy={handLy} r="3.2" fill="var(--dm-cyan)" opacity={0.5 + downbeat * 0.5} />
        <circle cx={handRx} cy={handRy} r="3.2" fill="var(--dm-cyan)" opacity={0.5 + downbeat * 0.5} />
      </svg>

      {/* Reactive lane sparks (Performance mode only) */}
      {reactive && activeLanes > 0 && (
        <div className="da-sparks" aria-hidden="true">
          {(reactive.lanes || []).map((on, i) =>
            on ? <span key={i} className="da-spark" style={{ left: `${15 + i * 23}%` }} /> : null
          )}
        </div>
      )}
    </div>
  );
}
