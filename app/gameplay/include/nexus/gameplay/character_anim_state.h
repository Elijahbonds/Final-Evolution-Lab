// Animation state machine — maps game-mode state to animation clip names.
// This is the T-pose fix: the C++ layer always emits a valid clip name.
// The Swift/Metal renderer reads the clip name from stateJson() and drives
// playback. Clip names follow the Meshy/Mixamo free-asset naming convention.
#pragma once

#include "nexus/gameplay/arena_3d_space.h"

#include <cstdint>
#include <string>
#include <string_view>

namespace nexus::gameplay {

// All clip names are lower_snake_case to match common free 3D asset conventions
// (Mixamo, Meshy, ReadyPlayerMe, etc.). The renderer plays these by name.
namespace clips {
  // ── Locomotion ──────────────────────────────────────────────────────────
  inline constexpr std::string_view kIdle         = "idle_stand";
  inline constexpr std::string_view kWalk         = "walk_forward";   // normal-pace movement
  inline constexpr std::string_view kRun          = "run_forward";    // fast/perk movement
  inline constexpr std::string_view kRunBack      = "run_backward";
  inline constexpr std::string_view kSprint       = "sprint_forward";
  inline constexpr std::string_view kJump         = "jump_up";
  inline constexpr std::string_view kLand         = "jump_land";
  inline constexpr std::string_view kFall         = "fall_loop";
  inline constexpr std::string_view kStrafe_L     = "strafe_left";
  inline constexpr std::string_view kStrafe_R     = "strafe_right";

  // ── Idle variants (rotate through every ~5 s to avoid static T-pose feel) ─
  inline constexpr std::string_view kIdleBreath   = "idle_breathe";        // variant 1
  inline constexpr std::string_view kIdleStretch  = "idle_stretch";        // variant 2
  inline constexpr std::string_view kIdleShift    = "idle_shift_weight";   // variant 3

  // ── Dunk Contest ────────────────────────────────────────────────────────
  inline constexpr std::string_view kDunkApproach = "dunk_approach_run";
  inline constexpr std::string_view kDunkCharge   = "dunk_charge_gather";
  inline constexpr std::string_view kDunkLaunch   = "dunk_launch";
  inline constexpr std::string_view kDunkAirborne = "dunk_airborne_float";
  inline constexpr std::string_view kDunkScore    = "dunk_score_hang";
  inline constexpr std::string_view kDunkLand     = "dunk_land_crouch";
  // signature dunks
  inline constexpr std::string_view kDunk360Scoop        = "dunk_360_scoop";
  inline constexpr std::string_view kDunk360Eastbay      = "dunk_360_eastbay";
  inline constexpr std::string_view kDunk360FakeEastbay  = "dunk_360_fake_eastbay";
  inline constexpr std::string_view kDunkOffBoardWindmill= "dunk_off_board_windmill";

  // ── Karate / Combat ──────────────────────────────────────────────────────
  inline constexpr std::string_view kKarateIdle   = "karate_idle_stance";
  inline constexpr std::string_view kKarateLightP = "karate_punch_light";
  inline constexpr std::string_view kKarateHeavyP = "karate_punch_heavy";
  inline constexpr std::string_view kKarateKick   = "karate_kick_roundhouse";
  inline constexpr std::string_view kKarateBlock  = "karate_block";
  inline constexpr std::string_view kKarateDodge  = "karate_dodge_roll";
  inline constexpr std::string_view kKarateCounter= "karate_counter_throw";
  inline constexpr std::string_view kKarateHit    = "karate_hit_react";
  inline constexpr std::string_view kKarateDown   = "karate_knockdown";
  inline constexpr std::string_view kKarateWin    = "karate_victory_pose";

