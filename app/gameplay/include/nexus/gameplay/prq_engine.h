// Spec §7.4 — Performance Readiness Quotient derived from normalized fitness telemetry.
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
  /// Fallback sprint readiness used before a measured fitness scan arrives.
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
