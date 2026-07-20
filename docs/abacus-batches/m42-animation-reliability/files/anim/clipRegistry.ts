// clipRegistry — THE fix for the single biggest live-quality defect found in
// the July 20 re-audit: characters are in bind pose (T-pose) in nearly every
// mode, on nearly every action, with ZERO console warning.
//
// ROOT CAUSE (confirmed via full FEL-ANIM log capture on the live build):
// the hero's imported GLB only ships NINE real animation groups —
//   guard · high_kick · hook · jab · jumpshot · roundhouse · run · uppercut · walk
// — a generic fighter/locomotion rig. Every sport-specific name the mode code
// calls (golf_address, tennis_forehand, board_ride_idle, run_forward,
// derby_swing, karate_punch_light, penalty_strike, …) matches NOTHING. The
// resolver's "MISSING CLIP" warning (M30) only fires for GLB-instancing
// suffix mismatches — it never fires for a name that was never registered at
// all, so the failure is completely silent: animator.play() no-ops, weights
// stay at zero, and the rig sits at bind pose. This affects basketball,
// karate, football, all three board sports, and all four precision sports.
//
// THE FIX has two parts:
//  1. safePlay() — a drop-in replacement for animator.play() that (a) checks
//     the name against the registry BEFORE calling into the animator, (b)
//     logs a loud, specific warning the instant a name doesn't resolve, and
//     (c) automatically substitutes a real clip instead of leaving the rig
//     at bind pose. Bind pose becomes categorically unreachable.
//  2. SPORT_CLIP — the alias table every mode should route through instead
//     of hand-writing clip-name strings. It maps every semantic gesture the
//     game needs onto the closest REAL clip available today. This is a
//     content limitation, not a code bug — the underlying rig does not have
//     bespoke golf/tennis/board/soccer animations yet. Aliasing to the
//     fighter-rig clips is what makes every mode look ANIMATED and readable
//     right now; commissioning real sport-specific mocap for these gestures
//     is the follow-up content workstream (flagged in the batch README).

import type { CharacterAnimator, PlayOpts } from './CharacterAnimator';

/** Names that actually exist on the live rig today. Update this the moment
 *  new clips are authored or imported — it is the single source of truth. */
export const REAL_CLIPS = new Set([
  // imported GLB (generic fighter rig)
  'guard', 'high_kick', 'hook', 'jab', 'jumpshot', 'roundhouse', 'run', 'uppercut', 'walk',
  // authored/code-driven (M24 procedural clips — always safe)
  'idle_stand', 'strafe_left', 'strafe_right', 'jump_up', 'jump_land',
  'dunk_charge_gather', 'dunk_launch', 'dunk_360_eastbay', 'dunk_score_hang', 'dunk_land_crouch',
  'football_juke_left', 'football_juke_right', 'football_spin_move', 'football_tackled_fall',
  'karate_hit_react', 'karate_knockdown',
]);

/** The universal fallback when nothing better applies. Always real. */
const SAFE_DEFAULT = 'guard';

/**
 * Semantic gesture → real clip. Every mode should request gestures by their
 * SPORT_CLIP key (e.g. SPORT_CLIP.golfSwing), never a raw string, so the
 * whole game can be re-pointed at real assets by editing this one table.
 */
export const SPORT_CLIP = {
  // locomotion (shared)
  idle: 'idle_stand',
  moveLoop: 'run',
  walkLoop: 'walk',
  jumpUp: 'jump_up',
  jumpLand: 'jump_land',
  fallReact: 'football_tackled_fall',

  // basketball
  dunkChargeGather: 'dunk_charge_gather',
  dunkLaunchPower: 'dunk_launch',
  dunkLaunchFlashy: 'roundhouse',        // no scoop clip yet — reads as a mid-air flourish
  dunkLaunchSig: 'dunk_360_eastbay',
  dunkScoreHang: 'dunk_score_hang',
  dunkLandCrouch: 'dunk_land_crouch',
  scoreCelebrate: 'uppercut',            // arms-up beat reads as a celebration pop

  // karate
  karateStance: 'guard',
  karateJab: 'jab',
  karateKick: 'high_kick',
  karateHeavy: 'uppercut',
  karateBlock: 'guard',
  karateHitReact: 'karate_hit_react',
  karateKnockdown: 'karate_knockdown',

  // football
  footballJukeLeft: 'football_juke_left',
  footballJukeRight: 'football_juke_right',
  footballSpin: 'football_spin_move',
  footballHurdle: 'jump_up',
  footballTackled: 'football_tackled_fall',

  // board sports (skate / snowboard / surf) — no board-specific mocap yet;
  // the fighter-rig clips give real, readable arm/leg motion instead of a
  // static T-pose while riding.
  boardIdle: 'guard',
  boardCarve: 'walk',
  boardAir: 'jump_up',
  boardGrab: 'hook',
  boardFlipTrick: 'roundhouse',
  boardGrind: 'guard',
  boardTuck: 'guard',
  boardBail: 'football_tackled_fall',

  // precision sports
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

/**
 * Wraps a CharacterAnimator so EVERY play() call — whether it uses a
 * SPORT_CLIP alias or a raw string — is validated before it reaches the
 * animator. Call once per spawned character, immediately after
 * neverBindPose() (M35). Order matters: safePlay wraps the OUTERMOST play,
 * so a request that fails resolution never reaches neverBindPose's
 * onEnd-chaining logic with a bad name.
 */
export function installSafePlay(animator: CharacterAnimator, modeId: string): void {
  const rawPlay = animator.play.bind(animator);
  animator.play = (name: string, opts: PlayOpts = {}) => {
    if (REAL_CLIPS.has(name)) return rawPlay(name, opts);
    console.error(`[FEL-ANIM] MISSING CLIP "${name}" requested in "${modeId}" — falling back to "${SAFE_DEFAULT}" (bind pose avoided)`);
    return rawPlay(SAFE_DEFAULT, opts);
  };
}

/** Convenience: play a semantic gesture by its SPORT_CLIP key. */
export function playGesture(animator: CharacterAnimator, gesture: SportGesture, opts: PlayOpts = {}): void {
  animator.play(SPORT_CLIP[gesture], opts);
}

// WIRING
// CharacterLibrary.spawn — right after neverBindPose(animator, baseLoop):
//     installSafePlay(animator, modeId);
// Every mode file in this batch has been rewritten to call playGesture(...)
// or SPORT_CLIP.xxx instead of a hand-written string. Any FUTURE mode code
// that still hand-writes a clip name is protected by installSafePlay either
// way — it just won't get a semantic name in the registry until added here.
