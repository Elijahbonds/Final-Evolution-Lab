#include "nexus/gameplay/prq_engine.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kSprintPrqScore = 75.0F;
constexpr float kSprintNeuralDrive = 60.0F;

[[nodiscard]] auto breathPhaseReadiness(std::int8_t breathPhase) -> float {
  if (breathPhase > 0) {
    return 1.0F;
  }
  if (breathPhase < 0) {
    return 0.35F;
  }
  return 0.65F;
}

[[nodiscard]] auto hasMeasuredFitness(const FitnessSnapshot& snapshot) -> bool {
  return snapshot.revision > 0;
}

[[nodiscard]] auto clampScore(float score) -> float {
  return std::clamp(score, 0.0F, 100.0F);
}

} // namespace

auto PRQEngine::getScore() -> float {
  return kSprintPrqScore;
}

auto PRQEngine::getScore(const FitnessSnapshot& snapshot) -> float {
  if (!hasMeasuredFitness(snapshot)) {
    return getScore();
  }

  const float frcComposite = computeFrcComposite(snapshot.frc);
  const float iapComposite = computeIapComposite(snapshot.iap);
  const float powerReadiness = computePowerReadiness(snapshot.frc, snapshot.iap);
  const float breathReadiness = breathPhaseReadiness(snapshot.iap.breathPhase);
  return clampScore((powerReadiness * 0.60F + frcComposite * 0.20F +
                     iapComposite * 0.10F + breathReadiness * 0.10F) *
                    100.0F);
}

auto PRQEngine::getNeuralDrive() -> float {
  return kSprintNeuralDrive;
}

auto PRQEngine::getNeuralDrive(const FitnessSnapshot& snapshot) -> float {
  if (!hasMeasuredFitness(snapshot)) {
    return getNeuralDrive();
  }

  const float iapComposite = computeIapComposite(snapshot.iap);
  const float powerReadiness = computePowerReadiness(snapshot.frc, snapshot.iap);
  const float breathReadiness = breathPhaseReadiness(snapshot.iap.breathPhase);
  return clampScore((iapComposite * 0.50F + powerReadiness * 0.30F +
                     snapshot.frc.controlScore * 0.10F + breathReadiness * 0.10F) *
                    100.0F);
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
