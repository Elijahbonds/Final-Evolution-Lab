// Spec §7.4 — PRQ score derived from the latest fitness snapshot.
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
  [[nodiscard]] static auto getScore() -> float;
  [[nodiscard]] static auto getNeuralDrive() -> float;
  [[nodiscard]] static auto getGrade() -> PRQGrade;
  [[nodiscard]] static auto scoreFromSnapshot(const FitnessSnapshot& snapshot) -> float;
  [[nodiscard]] static auto neuralDriveFromSnapshot(const FitnessSnapshot& snapshot) -> float;
  [[nodiscard]] static auto gradeForScore(float score) -> PRQGrade;
  [[nodiscard]] static auto gradeLabel(PRQGrade grade) -> std::string_view;
};

} // namespace nexus::gameplay
