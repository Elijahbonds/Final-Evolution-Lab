// PoseProbe — answers "why am I T-posing?" from the live build.
//
// I have guessed at this cause twice and been wrong once. M64 fixed the idle
// (`solveArmsDown`) and the live console confirms `restPose solved` on every
// load — so the idle is NOT the remaining cause, and I am not going to guess
// a third time. This measures it instead.
//
// WHAT A T-POSE ACTUALLY IS, MEASURABLY
// Bind pose on this rig is arms-out: the shoulder→hand vector is roughly
// horizontal. Any pose a human reads as "normal standing" has that vector
// pointing substantially downward. So the arm's angle from straight-down is a
// direct, single-number T-pose detector — no clip names, no guessing, no
// dependence on which mode is running.
//
//   0°   arms hanging at the sides
//   90°  arms straight out — T-pose
//
// The probe watches that number and, when it stays high, prints WHAT WAS
// PLAYING at that moment. That distinguishes the three causes that all look
// identical on screen and need completely different fixes:
//
//   1. nothing is playing            → the mode never started a clip
//   2. a clip is playing but is thin → the clip's keys barely leave bind
//   3. a clip is playing and bound   → real animation; something else is wrong
//
// Gated on `?probe=1` so it costs nothing in normal play.

import type { AnimationGroup, Scene, Skeleton, Vector3 } from '@babylonjs/core';

/** How far from straight-down counts as "arm is out". */
const T_POSE_DEGREES = 55;
/** How long it must persist before reporting — a jumping jack is not a bug. */
const T_POSE_SECONDS = 2.5;
/** Sample rate. 6/sec is plenty and keeps the probe off the hot path. */
const SAMPLE_MS = 166;

export interface PoseSample {
  /** Degrees from straight-down, averaged across both arms. 90 = T-pose. */
  armSpread: number;
  /** Names of animation groups currently playing. */
  playing: string[];
  /** How many bones the playing groups actually target. */
  boundBones: number;
}

/**
 * Angle in DEGREES between the shoulder→hand vector and straight down.
 *
 * Pure math, deliberately: it takes plain {x,y,z} so it can be tested without
 * a Babylon scene, and so the number in a bug report can be reproduced.
 */
export function armSpreadDegrees(
  shoulder: { x: number; y: number; z: number },
  hand: { x: number; y: number; z: number },
): number {
  const dx = hand.x - shoulder.x;
  const dy = hand.y - shoulder.y;
  const dz = hand.z - shoulder.z;
  const len = Math.hypot(dx, dy, dz);
  if (len < 1e-6) return 0;
  // dot with (0,-1,0) is just -dy
  const cos = Math.min(1, Math.max(-1, -dy / len));
  return (Math.acos(cos) * 180) / Math.PI;
}

/**
 * Classify a sustained high-spread reading into an actionable cause.
 *
 * Returns null when there is nothing wrong, so the caller can `if (msg)`.
 */
export function diagnose(s: PoseSample): string | null {
  if (s.armSpread < T_POSE_DEGREES) return null;

  const deg = s.armSpread.toFixed(0);
  if (s.playing.length === 0) {
    return `T-POSE (arms ${deg}° from down) and NO animation group is playing. `
      + 'The mode never started a clip — this is a mode-logic bug, not an animation bug. '
      + 'Check that the mode calls neverBindPose()/play("idle_stand") after load().';
  }
  if (s.boundBones === 0) {
    return `T-POSE (arms ${deg}°). "${s.playing.join(', ')}" is playing but targets ZERO bones. `
      + 'The clip loaded and resolved nothing — almost always prefixed bone names. '
      + 'Run tools/clip_check.mjs on the source file.';
  }
  return `T-POSE (arms ${deg}°) while "${s.playing.join(', ')}" is playing across `
    + `${s.boundBones} bone(s). The clip IS driving the skeleton, so its KEYS are the problem: `
    + 'the authored angles sit too close to the arms-out bind pose. '
    + 'This clip needs real animation data, not a tuning pass.';
}

/** Read one sample from a live skeleton. */
export function sample(skeleton: Skeleton, scene: Scene): PoseSample {
  const posOf = (bone: string): Vector3 | null => {
    const b = skeleton.bones.find((x) => x.name === bone);
    if (!b) return null;
    const n = b.getTransformNode();
    if (n) { n.computeWorldMatrix(true); return n.getAbsolutePosition(); }
    return b.getAbsolutePosition() ?? null;
  };

  const spreads: number[] = [];
  for (const [sh, hand] of [['LeftArm', 'LeftHand'], ['RightArm', 'RightHand']] as const) {
    const a = posOf(sh); const b = posOf(hand);
    if (a && b) spreads.push(armSpreadDegrees(a, b));
  }

  const playing = scene.animationGroups.filter((g) => g.isPlaying);
  return {
    armSpread: spreads.length ? spreads.reduce((x, y) => x + y, 0) / spreads.length : 0,
    playing: playing.map((g: AnimationGroup) => g.name),
    boundBones: playing.reduce((n, g) => n + g.targetedAnimations.length, 0),
  };
}

/**
 * Start watching. Returns a stop function.
 *
 * Reports at most once per distinct cause per mode — a probe that prints
 * every 166ms is a probe nobody reads.
 */
export function attachPoseProbe(scene: Scene, skeleton: Skeleton, modeId = 'unknown'): () => void {
  if (typeof window !== 'undefined'
      && !new URLSearchParams(window.location.search).has('probe')) {
    return () => {};
  }

  let held = 0;
  let lastReport = '';
  const timer = setInterval(() => {
    const s = sample(skeleton, scene);
    if (s.armSpread < T_POSE_DEGREES) { held = 0; return; }
    held += SAMPLE_MS / 1000;
    if (held < T_POSE_SECONDS) return;

    const msg = diagnose(s);
    if (msg && msg !== lastReport) {
      lastReport = msg;
      console.warn(`[FEL-POSE] ${modeId}: ${msg}`);
    }
  }, SAMPLE_MS);

  console.info(`[FEL-POSE] probe attached to ${modeId} `
    + `(T-pose = arms >${T_POSE_DEGREES}° from down for >${T_POSE_SECONDS}s)`);
  return () => clearInterval(timer);
}

/**
 * One-shot report for the agent bridge and the smoke test.
 *
 * The smoke test currently proves a mode reaches `playing`. It cannot see a
 * character standing in a T-pose the whole time, which is precisely the bug
 * that has survived every green run. This makes that visible to automation.
 */
export function poseReport(scene: Scene, skeleton: Skeleton): PoseSample & { verdict: string } {
  const s = sample(skeleton, scene);
  return { ...s, verdict: diagnose(s) ?? 'ok' };
}
