// ExternalClipLoader — the missing link between Meshy/DeepMotion and the game.
//
// WHY YOUR MOCAP ISN'T THERE
// I traced the whole chain on the live build. The animation system is not
// broken — clips load, register, and play. The problem is simpler and worse:
// THERE IS NO PATH FOR AN EXTERNAL ANIMATION TO REACH IT.
//
// What the game actually animates with today:
//   1. ~9 clips that ride INSIDE the character GLB (guard, jab, hook,
//      high_kick, roundhouse, jumpshot, run, walk, uppercut). The console
//      shows them being sanitised on every load.
//   2. Procedural clips authored as quaternion keyframes IN CODE —
//      dunk_charge_gather, dunk_launch, dunk_360_eastbay, idle_stand and the
//      rest. A programmer typed those angles. That is exactly why the dunk
//      looks stiff and why the idle reads as a T-pose: `idle_stand` keys the
//      arms only ~8-10° away from the arms-out bind pose.
//
// There is no Meshy animation and no DeepMotion mocap anywhere in the
// project — `assets/` holds 13 Luma FBX environments and zero character or
// animation files. Nothing loads external clips because nothing was ever
// written to. This file is that thing.
//
// THE FULL CHAIN, AND WHAT EXISTS
//   1. Export from Meshy / DeepMotion  → .glb or .fbx        (you do this)
//   2. Conform: strip `mixamorig:`, animation-only export     ← ALREADY BUILT
//        tools/fel_conform.py (M65) — written, NEVER RUN. Needs Blender.
//   3. Drop in assets/ready/anim/                             (a folder)
//   4. Load at runtime + retarget onto the live skeleton      ← THIS FILE
//   5. Register under a clip id so modes can play it          ← THIS FILE
//
// Step 2 is the one that silently kills everything if skipped. FEL resolves
// bones by UNPREFIXED name (`Hips`, `LeftArm`). Meshy, Mixamo and DeepMotion
// nearly all export `mixamorig:Hips`. A prefixed clip targets bones that do
// not exist, animates nothing, and leaves the character in bind pose — which
// looks exactly like "the animation didn't fire".

import { AnimationGroup, LoadAssetContainerAsync } from '@babylonjs/core';
import type { Scene, Skeleton, TransformNode } from '@babylonjs/core';
import { stripPrefix, isPrefixed } from './boneNames';

export { stripPrefix, isPrefixed };

export interface LoadedClip {
  id: string;
  group: AnimationGroup;
  /** Bones the clip drove successfully. */
  bound: string[];
  /** Bones the clip targeted that this skeleton does not have. */
  unmatched: string[];
  sourceUrl: string;
}

export interface ClipSource {
  /** Clip id modes will play, e.g. 'dunk_launch'. */
  id: string;
  /** URL of an ANIMATION-ONLY glb (mesh stripped by fel_conform.py). */
  url: string;
  /** Play speed multiplier if the clip was authored at a different rate. */
  speedRatio?: number;
}

/**
 * Retarget a loaded AnimationGroup onto `skeleton` by BONE NAME.
 *
 * Name-based retargeting only — no IK, no proportion solving. That is a
 * deliberate limit: it is correct whenever the source and target share a
 * humanoid naming convention (which is the whole point of conforming first),
 * and it fails loudly rather than producing subtly wrong motion. If a rig
 * needs real retargeting, that belongs in Blender before export, not at
 * runtime in the game.
 */
export function retargetToSkeleton(
  group: AnimationGroup, skeleton: Skeleton, scene: Scene,
): { group: AnimationGroup | null; bound: string[]; unmatched: string[] } {
  const nodeFor = (bone: string): TransformNode | null =>
    skeleton.bones.find((b) => b.name === bone)?.getTransformNode() ?? null;

  const bound: string[] = [];
  const unmatched: string[] = [];
  const retargeted = new AnimationGroup(group.name, scene);

  for (const ta of group.targetedAnimations) {
    const rawName = (ta.target as { name?: string })?.name ?? '';
    const boneName = stripPrefix(rawName);
    const node = nodeFor(boneName);
    if (!node) {
      // Report the RAW name, not the stripped one. The stripped name is what
      // we looked up; the raw name is what is actually in the file, and it is
      // the only version that tells you whether the file was ever conformed.
      // (An earlier draft reported stripped names and then tested them for a
      // ':' to detect prefixes — a check that could never fire.)
      if (!unmatched.includes(rawName)) unmatched.push(rawName);
      continue;
    }
    // POSITION TRACKS ARE DROPPED except on Hips.
    //
    // Mocap carries absolute bone positions from the SOURCE skeleton's
    // proportions. Applied to a different body they stretch limbs and detach
    // joints. Rotation is proportion-independent, so rotation-only retargets
    // cleanly. Hips keeps position because that is the root motion — drop it
    // and the character animates perfectly while sliding nowhere.
    const prop = ta.animation.targetProperty;
    if (prop === 'position' && boneName !== 'Hips') continue;

    retargeted.addTargetedAnimation(ta.animation, node);
    if (!bound.includes(boneName)) bound.push(boneName);
  }

  // Read the range BEFORE disposing the source — `group.from`/`group.to` are
  // derived from its targeted animations and are meaningless afterwards.
  const from = group.from;
  const to = group.to;
  group.dispose();

  if (bound.length === 0) {
    retargeted.dispose();
    return { group: null, bound, unmatched };
  }
  retargeted.normalize(from, to);
  return { group: retargeted, bound, unmatched };
}

