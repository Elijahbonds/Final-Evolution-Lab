// SkinningGuard v2 — REPLACES the M51 file. Fixes a FALSE POSITIVE the v1
// guard is producing on the live build right now.
//
// WHAT THE LIVE SMOKE TEST FOUND
// v1 is deployed and firing on Karate Endless, logging SKINNING STALL for
// four characters at once (char_198, char_264, char_330, char_396) and
// forcing them all to CPU skinning. That is almost certainly wrong:
//   · it samples ONE bone — `Spine` — and karate's `guard` stance clip
//     barely moves the spine, so a perfectly healthy character reads as
//     stalled;
//   · four simultaneous "stalls" in a mode whose characters visibly animate
//     is the signature of a bad heuristic, not four broken rigs;
//   · the penalty is real — CPU skinning costs frame time on every one of
//     them, so a false positive makes the game slower for no reason.
//
// v2 keeps the safety net but makes it hard to trip by accident:
//   1. SAMPLES MULTIPLE BONES (arms, legs, spine). A stall means EVERY
//      sampled bone is frozen — one static bone proves nothing.
//   2. LONGER WINDOW (20 → 45 frames) so slow clips and long crossfades
//      aren't mistaken for a stall.
//   3. REQUIRES A PLAYING CLIP with real weight. If nothing is actually
//      playing, "not moving" is correct behaviour, not a defect.
//   4. Distinguishes SUSPECT from STALL: a partial freeze logs a warning
//      and takes no action. Only a total freeze triggers the CPU fallback.

import type { AbstractMesh, Scene, Skeleton } from '@babylonjs/core';

const warnedIds = new Set<string>();
const FRAMES_TO_WAIT = 45;
const EPSILON = 1e-3;

/** Bones sampled for motion. Spread across limbs on purpose — an idle clip
 *  may hold the spine still, but it will not hold ALL of these still. */
const SAMPLE_BONES = ['Spine', 'LeftArm', 'RightArm', 'LeftUpLeg', 'RightUpLeg', 'Head'];

export const SkinningGuard = {
  /** Call once per spawn, right after the character's base loop starts. */
  verify(
    scene: Scene,
    id: string,
    meshes: AbstractMesh[],
    skeleton: Skeleton,
    /** Optional: lets the guard confirm a clip is genuinely playing before
     *  it accuses the skinning pipeline of anything. */
    isAnimating?: () => boolean,
  ): void {
    const bones = SAMPLE_BONES
      .map((n) => skeleton.bones.find((b) => b.name === n))
      .filter((b): b is NonNullable<typeof b> => !!b);

    if (bones.length === 0) {
      console.warn(`[FEL-ANIM] SkinningGuard: none of the sampled bones exist on "${id}" — `
        + 'check the rig against AvatarSkeletonSpec.md (names are UNPREFIXED).');
      return;
    }

    const baseline = bones.map((b) => b.getWorldMatrix().clone());
    let frames = 0;

    const obs = scene.onAfterRenderObservable.add(() => {
      frames++;
      if (frames < FRAMES_TO_WAIT) return;
      scene.onAfterRenderObservable.remove(obs);

      // If nothing is playing, stillness is correct — say nothing.
      if (isAnimating && !isAnimating()) return;

      const moved = bones.map((b, i) => !b.getWorldMatrix().equalsWithEpsilon(baseline[i], EPSILON));
      const movedCount = moved.filter(Boolean).length;

      if (movedCount === bones.length) return;                    // fully healthy

      if (movedCount > 0) {
        // Partial: normal for many clips (a guard stance holds the spine).
        // Report at debug level and take NO action — acting here is what
        // v1 got wrong.
        const still = bones.filter((_, i) => !moved[i]).map((b) => b.name);
        console.debug(`[FEL-ANIM] SkinningGuard: "${id}" — ${movedCount}/${bones.length} sampled bones moving `
          + `(static: ${still.join(', ')}). Normal for clips that hold part of the body still; no action taken.`);
        return;
      }

      // Total freeze across every sampled bone, with a clip playing.
      if (warnedIds.has(id)) return;
      warnedIds.add(id);
      console.error(
        `[FEL-ANIM] SKINNING STALL on "${id}" — NONE of ${bones.length} sampled bones `
        + `(${bones.map((b) => b.name).join(', ')}) moved in ${FRAMES_TO_WAIT} rendered frames `
        + 'while a clip was playing. Forcing CPU skinning for this character.',
      );
      for (const m of meshes) {
        m.computeBonesUsingShaders = false;
        m.markAsDirty('material');
      }
    });
  },

  /** Test hook — lets a fresh run re-report. */
  reset(): void { warnedIds.clear(); },
};

// WIRING — CharacterLibrary.spawn(), after `animator.play(startClip, { loop: true })`:
//   SkinningGuard.verify(scene, id, meshes, skeleton, () => animator.isPlaying);
// The 5th argument is optional but recommended: without it the guard cannot
// tell "stalled" from "nothing is playing".
