#include "nexus/gameplay/prq_engine.h"

namespace nexus::gameplay {

namespace {

constexpr float kSprintPrqScore = 75.0F;
constexpr float kSprintNeuralDrive = 60.0F;
constexpr float kPercentScale = 100.0F;

[[nodiscard]] auto hasFitnessSignal(const FitnessSnapshot& fitness) -> bool {
  return fitness.revision > 0;
}

[[nodiscard]] auto gradeForScore(float score) -> PRQGrade {
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

} // namespace

auto PRQEngine::getScore() -> float {
  return kSprintPrqScore;
}

auto PRQEngine::getScore(const FitnessSnapshot& fitness) -> float {
  if (!hasFitnessSignal(fitness)) {
    return getScore();
  }
  return fitness.powerReadiness * kPercentScale;
}

auto PRQEngine::getNeuralDrive() -> float {
  return kSprintNeuralDrive;
}

auto PRQEngine::getNeuralDrive(const FitnessSnapshot& fitness) -> float {
  if (!hasFitnessSignal(fitness)) {
    return getNeuralDrive();
  }
  return fitness.iapComposite * kPercentScale;
}

auto PRQEngine::getGrade() -> PRQGrade {
  return gradeForScore(getScore());
}

auto PRQEngine::getGrade(const FitnessSnapshot& fitness) -> PRQGrade {
  return gradeForScore(getScore(fitness));
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
