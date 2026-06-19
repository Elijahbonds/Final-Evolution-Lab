// File: app/gameplay/src/throw_catch_physics.cpp
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 01 Gameplay Loop Protocol, 10 Phase 0 Foundation
#include "nexus/gameplay/throw_catch_physics.h"

#include "nexus/physics/physics_world.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

constexpr double kPhaseDurationSeconds = 0.25;
constexpr float kBasePowerMultiplier = 1.0F;
constexpr float kFrcPowerWeight = 0.35F;
constexpr float kIapPowerWeight = 0.25F;
constexpr float kBaseThrowImpulseY = 8.0F;
constexpr std::uint64_t kThrowBodyId = 1;

} // namespace

void ThrowCatchPhysicsController::update(double deltaSeconds,
                                           const FitnessReadView& fitnessView,
                                           physics::PhysicsWorld& physicsWorld) {
  const auto snapshot = fitnessView.snapshot();
  const float frcScore = std::clamp(
      (snapshot.frc.mobilityScore + snapshot.frc.activeRangeScore + snapshot.frc.controlScore) /
          3.0F,
      0.0F,
      1.0F);
  const float iapScore = std::clamp(snapshot.iap.engagementScore * snapshot.iap.confidence,
                                   0.0F,
                                   1.0F);

  m_state.powerMultiplier = kBasePowerMultiplier + (frcScore * kFrcPowerWeight) +
                            (iapScore * kIapPowerWeight);
  m_state.phaseTimeSeconds += deltaSeconds;

  while (m_state.phaseTimeSeconds >= kPhaseDurationSeconds) {
    m_state.phaseTimeSeconds -= kPhaseDurationSeconds;
    advance_phase(physicsWorld);
  }
}

auto ThrowCatchPhysicsController::state() const -> const ThrowCatchState& {
  return m_state;
}

void ThrowCatchPhysicsController::advance_phase(physics::PhysicsWorld& physicsWorld) {
  switch (m_state.phase) {
  case ThrowCatchPhase::kCatch:
    m_state.phase = ThrowCatchPhase::kLoad;
    break;
  case ThrowCatchPhase::kLoad:
    m_state.phase = ThrowCatchPhase::kThrow;
    ++m_state.throwsTriggered;
    {
      physics::PhysicsIntent intent{};
      intent.kind = physics::PhysicsIntentKind::kApplyImpulse;
      intent.bodyId = kThrowBodyId;
      intent.impulseOrVelocity.y = kBaseThrowImpulseY * m_state.powerMultiplier;
      physicsWorld.queueIntent(intent);
    }
    break;
  case ThrowCatchPhase::kThrow:
    m_state.phase = ThrowCatchPhase::kRecover;
    break;
  case ThrowCatchPhase::kRecover:
    m_state.phase = ThrowCatchPhase::kCatch;
    break;
  }
}

} // namespace nexus::gameplay
