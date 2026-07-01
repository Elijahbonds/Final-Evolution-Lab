#pragma once

#include "nexus/core/result.h"

#include <cstdint>
#include <deque>
#include <mutex>
#include <optional>
#include <vector>

namespace nexus::core {
class JobSystem;
}

namespace nexus::physics {

enum class PhysicsBackendKind : std::uint8_t {
  kIntentQueueStub,
  kJolt,
};

struct PhysicsConfig {
  float gravityMetersPerSecondSquared{-11.5F};
  PhysicsBackendKind backend{PhysicsBackendKind::kIntentQueueStub};
  float bounceElasticity{0.85F};
  float linearDrag{0.02F};
  // Advanced solver (Workstream 2). CCD prevents fast-body tunnelling through the
  // floor; constraintIterations drives the Jolt-style position solver used by
  // ragdoll/joint constraints. Defaults preserve legacy single-body behaviour.
  bool continuousCollision{true};
  std::uint32_t constraintIterations{8};
};

struct Vec3 {
  float x{0.0F};
  float y{0.0F};
  float z{0.0F};
};

struct RigidBodyDescriptor {
  std::uint64_t bodyId{0};
  Vec3 initialPosition{};
  float massKg{1.0F};
  bool dynamic{true};
};

enum class PhysicsIntentKind : std::uint8_t {
  kApplyImpulse,
  kSpawnProjectile,
  kIntegrateGravity,
  kSetVelocity,
};

/// Gameplay-facing physics intent queued for the next fixed step.
/// Engine stub integrates intents without Jolt; swap in a real backend later.
struct PhysicsIntent {
  PhysicsIntentKind kind{PhysicsIntentKind::kApplyImpulse};
  std::uint64_t bodyId{0};
  Vec3 impulseOrVelocity{};
  Vec3 spawnPosition{};
  float massKg{1.0F};
  std::uint64_t sequenceId{0};
};

struct PhysicsBodyState {
  std::uint64_t bodyId{0};
  Vec3 position{};
  Vec3 velocity{};
  float massKg{1.0F};
  bool dynamic{true};
};

/// Joint/distance constraint used to assemble ragdolls and articulated bodies.
enum class ConstraintKind : std::uint8_t {
  kDistance, // hard rest-length link (PBD projection)
  kSpring,   // soft rest-length link (stiffness-scaled correction)
};

struct PhysicsConstraint {
  std::uint64_t constraintId{0};
  std::uint64_t bodyA{0};
  std::uint64_t bodyB{0};
  float restLength{1.0F};
  float stiffness{1.0F}; // [0,1] correction fraction per iteration for kSpring
  ConstraintKind kind{ConstraintKind::kDistance};
};

class PhysicsWorld {
public:
  auto init(PhysicsConfig config) -> Result<void>;
  auto registerRigidBody(RigidBodyDescriptor descriptor) -> Result<void>;
  void step(double fixedDeltaSeconds);

  /// Adds a joint/distance constraint (ragdoll assembly). Both bodies must exist.
  auto addConstraint(PhysicsConstraint constraint) -> Result<void>;
  [[nodiscard]] auto constraintCount() const -> std::size_t;

  /// Queues an intent consumed on the next physics step (thread-safe for IO thread).
  void queueIntent(PhysicsIntent intent);

  /// Returns intents consumed during the latest step (for gameplay diagnostics).
  [[nodiscard]] auto lastConsumedIntents() const -> const std::vector<PhysicsIntent>&;

  [[nodiscard]] auto simulationTimeSeconds() const -> double;
  [[nodiscard]] auto pendingIntentCount() const -> std::size_t;
  [[nodiscard]] auto totalConsumedIntents() const -> std::uint64_t;
  [[nodiscard]] auto bodyState(std::uint64_t bodyId) const -> std::optional<PhysicsBodyState>;
  [[nodiscard]] auto bodies() const -> const std::vector<PhysicsBodyState>&;
  [[nodiscard]] auto backendKind() const -> PhysicsBackendKind;
  [[nodiscard]] auto isBodyRegistered(std::uint64_t bodyId) const -> bool;
  /// Count of CCD time-of-impact resolutions since init (diagnostics/tests).
  [[nodiscard]] auto ccdResolutionCount() const -> std::uint64_t;

  void shutdown();

  /// Optional work-stealing scheduler for parallel body integration (Engine::tick).
  void attachJobSystem(nexus::core::JobSystem* jobSystem);

private:
  void consumeQueuedIntents();
  void integrateBodies(double fixedDeltaSeconds);
  void solveConstraints();
  [[nodiscard]] auto findBody(std::uint64_t bodyId) -> PhysicsBodyState*;
  [[nodiscard]] auto findOrCreateBody(std::uint64_t bodyId) -> PhysicsBodyState&;
  void clampVelocities();

  static constexpr float kMaxSpeedMetersPerSecond = 14.0F;

  PhysicsConfig m_config;
  std::vector<std::uint64_t> m_registeredBodyIds;
  double m_simulationTimeSeconds{0.0};
  std::deque<PhysicsIntent> m_pendingIntents;
  std::vector<PhysicsIntent> m_lastConsumedIntents;
  std::vector<PhysicsBodyState> m_bodies;
  std::vector<PhysicsConstraint> m_constraints;
  mutable std::mutex m_mutex;
  std::uint64_t m_nextSequenceId{1};
  std::uint64_t m_totalConsumedIntents{0};
  std::uint64_t m_ccdResolutions{0};
  nexus::core::JobSystem* m_jobSystem{nullptr};
};

} // namespace nexus::physics
