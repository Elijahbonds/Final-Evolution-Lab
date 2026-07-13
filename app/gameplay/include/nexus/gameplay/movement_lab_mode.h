// Movement Lab — Bonds Bounce Blueprint curriculum education module (movement_lab)
//
// Non-scoring, non-game education module. Tracks athlete progress through
// structured movement drills (Bonds Bounce Blueprint curriculum). Each drill
// maps to a phase of the jump training framework:
//   0  intro          — posture overview + foot placement
//   1  loading        — hip hinge + eccentric load
//   2  triple_ext     — triple extension mechanics
//   3  arm_drive      — arm-swing timing and overhead reach
//   4  landing        — landing absorption + joint stack
//   5  full_sequence  — integrated rep with PRQ feedback
//
// Commands:
//   fel.movement_lab.start_drill    { "drill_id": "loading" }
//   fel.movement_lab.complete_drill { "drill_id": "loading", "prq_score": 0.75 }
//   fel.movement_lab.reset
//
// Queries:
//   fel.hud.poll → payload["movement_lab"]  — progress + active drill state
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string>
#include <unordered_set>
#include <vector>

namespace nexus::gameplay {

struct MovementLabDrill {
  std::string id;
  std::string displayName;
  /// Minimum PRQ score required to mark the drill complete (0–1).
  float prqThreshold{0.60F};
};

class MovementLabMode {
public:
  static constexpr int kTotalDrills = 6;

  static const MovementLabDrill kDrills[kTotalDrills];

  void reset();

  /// Start a named drill. Idempotent if the drill is already active.
  auto startDrill(std::string_view drillId) -> Result<nlohmann::json>;

  /// Complete the active drill with a PRQ feedback score (0–1).
  /// Returns an error if the drill is not active or the PRQ score is below threshold.
  auto completeDrill(std::string_view drillId, float prqScore) -> Result<nlohmann::json>;

  [[nodiscard]] auto activeDrillId() const -> const std::string& { return m_activeDrillId; }
  [[nodiscard]] auto completedDrillCount() const -> int32_t {
    return static_cast<int32_t>(m_completedDrills.size());
  }
  [[nodiscard]] auto progressPercent() const -> float {
    return (static_cast<float>(m_completedDrills.size()) / kTotalDrills) * 100.0F;
  }
  [[nodiscard]] auto isCurriculumComplete() const -> bool {
    return static_cast<int32_t>(m_completedDrills.size()) >= kTotalDrills;
  }
  [[nodiscard]] auto isDrillCompleted(std::string_view drillId) const -> bool {
    return m_completedDrills.count(std::string(drillId)) > 0;
  }
  [[nodiscard]] auto peakPrqScore() const -> float { return m_peakPrqScore; }

  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] static auto findDrill(std::string_view drillId) -> const MovementLabDrill*;

  std::string                     m_activeDrillId;
  std::unordered_set<std::string> m_completedDrills;
  float                           m_peakPrqScore{0.0F};
  int32_t                         m_totalAttempts{0};
};

} // namespace nexus::gameplay
