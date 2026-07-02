#include "nexus/gameplay/prq_engine.h"

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
