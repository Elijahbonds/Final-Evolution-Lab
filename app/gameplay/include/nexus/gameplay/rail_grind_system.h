// Sonic Adventure Battle 2 — style rail grinding system.
// A Rail is a sequence of world-space waypoints; the player snaps onto it when
// they step within kSnapRadius of any segment.  While grinding they slide along
// the path automatically (locked position, no free movement), accumulate combo
// points, and can perform mid-rail tricks.  They exit by jumping or reaching
// the end.
//
// This is intentionally physics-lite: speeds and distances are in metres/second
// consistent with the rest of the NEXUS game-logic layer.  The Swift/Metal
// renderer reads animClip and t (0→1 along rail) from stateJson().
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/arena_3d_space.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstdint>
#include <string_view>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class GrindState : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class GrindState : std::uint8_t {
  kOff      = 0,  // not on a rail
  kSnapping = 1,  // within snap radius, transitioning
  kGrinding = 2,  // locked to rail, sliding
  kTrick    = 3,  // mid-rail trick pose (brief)
  kExit     = 4,  // jumping off or reached end
};

// A trick performed mid-grind — maps to a clip name and a score bonus.
struct GrindTrick {
  std::string_view name;     // e.g. "nosegrind", "50-50", "noseslide"
  float            bonus;    // score added when trick completes
};

// Five canonical story-world rails (boardwalk + apron + rooftop)
struct RailDef {
  std::string_view id;
  std::array<Vec3, 4> waypoints;  // cubic segment: start, cp1, cp2, end (world-space metres)
  float              length;       // approximate arc length in metres
  bool               loop;         // true = rail wraps back to start
};

inline constexpr std::array<RailDef, 5> kStoryRails{{
  // Boardwalk north railing
  { "boardwalk_north",
    {{ Vec3{-12.0F, 1.2F, -9.5F}, Vec3{-4.0F, 1.4F, -9.5F},
       Vec3{4.0F,  1.4F, -9.5F}, Vec3{12.0F, 1.2F, -9.5F} }},
    24.1F, false },

  // Boardwalk south railing (mirror)
  { "boardwalk_south",
    {{ Vec3{12.0F, 1.2F, 9.5F}, Vec3{4.0F, 1.4F, 9.5F},
       Vec3{-4.0F, 1.4F, 9.5F}, Vec3{-12.0F, 1.2F, 9.5F} }},
    24.1F, false },

  // East apron skate rail
  { "apron_east",
    {{ Vec3{8.5F, 0.6F, -4.0F}, Vec3{8.5F, 1.6F, -1.0F},
       Vec3{8.5F, 1.6F,  2.0F}, Vec3{8.5F, 0.6F,  4.5F} }},
    11.2F, false },

  // West apron skate rail (mirror)
  { "apron_west",
    {{ Vec3{-8.5F, 0.6F, -4.0F}, Vec3{-8.5F, 1.6F, -1.0F},
       Vec3{-8.5F, 1.6F,  2.0F}, Vec3{-8.5F, 0.6F,  4.5F} }},
    11.2F, false },

  // Rooftop awning loop rail
  { "rooftop_loop",
    {{ Vec3{-6.0F, 5.5F, -6.0F}, Vec3{6.0F, 6.5F, -6.0F},
       Vec3{6.0F,  6.5F,  6.0F}, Vec3{-6.0F, 5.5F,  6.0F} }},
    26.0F, true  },
}};

// ─────────────────────────────────────────────────────────────────────────────
class RailGrindSystem {
public:
  static constexpr float kSnapRadius   = 1.5F;  // metres — proximity to enter grind
  static constexpr float kBaseSpeed    = 8.0F;  // metres/sec at PRQ 0
  static constexpr float kMaxSpeed     = 22.0F; // metres/sec at PRQ 100 (near Sonic)

  void reset();
  void update(double deltaSeconds, float grindAcceleration);

  // Attempt to snap onto the nearest rail from playerPos.
  // grindAcceleration comes from ArcadePhysicsParams (PRQ-scaled).
  // Returns ok({}) when snap succeeds, err when no rail is within snap radius.
  auto trySnapToRail(Vec3 playerPos, float grindAcceleration) -> Result<nlohmann::json>;

  // Perform a named mid-grind trick.  Only valid while kGrinding.
  auto performTrick(std::string_view trickName) -> Result<nlohmann::json>;

  // Jump off the current rail.
  auto exitGrind() -> Result<nlohmann::json>;

  [[nodiscard]] auto state() const -> GrindState { return m_state; }
  [[nodiscard]] auto isGrinding() const -> bool   { return m_state == GrindState::kGrinding || m_state == GrindState::kTrick; }
  [[nodiscard]] auto grindScore() const -> float  { return m_grindScore; }
  [[nodiscard]] auto currentRailId() const -> std::string_view;
  [[nodiscard]] auto playerPosOnRail() const -> Vec3;
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] static auto trickBonus(std::string_view name) -> float;
  [[nodiscard]] static auto evalRailPos(const RailDef& rail, float t) -> Vec3;

  GrindState m_state{GrindState::kOff};
  int        m_railIndex{-1};        // index into kStoryRails
  float      m_t{0.0F};              // 0→1 along the rail arc
  float      m_speed{0.0F};          // current slide speed (metres/sec)
  float      m_grindScore{0.0F};
  float      m_trickTimer{0.0F};     // non-zero = trick animation in progress
  int        m_trickCount{0};
  std::string m_lastTrick;
};

} // namespace nexus::gameplay
