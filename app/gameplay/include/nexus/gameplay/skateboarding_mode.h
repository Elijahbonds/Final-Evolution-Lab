// Skateboarding — Skate Park line/trick/combo simulator (skateboarding)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

namespace nexus::gameplay {

enum class SkatePhase : std::uint8_t {
  kRun = 0,
  kRunComplete = 1,
};

class SkateboardingMode {
public:
  static constexpr int kWinScore = 50;
  static constexpr int kMaxBails = 5;

  void reset();
  void update(double deltaSeconds);

  auto landTrick(float difficulty, int32_t comboMultiplier) -> Result<nlohmann::json>;
  auto bail() -> Result<nlohmann::json>;

  [[nodiscard]] auto trickScore() const -> int32_t { return m_trickScore; }
  [[nodiscard]] auto isRunComplete() const -> bool {
    return m_phase == SkatePhase::kRunComplete;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  SkatePhase m_phase{SkatePhase::kRun};
  float m_trickScore{0.0F};
  int32_t m_comboMultiplier{1};
  int32_t m_tricksLanded{0};
  int32_t m_tricksBailed{0};
  int32_t m_peakCombo{1};
};

} // namespace nexus::gameplay
