// ballRig — the ball lives in the hands. Uses the character hook's existing
// bone(name) accessor (boneMap is already built in your hook). Ends the
// ball-on-the-floor and invisible-flight bugs.

import { Object3D, Vector3, Quaternion } from 'three';
import { EASTBAY_TIMING as T } from './authoredClips';

const PALM_OFFSET = new Vector3(0, -0.07, 0.1);   // ball center relative to hand bone

/** Parent the ball mesh to a hand bone. Call on possession changes. */
export function attachBall(ball: Object3D, hand: Object3D): void {
  hand.add(ball);
  ball.position.copy(PALM_OFFSET);
  ball.quaternion.identity();
}

/** Detach into world space, preserving transform (for flight/physics). */
export function releaseBall(ball: Object3D, world: Object3D): void {
  const pos = ball.getWorldPosition(new Vector3());
  const rot = ball.getWorldQuaternion(new Quaternion());
  world.add(ball);
  ball.position.copy(pos);
  ball.quaternion.copy(rot);
}

/**
 * Eastbay ball choreography — keyed to the SAME timestamps as the authored
 * dunk_360_eastbay clip. Call every frame with clip-local time t (seconds):
 *   right hand carries → passes under the raised knee → left hand carries to rim.
 * Handles the single re-parent at the hand-off moment.
 */
export function runEastbayPath(
  ball: Object3D,
  bones: { rightHand: Object3D; leftHand: Object3D },
  t: number,
  state: { inLeftHand: boolean },
): void {
  if (t < T.handOff) {
    if (state.inLeftHand) { attachBall(ball, bones.rightHand); state.inLeftHand = false; }
  } else if (!state.inLeftHand) {
    attachBall(ball, bones.leftHand); state.inLeftHand = true;
  }
  // small carry easing so the ball leads the receiving hand slightly at the pass
  const nearPass = Math.max(0, 1 - Math.abs(t - T.handOff) / 0.12);
  ball.position.copy(PALM_OFFSET).addScaledVector(new Vector3(0, -0.05, 0.05), nearPass);
}

/**
 * Flush: from the moment of release, drive the ball through the rim center and
 * down through the net. Returns true when finished. Call with seconds since release.
 */
export function flushThroughRim(
  ball: Object3D, rimCenter: Vector3, releasePos: Vector3, sinceRelease: number,
): boolean {
  const DUR = 0.22;
  const k = Math.min(1, sinceRelease / DUR);
  const ease = 1 - (1 - k) * (1 - k);
  ball.position.lerpVectors(releasePos, rimCenter, ease);
  if (k >= 1) {
    // through the net: straight down 0.6m over 0.25s handled by caller physics or:
    ball.position.y = rimCenter.y - (sinceRelease - DUR) * 2.4;
    return sinceRelease > DUR + 0.25;
  }
  return false;
}

/** Miss: deflect off the rim — visible clank, never a silent disappear. */
export function clankOffRim(
  ball: Object3D, rimCenter: Vector3, velocityOut: Vector3,
): void {
  const away = ball.position.clone().sub(rimCenter).setY(0).normalize();
  velocityOut.set(away.x * 3.2, 2.6, away.z * 3.2);   // caller integrates gravity
}

/**
 * Wiring for the dunk mode (replaces the floor-ball):
 *   const rh = char.bone('RightHand'), lh = char.bone('LeftHand');
 *   on approach/charge: attachBall(ball, rh)
 *   on airborne(style==='360_eastbay'): runEastbayPath(ball, {rightHand: rh, leftHand: lh}, clipTime, st)
 *   at slam QTE success: releaseBall(ball, scene); then flushThroughRim(...) per frame
 *   at miss: releaseBall + clankOffRim, integrate simple gravity
 */
