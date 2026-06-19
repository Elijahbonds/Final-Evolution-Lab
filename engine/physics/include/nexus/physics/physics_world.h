#pragma once

#include "nexus/core/result.h"

#include <cstdint>
#include <deque>
#include <mutex>
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
/// Engine stub integrates intents without Jolt; swap in a real backend later.
struct PhysicsIntent {
  PhysicsIntentKind kind{PhysicsIntentKind::kApplyImpulse};
  std::uint64_t bodyId{0};
  Vec3 impulseOrVelocity{};
  Vec3 spawnPosition{};
  float massKg{1.0F};
  std::uint64_t sequenceId{0};
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

  void shutdown();

private:
  void consumeQueuedIntents();

  PhysicsConfig m_config;
  double m_simulationTimeSeconds{0.0};
  std::deque<PhysicsIntent> m_pendingIntents;
  std::vector<PhysicsIntent> m_lastConsumedIntents;
  mutable std::mutex m_mutex;
  std::uint64_t m_nextSequenceId{1};
  std::uint64_t m_totalConsumedIntents{0};
};

} // namespace nexus::physics
