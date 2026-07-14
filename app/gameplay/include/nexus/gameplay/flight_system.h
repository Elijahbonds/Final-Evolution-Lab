// Kingdom Hearts 1 — style flight / glide system.
// The player launches into a sustained glide by jumping then activating flight.
// A flightEnergy bar (0→1) drains while airborne; when it hits zero the player
// falls.  PRQ drives both max duration and airspeed — at Elite PRQ the player
// moves at near-Sonic airboost speed.
//
// This class owns only the logic state.  The renderer/Swift layer reads
// phase and velocity from stateJson() and drives animation + camera.
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/arcade_physics.h"
#include "nexus/gameplay/arena_3d_space.h"

#include <nlohmann/json.hpp>
#include <cstdint>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class FlightPhase : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class FlightPhase : std::uint8_t {
  kGrounded  = 0,  // player on floor, flight unavailable
  kJumping   = 1,  // airborne, not yet activating flight
  kGliding   = 2,  // flight active, draining energy
  kBoosting  = 3,  // PRQ neural burst — brief Sonic-speed surge
  kFalling   = 4,  // energy depleted, falling back to ground
};

// ─────────────────────────────────────────────────────────────────────────────
class FlightSystem {
public:
  // Base energy (seconds of flight) at minimum PRQ; scales with movementSpeedScale.
  static constexpr float kBaseFlightSeconds  = 3.0F;
  static constexpr float kMaxFlightSeconds   = 9.0F;   // at PRQ 100
  static constexpr float kGlideBaseSpeed     = 6.5F;   // m/s at Sora tier
  static constexpr float kGlideMaxSpeed      = 22.0F;  // m/s at Sonic tier
  static constexpr float kBoostDuration      = 1.2F;   // seconds of neural burst
  static constexpr float kJumpLaunchVelocity = 8.0F;   // initial jump Y velocity (m/s)

  void reset();
  void update(double deltaSeconds, const ArcadePhysicsParams& physics);

  // Call when player presses jump from ground.
  auto jump() -> Result<nlohmann::json>;

  // Activate glide from kJumping phase.  Fails if already kGrounded / kGliding.
  auto activateFlight(const ArcadePhysicsParams& physics) -> Result<nlohmann::json>;

  // Neural-burst boost — only available when kGliding and neuralBurstActive.
  auto triggerBoost(const ArcadePhysicsParams& physics) -> Result<nlohmann::json>;

  // Force land (e.g. player hits a platform trigger).
  auto land() -> Result<nlohmann::json>;

  [[nodiscard]] auto phase()         const -> FlightPhase { return m_phase; }
  [[nodiscard]] auto isAirborne()    const -> bool { return m_phase != FlightPhase::kGrounded; }
  [[nodiscard]] auto flightEnergy()  const -> float { return m_energy; }
  [[nodiscard]] auto altitude()      const -> float { return m_altitude; }
  [[nodiscard]] auto velocity()      const -> Vec3  { return m_velocity; }
  [[nodiscard]] auto stateJson()     const -> nlohmann::json;

private:
  [[nodiscard]] static auto maxEnergy(float movementSpeedScale) -> float;
  [[nodiscard]] static auto glideSpeed(float flightSpeedScale)  -> float;

  FlightPhase m_phase{FlightPhase::kGrounded};
  float m_energy{1.0F};        // 0→1 (1 = full)
  float m_altitude{0.0F};      // metres above ground
  Vec3  m_velocity{};
  float m_boostTimer{0.0F};
};

} // namespace nexus::gameplay
