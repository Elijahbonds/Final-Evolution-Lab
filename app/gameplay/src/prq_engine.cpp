#include "nexus/gameplay/prq_engine.h"

#include <algorithm>
#include <cmath>

namespace nexus::gameplay {

namespace {

constexpr float kSprintPrqScore = 75.0F;
constexpr float kSprintNeuralDrive = 60.0F;

[[nodiscard]] auto clampScore(float value, float fallback) -> float {
  if (!std::isfinite(value)) {
    return fallback;
  }
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

auto PRQEngine::scoreFromSnapshot(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return kSprintPrqScore;
  }
  return clampScore(snapshot.powerReadiness * 100.0F, kSprintPrqScore);
}

auto PRQEngine::neuralDriveFromSnapshot(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return kSprintNeuralDrive;
  }
  return clampScore(snapshot.iapComposite * 100.0F, kSprintNeuralDrive);
}

auto PRQEngine::gradeForScore(float score) -> PRQGrade {
  const float clamped = clampScore(score, kSprintPrqScore);
  if (clamped >= 90.0F) {
    return PRQGrade::kElite;
  }
  if (clamped >= 75.0F) {
    return PRQGrade::kPrimed;
  }
  if (clamped >= 60.0F) {
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
    return "BUILDING";
  }
  return "UNKNOWN";
}

} // namespace nexus::gameplay
