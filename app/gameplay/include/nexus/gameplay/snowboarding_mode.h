// Snowboarding — Mountain Slope carve/jump/butter simulator (snowboarding)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class SnowPhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class SnowPhase : std::uint8_t {
  kRun = 0,
  kRunComplete = 1,
};

class SnowboardingMode {
public:
  static constexpr int kWinScore = 50;
  static constexpr int kMaxWipeouts = 4;

  void reset();
  void update(double deltaSeconds);

  auto carve(float timing, float lineDifficulty) -> Result<nlohmann::json>;
  auto jump(float airDifficulty, int32_t comboMultiplier) -> Result<nlohmann::json>;
  auto butter(float style) -> Result<nlohmann::json>;
  /// Grab during a jump — adds style multiplier and flow bonus.
  /// grabName: "indy", "melon", "stalefish", "mute", "tail", "nose" (others treated as generic).
  auto grab(std::string_view grabName, float timing) -> Result<nlohmann::json>;
  auto wipeout() -> Result<nlohmann::json>;

  [[nodiscard]] auto lineScore() const -> int32_t { return static_cast<int32_t>(m_lineScore); }
  [[nodiscard]] auto isRunComplete() const -> bool {
    return m_phase == SnowPhase::kRunComplete;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  SnowPhase m_phase{SnowPhase::kRun};
  float m_lineScore{0.0F};
  float m_flowMeter{0.0F};
  int32_t m_comboMultiplier{1};
  int32_t m_carvesLanded{0};
  int32_t m_jumpsLanded{0};
  int32_t m_butterMoves{0};
  int32_t m_grabs{0};
  int32_t m_wipeouts{0};
  int32_t m_peakCombo{1};
};

} // namespace nexus::gameplay
