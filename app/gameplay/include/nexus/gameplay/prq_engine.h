// Spec §7.4 — sprint PRQ scoring fed by HealthKit/scan readiness snapshots.
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
  static constexpr float kFallbackScore = 75.0F;
  static constexpr float kFallbackNeuralDrive = 60.0F;

  [[nodiscard]] static auto getScore() -> float;
  [[nodiscard]] static auto getNeuralDrive() -> float;
  [[nodiscard]] static auto getGrade() -> PRQGrade;
  [[nodiscard]] static auto scoreForFitness(const FitnessSnapshot& snapshot) -> float;
  [[nodiscard]] static auto neuralDriveForFitness(const FitnessSnapshot& snapshot) -> float;
  [[nodiscard]] static auto gradeForScore(float score) -> PRQGrade;
  [[nodiscard]] static auto gradeLabel(PRQGrade grade) -> std::string_view;
};

} // namespace nexus::gameplay
