// File: app/gameplay/src/throw_catch_physics.cpp
// Part of: Final Evolution Lab (FEL) Game Logic
// Spec: 01 Gameplay Loop Protocol, 10 Phase 0 Foundation
#include "nexus/gameplay/throw_catch_physics.h"

#include "nexus/core/log.h"
#include "nexus/physics/physics_world.h"

#include <algorithm>
#include <string>

namespace nexus::gameplay {

namespace {

constexpr float kBasePowerMultiplier = 1.0F;
constexpr float kFrcPowerWeight = 0.40F;
constexpr float kIapPowerWeight = 0.30F;
constexpr float kReadinessPowerWeight = 0.25F;
constexpr float kBaseThrowImpulseY = 9.5F;
constexpr float kMaxThrowImpulseY = 18.0F;
constexpr float kCatchRadiusMin = 0.40F;
constexpr float kCatchRadiusMax = 1.25F;
constexpr float kMobilityImpulseScale = 0.45F;
constexpr std::uint64_t kThrowBodyId = 1;

[[nodiscard]] auto catchFeedbackLabel(CatchFeedback feedback) -> const char* {
  switch (feedback) {
  case CatchFeedback::kGraze:
    return "graze";
  case CatchFeedback::kSolid:
    return "solid";
  case CatchFeedback::kPerfect:
    return "perfect";
  case CatchFeedback::kMiss:
  default:
    return "miss";
  }
}

} // namespace

void ThrowCatchPhysicsController::update(double deltaSeconds,
                                           const FitnessReadView& fitnessView,
                                           physics::PhysicsWorld& physicsWorld) {
  if (!physicsWorld.isBodyRegistered(kThrowBodyId)) {
    physics::RigidBodyDescriptor body{};
    body.bodyId = kThrowBodyId;
    body.initialPosition = {0.0F, 1.5F, 0.0F};
    body.massKg = 0.6F;
    body.dynamic = true;
    (void)physicsWorld.registerRigidBody(body);
  }

  const auto snapshot = fitnessView.snapshot();

  m_state.catchRadiusNormalized =
      kCatchRadiusMin + snapshot.frc.controlScore * (kCatchRadiusMax - kCatchRadiusMin);
  m_state.powerMultiplier =
      kBasePowerMultiplier + (snapshot.frcComposite * kFrcPowerWeight) +
      (snapshot.iapComposite * kIapPowerWeight) +
      (snapshot.powerReadiness * kReadinessPowerWeight);
  m_state.phaseDurationSeconds = phaseDuration(m_state.phase);
  m_state.phaseTimeSeconds += deltaSeconds;

  if (m_state.phase == ThrowCatchPhase::kCatch) {
    evaluateCatchWindow(snapshot);
  }

  while (m_state.phaseTimeSeconds >= m_state.phaseDurationSeconds) {
    m_state.phaseTimeSeconds -= m_state.phaseDurationSeconds;
    advance_phase(physicsWorld, snapshot);
    m_state.phaseDurationSeconds = phaseDuration(m_state.phase);
  }
}

auto ThrowCatchPhysicsController::state() const -> const ThrowCatchState& {
  return m_state;
}

auto ThrowCatchPhysicsController::stateToJson(const ThrowCatchState& state) -> nlohmann::json {
  return {
      {"phase", static_cast<int>(state.phase)},
      {"phase_time_seconds", state.phaseTimeSeconds},
      {"phase_duration_seconds", state.phaseDurationSeconds},
      {"power_multiplier", state.powerMultiplier},
      {"throws_triggered", state.throwsTriggered},
      {"catch_radius_normalized", state.catchRadiusNormalized},
      {"catch_feedback", catchFeedbackLabel(state.catchFeedback)},
      {"last_pulse",
       {
           {"impulse_y", state.lastPulse.impulseY},
           {"breath_boost", state.lastPulse.breathBoost},
           {"catch_feedback", catchFeedbackLabel(state.lastPulse.catchFeedback)},
           {"catch_radius_normalized", state.lastPulse.catchRadiusNormalized},
       }},
      {"agent_envelope",
       {
           {"impulse_range", {{"min", kBaseThrowImpulseY * 0.75F}, {"max", kMaxThrowImpulseY}}},
           {"catch_radius_range", {{"min", kCatchRadiusMin}, {"max", kCatchRadiusMax}}},
           {"phase_durations_ms",
            {{"catch", 220}, {"load", 140}, {"throw", 70}, {"recover", 280}}},
           {"feedback_weights",
            {{"perfect", 1.25F}, {"solid", 1.12F}, {"graze", 1.04F}, {"miss", 0.85F}}},
       }},
  };
}

void ThrowCatchPhysicsController::evaluateCatchWindow(const FitnessSnapshot& fitness) {
  const float windowProgress = static_cast<float>(
      m_state.phaseTimeSeconds / std::max(0.001, m_state.phaseDurationSeconds));
  const float targetWindow = 0.52F;
  const float distance = std::abs(windowProgress - targetWindow);
  const float tolerance = m_state.catchRadiusNormalized * 0.40F;

  CatchFeedback feedback = CatchFeedback::kMiss;
  if (distance <= tolerance * 0.25F) {
    feedback = CatchFeedback::kPerfect;
  } else if (distance <= tolerance * 0.55F) {
    feedback = CatchFeedback::kSolid;
  } else if (distance <= tolerance) {
    feedback = CatchFeedback::kGraze;
  }

  m_state.catchFeedback = feedback;

  if (feedback == CatchFeedback::kPerfect && fitness.iap.breathPhase == 1) {
    m_state.catchFeedback = CatchFeedback::kPerfect;
  }
}

void ThrowCatchPhysicsController::advance_phase(physics::PhysicsWorld& physicsWorld,
                                                  const FitnessSnapshot& fitness) {
  switch (m_state.phase) {
  case ThrowCatchPhase::kCatch:
    m_state.phase = ThrowCatchPhase::kLoad;
    break;
  case ThrowCatchPhase::kLoad:
    m_state.phase = ThrowCatchPhase::kThrow;
    break;
  case ThrowCatchPhase::kThrow:
    ++m_state.throwsTriggered;
    {
      const float breathBoost = breathImpulseBoost(fitness.iap.breathPhase);
      float catchQualityBoost = 1.0F;
      switch (m_state.catchFeedback) {
      case CatchFeedback::kPerfect:
        catchQualityBoost = 1.25F;
        break;
      case CatchFeedback::kSolid:
        catchQualityBoost = 1.12F;
        break;
      case CatchFeedback::kGraze:
        catchQualityBoost = 1.04F;
        break;
      case CatchFeedback::kMiss:
      default:
        catchQualityBoost = 0.85F;
        break;
      }

      const float impulseY = std::clamp(kBaseThrowImpulseY * m_state.powerMultiplier *
                                            breathBoost * catchQualityBoost,
                                        kBaseThrowImpulseY * 0.75F,
                                        kMaxThrowImpulseY);

      m_state.lastPulse = {
          .impulseY = impulseY,
          .breathBoost = breathBoost,
          .catchFeedback = m_state.catchFeedback,
          .catchRadiusNormalized = m_state.catchRadiusNormalized,
      };

      physics::PhysicsIntent intent{};
      intent.kind = physics::PhysicsIntentKind::kApplyImpulse;
      intent.bodyId = kThrowBodyId;
      intent.impulseOrVelocity.y = impulseY;
      intent.impulseOrVelocity.x = fitness.frc.mobilityScore * kMobilityImpulseScale;
      physicsWorld.queueIntent(intent);
    }
    m_state.phase = ThrowCatchPhase::kRecover;
    break;
  case ThrowCatchPhase::kRecover:
    m_state.phase = ThrowCatchPhase::kCatch;
    break;
  }
}

auto ThrowCatchPhysicsController::phaseDuration(ThrowCatchPhase phase) const -> double {
  switch (phase) {
  case ThrowCatchPhase::kCatch:
    return 0.22;
  case ThrowCatchPhase::kLoad:
    return 0.14;
  case ThrowCatchPhase::kThrow:
    return 0.07;
  case ThrowCatchPhase::kRecover:
    return 0.28;
  }
  return 0.25;
}

auto ThrowCatchPhysicsController::breathImpulseBoost(std::int8_t breathPhase) const -> float {
  switch (breathPhase) {
  case 1:
    return 1.12F;
  case -1:
    return 0.92F;
  case 0:
  default:
    return 1.0F;
  }
}

} // namespace nexus::gameplay
