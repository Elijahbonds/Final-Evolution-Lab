// Home Run Derby — Baseball_Park swipe-to-swing batting simulator (baseball)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

namespace nexus::gameplay {

enum class DerbyPhase : std::uint8_t {
  kBatting = 0,   // live at-bat
  kDerbyOver = 1, // win or out of outs
};

enum class SwingGrade : std::uint8_t {
  kMiss = 0,
  kContact = 1,
  kHomeRun = 2,
};

class HomeRunDerbyMode {
public:
  static constexpr int kWinHomeRuns = 10;
  static constexpr int kMaxOuts = 9;

  void reset();
  void update(double deltaSeconds);

  // pitch: speed [0,1], location [-1 left … +1 right]
  auto pitch(float speed, float location) -> Result<nlohmann::json>;
  // swing: timing [0,1], power [0,1]
  auto swing(float timing, float power) -> Result<nlohmann::json>;

  [[nodiscard]] auto homeRuns() const -> int32_t { return m_homeRuns; }
  [[nodiscard]] auto outs() const -> int32_t { return m_outs; }
  [[nodiscard]] auto isDerbyOver() const -> bool { return m_phase == DerbyPhase::kDerbyOver; }
  [[nodiscard]] auto isVictory() const -> bool {
    return m_phase == DerbyPhase::kDerbyOver && m_homeRuns >= kWinHomeRuns;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] auto gradeSwing(float timing, float power) const -> SwingGrade;

  DerbyPhase m_phase{DerbyPhase::kBatting};
  float m_pendingPitchSpeed{0.5F};
  float m_pendingPitchLocation{0.0F};
  bool m_pitchLive{false};
  int32_t m_homeRuns{0};
  int32_t m_outs{0};
  int32_t m_totalSwings{0};
  int32_t m_contacts{0};
  int32_t m_opponentHomeRuns{0};
};

} // namespace nexus::gameplay
