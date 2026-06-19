// File: app/gameplay/include/nexus/gameplay/throw_catch_physics.h
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 01 Gameplay Loop Protocol, 10 Phase 0 Foundation
#pragma once

#include "nexus/gameplay/fitness_data.h"

#include <cstdint>

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

struct ThrowCatchState {
  // Current phase of the oscillatory throw-catch cycle.
  ThrowCatchPhase phase{ThrowCatchPhase::kCatch};
  // Current normalized phase time in seconds.
  double phaseTimeSeconds{0.0};
  // Current power multiplier derived from FRC and IAP metrics.
  float powerMultiplier{1.0F};
  // Count of completed throw pulses.
  std::uint64_t throwsTriggered{0};
};

class ThrowCatchPhysicsController {
public:
  /// Advances the throw-catch gameplay module from read-only fitness data.
  void update(double deltaSeconds,
              const FitnessReadView& fitnessView,
              physics::PhysicsWorld& physicsWorld);

  /// Returns the current throw-catch module state.
  [[nodiscard]] auto state() const -> const ThrowCatchState&;

private:
  void advance_phase(physics::PhysicsWorld& physicsWorld);

  ThrowCatchState m_state;
};

} // namespace nexus::gameplay
