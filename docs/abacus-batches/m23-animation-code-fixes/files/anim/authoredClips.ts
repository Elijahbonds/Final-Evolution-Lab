// authoredClips — programmatic THREE.AnimationClips for actions the asset lacks.
// Built at runtime against the loaded skeleton's REAL bone names (verified from
// elijah-hero.glb): Hips, Spine, Spine1, Spine2, Neck, Head,
// Left/Right Shoulder-Arm-ForeArm-Hand, Left/Right UpLeg-Leg-Foot-ToeBase.
// Because tracks are named from live bones, name-mismatch cannot happen.
//
// Register AFTER the GLB actions are built:
//   registerAuthoredClips(mixer, actionMap, clipNames);
// Authored clips OVERRIDE aliases in clipResolver automatically (exact-name hits).

import {
  AnimationClip, QuaternionKeyframeTrack, VectorKeyframeTrack,
  Quaternion, Euler, AnimationMixer, AnimationAction,
} from 'three';

type Deg = number;
const q = (x: Deg, y: Deg, z: Deg): number[] => {
  const quat = new Quaternion().setFromEuler(
    new Euler((x * Math.PI) / 180, (y * Math.PI) / 180, (z * Math.PI) / 180),
  );
  return [quat.x, quat.y, quat.z, quat.w];
};

/** One bone's rotation keys: [time, xDeg, yDeg, zDeg][] */
type BoneKeys = Record<string, [number, Deg, Deg, Deg][]>;

function clipFrom(name: string, duration: number, bones: BoneKeys, hipsY?: [number, number][]): AnimationClip {
  const tracks: (QuaternionKeyframeTrack | VectorKeyframeTrack)[] = [];
  for (const [bone, keys] of Object.entries(bones)) {
    const times = keys.map((k) => k[0]);
    const values = keys.flatMap((k) => q(k[1], k[2], k[3]));
    tracks.push(new QuaternionKeyframeTrack(`${bone}.quaternion`, times, values));
  }
  if (hipsY) {
    tracks.push(new VectorKeyframeTrack(
      'Hips.position', hipsY.map((k) => k[0]), hipsY.flatMap((k) => [0, k[1], 0]),
    ));
  }
  return new AnimationClip(name, duration, tracks);
}

// ─────────────────────────────────────────────────────────────────────────────
// THE EASTBAY (dunk_360_eastbay) — the reference dunk. 1.5 s, six beats:
// gather(0.0) → rise+knee up(0.3) → ball hand under knee(0.55) →
// hand-to-hand under the leg(0.75) → off-hand carry up(1.0) →
// one-hand extension to flush(1.25) → hang(1.5).
// ballRig.runEastbayPath() is keyed to these SAME timestamps.
// ─────────────────────────────────────────────────────────────────────────────
export const EASTBAY_TIMING = {
  gather: 0.0, rise: 0.3, underKnee: 0.55, handOff: 0.75,
  carryUp: 1.0, extend: 1.25, hang: 1.5, duration: 1.5,
} as const;

function eastbay(): AnimationClip {
  const T = EASTBAY_TIMING;
  return clipFrom('dunk_360_eastbay', T.duration, {
    Spine:        [[T.gather, 22, 0, 0], [T.rise, 8, 0, 0], [T.underKnee, 18, 6, 0], [T.handOff, 16, -6, 0], [T.carryUp, -6, 0, 0], [T.extend, -14, 0, 0], [T.hang, -8, 0, 0]],
    Spine2:       [[T.gather, 12, 0, 0], [T.rise, 4, 0, 0], [T.underKnee, 10, 8, 0], [T.handOff, 8, -8, 0], [T.carryUp, -6, 0, 0], [T.extend, -10, 0, 0], [T.hang, -6, 0, 0]],
    Neck:         [[T.gather, 10, 0, 0], [T.underKnee, 24, 0, 0], [T.carryUp, -10, 0, 0], [T.extend, -18, 0, 0], [T.hang, -8, 0, 0]],
    // Left knee drives UP and stays up while the ball passes under it
    LeftUpLeg:    [[T.gather, -18, 0, 0], [T.rise, -95, 0, 8], [T.handOff, -100, 0, 8], [T.carryUp, -60, 0, 4], [T.extend, -30, 0, 0], [T.hang, -20, 0, 0]],
    LeftLeg:      [[T.gather, 24, 0, 0], [T.rise, 96, 0, 0], [T.handOff, 100, 0, 0], [T.carryUp, 55, 0, 0], [T.extend, 30, 0, 0], [T.hang, 25, 0, 0]],
    RightUpLeg:   [[T.gather, -20, 0, -4], [T.rise, -20, 0, -6], [T.extend, -12, 0, -4], [T.hang, -16, 0, -4]],
    RightLeg:     [[T.gather, 30, 0, 0], [T.rise, 24, 0, 0], [T.extend, 14, 0, 0], [T.hang, 18, 0, 0]],
    // RIGHT hand takes the ball down under the raised left knee…
    RightShoulder:[[T.gather, 0, 0, 8], [T.underKnee, 4, 0, 30], [T.handOff, 4, 0, 34], [T.carryUp, 0, 0, 10], [T.extend, 0, 0, -6]],
    RightArm:     [[T.gather, 55, 0, -12], [T.rise, 40, 10, -10], [T.underKnee, 78, 30, -35], [T.handOff, 82, 34, -40], [T.carryUp, 20, 0, -10], [T.extend, -35, 0, -8], [T.hang, -20, 0, -8]],
    RightForeArm: [[T.gather, 30, 0, 0], [T.underKnee, 55, 0, 0], [T.handOff, 60, 0, 0], [T.carryUp, 15, 0, 0], [T.extend, 5, 0, 0]],
    // …LEFT hand receives under the knee and carries up to the flush
    LeftShoulder: [[T.gather, 0, 0, -8], [T.underKnee, 4, 0, -26], [T.handOff, 6, 0, -34], [T.carryUp, 0, 0, -12], [T.extend, 0, 0, 6]],
    LeftArm:      [[T.gather, 55, 0, 12], [T.rise, 45, -8, 10], [T.underKnee, 70, -26, 30], [T.handOff, 80, -32, 38], [T.carryUp, -60, 0, 14], [T.extend, -160, 0, 10], [T.hang, -120, 0, 10]],
    LeftForeArm:  [[T.gather, 30, 0, 0], [T.underKnee, 50, 0, 0], [T.handOff, 58, 0, 0], [T.carryUp, 25, 0, 0], [T.extend, 8, 0, 0], [T.hang, 30, 0, 0]],
    Hips:         [[T.gather, 14, 0, 0], [T.rise, 4, 18, 0], [T.handOff, 8, 40, 0], [T.carryUp, -4, 12, 0], [T.extend, -8, 0, 0], [T.hang, -4, 0, 0]],
  });
}

