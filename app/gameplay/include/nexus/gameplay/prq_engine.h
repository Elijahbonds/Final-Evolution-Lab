// Spec §7.4 — PRQ readiness scoring for sprint physics and HUD state.
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
  /// Backward-compatible sprint default used until a live fitness snapshot arrives.
  [[nodiscard]] static auto getScore() -> float;
  [[nodiscard]] static auto getNeuralDrive() -> float;
  [[nodiscard]] static auto getGrade() -> PRQGrade;
  [[nodiscard]] static auto scoreForSnapshot(const FitnessSnapshot& snapshot) -> float;
  [[nodiscard]] static auto neuralDriveForSnapshot(const FitnessSnapshot& snapshot) -> float;
  [[nodiscard]] static auto gradeForScore(float score) -> PRQGrade;
  [[nodiscard]] static auto gradeLabel(PRQGrade grade) -> std::string_view;
};

} // namespace nexus::gameplay
