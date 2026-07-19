// M24 Batch 1 barrel — import everything from here.
//
// WIRING CHEAT-SHEET
// 1) After character GLB load:
//      const animator = new CharacterAnimator(scene, result.animationGroups);
//      registerAuthoredClips(animator, scene, result.skeletons[0]);
//      animator.play('idle_stand', { loop: true });
// 2) Every state change: animator.play(REGISTRY_NAME, { loop, speedRatio, onEnd })
//    — never call AnimationGroup.play/start directly; never scrub animations[0].
// 3) Dunk phases: charge→'dunk_charge_gather' · launch→'dunk_launch' ·
//    airborne(style)→'dunk_360_eastbay' etc. · scored→'dunk_score_hang' ·
//    land→'dunk_land_crouch'. Sync ball with runEastbayPath(clipTime).
// 4) Every mode scene: const rig = mountLightRig(scene, MODE_MOODS[modeId]);
//    after venue load: liftBlackMaterials(scene); addShadowCasters(rig, meshes).
// 5) Dunk replay: new DunkReplayRecorder(...); await rec.play(rimCenter) on make.

export { CLIP_ALIASES, FALLBACK_CLIP } from './anim/clipAliases';
export { resolveClip, missingClipList, missingClipCount } from './anim/clipResolver';
export { CharacterAnimator, type PlayOpts } from './anim/CharacterAnimator';
export { buildClip, type BoneKeys, type HipsYKeys } from './anim/clipBuilder';
export { EASTBAY_TIMING, DUNK_TIMING } from './anim/authored/timing';
export { registerAuthoredClips } from './anim/authored';
export {
  attachBallToHand, releaseBall, runEastbayPath, flushThroughRim, clankOffRim,
} from './anim/ballRig';
export { MOODS, MODE_MOODS, type VenueMood } from './scene/moods';
export { mountLightRig, liftBlackMaterials, addShadowCasters, type LightRigHandle } from './scene/LightRig';
export { DunkReplayRecorder } from './scene/DunkReplayCam';
