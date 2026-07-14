// Gymnastics — Training Floor rhythm-tap routine simulator (gymnastics)
// Inspirator: Olympic Games gymnastics / Beat Saber-style rhythm scoring
// Additions: D-score (declared difficulty 5.0/6.0/7.0) + E-score (execution),
//            apparatus rotation (floor/beam/vault/bars), fall deduction system.
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string_view>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class GymnasticsPhase     : std::uint8_t;
  enum class GymnasticsApparatus : std::uint8_t;
  enum class RoutineDifficulty   : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class GymnasticsPhase : std::uint8_t {
  kWarmup  = 0,
  kRoutine = 1,
  kScored  = 2,
};

// Four Olympic apparatus in rotation order.
enum class GymnasticsApparatus : std::uint8_t {
  kFloorExercise = 0,
  kBalanceBeam   = 1,
  kVault         = 2,
  kParallelBars  = 3,
};

// Player declares the difficulty value before each routine starts.
// Higher D-score = harder timing windows but higher score ceiling.
enum class RoutineDifficulty : std::uint8_t {
  kD5 = 0,  // base D-score 5.0 — balanced window
  kD6 = 1,  // D-score 6.0 — tighter perfect window
  kD7 = 2,  // D-score 7.0 — hardest window, highest ceiling
};

class GymnasticsMode {
public:
  static constexpr float kGoldThreshold = 85.0F;
  static constexpr int   kTargetElements = 6;

  // D-score base values.
  static constexpr float kDScoreD5 = 5.0F;
  static constexpr float kDScoreD6 = 6.0F;
  static constexpr float kDScoreD7 = 7.0F;

  // Olympic deduction constants.
  static constexpr float kDeductionMissedElement = 0.3F;  // per missed element
  static constexpr float kDeductionFall          = 1.0F;  // two consecutive misses = fall

  void reset();
  void update(double deltaSeconds);

  /// Declare the routine difficulty before starting.  Must be called before
  /// the first rhythmTap to take effect.
  auto declareRoutine(RoutineDifficulty difficulty) -> Result<nlohmann::json>;

  /// Advance to the next apparatus in the rotation sequence.
  auto rotateApparatus() -> Result<nlohmann::json>;

  auto rhythmTap(float timingNormalized, float difficulty) -> Result<nlohmann::json>;
  auto applyDeduction(float value) -> Result<nlohmann::json>;

  [[nodiscard]] auto judgeScore()     const -> float               { return m_judgeScore; }
  [[nodiscard]] auto dScore()         const -> float               { return m_dScore; }
  [[nodiscard]] auto eScore()         const -> float               { return m_eScore; }
  [[nodiscard]] auto apparatus()      const -> GymnasticsApparatus { return m_apparatus; }
  [[nodiscard]] auto routinesScored() const -> int                 { return m_routinesScored; }
  [[nodiscard]] auto isRoutineComplete() const -> bool {
    return m_phase == GymnasticsPhase::kScored;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] auto scoreTap(float timingNormalized, float difficulty) -> float;
  void checkCompletion();
  [[nodiscard]] static auto apparatusLabel(GymnasticsApparatus a) -> const char*;
  [[nodiscard]] static auto difficultyLabel(RoutineDifficulty d) -> const char*;
  [[nodiscard]] static auto dScoreForDifficulty(RoutineDifficulty d) -> float;
  // Apparatus modifies perfect/good timing thresholds.
  [[nodiscard]] auto perfectThreshold() const -> float;
  [[nodiscard]] auto goodThreshold()    const -> float;

  GymnasticsPhase     m_phase{GymnasticsPhase::kWarmup};
  GymnasticsApparatus m_apparatus{GymnasticsApparatus::kFloorExercise};
  RoutineDifficulty   m_declaredDifficulty{RoutineDifficulty::kD5};

  float m_judgeScore{0.0F};  // total = D-score + E-score − deductions
  float m_dScore{kDScoreD5};
  float m_eScore{0.0F};

  float m_difficultyTotal{0.0F};
  float m_executionTotal{0.0F};
  float m_artistryTotal{0.0F};
  int   m_elementsCompleted{0};
  int   m_consecutiveClean{0};
  int   m_consecutiveMisses{0};  // triggers fall penalty at 2
  int   m_deductions{0};
  float m_deductionPoints{0.0F};
  int   m_routinesScored{0};
};

} // namespace nexus::gameplay
