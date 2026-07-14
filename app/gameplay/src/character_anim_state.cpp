#include "nexus/gameplay/character_anim_state.h"

#include <string>

namespace nexus::gameplay {

auto CharacterAnimStateMachine::resolve(std::string_view modeId,
                                        std::string_view phase,
                                        std::string_view lastAction) -> AnimClip {
  // ── Dunk Contest ──────────────────────────────────────────────────────────
  if (modeId == "basketball_dunk") {
    if (phase == "charging") {
      return {std::string(clips::kDunkCharge), 1.0F, true, 1.0F};
    }
    if (phase == "launch") {
      return {std::string(clips::kDunkLaunch), 1.0F, false, 1.0F};
    }
    if (phase == "airborne") {
      // Resolve signature clip from last action
      if (lastAction == "360_scoop") {
        return {std::string(clips::kDunk360Scoop), 1.0F, false, 0.85F};
      }
      if (lastAction == "360_eastbay") {
        return {std::string(clips::kDunk360Eastbay), 1.0F, false, 0.85F};
      }
      if (lastAction == "360_fake_eastbay") {
        return {std::string(clips::kDunk360FakeEastbay), 1.0F, false, 0.9F};
      }
      if (lastAction == "off_board_windmill") {
        return {std::string(clips::kDunkOffBoardWindmill), 1.0F, false, 0.8F};
      }
      return {std::string(clips::kDunkAirborne), 1.0F, true, 1.0F};
    }
    if (phase == "scored") {
      return {std::string(clips::kDunkScore), 1.0F, false, 1.0F};
    }
    if (phase == "match_won") {
      return {std::string(clips::kDunkScore), 1.0F, false, 0.7F};
    }
    // Default dunk idle = approach run
    return {std::string(clips::kDunkApproach), 1.0F, true, 1.0F};
  }

  // ── Karate ────────────────────────────────────────────────────────────────
  if (modeId == "karate_endless" || modeId == "karate_kata") {
    if (phase == "victory") {
      return {std::string(clips::kKarateWin), 1.0F, false, 1.0F};
    }
    if (phase == "defeat") {
      return {std::string(clips::kKarateDown), 1.0F, false, 1.0F};
    }
    if (phase == "intermission") {
      return {std::string(clips::kKarateIdle), 1.0F, true, 0.6F};
    }
    // Combat phase — read last action
    if (lastAction == "light_strike") {
      return {std::string(clips::kKarateLightP), 1.0F, false, 1.1F};
    }
    if (lastAction == "heavy_strike") {
      return {std::string(clips::kKarateHeavyP), 1.0F, false, 0.9F};
    }
    if (lastAction == "kick") {
      return {std::string(clips::kKarateKick), 1.0F, false, 1.0F};
    }
    if (lastAction == "block") {
      return {std::string(clips::kKarateBlock), 1.0F, false, 1.2F};
    }
    if (lastAction == "dodge") {
      return {std::string(clips::kKarateDodge), 1.0F, false, 1.1F};
    }
    if (lastAction == "counter") {
      return {std::string(clips::kKarateCounter), 1.0F, false, 0.85F};
    }
    if (lastAction == "hit") {
      return {std::string(clips::kKarateHit), 1.0F, false, 1.0F};
    }
    return {std::string(clips::kKarateIdle), 1.0F, true, 1.0F};
  }

  // ── Basketball pickup / 3v3 ───────────────────────────────────────────────
  if (modeId == "basketball_h2h" || modeId == "venice_pickup" || modeId == "basketball_3v3") {
    if (lastAction == "shoot") {
      return {std::string(clips::kBballShoot), 1.0F, false, 1.0F};
    }
    if (lastAction == "score") {
      return {std::string(clips::kBballScore), 1.0F, false, 1.0F};
    }
    if (lastAction == "block") {
      return {std::string(clips::kBballBlock), 1.0F, false, 1.1F};
    }
    if (lastAction == "defend") {
      return {std::string(clips::kBballDefend), 1.0F, true, 1.0F};
    }
    return {std::string(clips::kBballDribble), 1.0F, true, 1.0F};
  }

  // ── Soccer ────────────────────────────────────────────────────────────────
  if (modeId == "soccer") {
    if (lastAction == "shoot") {
      return {std::string(clips::kSoccerShoot), 1.0F, false, 1.0F};
    }
    if (lastAction == "pass") {
      return {std::string(clips::kSoccerPass), 1.0F, false, 1.1F};
    }
    if (lastAction == "tackle") {
      return {std::string(clips::kSoccerTackle), 1.0F, false, 0.9F};
    }
    if (lastAction == "goal" || phase == "goal") {
      return {std::string(clips::kSoccerCeleb), 1.0F, false, 0.85F};
    }
    if (lastAction == "header") {
      return {std::string(clips::kSoccerHeader), 1.0F, false, 1.0F};
    }
    return {std::string(clips::kSoccerDribble), 1.0F, true, 1.0F};
  }

  // ── Football kick return ──────────────────────────────────────────────────
  if (modeId == "football") {
    if (phase == "touchdown") {
      return {std::string(clips::kFbTouchdown), 1.0F, false, 0.85F};
    }
    if (phase == "tackled") {
      return {std::string(clips::kFbTackled), 1.0F, false, 1.0F};
    }
    if (lastAction == "juke_left") {
      return {std::string(clips::kFbJukeLeft), 1.0F, false, 1.2F};
    }
    if (lastAction == "juke_right") {
      return {std::string(clips::kFbJukeRight), 1.0F, false, 1.2F};
    }
    if (lastAction == "spin") {
      return {std::string(clips::kFbSpin), 1.0F, false, 1.0F};
    }
    if (lastAction == "stiff_arm") {
      return {std::string(clips::kFbStiffArm), 1.0F, false, 1.1F};
    }
    return {std::string(clips::kFbSprint), 1.0F, true, 1.0F};
  }

  // ── Board sports ──────────────────────────────────────────────────────────
  if (modeId == "skateboarding") {
    if (lastAction == "bail") {
      return {std::string(clips::kSkateBail), 1.0F, false, 1.0F};
    }
    if (lastAction == "kickflip") {
      return {std::string(clips::kSkateKickflip), 1.0F, false, 1.0F};
    }
    if (lastAction == "heelflip") {
      return {std::string(clips::kSkateHeelflip), 1.0F, false, 1.0F};
    }
    if (lastAction == "treflip" || lastAction == "360flip") {
      return {std::string(clips::kSkateTreflip), 1.0F, false, 0.9F};
    }
    return {std::string(clips::kSkateIdle), 1.0F, true, 1.0F};
  }
  if (modeId == "snowboarding") {
    if (lastAction == "jump") {
      return {std::string(clips::kSnowJump), 1.0F, false, 1.0F};
    }
    if (lastAction == "grab") {
      return {std::string(clips::kSnowGrab), 1.0F, false, 1.0F};
    }
    return {std::string(clips::kSnowCarve), 1.0F, true, 1.0F};
  }
  if (modeId == "surfing") {
    if (lastAction == "aerial") {
      return {std::string(clips::kSurfAerial), 1.0F, false, 1.0F};
    }
    if (lastAction == "tube_ride") {
      return {std::string(clips::kSurfTube), 1.0F, true, 1.0F};
    }
    return {std::string(clips::kSurfCarve), 1.0F, true, 1.0F};
  }

  // ── Default fallback (never T-pose) ───────────────────────────────────────
  return {std::string(clips::kIdle), 1.0F, true, 1.0F};
}

auto CharacterAnimStateMachine::combatActionClip(int actionInt) -> AnimClip {
  // CombatAction: 0=light, 1=heavy, 2=block, 3=dodge, 4=counter
  switch (actionInt) {
  case 0: return {std::string(clips::kKarateLightP), 1.0F, false, 1.1F};
  case 1: return {std::string(clips::kKarateHeavyP), 1.0F, false, 0.9F};
  case 2: return {std::string(clips::kKarateBlock),  1.0F, false, 1.2F};
  case 3: return {std::string(clips::kKarateDodge),  1.0F, false, 1.1F};
  case 4: return {std::string(clips::kKarateCounter),1.0F, false, 0.85F};
  default: return {std::string(clips::kKarateIdle),  1.0F, true,  1.0F};
  }
}

auto CharacterAnimStateMachine::dunkStyleClip(int styleInt, bool airborne) -> AnimClip {
  // DunkStyle: 0=Standard, 1=Flashy, 2=Power, 3=Signature,
  //            4=360Scoop, 5=360Eastbay, 6=360FakeEastbay, 7=OffBackboardWindmill
  if (!airborne) {
    return {std::string(clips::kDunkApproach), 1.0F, true, 1.0F};
  }
  switch (styleInt) {
  case 4: return {std::string(clips::kDunk360Scoop),         1.0F, false, 0.85F};
  case 5: return {std::string(clips::kDunk360Eastbay),       1.0F, false, 0.85F};
  case 6: return {std::string(clips::kDunk360FakeEastbay),   1.0F, false, 0.9F};
  case 7: return {std::string(clips::kDunkOffBoardWindmill), 1.0F, false, 0.8F};
  default: return {std::string(clips::kDunkAirborne),        1.0F, true,  1.0F};
  }
}

} // namespace nexus::gameplay
