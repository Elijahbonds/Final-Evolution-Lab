// Spec §7.4 — sprint PRQ stub (hardcoded 75 until HealthKit bridge)
#pragma once

#include <cstdint>
#include <string_view>

namespace nexus::gameplay {

struct FitnessSnapshot;

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
  static void syncFromSnapshot(const FitnessSnapshot& snapshot);
  static void resetToSprintDefaults();
  [[nodiscard]] static auto getGrade() -> PRQGrade;
  [[nodiscard]] static auto gradeLabel(PRQGrade grade) -> std::string_view;
};

} // namespace nexus::gameplay