  // ── Basketball (pickup / H2H / 3v3 / dunk) ──────────────────────────────
  // ── No-ball locomotion ───────────────────────────────────────────────────
  inline constexpr std::string_view kBballIdle        = "bball_idle_stand";
  inline constexpr std::string_view kBballWalk        = "bball_walk_noBall";   // walking, no possession
  inline constexpr std::string_view kBballJog         = "bball_jog_noBall";    // jogging, no possession
  // ── Ball-possession locomotion ───────────────────────────────────────────
  inline constexpr std::string_view kBballDribbleWalk = "bball_dribble_walk";  // slow dribble
  inline constexpr std::string_view kBballDribble     = "bball_dribble_run";   // full-speed dribble
  inline constexpr std::string_view kBballCarry       = "bball_carry_twohand"; // ball held (no dribble)
  // ── Ball pickup transitions ──────────────────────────────────────────────
  inline constexpr std::string_view kBballPickupRebound   = "bball_pickup_rebound";    // jump + two-hand grab (airborne ball)
  inline constexpr std::string_view kBballPickupLiveBounce= "bball_pickup_livebounce"; // bend + snatch mid-bounce
  inline constexpr std::string_view kBballPickupFloor     = "bball_pickup_floor";      // bend down + scoop (dead ball)
  // ── Dribble moves ────────────────────────────────────────────────────────
  inline constexpr std::string_view kBballCrossover   = "bball_crossover";
  inline constexpr std::string_view kBballBehindBack  = "bball_behind_back";
  inline constexpr std::string_view kBballSpin        = "bball_spin_move";
  inline constexpr std::string_view kBballHesitation  = "bball_hesitation";
  // ── Shooting / defense ───────────────────────────────────────────────────
  inline constexpr std::string_view kBballShoot       = "bball_shoot_jumper";
  inline constexpr std::string_view kBballScore       = "bball_score_celebrate";
  inline constexpr std::string_view kBballDefend      = "bball_defend_stance";
  inline constexpr std::string_view kBballBlock       = "bball_block_reach";
  // ── Signature dunk packages (NBA Live 07/08 / 2K style) ─────────────────
  inline constexpr std::string_view kDunkWindmill          = "dunk_windmill";
  inline constexpr std::string_view kDunkReverseOneHand    = "dunk_reverse_onehand";
  inline constexpr std::string_view kDunkAlleyOopCatch     = "dunk_alleyoop_catch";
  inline constexpr std::string_view kDunkTomahawk          = "dunk_tomahawk";
  inline constexpr std::string_view kDunkPutback           = "dunk_putback_slam";

  // ── Soccer ───────────────────────────────────────────────────────────────
  inline constexpr std::string_view kSoccerDribble= "soccer_dribble_jog";
  inline constexpr std::string_view kSoccerShoot  = "soccer_kick_shoot";
  inline constexpr std::string_view kSoccerPass   = "soccer_kick_pass";
  inline constexpr std::string_view kSoccerTackle = "soccer_tackle_slide";
  inline constexpr std::string_view kSoccerCeleb  = "soccer_goal_celebrate";
  inline constexpr std::string_view kSoccerHeader = "soccer_header_jump";

  // ── Football — NFL Street 3D ─────────────────────────────────────────────
  // Carrier locomotion
  inline constexpr std::string_view kFbIdle       = "football_idle_stance";
  inline constexpr std::string_view kFbJog        = "football_jog_noBall";
  inline constexpr std::string_view kFbSprint     = "football_sprint_return";
  inline constexpr std::string_view kFbSprintBall = "football_sprint_withBall"; // ball-carrier run
  // Juke package (NFL Street feel)
  inline constexpr std::string_view kFbJukeLeft   = "football_juke_left";
  inline constexpr std::string_view kFbJukeRight  = "football_juke_right";
  inline constexpr std::string_view kFbSpin       = "football_spin_move";
  inline constexpr std::string_view kFbStiffArm   = "football_stiff_arm";
  inline constexpr std::string_view kFbHurdle     = "football_hurdle_leap";
  inline constexpr std::string_view kFbDive       = "football_dive_endzone";
  inline constexpr std::string_view kFbGamebreaker= "football_gamebreaker_burst"; // Gamebreaker special
  // Passing / receiving
  inline constexpr std::string_view kFbThrow      = "football_qb_throw";
  inline constexpr std::string_view kFbCatch      = "football_catch_twohand";
  inline constexpr std::string_view kFbCatchOhp   = "football_catch_overhead";   // over-the-shoulder
  inline constexpr std::string_view kFbRoute      = "football_route_run";
  inline constexpr std::string_view kFbPassRush   = "football_pass_rush_bull";
  // Blocking
  inline constexpr std::string_view kFbBlock      = "football_block_drive";
  // Results
  inline constexpr std::string_view kFbTouchdown  = "football_touchdown_spike";
  inline constexpr std::string_view kFbTdBackflip = "football_td_backflip";     // style celebration
  inline constexpr std::string_view kFbTackled    = "football_tackled_fall";
  inline constexpr std::string_view kFbSafety     = "football_safety_sack";

