// File: app/gameplay/include/nexus/gameplay/throw_catch_physics.h
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 01 Gameplay Loop Protocol, 10 Phase 0 Foundation
#pragma once

#include "nexus/gameplay/fitness_data.h"

#include <cstdint>
#include <nlohmann/json.hpp>

namespace nexus::physics {
class PhysicsWorld;
}

namespace nexus::gameplay {

enum class ThrowCatchPhase : std::uint8_t {
  kCatch,
  kLoad,
  kThrow,
  kRecover,
};

enum class CatchFeedback : std::uint8_t {
  kMiss = 0,
  kGraze = 1,
  kSolid = 2,
  kPerfect = 3,
};

struct ThrowPulseEnvelope {
  // Vertical impulse applied on the throw phase.
  float impulseY{0.0F};
  // Breath-phase multiplier applied to the impulse.
  float breathBoost{1.0F};
  // Catch quality from the preceding catch window.
  CatchFeedback catchFeedback{CatchFeedback::kMiss};
  // Normalized catch radius used for the catch window (0–1).
  float catchRadiusNormalized{0.0F};
};

struct ThrowCatchState {
  // Current phase of the oscillatory throw-catch cycle.
  ThrowCatchPhase phase{ThrowCatchPhase::kCatch};
  // Current normalized phase time in seconds.
  double phaseTimeSeconds{0.0};
  // Duration of the active phase in seconds.
  double phaseDurationSeconds{0.25};
  // Current power multiplier derived from FRC and IAP metrics.
  float powerMultiplier{1.0F};
  // Count of completed throw pulses.
  std::uint64_t throwsTriggered{0};
  // Normalized catch radius from latest FRC control (HUD feedback).
  float catchRadiusNormalized{0.5F};
  // Latest catch quality evaluated during kCatch.
  CatchFeedback catchFeedback{CatchFeedback::kMiss};
  // Most recent throw impulse envelope for agent/HUD consumers.
  ThrowPulseEnvelope lastPulse{};
};

class ThrowCatchPhysicsController {
public:
  /// Advances the throw-catch gameplay module from read-only fitness data.
  void update(double deltaSeconds,
              const FitnessReadView& fitnessView,
              physics::PhysicsWorld& physicsWorld);

  /// Returns the current throw-catch module state.
  [[nodiscard]] auto state() const -> const ThrowCatchState&;

  /// Serializes throw-catch state for HUD and agent query envelopes.
  [[nodiscard]] static auto stateToJson(const ThrowCatchState& state) -> nlohmann::json;

private:
  void advance_phase(physics::PhysicsWorld& physicsWorld, const FitnessSnapshot& fitness);
  void evaluateCatchWindow(const FitnessSnapshot& fitness);
  [[nodiscard]] double phaseDuration(ThrowCatchPhase phase) const;
  [[nodiscard]] float breathImpulseBoost(std::int8_t breathPhase) const;

  ThrowCatchState m_state;
};

} // namespace nexus::gameplay
