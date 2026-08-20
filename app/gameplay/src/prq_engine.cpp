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

auto PRQEngine::getNeuralDrive() -> float {
  return kSprintNeuralDrive;
}

auto PRQEngine::getGrade() -> PRQGrade {
  return gradeForScore(getScore());
}

auto PRQEngine::scoreForSnapshot(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getScore();
  }

  const float score = 35.0F + snapshot.frcComposite * 35.0F +
                      snapshot.powerReadiness * 20.0F + snapshot.iapComposite * 10.0F;
  return clampPercent(score);
}

auto PRQEngine::neuralDriveForSnapshot(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getNeuralDrive();
  }

  const float breathBoost = snapshot.iap.breathPhase > 0   ? 10.0F
                            : snapshot.iap.breathPhase < 0 ? -5.0F
                                                           : 0.0F;
  const float neuralDrive = 30.0F + snapshot.iapComposite * 35.0F +
                            snapshot.powerReadiness * 25.0F + breathBoost;
  return clampPercent(neuralDrive);
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
