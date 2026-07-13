#include "nexus/gameplay/movement_lab_mode.h"

#include <algorithm>
#include <cstring>

namespace nexus::gameplay {

// Bonds Bounce Blueprint — six-phase curriculum
const MovementLabDrill MovementLabMode::kDrills[MovementLabMode::kTotalDrills] = {
    {.id = "intro",         .displayName = "Posture & Foot Placement",  .prqThreshold = 0.50F},
    {.id = "loading",       .displayName = "Hip Hinge & Eccentric Load", .prqThreshold = 0.60F},
    {.id = "triple_ext",    .displayName = "Triple Extension Mechanics", .prqThreshold = 0.65F},
    {.id = "arm_drive",     .displayName = "Arm Drive & Overhead Reach", .prqThreshold = 0.65F},
    {.id = "landing",       .displayName = "Landing Absorption & Stack", .prqThreshold = 0.70F},
    {.id = "full_sequence", .displayName = "Integrated Rep (PRQ Gate)",  .prqThreshold = 0.75F},
};

void MovementLabMode::reset() {
  m_activeDrillId.clear();
  m_completedDrills.clear();
  m_peakPrqScore = 0.0F;
  m_totalAttempts = 0;
}

auto MovementLabMode::startDrill(std::string_view drillId) -> Result<nlohmann::json> {
  const MovementLabDrill* drill = findDrill(drillId);
  if (!drill) {
    return Result<nlohmann::json>::err(
        "movement_lab: unknown drill id '" + std::string(drillId) + "'");
  }

  m_activeDrillId = std::string(drillId);
  ++m_totalAttempts;

  nlohmann::json payload = stateJson();
  payload["started_drill"] = drill->id;
  payload["display_name"]  = drill->displayName;
  payload["prq_threshold"] = drill->prqThreshold;
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto MovementLabMode::completeDrill(std::string_view drillId,
                                    float prqScore) -> Result<nlohmann::json> {
  const MovementLabDrill* drill = findDrill(drillId);
  if (!drill) {
    return Result<nlohmann::json>::err(
        "movement_lab: unknown drill id '" + std::string(drillId) + "'");
  }

  if (m_activeDrillId != std::string(drillId)) {
    return Result<nlohmann::json>::err(
        "movement_lab: drill '" + std::string(drillId) + "' is not the active drill");
  }

  const float clamped = std::clamp(prqScore, 0.0F, 1.0F);
  m_peakPrqScore = std::max(m_peakPrqScore, clamped);

  const bool passed = clamped >= drill->prqThreshold;
  if (passed) {
    m_completedDrills.insert(std::string(drillId));
    m_activeDrillId.clear();
  }

  nlohmann::json payload = stateJson();
  payload["completed_drill"] = {
      {"drill_id",       drill->id},
      {"display_name",   drill->displayName},
      {"prq_score",      clamped},
      {"prq_threshold",  drill->prqThreshold},
      {"passed",         passed},
  };
  return Result<nlohmann::json>::ok(std::move(payload));
}

auto MovementLabMode::stateJson() const -> nlohmann::json {
  std::vector<std::string> completed(m_completedDrills.begin(), m_completedDrills.end());
  std::sort(completed.begin(), completed.end());

  return {
      {"active_drill",      m_activeDrillId},
      {"completed_drills",  completed},
      {"completed_count",   completedDrillCount()},
      {"total_drills",      kTotalDrills},
      {"progress_percent",  progressPercent()},
      {"curriculum_complete", isCurriculumComplete()},
      {"peak_prq_score",    m_peakPrqScore},
      {"total_attempts",    m_totalAttempts},
  };
}

auto MovementLabMode::findDrill(std::string_view drillId) -> const MovementLabDrill* {
  for (const MovementLabDrill& drill : kDrills) {
    if (drill.id == drillId) {
      return &drill;
    }
  }
  return nullptr;
}

} // namespace nexus::gameplay