  // ── Baseball 3D ──────────────────────────────────────────────────────────
  // Pitching
  inline constexpr std::string_view kBbPitchIdle     = "baseball_pitcher_idle";
  inline constexpr std::string_view kBbPitchWindup   = "baseball_pitch_windup";
  inline constexpr std::string_view kBbPitchRelease  = "baseball_pitch_release";
  inline constexpr std::string_view kBbPitchFollow   = "baseball_pitch_followthrough";
  inline constexpr std::string_view kBbCheckRunner   = "baseball_check_runner";
  // Batting
  inline constexpr std::string_view kBbBatStance     = "baseball_bat_stance";
  inline constexpr std::string_view kBbBatLoad       = "baseball_bat_load";
  inline constexpr std::string_view kBbSwingFull     = "baseball_swing_full";
  inline constexpr std::string_view kBbSwingCheck    = "baseball_swing_check";
  inline constexpr std::string_view kBbBunt          = "baseball_bunt";
  inline constexpr std::string_view kBbHomeRun       = "baseball_homerun_watch";
  inline constexpr std::string_view kBbStrikeout     = "baseball_strikeout_react";
  // Fielding / running
  inline constexpr std::string_view kBbFielderRun    = "baseball_fielder_sprint";
  inline constexpr std::string_view kBbFielderThrow  = "baseball_fielder_throw";
  inline constexpr std::string_view kBbFielderDive   = "baseball_fielder_dive";
  inline constexpr std::string_view kBbBaseRun       = "baseball_baserunner_sprint";
  inline constexpr std::string_view kBbSlide         = "baseball_slide";
  inline constexpr std::string_view kBbSafe          = "baseball_safe_popup";
  inline constexpr std::string_view kBbCelebrate     = "baseball_team_celebrate";

  // ── Fitness / Workout (motion-capture driven) ─────────────────────────────
  inline constexpr std::string_view kFitIdle         = "fitness_ready_stance";
  inline constexpr std::string_view kFitSquat        = "fitness_squat";
  inline constexpr std::string_view kFitLunge        = "fitness_lunge";
  inline constexpr std::string_view kFitPushup       = "fitness_pushup";
  inline constexpr std::string_view kFitPullup       = "fitness_pullup";
  inline constexpr std::string_view kFitBurpee       = "fitness_burpee";
  inline constexpr std::string_view kFitPlank        = "fitness_plank_hold";
  inline constexpr std::string_view kFitJumpJack     = "fitness_jumping_jack";
  inline constexpr std::string_view kFitHighKnees    = "fitness_high_knees";
  inline constexpr std::string_view kFitMountainClimb= "fitness_mountain_climber";
  inline constexpr std::string_view kFitBicepCurl    = "fitness_bicep_curl";
  inline constexpr std::string_view kFitShoulderPress= "fitness_shoulder_press";
  inline constexpr std::string_view kFitDeadlift     = "fitness_deadlift";
  inline constexpr std::string_view kFitBoxJump      = "fitness_box_jump";
  inline constexpr std::string_view kFitMedBallSlam  = "fitness_medball_slam";
  inline constexpr std::string_view kFitSprintDrill  = "fitness_sprint_drill";
  inline constexpr std::string_view kFitLateralBand  = "fitness_lateral_band_walk";
  inline constexpr std::string_view kFitRestBetween  = "fitness_rest_stand";    // between sets

