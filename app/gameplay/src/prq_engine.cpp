#include "nexus/gameplay/prq_engine.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kBaselinePrqScore = 75.0F;
constexpr float kBaselineNeuralDrive = 60.0F;

[[nodiscard]] auto percent(float normalized) -> float {
  return std::clamp(normalized, 0.0F, 1.0F) * 100.0F;
}

} // namespace

auto PRQEngine::getScore() -> float {
  return kBaselinePrqScore;
}

auto PRQEngine::getScore(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getScore();
  }

  const float readiness =
      snapshot.frcComposite * 0.45F + snapshot.iapComposite * 0.25F +
      snapshot.powerReadiness * 0.30F;
  return percent(readiness);
}

auto PRQEngine::getNeuralDrive() -> float {
  return kBaselineNeuralDrive;
}

auto PRQEngine::getNeuralDrive(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getNeuralDrive();
  }

  const float breathTiming = snapshot.iap.breathPhase == 1   ? 1.0F
                              : snapshot.iap.breathPhase == 0 ? 0.65F
                                                              : 0.45F;
  const float neural =
      snapshot.iapComposite * 0.55F + snapshot.frc.controlScore * 0.30F +
      breathTiming * 0.15F;
  return percent(neural);
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
