// Soccer Penalty Shootout — Soccer_Stadium penalty-kick/save alternating simulator (soccer)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

namespace nexus::gameplay {

enum class PenaltyPhase : std::uint8_t {
  kPlayerShoot = 0,    // player takes the kick
  kOpponentShoot = 1,  // opponent takes the kick
  kMatchOver = 2,
};

// Aim zones for shot placement
enum class AimZone : std::uint8_t {
  kLeft = 0,
  kCenter = 1,
  kRight = 2,
  kTopLeft = 3,
  kTopRight = 4,
};

class SoccerPenaltyMode {
public:
  static constexpr int kRoundsMain = 5;   // kicks each in regulation
  static constexpr int kWinGoals = 3;     // early win threshold

  void reset();
  void update(double deltaSeconds);

  // shoot: aim_zone [0-4], power [0,1]
  auto shoot(AimZone zone, float power) -> Result<nlohmann::json>;
  // save: dive_direction [-1 left … +1 right]
  auto save(float diveDirection) -> Result<nlohmann::json>;

  [[nodiscard]] auto playerGoals() const -> int32_t { return m_playerGoals; }
  [[nodiscard]] auto opponentGoals() const -> int32_t { return m_opponentGoals; }
  [[nodiscard]] auto round() const -> int32_t { return m_round; }
  [[nodiscard]] auto phase() const -> PenaltyPhase { return m_phase; }
  [[nodiscard]] auto isMatchOver() const -> bool { return m_phase == PenaltyPhase::kMatchOver; }
  [[nodiscard]] auto isVictory() const -> bool {
    return m_phase == PenaltyPhase::kMatchOver && m_playerGoals > m_opponentGoals;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void advancePhase();
  [[nodiscard]] auto keeperSaveChance(AimZone zone, float power) const -> float;
  [[nodiscard]] auto opponentShootGoal() const -> bool;

  PenaltyPhase m_phase{PenaltyPhase::kPlayerShoot};
  int32_t m_playerGoals{0};
  int32_t m_opponentGoals{0};
  int32_t m_round{1};
  int32_t m_playerKicksTaken{0};
  int32_t m_opponentKicksTaken{0};
  bool m_suddenDeath{false};
};

} // namespace nexus::gameplay
