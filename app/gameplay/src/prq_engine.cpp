#include "nexus/gameplay/prq_engine.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kSprintPrqScore = 75.0F;
constexpr float kSprintNeuralDrive = 60.0F;

} // namespace

auto PRQEngine::getScore() -> float {
  return kSprintPrqScore;
}

auto PRQEngine::getNeuralDrive() -> float {
  return kSprintNeuralDrive;
}

auto PRQEngine::scoreForFitness(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getScore();
  }
  const float readiness = std::clamp(snapshot.powerReadiness, 0.0F, 1.0F);
  const float control = std::clamp(snapshot.frc.controlScore, 0.0F, 1.0F);
  const float breathConfidence = std::clamp(snapshot.iap.confidence, 0.0F, 1.0F);
  return std::clamp((readiness * 0.55F + control * 0.30F + breathConfidence * 0.15F) * 100.0F,
                    0.0F,
                    100.0F);
}

auto PRQEngine::neuralDriveForFitness(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getNeuralDrive();
  }
  const float control = std::clamp(snapshot.frc.controlScore, 0.0F, 1.0F);
  const float iap = std::clamp(snapshot.iapComposite, 0.0F, 1.0F);
  return std::clamp((control * 0.60F + iap * 0.40F) * 100.0F, 0.0F, 100.0F);
}

auto PRQEngine::getGrade() -> PRQGrade {
  return gradeForScore(getScore());
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
