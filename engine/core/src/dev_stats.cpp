#include "nexus/core/dev_stats.h"

#include "nexus/core/log.h"

#include <nlohmann/json.hpp>

#include <chrono>
#include <cstdlib>
#include <fstream>
#include <string>
#include <string_view>

namespace nexus::core {

namespace {

auto envTruthy(std::string_view key) -> bool {
  const char* flag = std::getenv(std::string(key).c_str());
  return flag != nullptr &&
         (std::string_view{flag} == "1" || std::string_view{flag} == "true");
}

} // namespace

auto devStatsLoggingEnabled() -> bool {
  const char* flag = std::getenv("NEXUS_DEV_STATS");
  if (flag == nullptr) {
    return true;
  }
  return std::string_view{flag} != "0" && std::string_view{flag} != "false";
}

auto devHudOverlayEnabled() -> bool {
  const char* flag = std::getenv("NEXUS_DEV_HUD");
  return flag != nullptr &&
         (std::string_view{flag} == "1" || std::string_view{flag} == "true");
}

void logDevHudOverlay(const FrameDevStats& stats) {
  if (!devHudOverlayEnabled()) {
    return;
  }

  const std::string budgetTag = stats.withinDrawBudget ? "ok" : "EXCEEDED";
  NEXUS_LOG_INFO(LogChannel::kCore,
                 "dev_hud fps=" + std::to_string(stats.fps) + " frame_ms=" +
                     std::to_string(stats.frameTimeMs) + " draws=" +
                     std::to_string(stats.visibleDraws) + " tris=" +
                     std::to_string(stats.triangleCount) + " budget=" + budgetTag);
}

void logFrameDevStats(const FrameDevStats& stats) {
  if (!devStatsLoggingEnabled()) {
    return;
  }

  const std::string budgetTag = stats.withinDrawBudget ? "ok" : "EXCEEDED";
  NEXUS_LOG_INFO(LogChannel::kCore,
                 "dev_stats fps=" + std::to_string(stats.fps) +
                     " frame_ms=" + std::to_string(stats.frameTimeMs) + " draws=" +
                     std::to_string(stats.visibleDraws) + " culled=" +
                     std::to_string(stats.culledDraws) + " tris=" +
                     std::to_string(stats.triangleCount) + " budget=" + budgetTag);
}

auto playtestExportEnabled() -> bool {
  return envTruthy("NEXUS_PLAYTEST_EXPORT");
}

auto playtestExportPath() -> std::string {
  if (const char* path = std::getenv("NEXUS_PLAYTEST_EXPORT_PATH"); path != nullptr && path[0] != '\0') {
    return std::string{path};
  }
  return "artifacts/playtest/dev_stats_tick.json";
}

void exportPlaytestTickSnapshot(const FrameDevStats& stats, const PlaytestExportContext& context) {
  if (!playtestExportEnabled()) {
    return;
  }

  nlohmann::json agentResponses = nlohmann::json::array();
  if (!context.agentResponsesJson.empty()) {
    const auto parsed = nlohmann::json::parse(context.agentResponsesJson, nullptr, false);
    if (!parsed.is_discarded() && parsed.is_array()) {
      agentResponses = parsed;
    }
  }

  const auto now = std::chrono::system_clock::now();
  const auto epochMs = std::chrono::duration_cast<std::chrono::milliseconds>(
      now.time_since_epoch());

  const nlohmann::json snapshot{
      {"schema_version", "1"},
      {"timestamp_ms", epochMs.count()},
      {"frame", context.frame},
      {"mode_id", context.modeId},
      {"venue_id", context.venueId},
      {"dev_stats",
       {{"fps", stats.fps},
        {"frame_time_ms", stats.frameTimeMs},
        {"visible_draws", stats.visibleDraws},
        {"culled_draws", stats.culledDraws},
        {"triangle_count", stats.triangleCount},
        {"within_draw_budget", stats.withinDrawBudget}}},
      {"agent_responses", agentResponses},
  };

  const std::string exportPath = playtestExportPath();
  const std::string tempPath = exportPath + ".tmp";
  std::ofstream output(tempPath, std::ios::trunc);
  if (!output.is_open()) {
    NEXUS_LOG_WARN(LogChannel::kCore, "playtest export failed to open: " + tempPath);
    return;
  }
  output << snapshot.dump(2) << '\n';
  output.close();
  if (std::rename(tempPath.c_str(), exportPath.c_str()) != 0) {
    NEXUS_LOG_WARN(LogChannel::kCore, "playtest export rename failed: " + exportPath);
  }
}

} // namespace nexus::core
