// Golf 3D Mode — Wii Sports / Mario Golf style 3D golf gameplay.
// Swing mechanic: Address → Backswing (power) → Downswing (accuracy) → Follow Through.
// Ball physics: parabolic arc with wind, spin, and lie modifiers.
// Nine-hole course: tee → fairway/rough → green → pin.
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/arena_3d_space.h"
#include "nexus/gameplay/character_anim_state.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class GolfSwingPhase : std::uint8_t;
  enum class GolfClub : std::uint8_t;
  enum class GolfLie : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

// ── Enumerations ──────────────────────────────────────────────────────────────

enum class GolfSwingPhase : std::uint8_t {
  kWalking       = 0,  // player walking to ball
  kAddress       = 1,  // lined up, can adjust aim
  kBackswing     = 2,  // power meter filling (auto-fill)
  kDownswing     = 3,  // first tap locks power; second tap sets accuracy
  kFollowThrough = 4,  // post-impact animation
  kBallFlight    = 5,  // camera follows ball
  kBallLanded    = 6,  // brief summary (distance to pin, lie)
  kHoleComplete  = 7,  // score card shown for hole
  kRoundComplete = 8,  // final scorecard
};

enum class GolfClub : std::uint8_t {
  kDriver = 0,   // ~220 m, 12° loft, low accuracy
  kIron   = 1,   // ~150 m, 32° loft, medium accuracy
  kWedge  = 2,   // ~80 m,  52° loft, high accuracy
  kPutter = 3,   // used only on green, distance control
};

// Ball lie — affects shot distance and direction variance
enum class GolfLie : std::uint8_t {
  kTee      = 0,  // +10% distance, no penalty
  kFairway  = 1,  // no penalty
  kRough    = 2,  // -15% distance, ±3° random drift
  kBunker   = 3,  // -25% distance, forced wedge
  kGreen    = 4,  // putter only
};

// ── Golf camera (lighter than karate Camera3D; owns just position + target) ──

struct GolfCamera {
  Vec3  position{0.0F, 2.5F, -5.0F};
  Vec3  target{0.0F, 0.0F, 0.0F};
  float fovDegrees{70.0F};
};

// ── Per-hole layout ───────────────────────────────────────────────────────────

struct GolfHole {
  Vec3  teePos;          // player starts here
  Vec3  pinPos;          // where the flag is (goal)
  float fairwayYaw;      // suggested aim direction (degrees) from tee
  int   par;             // par for this hole
  float holeDistMeters;  // straight-line tee-to-pin distance
};

// ── Ball state ────────────────────────────────────────────────────────────────

struct GolfBall {
  Vec3  position{};
  Vec3  velocity{};
  bool  inFlight{false};
  bool  landed{false};
  float spinRpm{0.0F};   // back/top spin affects roll distance

  void update(float gravity, float windX, float windZ, double dt) noexcept;
  [[nodiscard]] auto lie() const -> GolfLie;
};

// ── Score tracking ────────────────────────────────────────────────────────────

struct GolfHoleResult {
  int holeNumber{0};
  int par{0};
  int strokes{0};   // number of strokes taken
  [[nodiscard]] auto relativeToPar() const -> int { return strokes - par; }
  [[nodiscard]] auto label() const -> std::string_view;
};

// ── Main mode class ───────────────────────────────────────────────────────────

class Golf3DMode {
public:
  static constexpr int kHoleCount         = 9;    // 9-hole round
  static constexpr int kMaxStrokesPerHole = 8;    // pick-up rule: auto-advance at stroke limit
  static constexpr float kGravity         = 9.81F;
  static constexpr float kWindSpeedMax    = 3.0F; // m/s max wind

  void reset();
  void update(double deltaSeconds);

  // ── Swing controls ────────────────────────────────────────────────────────
  // Call to begin lining up a shot from the current ball position.
  // autoSelectClub: picks appropriate club based on distance to pin and lie.
  auto beginAddress(bool autoSelectClub = true) -> Result<nlohmann::json>;

  // Adjust aim left/right while in kAddress phase.
  // deltaDegrees: positive = right, negative = left.
  auto adjustAim(float deltaDegrees) -> Result<nlohmann::json>;

  // Select a specific club (overrides auto-selection).
  auto selectClub(GolfClub club) -> Result<nlohmann::json>;

  // Start the backswing (power meter begins filling automatically).
  auto startSwing() -> Result<nlohmann::json>;

  // First tap during kBackswing/kDownswing: sets power if in backswing,
  // or sets accuracy offset if in downswing.
  auto swingTap() -> Result<nlohmann::json>;

  // Move player on foot between shots (kWalking phase only).
  // dx/dz each in [-1,1].
  auto movePlayer(float dx, float dz, double deltaSeconds) -> Result<nlohmann::json>;

  [[nodiscard]] auto phase()         const -> GolfSwingPhase { return m_phase; }
  [[nodiscard]] auto currentHole()   const -> int  { return m_currentHole; }
  [[nodiscard]] auto totalStrokes()  const -> int  { return m_totalStrokes; }
  [[nodiscard]] auto totalScore()    const -> int;  // cumulative relative-to-par
  [[nodiscard]] auto isRoundComplete() const -> bool {
    return m_phase == GolfSwingPhase::kRoundComplete;
  }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  // ── Swing resolution ──────────────────────────────────────────────────────
  void resolveShotLaunch();
  void onBallLanded();
  void advanceHole();

  [[nodiscard]] auto autoClubForDistance(float distMeters, GolfLie lie) const -> GolfClub;
  [[nodiscard]] auto clubLoftDegrees(GolfClub club) const -> float;
  [[nodiscard]] auto clubMaxDistanceMeters(GolfClub club) const -> float;
  [[nodiscard]] auto phaseLabel() const -> std::string_view;

  // ── Course layout (9 fixed holes) ────────────────────────────────────────
  static auto buildCourse() -> std::array<GolfHole, kHoleCount>;

  // ── State ──────────────────────────────────────────────────────────────────
  std::array<GolfHole, kHoleCount> m_course;
  GolfBall                         m_ball{};
  CharacterState3D                 m_player3D{};
  GolfCamera                       m_camera{};

  GolfSwingPhase m_phase{GolfSwingPhase::kAddress};
  GolfClub       m_selectedClub{GolfClub::kDriver};
  int            m_currentHole{0};        // 0-indexed
  int            m_strokesThisHole{0};
  int            m_totalStrokes{0};

  float m_aimYaw{0.0F};        // current aim direction (degrees)
  float m_powerMeter{0.0F};    // 0–1, fills automatically during backswing
  float m_accuracyOffset{0.0F};// -1 (hook) to +1 (slice), locked on 2nd tap
  bool  m_powerLocked{false};  // true after 1st tap in downswing
  float m_phaseTimer{0.0F};

  // Wind: changes per-hole
  float m_windX{0.0F};
  float m_windZ{0.0F};

  std::vector<GolfHoleResult> m_holeResults;

  // Power fill rate: full meter in 1.2 s (Wii Sports pace)
  static constexpr float kPowerFillRate  = 1.0F / 1.2F;
  // Follow-through animation duration
  static constexpr float kFollowThruDur  = 0.8F;
  // After landing, pause before auto-advancing to address
  static constexpr float kLandedPauseDur = 2.5F;
};

} // namespace nexus::gameplay
