// Surfing — Venice Beach wave/carve/aerial simulator (surfing)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

namespace nexus::gameplay {

enum class SurfPhase : std::uint8_t {
  kRun = 0,
  kRunComplete = 1,
};

class SurfingMode {
public:
  static constexpr int kWinScore = 75;
  static constexpr int kMaxWipeouts = 4;

  void reset();
  void update(double deltaSeconds);

  auto carve(float timing, float waveDifficulty) -> Result<nlohmann::json>;
  auto aerial(float airDifficulty, int32_t comboMultiplier) -> Result<nlohmann::json>;
  auto wipeout() -> Result<nlohmann::json>;

  [[nodiscard]] auto waveScore() const -> int32_t { return static_cast<int32_t>(m_waveScore); }
  [[nodiscard]] auto isRunComplete() const -> bool {
    return m_phase == SurfPhase::kRunComplete;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  SurfPhase m_phase{SurfPhase::kRun};
  float m_waveScore{0.0F};
  float m_flowMeter{0.0F};
  int32_t m_comboMultiplier{1};
  int32_t m_carvesLanded{0};
  int32_t m_aerialsLanded{0};
  int32_t m_wipeouts{0};
  int32_t m_peakCombo{1};
};

} // namespace nexus::gameplay
