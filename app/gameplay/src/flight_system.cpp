#include "nexus/gameplay/flight_system.h"

#include <algorithm>

namespace nexus::gameplay {

void FlightSystem::reset() {
  m_phase     = FlightPhase::kGrounded;
  m_energy    = 1.0F;
  m_altitude  = 0.0F;
  m_velocity  = {};
  m_boostTimer = 0.0F;
}

void FlightSystem::update(double deltaSeconds, const ArcadePhysicsParams& physics) {
  const float dt = static_cast<float>(deltaSeconds);
  constexpr float kGravity = 14.0F;  // m/s² — heavier than real to feel KH1-snappy

  switch (m_phase) {
  case FlightPhase::kGrounded:
    break;

  case FlightPhase::kJumping:
    // Arc up then start falling — wait for activateFlight() or auto-fall.
    m_velocity.y -= kGravity * dt;
    m_altitude   += m_velocity.y * dt;
    if (m_altitude <= 0.0F) {
      m_altitude  = 0.0F;
      m_velocity  = {};
      m_phase     = FlightPhase::kGrounded;
      m_energy    = 1.0F;
    }
    break;

  case FlightPhase::kGliding: {
    // Drain energy proportional to inverse flight speed (longer glide at low speed).
    const float maxE    = maxEnergy(physics.movementSpeedScale);
    const float drainRate = 1.0F / maxE;  // energy per second
    m_energy -= drainRate * dt;

    if (m_energy <= 0.0F) {
      m_energy = 0.0F;
      m_phase  = FlightPhase::kFalling;
    } else {
      // Maintain altitude with a gentle upward correction (KH1 "float" feel)
      const float upCorrect = 1.5F * dt;
      m_altitude += upCorrect - 0.2F * dt;  // net: slow altitude drift
      m_altitude  = std::max(m_altitude, 0.1F);
    }
    break;
  }

  case FlightPhase::kBoosting:
    m_boostTimer -= dt;
    if (m_boostTimer <= 0.0F) {
      m_boostTimer = 0.0F;
      m_phase      = m_energy > 0.0F ? FlightPhase::kGliding : FlightPhase::kFalling;
    }
    // Burn more energy during boost
    m_energy -= (2.5F / maxEnergy(physics.movementSpeedScale)) * dt;
    if (m_energy <= 0.0F) {
      m_energy     = 0.0F;
      m_phase      = FlightPhase::kFalling;
    }
    break;

  case FlightPhase::kFalling:
    m_velocity.y -= kGravity * dt;
    m_altitude   += m_velocity.y * dt;
    if (m_altitude <= 0.0F) {
      m_altitude  = 0.0F;
      m_velocity  = {};
      m_phase     = FlightPhase::kGrounded;
      m_energy    = 1.0F;
    }
    break;
  }
}

auto FlightSystem::jump() -> Result<nlohmann::json> {
  if (m_phase != FlightPhase::kGrounded) {
    return Result<nlohmann::json>::err("already airborne");
  }
  m_phase      = FlightPhase::kJumping;
  m_velocity.y = kJumpLaunchVelocity;
  m_altitude   = 0.01F;
  return Result<nlohmann::json>::ok({
      {"flight_phase", "jumping"},
      {"launch_velocity", kJumpLaunchVelocity},
  });
}

auto FlightSystem::activateFlight(const ArcadePhysicsParams& physics)
    -> Result<nlohmann::json> {
  if (m_phase != FlightPhase::kJumping) {
    return Result<nlohmann::json>::err("must be jumping to activate flight");
  }
  m_phase    = FlightPhase::kGliding;
  m_velocity = {};  // level out

  const float spd = glideSpeed(physics.flightSpeedScale);
  return Result<nlohmann::json>::ok({
      {"flight_phase", "gliding"},
      {"glide_speed", spd},
      {"flight_energy", m_energy},
      {"max_duration_seconds", maxEnergy(physics.movementSpeedScale)},
  });
}

auto FlightSystem::triggerBoost(const ArcadePhysicsParams& physics)
    -> Result<nlohmann::json> {
  if (m_phase != FlightPhase::kGliding) {
    return Result<nlohmann::json>::err("must be gliding to boost");
  }
  if (!physics.neuralBurstActive) {
    return Result<nlohmann::json>::err("neural burst not active — PRQ too low");
  }
  m_phase      = FlightPhase::kBoosting;
  m_boostTimer = kBoostDuration;

  const float boostSpd = glideSpeed(physics.flightSpeedScale) * physics.neuralBurstMultiplier;
  return Result<nlohmann::json>::ok({
      {"flight_phase", "boosting"},
      {"boost_speed", boostSpd},
      {"boost_duration", kBoostDuration},
  });
}

auto FlightSystem::land() -> Result<nlohmann::json> {
  if (m_phase == FlightPhase::kGrounded) {
    return Result<nlohmann::json>::err("already grounded");
  }
  const float altitude = m_altitude;
  m_altitude   = 0.0F;
  m_velocity   = {};
  m_phase      = FlightPhase::kGrounded;
  m_energy     = 1.0F;
  m_boostTimer = 0.0F;
  return Result<nlohmann::json>::ok({
      {"flight_phase", "grounded"},
      {"landing_altitude", altitude},
  });
}

auto FlightSystem::stateJson() const -> nlohmann::json {
  return {
      {"flight_phase", static_cast<int>(m_phase)},
      {"flight_energy", m_energy},
      {"altitude", m_altitude},
      {"velocity", {{"x", m_velocity.x}, {"y", m_velocity.y}, {"z", m_velocity.z}}},
      {"boost_timer", m_boostTimer},
      {"is_airborne", isAirborne()},
  };
}

// ── Private helpers ──────────────────────────────────────────────────────────

auto FlightSystem::maxEnergy(float movementSpeedScale) -> float {
  // Higher PRQ → longer flight (more energy)
  const float norm = std::clamp((movementSpeedScale - 0.6F) / 2.2F, 0.0F, 1.0F);
  return kBaseFlightSeconds + (kMaxFlightSeconds - kBaseFlightSeconds) * norm;
}

auto FlightSystem::glideSpeed(float flightSpeedScale) -> float {
  return kGlideBaseSpeed + (kGlideMaxSpeed - kGlideBaseSpeed) *
         std::clamp((flightSpeedScale - 0.8F) / 1.2F, 0.0F, 1.0F);
}

} // namespace nexus::gameplay
