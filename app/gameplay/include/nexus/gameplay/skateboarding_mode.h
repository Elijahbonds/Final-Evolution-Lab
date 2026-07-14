// Skateboarding — Skate Park line/trick/combo simulator (skateboarding)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class SkatePhase : std::uint8_t;
} } // namespace nexus::gameplay

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
  /// Named trick variant — resolves trick name to canonical difficulty and awards timing bonus.
  /// Trick names: kickflip, heelflip, treflip, 360flip, noseslide, manual, 50-50, nollie, hardflip.
  auto onNamedTrick(std::string_view trickName, float timingNormalized) -> Result<nlohmann::json>;
  auto bail() -> Result<nlohmann::json>;

  [[nodiscard]] auto trickScore() const -> int32_t { return m_trickScore; }
  [[nodiscard]] auto isRunComplete() const -> bool {
    return m_phase == SkatePhase::kRunComplete;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] static auto trickDifficulty(std::string_view trickName) -> float;
  [[nodiscard]] static auto timingBonus(float timingNormalized) -> float;

  SkatePhase m_phase{SkatePhase::kRun};
  float m_trickScore{0.0F};
  int32_t m_comboMultiplier{1};
  int32_t m_tricksLanded{0};
  int32_t m_tricksBailed{0};
  int32_t m_peakCombo{1};
  std::string m_lastTrickName;
};

} // namespace nexus::gameplay
