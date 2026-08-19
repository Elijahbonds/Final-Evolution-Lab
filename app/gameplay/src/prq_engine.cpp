#include "nexus/gameplay/prq_engine.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr float kSprintPrqScore = 75.0F;
constexpr float kSprintNeuralDrive = 60.0F;

struct PRQSnapshot {
  float score{kSprintPrqScore};
  float neuralDrive{kSprintNeuralDrive};
};

[[nodiscard]] auto activeSnapshot() -> PRQSnapshot& {
  static thread_local PRQSnapshot snapshot;
  return snapshot;
}

} // namespace

void PRQEngine::updateFromFitness(const FitnessSnapshot& snapshot) {
  auto& prq = activeSnapshot();
  if (snapshot.revision == 0) {
    prq = {};
    return;
  }
  prq.score = std::clamp(snapshot.powerReadiness * 100.0F, 0.0F, 100.0F);
  prq.neuralDrive = std::clamp(snapshot.iapComposite * 100.0F, 0.0F, 100.0F);
}

void PRQEngine::resetToSprintDefaults() {
  activeSnapshot() = {};
}

auto PRQEngine::getScore() -> float {
  return activeSnapshot().score;
}

auto PRQEngine::getNeuralDrive() -> float {
  return activeSnapshot().neuralDrive;
}

auto PRQEngine::getGrade() -> PRQGrade {
  const float score = getScore();
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
