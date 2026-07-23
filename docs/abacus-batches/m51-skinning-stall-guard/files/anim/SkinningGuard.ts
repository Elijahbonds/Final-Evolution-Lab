// SkinningGuard — detects and self-heals the "animation logic is 100%
// correct but the character never visibly moves off bind pose" failure mode
// found in the M50 dunk-contest live audit (see 00-README-PROMPT.md for the
// full investigation). Runs once per spawned character: samples one bone's
// WORLD matrix ~20 rendered frames after its base clip starts (long enough
// for any weight-ramp/keyframe motion to show), compares it to the bind-pose
// matrix captured at spawn, and if it hasn't moved, forces CPU skinning
// (bypasses whatever GPU/shader skinning path silently failed to apply) and
// logs loudly so every future playtest sweep catches this immediately if it
// recurs on any device.

import type { AbstractMesh, Scene, Skeleton } from '@babylonjs/core';

const warnedIds = new Set<string>();
const FRAMES_TO_WAIT = 20;
const EPSILON = 1e-3;

export const SkinningGuard = {
  /** Call once per spawn, right after the character's base idle/loop clip starts playing. */
  verify(scene: Scene, id: string, meshes: AbstractMesh[], skeleton: Skeleton, checkBoneName = 'Spine'): void {
    const bone = skeleton.bones.find((b) => b.name === checkBoneName) ?? skeleton.bones[0];
    if (!bone) return;
    const bindWorld = bone.getWorldMatrix().clone();

    let frames = 0;
    const obs = scene.onAfterRenderObservable.add(() => {
      frames++;
      if (frames < FRAMES_TO_WAIT) return;
      scene.onAfterRenderObservable.remove(obs);

      const moved = !bone.getWorldMatrix().equalsWithEpsilon(bindWorld, EPSILON);
      if (moved || warnedIds.has(id)) return;
      warnedIds.add(id);

      console.error(
        `[FEL-ANIM] SKINNING STALL on "${id}" — bone "${bone.name}" unchanged after ` +
        `${FRAMES_TO_WAIT} rendered frames despite a playing, fully-weighted clip. ` +
        `Forcing CPU skinning fallback for this character.`,
      );
      for (const m of meshes) {
        m.computeBonesUsingShaders = false;
        m.markAsDirty('material');
      }
    });
  },
};

// WIRING — CharacterLibrary.spawn(), right after `animator.play(startClip, { loop: true })`:
//   SkinningGuard.verify(scene, id, meshes, skeleton);
// No other call sites need this — one guard per spawned character covers every
// mode, since every mode spawns through CharacterLibrary.
