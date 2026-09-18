#include "nexus/gameplay/prq_engine.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

[[nodiscard]] auto clampPercent(float value) -> float {
  return std::clamp(value, 0.0F, 100.0F);
}

} // namespace

auto PRQEngine::getScore() -> float {
  return kDefaultScore;
}

auto PRQEngine::getNeuralDrive() -> float {
  return kDefaultNeuralDrive;
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

auto PRQEngine::fromFitnessSnapshot(const FitnessSnapshot& snapshot) -> PRQProfile {
  if (snapshot.revision == 0) {
    return {kDefaultScore, kDefaultNeuralDrive, gradeForScore(kDefaultScore), 0};
  }

  const float score = clampPercent(snapshot.powerReadiness * 100.0F);
  const float neuralDrive = clampPercent(
      (snapshot.iapComposite * 0.65F + snapshot.frc.controlScore * 0.35F) * 100.0F);
  return {score, neuralDrive, gradeForScore(score), snapshot.revision};
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