  // ── Board sports (Meshy/free replacements) ───────────────────────────────
  inline constexpr std::string_view kSkateIdle    = "skate_idle_cruise";
  inline constexpr std::string_view kSkateKickflip= "skate_kickflip";
  inline constexpr std::string_view kSkateHeelflip= "skate_heelflip";
  inline constexpr std::string_view kSkateTreflip = "skate_treflip";
  inline constexpr std::string_view kSkateBail    = "skate_bail_fall";
  inline constexpr std::string_view kSnowCarve    = "snow_carve_lean";
  inline constexpr std::string_view kSnowJump     = "snow_jump_float";
  inline constexpr std::string_view kSnowGrab     = "snow_grab_indy";
  inline constexpr std::string_view kSurfCarve    = "surf_carve_cutback";
  inline constexpr std::string_view kSurfAerial   = "surf_aerial_360";
  inline constexpr std::string_view kSurfTube     = "surf_tube_crouch";

  // ── Golf 3D ────────────────────────────────────────────────────────────────
  inline constexpr std::string_view kGolfIdle          = "golf_idle_address";
  inline constexpr std::string_view kGolfWalk          = "golf_walk";
  inline constexpr std::string_view kGolfAddress       = "golf_address_setup";   // player lining up
  inline constexpr std::string_view kGolfBackswing     = "golf_backswing";       // power wind-up
  inline constexpr std::string_view kGolfSwing         = "golf_downswing";       // impact
  inline constexpr std::string_view kGolfFollowThrough = "golf_follow_through";  // finish
  inline constexpr std::string_view kGolfPutt          = "golf_putt_stroke";     // putting
  inline constexpr std::string_view kGolfChip          = "golf_chip_shot";       // chip near green
  inline constexpr std::string_view kGolfCelebrate     = "golf_celebrate";       // birdie/eagle

  // ── Story / traversal (KH1 + SA2 inspired) ───────────────────────────────
  // Rail grind clips (Sonic Adventure Battle 2 style)
  inline constexpr std::string_view kGrindEnter   = "grind_enter_lock";   // snap to rail
  inline constexpr std::string_view kGrindLoop    = "grind_loop_slide";   // sliding on rail
  inline constexpr std::string_view kGrindTrick   = "grind_trick_pose";   // mid-rail trick
  inline constexpr std::string_view kGrindJump    = "grind_jump_exit";    // jump off rail end

  // Flight / glide clips (Kingdom Hearts 1 Glide ability)
  inline constexpr std::string_view kFlightLaunch = "flight_launch_burst"; // initial takeoff
  inline constexpr std::string_view kFlightGlide  = "flight_glide_loop";   // sustained glide
  inline constexpr std::string_view kFlightBoost  = "flight_boost_surge";  // PRQ boost burst
  inline constexpr std::string_view kFlightLand   = "flight_land_soft";    // touch down

  // Board game traversal
  inline constexpr std::string_view kBoardMove    = "board_token_hop";     // moving token
  inline constexpr std::string_view kBoardLand    = "board_token_land";    // landing on space
  inline constexpr std::string_view kBoardBoss    = "board_boss_ready";    // boss trigger pose
} // namespace clips

// ──────────────────────────────────────────────────────────────────────────────
// CharacterAnimStateMachine
// Given: mode kind (as string_view "dunk_contest", "karate_endless", etc.)
//        game phase string  (e.g. "airborne", "combat", "idle")
//        last action string (e.g. "charge_begin", "light_strike")
// Returns: AnimClip { name, blendWeight, loop, speedScale }
//
// This is intentionally stateless/pure so it can be called any time without
// owning mode references — modes call it in stateJson() to fill "anim_clip".
// ──────────────────────────────────────────────────────────────────────────────
class CharacterAnimStateMachine {
public:
  [[nodiscard]] static auto resolve(std::string_view modeId,
                                    std::string_view phase,
                                    std::string_view lastAction) -> AnimClip;

  // Convenience: map a CombatAction integer (0=light, 1=heavy, 2=block, 3=dodge, 4=counter)
  // to the correct karate clip.
  [[nodiscard]] static auto combatActionClip(int actionInt) -> AnimClip;

  // Map a signature DunkStyle integer to the correct dunk clip.
  [[nodiscard]] static auto dunkStyleClip(int styleInt, bool airborne) -> AnimClip;
};

} // namespace nexus::gameplay
