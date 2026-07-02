#include "nexus/gameplay/prq_engine.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kSprintPrqScore = 75.0F;
constexpr float kSprintNeuralDrive = 60.0F;

[[nodiscard]] auto hasLiveFitness(const FitnessSnapshot& snapshot) -> bool {
  return snapshot.revision > 0;
}

[[nodiscard]] auto scoreFromSnapshot(const FitnessSnapshot& snapshot) -> float {
  const float readiness = std::clamp(snapshot.powerReadiness, 0.0F, 1.0F);
  const float frcComposite = std::clamp(snapshot.frcComposite, 0.0F, 1.0F);
  const float control = std::clamp(snapshot.frc.controlScore, 0.0F, 1.0F);
  return std::clamp((readiness * 0.50F + frcComposite * 0.30F + control * 0.20F) * 100.0F,
                    0.0F,
                    100.0F);
}

[[nodiscard]] auto neuralDriveFromSnapshot(const FitnessSnapshot& snapshot) -> float {
  const float breath = std::clamp(snapshot.iapComposite, 0.0F, 1.0F);
  const float control = std::clamp(snapshot.frc.controlScore, 0.0F, 1.0F);
  return std::clamp((breath * 0.65F + control * 0.35F) * 100.0F, 0.0F, 100.0F);
}

} // namespace

auto PRQEngine::getScore() -> float {
  return kSprintPrqScore;
}

auto PRQEngine::getScore(const FitnessSnapshot& snapshot) -> float {
  if (!hasLiveFitness(snapshot)) {
    return getScore();
  }
  return scoreFromSnapshot(snapshot);
}

auto PRQEngine::getNeuralDrive() -> float {
  return kSprintNeuralDrive;
}

auto PRQEngine::getNeuralDrive(const FitnessSnapshot& snapshot) -> float {
  if (!hasLiveFitness(snapshot)) {
    return getNeuralDrive();
  }
  return neuralDriveFromSnapshot(snapshot);
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

auto PRQEngine::getGrade(const FitnessSnapshot& snapshot) -> PRQGrade {
  return getGrade(getScore(snapshot));
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
