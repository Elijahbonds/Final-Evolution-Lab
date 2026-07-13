#include "nexus/gameplay/soccer_penalty_mode.h"

#include <algorithm>
#include <cmath>

namespace nexus::gameplay {

namespace {

// Base save probability per aim zone (keeper is well-positioned for center)
constexpr float kSaveChanceCenter = 0.55F;
constexpr float kSaveChanceSide = 0.30F;
constexpr float kSaveChanceTop = 0.18F;
// Power above this threshold reduces save chance further
constexpr float kPowerThreshold = 0.75F;

} // namespace

void SoccerPenaltyMode::reset() {
  m_phase = PenaltyPhase::kPlayerShoot;
  m_playerGoals = 0;
  m_opponentGoals = 0;
  m_round = 1;
  m_playerKicksTaken = 0;
  m_opponentKicksTaken = 0;
  m_suddenDeath = false;
}

void SoccerPenaltyMode::update(double /*deltaSeconds*/) {
  // Turn-based — no time-based transitions
}

auto SoccerPenaltyMode::shoot(AimZone zone, float power) -> Result<nlohmann::json> {
  if (m_phase != PenaltyPhase::kPlayerShoot) {
    return Result<nlohmann::json>::err("not player shoot phase");
  }
  if (m_phase == PenaltyPhase::kMatchOver) {
    return Result<nlohmann::json>::err("match already over");
  }

  const float p = std::clamp(power, 0.0F, 1.0F);
  ++m_playerKicksTaken;

  // Compute whether keeper saves it
  const float saveProbability = keeperSaveChance(zone, p);
  // Pseudo-deterministic: use kick count + power to produce a fair result
  const float outcomeScore = 0.5F + (p - 0.5F) * 0.6F -
                             saveProbability * 0.5F +
                             static_cast<float>(m_playerKicksTaken % 3) * 0.05F;
  const bool scored = outcomeScore > 0.5F;

  if (scored) {
    ++m_playerGoals;
  }

  // Transition: player shot → opponent shot
  m_phase = PenaltyPhase::kOpponentShoot;

  // Immediately simulate opponent kick
  const bool opponentScored = opponentShootGoal();
  if (opponentScored) {
    ++m_opponentGoals;
  }
  ++m_opponentKicksTaken;
  m_phase = PenaltyPhase::kPlayerShoot;

  // End-of-round check
  if (m_playerKicksTaken >= kRoundsMain && m_opponentKicksTaken >= kRoundsMain && !m_suddenDeath) {
    if (m_playerGoals != m_opponentGoals) {
      m_phase = PenaltyPhase::kMatchOver;
    } else {
      m_suddenDeath = true;
      ++m_round;
    }
  } else if (m_suddenDeath && m_playerKicksTaken > m_opponentKicksTaken &&
             m_playerGoals != m_opponentGoals) {
    m_phase = PenaltyPhase::kMatchOver;
  } else if (!m_suddenDeath && m_playerGoals >= kWinGoals) {
    m_phase = PenaltyPhase::kMatchOver;
  } else if (!m_suddenDeath && m_playerKicksTaken > 0 &&
             m_opponentGoals >= kWinGoals) {
    m_phase = PenaltyPhase::kMatchOver;
  } else {
    ++m_round;
  }

  const char* zoneLabel = [zone]() {
    switch (zone) {
      case AimZone::kLeft:     return "left";
      case AimZone::kRight:    return "right";
      case AimZone::kCenter:   return "center";
      case AimZone::kTopLeft:  return "top_left";
      case AimZone::kTopRight: return "top_right";
    }
    return "center";
  }();

  nlohmann::json payload = stateJson();
  payload["shoot"] = {
      {"aim_zone", zoneLabel},
      {"power", p},
      {"scored", scored},
      {"opponent_scored", opponentScored},
  };
  payload["agent_envelope"] = {
      {"command", "fel.soccer.shoot"},
      {"player_goals", m_playerGoals},
      {"opponent_goals", m_opponentGoals},
      {"round", m_round},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SoccerPenaltyMode::save(float diveDirection) -> Result<nlohmann::json> {
  if (m_phase == PenaltyPhase::kMatchOver) {
    return Result<nlohmann::json>::err("match already over");
  }

  // Player acts as keeper on opponent's turn — dive decision affects next opponent kick
  const float dir = std::clamp(diveDirection, -1.0F, 1.0F);

  nlohmann::json payload = stateJson();
  payload["save"] = {
      {"dive_direction", dir},
      {"note", "keeper dive registered; affects next opponent shot"},
  };
  payload["agent_envelope"] = {
      {"command", "fel.soccer.save"},
      {"dive_direction", dir},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto SoccerPenaltyMode::keeperSaveChance(AimZone zone, float power) const -> float {
  float base = 0.0F;
  switch (zone) {
    case AimZone::kCenter:   base = kSaveChanceCenter; break;
    case AimZone::kLeft:
    case AimZone::kRight:    base = kSaveChanceSide; break;
    case AimZone::kTopLeft:
    case AimZone::kTopRight: base = kSaveChanceTop; break;
  }
  // High power shots harder to save
  if (power >= kPowerThreshold) {
    base *= (1.0F - (power - kPowerThreshold) * 0.4F);
  }
  return std::clamp(base, 0.05F, 0.80F);
}

auto SoccerPenaltyMode::opponentShootGoal() const -> bool {
  // Opponent scores ~65% of the time; harder in sudden death
  const float successRate = m_suddenDeath ? 0.58F : 0.65F;
  // Pseudo-deterministic based on kick count parity
  const float score = successRate -
                      static_cast<float>(m_opponentKicksTaken % 4) * 0.03F +
                      (m_opponentKicksTaken % 2 == 0 ? 0.02F : -0.02F);
  return score > 0.5F;
}

auto SoccerPenaltyMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"player_goals", m_playerGoals},
      {"opponent_goals", m_opponentGoals},
      {"round", m_round},
      {"rounds_main", kRoundsMain},
      {"win_target", kWinGoals},
      {"player_kicks_taken", m_playerKicksTaken},
      {"opponent_kicks_taken", m_opponentKicksTaken},
      {"sudden_death", m_suddenDeath},
      {"match_over", isMatchOver()},
      {"victory", isVictory()},
      {"release_state", "validate_only"},
  };
}

void SoccerPenaltyMode::advancePhase() {
  if (m_phase == PenaltyPhase::kPlayerShoot) {
    m_phase = PenaltyPhase::kOpponentShoot;
  } else if (m_phase == PenaltyPhase::kOpponentShoot) {
    m_phase = PenaltyPhase::kPlayerShoot;
  }
}

} // namespace nexus::gameplay
