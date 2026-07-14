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
  inline constexpr std::string_view kRun          = "run_forward";
  inline constexpr std::string_view kRunBack      = "run_backward";
  inline constexpr std::string_view kSprint       = "sprint_forward";
  inline constexpr std::string_view kJump         = "jump_up";
  inline constexpr std::string_view kLand         = "jump_land";
  inline constexpr std::string_view kFall         = "fall_loop";
  inline constexpr std::string_view kStrafe_L     = "strafe_left";
  inline constexpr std::string_view kStrafe_R     = "strafe_right";

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

  // ── Basketball (pickup / 3v3) ────────────────────────────────────────────
  inline constexpr std::string_view kBballDribble = "bball_dribble_run";
  inline constexpr std::string_view kBballShoot   = "bball_shoot_jumper";
  inline constexpr std::string_view kBballScore   = "bball_score_celebrate";
  inline constexpr std::string_view kBballDefend  = "bball_defend_stance";
  inline constexpr std::string_view kBballBlock   = "bball_block_reach";

  // ── Soccer ───────────────────────────────────────────────────────────────
  inline constexpr std::string_view kSoccerDribble= "soccer_dribble_jog";
  inline constexpr std::string_view kSoccerShoot  = "soccer_kick_shoot";
  inline constexpr std::string_view kSoccerPass   = "soccer_kick_pass";
  inline constexpr std::string_view kSoccerTackle = "soccer_tackle_slide";
  inline constexpr std::string_view kSoccerCeleb  = "soccer_goal_celebrate";
  inline constexpr std::string_view kSoccerHeader = "soccer_header_jump";

  // ── Football / Kick Return ───────────────────────────────────────────────
  inline constexpr std::string_view kFbSprint     = "football_sprint_return";
  inline constexpr std::string_view kFbJukeLeft   = "football_juke_left";
  inline constexpr std::string_view kFbJukeRight  = "football_juke_right";
  inline constexpr std::string_view kFbSpin       = "football_spin_move";
  inline constexpr std::string_view kFbStiffArm   = "football_stiff_arm";
  inline constexpr std::string_view kFbTouchdown  = "football_touchdown_spike";
  inline constexpr std::string_view kFbTackled    = "football_tackled_fall";

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
