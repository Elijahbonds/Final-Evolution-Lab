#include "nexus/gameplay/prq_engine.h"

#include "nexus/gameplay/fitness_data.h"

#include <algorithm>
#include <atomic>

namespace nexus::gameplay {

namespace {

constexpr float kSprintPrqScore = 75.0F;
constexpr float kSprintNeuralDrive = 60.0F;
std::atomic<float> g_prqScore{kSprintPrqScore};
std::atomic<float> g_neuralDrive{kSprintNeuralDrive};

[[nodiscard]] auto normalizedToScore(float value) -> float {
  return std::clamp(value, 0.0F, 1.0F) * 100.0F;
}

} // namespace

auto PRQEngine::getScore() -> float {
  return g_prqScore.load();
}

auto PRQEngine::getNeuralDrive() -> float {
  return g_neuralDrive.load();
}

void PRQEngine::syncFromSnapshot(const FitnessSnapshot& snapshot) {
  g_prqScore.store(normalizedToScore(snapshot.frc.controlScore));
  g_neuralDrive.store(normalizedToScore(snapshot.iap.engagementScore));
}

void PRQEngine::resetToSprintDefaults() {
  g_prqScore.store(kSprintPrqScore);
  g_neuralDrive.store(kSprintNeuralDrive);
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
