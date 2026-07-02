#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <string_view>

namespace nexus::core {

struct FrameDevStats {
  float fps{0.0F};
  float frameTimeMs{0.0F};
  std::size_t visibleDraws{0};
  std::size_t culledDraws{0};
  std::size_t triangleCount{0};
  bool withinDrawBudget{true};
};

struct PlaytestExportContext {
  std::uint64_t frame{0};
  std::string modeId;
  std::string venueId;
  /// JSON array of serialized agent responses for this tick (may be empty).
  std::string agentResponsesJson{"[]"};
};

[[nodiscard]] auto devStatsLoggingEnabled() -> bool;
[[nodiscard]] auto devHudOverlayEnabled() -> bool;
[[nodiscard]] auto playtestExportEnabled() -> bool;
[[nodiscard]] auto playtestExportPath() -> std::string;
void logFrameDevStats(const FrameDevStats& stats);
void logDevHudOverlay(const FrameDevStats& stats);
void exportPlaytestTickSnapshot(const FrameDevStats& stats, const PlaytestExportContext& context);

} // namespace nexus::core
