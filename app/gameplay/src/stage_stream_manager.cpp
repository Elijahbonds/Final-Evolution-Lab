#include "nexus/gameplay/stage_stream_manager.h"

namespace nexus::gameplay {

void StageStreamManager::reset() {
  for (auto& s : m_states) {
    s = StageLoadState::kUnloaded;
  }
  for (auto& c : m_streamingCounter) {
    c = 0;
  }
  // Start with the boardwalk zone ready.
  m_activeZone = StageZoneId::kBoardwalk;
  m_states[0] = StageLoadState::kActive;
}

auto StageStreamManager::activateZone(StageZoneId zone) -> bool {
  const auto idx = static_cast<int>(zone);
  if (idx < 0 || idx >= kZoneCount) {
    return false;
  }
  // Suspend the current active zone without unloading it (PSP keep-resident).
  const auto prevIdx = static_cast<int>(m_activeZone);
  if (m_states[prevIdx] == StageLoadState::kActive) {
    m_states[prevIdx] = StageLoadState::kSuspended;
  }
  m_activeZone = zone;

  if (m_states[idx] == StageLoadState::kUnloaded) {
    // Start streaming in.
    m_states[idx] = StageLoadState::kStreaming;
    m_streamingCounter[idx] = 0;
  } else if (m_states[idx] == StageLoadState::kReady ||
             m_states[idx] == StageLoadState::kSuspended) {
    // Already in memory — promote immediately.
    m_states[idx] = StageLoadState::kActive;
  }
  return true;
}

void StageStreamManager::update() {
  for (int i = 0; i < kZoneCount; ++i) {
    if (m_states[i] == StageLoadState::kStreaming) {
      ++m_streamingCounter[i];
      if (m_streamingCounter[i] >= kStreamingFrames) {
        // Promote: if this zone is the desired active one, go kActive; else kReady.
        m_states[i] = (static_cast<int>(m_activeZone) == i)
                          ? StageLoadState::kActive
                          : StageLoadState::kReady;
      }
    }
  }
}

auto StageStreamManager::loadState(StageZoneId zone) const -> StageLoadState {
  const auto idx = static_cast<int>(zone);
  if (idx < 0 || idx >= kZoneCount) {
    return StageLoadState::kUnloaded;
  }
  return m_states[idx];
}

auto StageStreamManager::meta(StageZoneId zone) const -> const StageZoneMeta& {
  const auto idx = static_cast<std::size_t>(zone);
  return kStageZones[idx < kStageZones.size() ? idx : 0];
}

auto StageStreamManager::isActiveZoneReady() const -> bool {
  return m_states[static_cast<int>(m_activeZone)] == StageLoadState::kActive;
}

auto StageStreamManager::stateJson() const -> nlohmann::json {
  nlohmann::json zones = nlohmann::json::array();
  for (int i = 0; i < kZoneCount; ++i) {
    const auto& m = kStageZones[static_cast<std::size_t>(i)];
    zones.push_back({
        {"id", i},
        {"name", m.name},
        {"sublevel", m.sublevel},
        {"load_state", static_cast<int>(m_states[i])},
        {"has_boss", m.hasBoss},
        {"requires_flight", m.requiresFlight},
        {"obstacle_count", m.obstacleCount},
    });
  }
  return {
      {"active_zone", static_cast<int>(m_activeZone)},
      {"active_zone_ready", isActiveZoneReady()},
      {"zones", std::move(zones)},
  };
}

} // namespace nexus::gameplay
