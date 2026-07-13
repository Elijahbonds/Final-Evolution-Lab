// Football Kick Return — Gridiron_Stadium kick-return runner simulator (football)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

namespace nexus::gameplay {

enum class KickReturnPhase : std::uint8_t {
  kReturning = 0, // runner advancing downfield
  kTackled = 1,   // down after contact
  kTouchdown = 2, // endzone reached
  kDriveOver = 3, // win or possession exhausted
};

class FootballKickReturnMode {
public:
  static constexpr int kWinTouchdowns = 3;
  static constexpr int kMaxTackles = 6;

  void reset();
  void update(double deltaSeconds);

  // run: direction [-1 left … +1 right], burst [0,1]
  auto run(float direction, float burst) -> Result<nlohmann::json>;
  // dodge: direction [-1 … +1] to evade an incoming tackler
  auto dodge(float direction) -> Result<nlohmann::json>;
  // lateral: quick lateral cut, direction [-1,+1]
  auto lateral(float direction) -> Result<nlohmann::json>;

  [[nodiscard]] auto touchdowns() const -> int32_t { return m_touchdowns; }
  [[nodiscard]] auto yardsGained() const -> int32_t { return m_yardsGained; }
  [[nodiscard]] auto isDriveOver() const -> bool { return m_phase == KickReturnPhase::kDriveOver; }
  [[nodiscard]] auto isVictory() const -> bool {
    return m_phase == KickReturnPhase::kDriveOver && m_touchdowns >= kWinTouchdowns;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  void advanceYards(float direction, float burst);
  void checkTouchdown();
  void resetCarry();

  KickReturnPhase m_phase{KickReturnPhase::kReturning};
  int32_t m_touchdowns{0};
  int32_t m_opponentScore{0}; // field goals ceded
  int32_t m_yardsGained{0};
  int32_t m_carryYards{0};    // yards this possession
  int32_t m_tacklesTaken{0};
  int32_t m_dodgesLanded{0};
  float m_momentum{0.0F};     // 0-1, boosts burst
};

} // namespace nexus::gameplay
