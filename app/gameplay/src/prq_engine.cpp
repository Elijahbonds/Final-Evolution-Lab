#include "nexus/gameplay/prq_engine.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kSprintPrqScore = 75.0F;
constexpr float kSprintNeuralDrive = 60.0F;

[[nodiscard]] auto clampPercent(float value) -> float {
  return std::clamp(value, 0.0F, 100.0F);
}

} // namespace

auto PRQEngine::getScore() -> float {
  return kSprintPrqScore;
}

auto PRQEngine::getScore(const FitnessSnapshot& fitness) -> float {
  if (fitness.revision == 0) {
    return getScore();
  }
  return clampPercent(fitness.powerReadiness * 100.0F);
}

auto PRQEngine::getNeuralDrive() -> float {
  return kSprintNeuralDrive;
}

auto PRQEngine::getNeuralDrive(const FitnessSnapshot& fitness) -> float {
  if (fitness.revision == 0) {
    return getNeuralDrive();
  }

  const float breathPhaseBoost = fitness.iap.breathPhase > 0   ? 0.20F
                                : fitness.iap.breathPhase < 0 ? 0.05F
                                                               : 0.10F;
  const float neuralReadiness = fitness.iap.engagementScore * 0.45F +
                                fitness.iap.confidence * 0.35F + breathPhaseBoost;
  return clampPercent(neuralReadiness * 100.0F);
}

auto PRQEngine::getGrade() -> PRQGrade {
  return getGrade(getScore());
}

auto PRQEngine::getGrade(float score) -> PRQGrade {
  if (score >= 80.0F) {
    return PRQGrade::kElite;
  }
  if (score >= 60.0F) {
    return PRQGrade::kPrimed;
  }
  if (score >= 40.0F) {
    return PRQGrade::kReady;
  }
  return PRQGrade::kRecovering;
}

auto PRQEngine::getGrade(const FitnessSnapshot& fitness) -> PRQGrade {
  return getGrade(getScore(fitness));
}

auto PRQEngine::gradeLabel(PRQGrade grade) -> std::string_view {
  switch (grade) {
  case PRQGrade::kElite:
    return "ELITE";
  case PRQGrade::kPrimed:
    return "PRIMED";
  case PRQGrade::kReady:
    return "READY";
  case PRQGrade::kRecovering:
    return "RECOVERING";
  }
  return "UNKNOWN";
}

} // namespace nexus::gameplay
