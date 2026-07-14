// PSP-style stage streaming — mirrors how KH1 and God of War PSP loaded room
// geometry on demand, fighting for storage.  Each stage zone is kept in one of
// four states:  kUnloaded → kStreaming → kReady → kSuspended (background).
// Only one zone is kActive at a time; all others stay kSuspended or kUnloaded
// to stay within the iOS triangle / memory budget.
//
// Geometry decisions live in the renderer / Swift layer; this class owns only
// the LOAD-STATE machine and the per-zone metadata exposed via stateJson().
#pragma once

#include "nexus/gameplay/arena_3d_space.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstdint>
#include <string_view>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class StageLoadState : std::uint8_t;
  enum class StageZoneId : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class StageLoadState : std::uint8_t {
  kUnloaded   = 0,  // geometry not present in memory
  kStreaming  = 1,  // async load in flight (renderer should show transition)
  kReady      = 2,  // loaded, not yet active
  kActive     = 3,  // foreground: full detail, obstacles spawned
  kSuspended  = 4,  // loaded but background: LOD2, no active obstacles
};

enum class StageZoneId : std::uint8_t {
  kBoardwalk    = 0,  // Venice boardwalk outer ring — rail grind on railings
  kCourtFloor   = 1,  // Center court — basketball pillar arena
  kSkateApron   = 2,  // East/West apron — skate rails + launch ramps
  kBeachAccess  = 3,  // South beach — open flight section over sand
  kRooftopRow   = 4,  // Above bleachers — high-altitude rail + flight final stage
  kCount        = 5,
};

struct StageZoneMeta {
  StageZoneId   id;
  std::string_view name;          // human-readable zone label
  std::string_view sublevel;      // Swift/Metal sublevel asset token
  Vec3          boundsMin;        // AABB min (metres, court-space)
  Vec3          boundsMax;        // AABB max
  int           obstacleCount;    // number of obstacle props that spawn on activate
  bool          hasBoss;          // true → boss encounter available in this zone
  bool          requiresFlight;   // true → can only enter from flight / jump
};

// Canonical zone table — matches court_carnival_story_map.json
// Coordinates in metres (1 UE unit = 1 cm, converted ÷100)
inline constexpr std::array<StageZoneMeta, 5> kStageZones{{
  { StageZoneId::kBoardwalk,
    "Boardwalk",     "SL_Story_Boardwalk",
    {-12.0F, 0.0F, -9.5F}, {12.0F, 5.0F,  9.5F},
    6, false, false },

  { StageZoneId::kCourtFloor,
    "Court Floor",   "SL_Story_CourtFloor",
    { -7.8F, 0.0F, -7.5F}, { 7.8F, 3.0F,  7.5F},
    8, true,  false },

  { StageZoneId::kSkateApron,
    "Skate Apron",   "SL_Story_SkateApron",
    { -8.5F, 0.0F, -9.0F}, { 8.5F, 4.0F,  9.0F},
    5, true,  false },

  { StageZoneId::kBeachAccess,
    "Beach Access",  "SL_Story_BeachAccess",
    { -9.5F, 0.0F,  7.5F}, { 9.5F, 6.0F, 12.0F},
    4, true,  false },

  { StageZoneId::kRooftopRow,
    "Rooftop Row",   "SL_Story_RooftopRow",
    { -8.5F, 3.5F, -8.5F}, { 8.5F, 8.0F,  8.5F},
    6, true,  true  },
}};

// ─────────────────────────────────────────────────────────────────────────────
class StageStreamManager {
public:
  static constexpr int kZoneCount = static_cast<int>(StageZoneId::kCount);

  void reset();

  // Transition the active zone.  Previous active zone becomes kSuspended.
  // Returns false if zoneId is invalid.
  auto activateZone(StageZoneId zone) -> bool;

  // Simulate async streaming: call each frame.  Zones in kStreaming advance
  // to kReady after kStreamingFrames.
  void update();

  [[nodiscard]] auto loadState(StageZoneId zone) const -> StageLoadState;
  [[nodiscard]] auto activeZone() const -> StageZoneId { return m_activeZone; }
  [[nodiscard]] auto meta(StageZoneId zone) const -> const StageZoneMeta&;

  // True when the active zone has completed loading and its obstacles are live.
  [[nodiscard]] auto isActiveZoneReady() const -> bool;

  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  static constexpr int kStreamingFrames = 3;  // simulated async load latency

  StageZoneId m_activeZone{StageZoneId::kBoardwalk};
  std::array<StageLoadState, kZoneCount> m_states{};
  std::array<int, kZoneCount> m_streamingCounter{};
};

} // namespace nexus::gameplay
