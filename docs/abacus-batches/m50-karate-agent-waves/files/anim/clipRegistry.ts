// clipRegistry v3 — REPLACES the M42/M45 file. Purely additive: two new
// semantic gestures for the Dunk Contest overhaul's alley-oop prop (a
// teammate toss + catch beat). Both map to real, already-available clips —
// no new assets required. Everything else is byte-identical to the M45
// version; ship this to keep every mode on the same registry.

import type { CharacterAnimator, PlayOpts } from './CharacterAnimator';

export const REAL_CLIPS = new Set([
  'guard', 'high_kick', 'hook', 'jab', 'jumpshot', 'roundhouse', 'run', 'uppercut', 'walk',
  'idle_stand', 'strafe_left', 'strafe_right', 'jump_up', 'jump_land',
  'dunk_charge_gather', 'dunk_launch', 'dunk_360_eastbay', 'dunk_score_hang', 'dunk_land_crouch',
  'football_juke_left', 'football_juke_right', 'football_spin_move', 'football_tackled_fall',
  'karate_hit_react', 'karate_knockdown',
]);

const SAFE_DEFAULT = 'guard';

export const SPORT_CLIP = {
  idle: 'idle_stand',
  moveLoop: 'run',
  walkLoop: 'walk',
  jumpUp: 'jump_up',
  jumpLand: 'jump_land',
  fallReact: 'football_tackled_fall',

  dunkChargeGather: 'dunk_charge_gather',
  dunkLaunchPower: 'dunk_launch',
  dunkLaunchFlashy: 'roundhouse',
  dunkLaunchSig: 'dunk_360_eastbay',
  dunkScoreHang: 'dunk_score_hang',
  dunkLandCrouch: 'dunk_land_crouch',
  scoreCelebrate: 'uppercut',
  // NEW — alley-oop prop (Dunk Contest overhaul)
  teammateToss: 'jumpshot',            // arm-raise reads as a lob release
  teammateIdle: 'idle_stand',

  karateStance: 'guard',
  karateJab: 'jab',
  karateKick: 'high_kick',
  karateHeavy: 'uppercut',
  karateBlock: 'guard',
  karateHitReact: 'karate_hit_react',
  karateKnockdown: 'karate_knockdown',

  footballJukeLeft: 'football_juke_left',
  footballJukeRight: 'football_juke_right',
  footballSpin: 'football_spin_move',
  footballHurdle: 'jump_up',
  footballTackled: 'football_tackled_fall',

  boardIdle: 'guard',
  boardCarve: 'walk',
  boardAir: 'jump_up',
  boardGrab: 'hook',
  boardFlipTrick: 'roundhouse',
  boardGrind: 'guard',
  boardTuck: 'guard',
  boardBail: 'football_tackled_fall',

  golfAddress: 'guard',
  golfSwing: 'roundhouse',
  tennisIdle: 'guard',
  tennisForehand: 'jab',
  derbyStance: 'guard',
  derbySwing: 'uppercut',
  derbyPitch: 'jab',
  penaltyIdle: 'guard',
  penaltyStrike: 'high_kick',
  keeperIdle: 'guard',
  keeperDive: 'jumpshot',
} as const;

export type SportGesture = keyof typeof SPORT_CLIP;

export function installSafePlay(animator: CharacterAnimator, modeId: string): void {
  const rawPlay = animator.play.bind(animator);
  animator.play = (name: string, opts: PlayOpts = {}) => {
    if (REAL_CLIPS.has(name)) return rawPlay(name, opts);
    console.error(`[FEL-ANIM] MISSING CLIP "${name}" requested in "${modeId}" — falling back to "${SAFE_DEFAULT}" (bind pose avoided)`);
    return rawPlay(SAFE_DEFAULT, opts);
  };
}

export function playGesture(animator: CharacterAnimator, gesture: SportGesture, opts: PlayOpts = {}): void {
  animator.play(SPORT_CLIP[gesture], opts);
}
