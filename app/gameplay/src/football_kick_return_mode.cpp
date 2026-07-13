#include "nexus/gameplay/football_kick_return_mode.h"

#include <algorithm>
#include <cmath>

namespace nexus::gameplay {

namespace {

constexpr int kYardsForTouchdown = 50;  // yards per carry to reach endzone
constexpr float kMomentumDecay = 0.05F;

} // namespace

void FootballKickReturnMode::reset() {
  m_phase = KickReturnPhase::kReturning;
  m_touchdowns = 0;
  m_opponentScore = 0;
  m_yardsGained = 0;
  m_carryYards = 0;
  m_tacklesTaken = 0;
  m_dodgesLanded = 0;
  m_momentum = 0.0F;
}

void FootballKickReturnMode::update(double deltaSeconds) {
  if (m_phase == KickReturnPhase::kDriveOver) {
    return;
  }
  m_momentum = std::max(0.0F, m_momentum - static_cast<float>(deltaSeconds) * kMomentumDecay);
  if (m_phase == KickReturnPhase::kTackled) {
    // Reset carry after a brief tackle pause (handled externally by next run call)
    m_phase = KickReturnPhase::kReturning;
  }
}

auto FootballKickReturnMode::run(float direction, float burst) -> Result<nlohmann::json> {
  if (m_phase == KickReturnPhase::kDriveOver) {
    return Result<nlohmann::json>::err("drive already over");
  }

  const float dir = std::clamp(direction, -1.0F, 1.0F);
  const float b = std::clamp(burst, 0.0F, 1.0F);
  const float momentumBoost = 1.0F + m_momentum * 0.5F;
  const float baseYards = 3.0F + b * 8.0F;
  const int32_t yards = static_cast<int32_t>(std::round(baseYards * momentumBoost));

  advanceYards(dir, b);
  checkTouchdown();

  m_momentum = std::clamp(m_momentum + b * 0.15F, 0.0F, 1.0F);

  nlohmann::json payload = stateJson();
  payload["run"] = {
      {"direction", dir},
      {"burst", b},
      {"yards", yards},
      {"momentum", m_momentum},
  };
  payload["agent_envelope"] = {
      {"command", "fel.football.run"},
      {"yards_gained", m_yardsGained},
      {"touchdowns", m_touchdowns},
      {"momentum", m_momentum},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto FootballKickReturnMode::dodge(float direction) -> Result<nlohmann::json> {
  if (m_phase == KickReturnPhase::kDriveOver) {
    return Result<nlohmann::json>::err("drive already over");
  }

  const float dir = std::clamp(direction, -1.0F, 1.0F);
  ++m_dodgesLanded;
  // Successful dodge boosts momentum and avoids a tackle
  m_momentum = std::clamp(m_momentum + 0.20F, 0.0F, 1.0F);

  nlohmann::json payload = stateJson();
  payload["dodge"] = {
      {"direction", dir},
      {"dodges_landed", m_dodgesLanded},
      {"momentum", m_momentum},
  };
  payload["agent_envelope"] = {
      {"command", "fel.football.dodge"},
      {"dodges_landed", m_dodgesLanded},
      {"momentum", m_momentum},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto FootballKickReturnMode::lateral(float direction) -> Result<nlohmann::json> {
  if (m_phase == KickReturnPhase::kDriveOver) {
    return Result<nlohmann::json>::err("drive already over");
  }

  const float dir = std::clamp(direction, -1.0F, 1.0F);
  // Lateral cuts gain fewer yards but maintain momentum better
  const int32_t yards = static_cast<int32_t>(2.0F + std::abs(dir) * 4.0F);
  m_yardsGained += yards;
  m_carryYards += yards;
  m_momentum = std::clamp(m_momentum + 0.10F, 0.0F, 1.0F);
  checkTouchdown();

  nlohmann::json payload = stateJson();
  payload["lateral"] = {
      {"direction", dir},
      {"yards", yards},
      {"carry_yards", m_carryYards},
  };
  payload["agent_envelope"] = {
      {"command", "fel.football.lateral"},
      {"yards_gained", m_yardsGained},
      {"carry_yards", m_carryYards},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

void FootballKickReturnMode::advanceYards(float /*direction*/, float burst) {
  const float momentumBoost = 1.0F + m_momentum * 0.5F;
  const int32_t yards = static_cast<int32_t>(std::round((3.0F + burst * 8.0F) * momentumBoost));
  m_yardsGained += yards;
  m_carryYards += yards;

  // Opponent pressure: if running without dodges, risk a tackle
  if (m_dodgesLanded == 0 || (m_carryYards > 15 && burst < 0.5F)) {
    ++m_tacklesTaken;
    m_momentum = 0.0F;
    if (m_tacklesTaken >= kMaxTackles) {
      m_phase = KickReturnPhase::kDriveOver;
      return;
    }
    // Record opponent pressure on ceded possessions
    m_opponentScore += 3; // field goal
    resetCarry();
    m_phase = KickReturnPhase::kTackled;
  }
}

void FootballKickReturnMode::checkTouchdown() {
  if (m_phase == KickReturnPhase::kDriveOver) {
    return;
  }
  if (m_carryYards >= kYardsForTouchdown) {
    m_phase = KickReturnPhase::kTouchdown;
    ++m_touchdowns;
    resetCarry();
    if (m_touchdowns >= kWinTouchdowns) {
      m_phase = KickReturnPhase::kDriveOver;
    } else {
      m_phase = KickReturnPhase::kReturning;
    }
  }
}

void FootballKickReturnMode::resetCarry() {
  m_carryYards = 0;
  m_momentum = 0.0F;
}

auto FootballKickReturnMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"touchdowns", m_touchdowns},
      {"win_target", kWinTouchdowns},
      {"opponent_score", m_opponentScore},
      {"yards_gained", m_yardsGained},
      {"carry_yards", m_carryYards},
      {"tackles_taken", m_tacklesTaken},
      {"max_tackles", kMaxTackles},
      {"dodges_landed", m_dodgesLanded},
      {"momentum", m_momentum},
      {"drive_over", isDriveOver()},
      {"victory", isVictory()},
      {"release_state", "validate_only"},
  };
}

} // namespace nexus::gameplay
