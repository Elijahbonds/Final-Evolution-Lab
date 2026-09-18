// Spec §7.4 — PRQ profile derived from live fitness/readiness snapshots.
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

struct PRQProfile {
  float score{75.0F};
  float neuralDrive{60.0F};
  PRQGrade grade{PRQGrade::kPrimed};
  std::uint64_t fitnessRevision{0};
};

class PRQEngine {
public:
  static constexpr float kDefaultScore = 75.0F;
  static constexpr float kDefaultNeuralDrive = 60.0F;

  [[nodiscard]] static auto getScore() -> float;
  [[nodiscard]] static auto getNeuralDrive() -> float;
  [[nodiscard]] static auto getGrade() -> PRQGrade;
  [[nodiscard]] static auto gradeForScore(float score) -> PRQGrade;
  [[nodiscard]] static auto fromFitnessSnapshot(const FitnessSnapshot& snapshot) -> PRQProfile;
  [[nodiscard]] static auto gradeLabel(PRQGrade grade) -> std::string_view;
};

} // namespace nexus::gameplay
