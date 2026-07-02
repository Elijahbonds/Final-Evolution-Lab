#include "nexus/gameplay/prq_engine.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kSprintPrqScore = 75.0F;
constexpr float kSprintNeuralDrive = 60.0F;

[[nodiscard]] auto unitToPercent(float value) -> float {
  return std::clamp(value, 0.0F, 1.0F) * 100.0F;
}

} // namespace

auto PRQEngine::getScore() -> float {
  return kSprintPrqScore;
}

auto PRQEngine::getNeuralDrive() -> float {
  return kSprintNeuralDrive;
}

auto PRQEngine::getGrade() -> PRQGrade {
  return gradeForScore(getScore());
}

auto PRQEngine::scoreFromFitness(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getScore();
  }
  return unitToPercent(snapshot.powerReadiness);
}

auto PRQEngine::neuralDriveFromFitness(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getNeuralDrive();
  }
  return unitToPercent(snapshot.iapComposite);
}

auto PRQEngine::gradeForScore(float score) -> PRQGrade {
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

auto PRQEngine::gradeFromFitness(const FitnessSnapshot& snapshot) -> PRQGrade {
  return gradeForScore(scoreFromFitness(snapshot));
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
