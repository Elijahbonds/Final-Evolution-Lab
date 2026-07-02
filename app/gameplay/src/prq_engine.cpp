#include "nexus/gameplay/prq_engine.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kNoDataPrqScore = 75.0F;
constexpr float kNoDataNeuralDrive = 60.0F;

[[nodiscard]] auto percent(float unitValue) -> float {
  return std::clamp(unitValue, 0.0F, 1.0F) * 100.0F;
}

} // namespace

auto PRQEngine::getScore() -> float {
  return kNoDataPrqScore;
}

auto PRQEngine::getScore(const FitnessSnapshot& fitness) -> float {
  if (fitness.revision == 0) {
    return getScore();
  }

  const float composite = fitness.powerReadiness * 0.60F + fitness.frcComposite * 0.30F +
                          fitness.iapComposite * 0.10F;
  return percent(composite);
}

auto PRQEngine::getNeuralDrive() -> float {
  return kNoDataNeuralDrive;
}

auto PRQEngine::getNeuralDrive(const FitnessSnapshot& fitness) -> float {
  if (fitness.revision == 0) {
    return getNeuralDrive();
  }

  const float breathPhaseBoost = fitness.iap.breathPhase == 1   ? 0.08F
                                : fitness.iap.breathPhase == -1 ? -0.06F
                                                                : 0.0F;
  const float composite = fitness.iapComposite * 0.45F + fitness.frc.controlScore * 0.35F +
                          fitness.frcComposite * 0.20F + breathPhaseBoost;
  return percent(composite);
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