function chargeGather(): AnimationClip {
  return clipFrom('dunk_charge_gather', 0.5, {
    Spine:     [[0, 6, 0, 0], [0.5, 30, 0, 0]],
    LeftUpLeg: [[0, -12, 0, 4], [0.5, -55, 0, 8]],
    LeftLeg:   [[0, 16, 0, 0], [0.5, 80, 0, 0]],
    RightUpLeg:[[0, -12, 0, -4], [0.5, -55, 0, -8]],
    RightLeg:  [[0, 16, 0, 0], [0.5, 80, 0, 0]],
    LeftArm:   [[0, 20, 0, 10], [0.5, 45, 0, 14]],
    RightArm:  [[0, 20, 0, -10], [0.5, 45, 0, -14]],
  }, [[0, 0], [0.5, -0.22]]);
}

function launch(): AnimationClip {
  return clipFrom('dunk_launch', 0.35, {
    Spine:     [[0, 30, 0, 0], [0.35, -10, 0, 0]],
    LeftUpLeg: [[0, -55, 0, 8], [0.35, -20, 0, 4]],
    LeftLeg:   [[0, 80, 0, 0], [0.35, 20, 0, 0]],
    RightUpLeg:[[0, -55, 0, -8], [0.35, -20, 0, -4]],
    RightLeg:  [[0, 80, 0, 0], [0.35, 20, 0, 0]],
    LeftArm:   [[0, 45, 0, 14], [0.35, -140, 0, 10]],
    RightArm:  [[0, 45, 0, -14], [0.35, -140, 0, -10]],
  }, [[0, -0.22], [0.35, 0.05]]);
}

function scoreHang(): AnimationClip {
  return clipFrom('dunk_score_hang', 0.8, {
    LeftArm:   [[0, -160, 0, 10], [0.4, -150, 0, 12], [0.8, -100, 0, 10]],
    LeftForeArm:[[0, 8, 0, 0], [0.4, 25, 0, 0], [0.8, 40, 0, 0]],
    RightArm:  [[0, -30, 0, -10], [0.8, 10, 0, -12]],
    Spine:     [[0, -12, 0, 0], [0.8, 2, 0, 0]],
    LeftUpLeg: [[0, -25, 0, 4], [0.8, -10, 0, 2]],
    RightUpLeg:[[0, -25, 0, -4], [0.8, -10, 0, -2]],
  });
}

function landCrouch(): AnimationClip {
  return clipFrom('dunk_land_crouch', 0.45, {
    Spine:     [[0, 0, 0, 0], [0.18, 26, 0, 0], [0.45, 6, 0, 0]],
    LeftUpLeg: [[0, -10, 0, 4], [0.18, -60, 0, 8], [0.45, -14, 0, 4]],
    LeftLeg:   [[0, 12, 0, 0], [0.18, 85, 0, 0], [0.45, 18, 0, 0]],
    RightUpLeg:[[0, -10, 0, -4], [0.18, -60, 0, -8], [0.45, -14, 0, -4]],
    RightLeg:  [[0, 12, 0, 0], [0.18, 85, 0, 0], [0.45, 18, 0, 0]],
    LeftArm:   [[0, 10, 0, 12], [0.18, 40, 0, 30], [0.45, 15, 0, 12]],
    RightArm:  [[0, 10, 0, -12], [0.18, 40, 0, -30], [0.45, 15, 0, -12]],
  }, [[0, 0.05], [0.18, -0.26], [0.45, 0]]);
}

