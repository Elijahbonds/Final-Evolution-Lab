#include "nexus/gameplay/gymnastics_mode.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kTimingPerfectThreshold = 0.92F;
constexpr float kTimingGoodThreshold = 0.65F;

} // namespace

void GymnasticsMode::reset() {
  m_phase = GymnasticsPhase::kWarmup;
  m_judgeScore = 0.0F;
  m_difficultyTotal = 0.0F;
  m_executionTotal = 0.0F;
  m_artistryTotal = 0.0F;
  m_elementsCompleted = 0;
  m_consecutiveClean = 0;
  m_deductions = 0;
  m_deductionPoints = 0.0F;
}

void GymnasticsMode::update(double /*deltaSeconds*/) {
  if (m_phase == GymnasticsPhase::kScored) {
    return;
  }
}

auto GymnasticsMode::rhythmTap(float timingNormalized, float difficulty)
    -> Result<nlohmann::json> {
  if (m_phase == GymnasticsPhase::kScored) {
    return Result<nlohmann::json>::err("gymnastics routine already scored");
  }

  const float timing = std::clamp(timingNormalized, 0.0F, 1.0F);
  const float diff = std::clamp(difficulty, 0.1F, 1.0F);
  m_phase = GymnasticsPhase::kRoutine;

  const float elementScore = scoreTap(timing, diff);
  // Flow momentum: consecutive clean elements (timing ≥ good threshold) grant compounding bonus.
  const bool isClean = timing >= kTimingGoodThreshold;
  if (isClean) {
    ++m_consecutiveClean;
  } else {
    m_consecutiveClean = 0;
  }
  const float flowBonus = m_consecutiveClean >= 3 ? 1.15F : m_consecutiveClean >= 2 ? 1.07F : 1.0F;
  const float scoredElement = elementScore * flowBonus;

  m_judgeScore = std::min(m_judgeScore + scoredElement, 100.0F);
  m_difficultyTotal += diff * 10.0F;
  m_executionTotal += scoredElement * 0.6F;
  m_artistryTotal += scoredElement * 0.4F;
  ++m_elementsCompleted;
  checkCompletion();

  return Result<nlohmann::json>::ok({
      {"gymnastics", stateJson()},
      {"tap",
       {{"timing", timing},
        {"difficulty", diff},
        {"element_score", scoredElement},
        {"flow_bonus", flowBonus},
        {"consecutive_clean", m_consecutiveClean},
        {"grade", timing >= kTimingPerfectThreshold   ? "perfect"
                  : timing >= kTimingGoodThreshold    ? "good"
                                                      : "miss"}}},
      {"release_state", "validate_only"},
  });
}

auto GymnasticsMode::applyDeduction(float value) -> Result<nlohmann::json> {
  if (m_phase == GymnasticsPhase::kScored) {
    return Result<nlohmann::json>::err("gymnastics routine already scored");
  }

  const float deduction = std::clamp(value, 0.1F, 5.0F);
  ++m_deductions;
  m_deductionPoints += deduction;
  m_judgeScore = std::max(m_judgeScore - deduction, 0.0F);
  m_consecutiveClean = 0;
  checkCompletion();

  return Result<nlohmann::json>::ok({
      {"gymnastics", stateJson()},
      {"deduction", {{"value", deduction}, {"total_deductions", m_deductions}}},
      {"release_state", "validate_only"},
  });
}

auto GymnasticsMode::scoreTap(float timingNormalized, float difficulty) -> float {
  const float base = timingNormalized >= kTimingPerfectThreshold   ? 14.0F
                     : timingNormalized >= kTimingGoodThreshold    ? 9.0F
                                                                   : 4.0F;
  return base * (0.75F + difficulty * 0.25F);
}

void GymnasticsMode::checkCompletion() {
  if (m_elementsCompleted >= kTargetElements || m_judgeScore >= kGoldThreshold) {
    m_phase = GymnasticsPhase::kScored;
  }
}

auto GymnasticsMode::stateJson() const -> nlohmann::json {
  return {
      {"phase", static_cast<int>(m_phase)},
      {"judge_score", m_judgeScore},
      {"gold_threshold", kGoldThreshold},
      {"difficulty_total", m_difficultyTotal},
      {"execution_total", m_executionTotal},
      {"artistry_total", m_artistryTotal},
      {"elements_completed", m_elementsCompleted},
      {"target_elements", kTargetElements},
      {"consecutive_clean", m_consecutiveClean},
      {"deductions", m_deductions},
      {"deduction_points", m_deductionPoints},
      {"routine_complete", isRoutineComplete()},
  };
}

} // namespace nexus::gameplay
