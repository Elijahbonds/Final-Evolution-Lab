// Spec §7.4 — sprint PRQ, driven by fitness telemetry with sprint-safe defaults.
#pragma once

#include "nexus/gameplay/fitness_data.h"

#include <cstdint>
#include <string_view>

namespace nexus::gameplay {

enum class PRQGrade : std::uint8_t {
  kRecovering = 0,
  kReady = 1,
  kPrimed = 2,
  kElite = 3,
};

class PRQEngine {
public:
  static void updateFromFitness(const FitnessSnapshot& snapshot);
  static void resetToSprintDefaults();

  [[nodiscard]] static auto getScore() -> float;
  [[nodiscard]] static auto getNeuralDrive() -> float;
  [[nodiscard]] static auto getGrade() -> PRQGrade;
  [[nodiscard]] static auto gradeLabel(PRQGrade grade) -> std::string_view;
};

} // namespace nexus::gameplay