function idleStand(): AnimationClip {
  return clipFrom('idle_stand', 3.0, {
    Spine:  [[0, 2, 0, 0], [1.5, 4.5, 0, 0], [3, 2, 0, 0]],
    Neck:   [[0, 0, 0, 0], [1.5, 2, 3, 0], [3, 0, 0, 0]],
    LeftArm:[[0, 8, 0, 6], [1.5, 10, 0, 7], [3, 8, 0, 6]],
    RightArm:[[0, 8, 0, -6], [1.5, 10, 0, -7], [3, 8, 0, -6]],
  }, [[0, 0], [1.5, -0.012], [3, 0]]);
}

function juke(dir: 1 | -1): AnimationClip {
  const name = dir === 1 ? 'football_juke_right' : 'football_juke_left';
  return clipFrom(name, 0.4, {
    Hips:  [[0, 0, 0, 0], [0.15, 0, 22 * dir, 10 * dir], [0.4, 0, 0, 0]],
    Spine: [[0, 4, 0, 0], [0.15, 10, 18 * dir, 8 * dir], [0.4, 4, 0, 0]],
    LeftUpLeg: [[0, -14, 0, 0], [0.15, dir === -1 ? -70 : -8, 0, 6 * -dir], [0.4, -14, 0, 0]],
    RightUpLeg:[[0, -14, 0, 0], [0.15, dir === 1 ? -70 : -8, 0, 6 * -dir], [0.4, -14, 0, 0]],
  });
}

function spinMove(): AnimationClip {
  return clipFrom('football_spin_move', 0.55, {
    Hips:  [[0, 0, 0, 0], [0.18, 0, 130, 0], [0.36, 0, 260, 0], [0.55, 0, 360, 0]],
    Spine: [[0, 8, 0, 0], [0.27, 14, 0, 6], [0.55, 8, 0, 0]],
    LeftArm:[[0, 20, 0, 10], [0.27, 70, 0, 40], [0.55, 20, 0, 10]],
    RightArm:[[0, 60, 0, -20], [0.27, 30, 0, -40], [0.55, 60, 0, -20]],
  });
}

function tackledFall(): AnimationClip {
  return clipFrom('football_tackled_fall', 0.6, {
    Spine: [[0, 4, 0, 0], [0.25, -30, 0, 12], [0.6, -70, 0, 18]],
    Neck:  [[0, 0, 0, 0], [0.25, -16, 0, 0], [0.6, -20, 0, 0]],
    LeftArm:[[0, 20, 0, 10], [0.3, -60, 0, 45], [0.6, -80, 0, 55]],
    RightArm:[[0, 60, 0, -20], [0.3, -50, 0, -45], [0.6, -80, 0, -55]],
    LeftUpLeg:[[0, -14, 0, 4], [0.6, -40, 0, 10]],
    RightUpLeg:[[0, -14, 0, -4], [0.6, -30, 0, -8]],
  }, [[0, 0], [0.6, -0.85]]);
}

function hitReact(): AnimationClip {
  return clipFrom('karate_hit_react', 0.3, {
    Spine: [[0, 0, 0, 0], [0.1, -14, 8, 4], [0.3, 0, 0, 0]],
    Neck:  [[0, 0, 0, 0], [0.1, -12, 10, 0], [0.3, 0, 0, 0]],
    Hips:  [[0, 0, 0, 0], [0.1, 0, 6, 0], [0.3, 0, 0, 0]],
  });
}

function knockdown(): AnimationClip {
  return clipFrom('karate_knockdown', 0.7, {
    Spine: [[0, 0, 0, 0], [0.3, -40, 10, 8], [0.7, -85, 12, 10]],
    Neck:  [[0, 0, 0, 0], [0.3, -18, 0, 0], [0.7, -10, 0, 0]],
    LeftArm:[[0, 15, 0, 10], [0.7, -70, 0, 60]],
    RightArm:[[0, 15, 0, -10], [0.7, -70, 0, -60]],
    LeftUpLeg:[[0, -12, 0, 4], [0.7, -35, 0, 12]],
    RightUpLeg:[[0, -12, 0, -4], [0.7, -25, 0, -10]],
  }, [[0, 0], [0.7, -0.9]]);
}

export function buildAuthoredClips(): AnimationClip[] {
  return [
    idleStand(), chargeGather(), launch(), eastbay(), scoreHang(), landCrouch(),
    juke(-1), juke(1), spinMove(), tackledFall(), hitReact(), knockdown(),
  ];
}

/** Add authored clips to an existing mixer/actionMap (call once after GLB load). */
export function registerAuthoredClips(
  mixer: AnimationMixer,
  actionMap: Map<string, AnimationAction>,
  clipNames: string[],
): void {
  for (const clip of buildAuthoredClips()) {
    if (actionMap.has(clip.name)) continue;        // real asset clip wins if added later
    const action = mixer.clipAction(clip);
    action.enabled = true;
    actionMap.set(clip.name, action);
    clipNames.push(clip.name);
  }
}
