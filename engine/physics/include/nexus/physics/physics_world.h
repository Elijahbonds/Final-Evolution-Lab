#pragma once

#include "nexus/core/result.h"

#include <array>
#include <cstdint>
#include <deque>
#include <mutex>
#include <optional>
#include <unordered_map>
#include <vector>

namespace nexus::physics {

struct PhysicsConfig {
  float gravityMetersPerSecondSquared{-9.80665F};
};

struct Vec3 {
  float x{0.0F};
  float y{0.0F};
  float z{0.0F};
};

enum class PhysicsIntentKind : std::uint8_t {
  kApplyImpulse,
  kSpawnProjectile,
};

/// Gameplay-facing physics intent queued for the next fixed step.
/// Intents mutate the deterministic rigid-body store on the next step().
struct PhysicsIntent {
  PhysicsIntentKind kind{PhysicsIntentKind::kApplyImpulse};
  std::uint64_t bodyId{0};
  Vec3 impulseOrVelocity{};
  Vec3 spawnPosition{};
  float massKg{1.0F};
  std::uint64_t sequenceId{0};
};

/// Immutable snapshot of a rigid body's state, returned by query methods.
struct BodyState {
  std::uint64_t id{0};
  std::array<float, 3> position{{0.0F, 0.0F, 0.0F}};
  std::array<float, 3> velocity{{0.0F, 0.0F, 0.0F}};
  float mass{1.0F};
};

class PhysicsWorld {
public:
  auto init(PhysicsConfig config) -> Result<void>;
  void step(double fixedDeltaSeconds);

  /// Queues an intent consumed on the next physics step (thread-safe for IO thread).
  void queueIntent(PhysicsIntent intent);

  /// Returns intents consumed during the latest step (for gameplay diagnostics).
  [[nodiscard]] auto lastConsumedIntents() const -> const std::vector<PhysicsIntent>&;

  [[nodiscard]] auto simulationTimeSeconds() const -> double;
  [[nodiscard]] auto pendingIntentCount() const -> std::size_t;
  [[nodiscard]] auto totalConsumedIntents() const -> std::uint64_t;

  /// Returns the state of body `id`, or nullopt if it has never been referenced (thread-safe).
  [[nodiscard]] auto bodyState(std::uint64_t id) const -> std::optional<BodyState>;

  /// Returns the number of rigid bodies currently tracked (thread-safe).
  [[nodiscard]] auto bodyCount() const -> std::size_t;

  void shutdown();

private:
  struct RigidBody {
    std::array<float, 3> position{{0.0F, 0.0F, 0.0F}};
    std::array<float, 3> velocity{{0.0F, 0.0F, 0.0F}};
    float mass{1.0F};
  };

  void consumeQueuedIntents();
  // The following helpers require m_mutex to be held by the caller.
  auto ensureBodyLocked(std::uint64_t id, float massHint) -> RigidBody&;
  void applyIntentLocked(const PhysicsIntent& intent);
  [[nodiscard]] auto effectiveGravity() const -> float;

  PhysicsConfig m_config;
  double m_simulationTimeSeconds{0.0};
  std::deque<PhysicsIntent> m_pendingIntents;
  std::vector<PhysicsIntent> m_lastConsumedIntents;
  std::unordered_map<std::uint64_t, RigidBody> m_bodies;
  mutable std::mutex m_mutex;
  std::uint64_t m_nextSequenceId{1};
  std::uint64_t m_totalConsumedIntents{0};
};

} // namespace nexus::physics