/**
 * Load one animation-only asset and bind it to a skeleton.
 *
 * Returns null on any failure — never throws. A missing or malformed clip
 * should degrade to the existing procedural animation, not take the mode
 * down with it.
 */
export async function loadExternalClip(
  scene: Scene, skeleton: Skeleton, src: ClipSource,
): Promise<LoadedClip | null> {
  let container;
  try {
    container = await LoadAssetContainerAsync(src.url, scene);
  } catch (e) {
    console.error(`[FEL-ANIM] external clip "${src.id}" failed to load from ${src.url}:`, e);
    return null;
  }

  const groups = container.animationGroups;
  if (groups.length === 0) {
    console.error(`[FEL-ANIM] "${src.id}" (${src.url}) contains NO animation groups. `
      + 'Export it as animation-only from Blender, or check the exporter actually baked the action.');
    container.dispose();
    return null;
  }
  if (groups.length > 1) {
    console.warn(`[FEL-ANIM] "${src.id}" contains ${groups.length} animation groups; using the first `
      + `("${groups[0].name}"). Split multi-clip exports into one file per clip.`);
  }

  const source = groups[0];
  source.stop();
  // `group` here is a NEW AnimationGroup pointing at the LIVE skeleton's
  // nodes. The one that came out of the file is disposed inside — returning
  // it would return a group bound to a skeleton we are about to throw away.
  const { group, bound, unmatched } = retargetToSkeleton(source, skeleton, scene);

  // Throw away the mesh/skeleton that rode along with the animation file —
  // we only ever wanted the tracks.
  container.meshes.forEach((m) => m.dispose());
  container.skeletons.forEach((s) => { if (s !== skeleton) s.dispose(); });

  if (bound.length === 0 || !group) {
    console.error(
      `[FEL-ANIM] "${src.id}" bound ZERO bones. Its tracks target: ${unmatched.slice(0, 6).join(', ')}`
      + (unmatched.some(isPrefixed)
        ? '\n           → Those names are still PREFIXED. Run tools/fel_conform.py on this file first; '
          + 'FEL resolves bones by unprefixed name and a prefixed clip animates nothing.'
        : '\n           → Names look unprefixed but do not match this rig. Compare against AvatarSkeletonSpec.md.'),
    );
    return null;
  }

  // The clip is played by NAME everywhere else in the game, and the exporter's
  // name is whatever Mixamo felt like ("Armature|mixamo.com|Layer0"). The id
  // is the contract; make the group match it.
  group.name = src.id;
  if (src.speedRatio && src.speedRatio !== 1) group.speedRatio = src.speedRatio;

  if (unmatched.length) {
    console.warn(`[FEL-ANIM] "${src.id}": ${bound.length} bones bound, `
      + `${unmatched.length} unmatched (${unmatched.slice(0, 5).join(', ')}). `
      + 'Extra source bones are usually harmless — fingers and twist joints this rig lacks.');
  } else {
    console.info(`[FEL-ANIM] external clip "${src.id}": ${bound.length} bones bound, clean.`);
  }

  return { id: src.id, group, bound, unmatched, sourceUrl: src.url };
}

/**
 * Load a whole pack and register each clip.
 *
 * Loads in parallel but reports per clip, because one bad file should not
 * hide the nine that worked.
 */
export async function loadClipPack(
  scene: Scene,
  skeleton: Skeleton,
  sources: ClipSource[],
  register: (id: string, group: AnimationGroup) => void,
): Promise<{ loaded: string[]; failed: string[] }> {
  const results = await Promise.all(
    sources.map((s) => loadExternalClip(scene, skeleton, s)),
  );
  const loaded: string[] = [];
  const failed: string[] = [];
  results.forEach((r, i) => {
    if (r) { register(r.id, r.group); loaded.push(r.id); }
    else failed.push(sources[i].id);
  });

  console.info(`[FEL-ANIM] clip pack: ${loaded.length}/${sources.length} loaded`
    + (failed.length ? ` — FAILED: ${failed.join(', ')}` : ''));
  return { loaded, failed };
}

/**
 * Which clip ids the game plays but has no external file for.
 *
 * Call this once at boot with your manifest. It answers "why is my mocap not
 * showing" directly instead of leaving you to infer it from a stiff dunk:
 * anything listed here is still running on the hand-authored quaternion keys.
 */
export function reportProceduralFallbacks(required: string[], externalIds: string[]): string[] {
  const missing = required.filter((id) => !externalIds.includes(id));
  if (missing.length) {
    console.warn(`[FEL-ANIM] ${missing.length} clip(s) still using PROCEDURAL keyframes, not mocap: `
      + missing.join(', ')
      + '\n           These are hand-authored angles. Supply conformed animation files to replace them.');
  }
  return missing;
}
