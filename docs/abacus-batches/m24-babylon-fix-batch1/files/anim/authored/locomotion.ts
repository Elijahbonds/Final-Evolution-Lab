// Locomotion fills: idle breathe, strafes, jump/land.

import type { Scene, Skeleton, AnimationGroup } from '@babylonjs/core';
import { buildClip } from '../clipBuilder';

export function buildIdleStand(scene: Scene, sk: Skeleton): AnimationGroup | null {
  return buildClip(scene, sk, 'idle_stand', 3.0, {
    Spine: [[0, 2, 0, 0], [1.5, 4.5, 0, 0], [3, 2, 0, 0]],
    Neck: [[0, 0, 0, 0], [1.5, 2, 3, 0], [3, 0, 0, 0]],
    LeftArm: [[0, 8, 0, 6], [1.5, 10, 0, 7], [3, 8, 0, 6]],
    RightArm: [[0, 8, 0, -6], [1.5, 10, 0, -7], [3, 8, 0, -6]],
  }, [[0, 0], [1.5, -0.012], [3, 0]]);
}

export function buildStrafe(scene: Scene, sk: Skeleton, dir: 'left' | 'right'): AnimationGroup | null {
  const s = dir === 'left' ? 1 : -1;
  return buildClip(scene, sk, `strafe_${dir}`, 0.6, {
    Hips: [[0, 0, 0, 6 * s], [0.3, 0, 0, 10 * s], [0.6, 0, 0, 6 * s]],
    Spine: [[0, 4, 0, -4 * s], [0.3, 6, 0, -6 * s], [0.6, 4, 0, -4 * s]],
    LeftUpLeg: [[0, -12, 0, 8 * s], [0.3, -22, 0, 14 * s], [0.6, -12, 0, 8 * s]],
    RightUpLeg: [[0, -12, 0, 8 * s], [0.3, -4, 0, 2 * s], [0.6, -12, 0, 8 * s]],
    LeftArm: [[0, 12, 0, 8], [0.3, 18, 0, 12], [0.6, 12, 0, 8]],
    RightArm: [[0, 12, 0, -8], [0.3, 18, 0, -12], [0.6, 12, 0, -8]],
  });
}

export function buildJumpUp(scene: Scene, sk: Skeleton): AnimationGroup | null {
  return buildClip(scene, sk, 'jump_up', 0.45, {
    Spine: [[0, 18, 0, 0], [0.2, -8, 0, 0], [0.45, -4, 0, 0]],
    LeftUpLeg: [[0, -45, 0, 6], [0.2, -18, 0, 3], [0.45, -25, 0, 4]],
    LeftLeg: [[0, 65, 0, 0], [0.2, 18, 0, 0], [0.45, 30, 0, 0]],
    RightUpLeg: [[0, -45, 0, -6], [0.2, -18, 0, -3], [0.45, -25, 0, -4]],
    RightLeg: [[0, 65, 0, 0], [0.2, 18, 0, 0], [0.45, 30, 0, 0]],
    LeftArm: [[0, 40, 0, 12], [0.2, -120, 0, 8], [0.45, -100, 0, 8]],
    RightArm: [[0, 40, 0, -12], [0.2, -120, 0, -8], [0.45, -100, 0, -8]],
  }, [[0, -0.18], [0.2, 0.02], [0.45, 0]]);
}

export function buildJumpLand(scene: Scene, sk: Skeleton): AnimationGroup | null {
  return buildClip(scene, sk, 'jump_land', 0.35, {
    Spine: [[0, -4, 0, 0], [0.14, 22, 0, 0], [0.35, 4, 0, 0]],
    LeftUpLeg: [[0, -20, 0, 4], [0.14, -55, 0, 8], [0.35, -12, 0, 4]],
    LeftLeg: [[0, 24, 0, 0], [0.14, 75, 0, 0], [0.35, 16, 0, 0]],
    RightUpLeg: [[0, -20, 0, -4], [0.14, -55, 0, -8], [0.35, -12, 0, -4]],
    RightLeg: [[0, 24, 0, 0], [0.14, 75, 0, 0], [0.35, 16, 0, 0]],
  }, [[0, 0.02], [0.14, -0.2], [0.35, 0]]);
}
