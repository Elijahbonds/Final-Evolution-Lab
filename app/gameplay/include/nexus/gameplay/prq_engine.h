// Spec §7.4 — PRQ readiness signal for arcade physics and HUD.
#pragma once

#include "nexus/gameplay/fitness_data.h"

#include <string_view>
#include <cstdint>

namespace nexus::gameplay {

enum class PRQGrade : std::uint8_t {
  kRecovering = 0,
  kReady = 1,
  kPrimed = 2,
  kElite = 3,
};

class PRQEngine {
public:
  /// Sprint-safe fallback used before HealthKit/FRC/IAP metrics arrive.
  [[nodiscard]] static auto getScore() -> float;
  [[nodiscard]] static auto getScore(const FitnessSnapshot& snapshot) -> float;
  [[nodiscard]] static auto getNeuralDrive() -> float;
  [[nodiscard]] static auto getNeuralDrive(const FitnessSnapshot& snapshot) -> float;
  [[nodiscard]] static auto getGrade() -> PRQGrade;
  [[nodiscard]] static auto getGrade(float score) -> PRQGrade;
  [[nodiscard]] static auto getGrade(const FitnessSnapshot& snapshot) -> PRQGrade;
  [[nodiscard]] static auto gradeLabel(PRQGrade grade) -> std::string_view;
};

} // namespace nexus::gameplay
