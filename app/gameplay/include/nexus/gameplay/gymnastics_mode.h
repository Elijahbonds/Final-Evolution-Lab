// Gymnastics — Training Floor rhythm-tap routine simulator (gymnastics)
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class GymnasticsPhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class GymnasticsPhase : std::uint8_t {
  kWarmup = 0,
  kRoutine = 1,
  kScored = 2,
};

class GymnasticsMode {
public:
  static constexpr float kGoldThreshold = 85.0F;
  static constexpr int kTargetElements = 6;

  void reset();
  void update(double deltaSeconds);

  auto rhythmTap(float timingNormalized, float difficulty) -> Result<nlohmann::json>;
  auto applyDeduction(float value) -> Result<nlohmann::json>;

  [[nodiscard]] auto judgeScore() const -> float { return m_judgeScore; }
  [[nodiscard]] auto isRoutineComplete() const -> bool {
    return m_phase == GymnasticsPhase::kScored;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] auto scoreTap(float timingNormalized, float difficulty) -> float;
  void checkCompletion();

  GymnasticsPhase m_phase{GymnasticsPhase::kWarmup};
  float m_judgeScore{0.0F};
  float m_difficultyTotal{0.0F};
  float m_executionTotal{0.0F};
  float m_artistryTotal{0.0F};
  int m_elementsCompleted{0};
  int m_consecutiveClean{0};
  int m_deductions{0};
  float m_deductionPoints{0.0F};
};

} // namespace nexus::gameplay
