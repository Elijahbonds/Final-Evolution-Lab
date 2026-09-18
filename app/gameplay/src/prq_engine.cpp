#include "nexus/gameplay/prq_engine.h"

#include "nexus/gameplay/fitness_data.h"

#include <algorithm>
#include <cmath>

namespace nexus::gameplay {

namespace {

[[nodiscard]] auto clampPercent(float value) -> float {
  if (!std::isfinite(value)) {
    return 0.0F;
  }
  return std::clamp(value, 0.0F, 100.0F);
}

} // namespace

auto PRQEngine::getScore() -> float {
  return kFallbackScore;
}

auto PRQEngine::getNeuralDrive() -> float {
  return kFallbackNeuralDrive;
}

auto PRQEngine::getGrade() -> PRQGrade {
  return gradeForScore(getScore());
}

auto PRQEngine::scoreForFitness(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getScore();
  }
  const float readiness = snapshot.powerReadiness * 100.0F;
  const float control = snapshot.frcComposite * 100.0F;
  return clampPercent(readiness * 0.70F + control * 0.30F);
}

auto PRQEngine::neuralDriveForFitness(const FitnessSnapshot& snapshot) -> float {
  if (snapshot.revision == 0) {
    return getNeuralDrive();
  }
  const float breathFocus = snapshot.iapComposite * 100.0F;
  const float readiness = snapshot.powerReadiness * 100.0F;
  return clampPercent(breathFocus * 0.65F + readiness * 0.35F);
}

auto PRQEngine::gradeForScore(float score) -> PRQGrade {
  score = clampPercent(score);
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
