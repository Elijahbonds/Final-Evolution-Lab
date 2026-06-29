#include "nexus/physics/physics_world.h"

#include "nexus/core/log.h"

#include <mutex>
#include <string>

namespace nexus::physics {

auto PhysicsWorld::init(PhysicsConfig config) -> Result<void> {
  std::scoped_lock lock(m_mutex);
  m_config = config;
  m_simulationTimeSeconds = 0.0;
  m_pendingIntents.clear();
  m_lastConsumedIntents.clear();
  m_bodies.clear();
  m_nextSequenceId = 1;
  m_totalConsumedIntents = 0;
  NEXUS_LOG_INFO(LogChannel::kPhysics,
                 "Physics world initialized (deterministic rigid-body integrator)");
  return Result<void>::ok();
}

auto PhysicsWorld::effectiveGravity() const -> float {
  // Honor the configured gravity; fall back to standard gravity only when a
  // zero-initialized config slips through so bodies never freeze in mid-air.
  return m_config.gravityMetersPerSecondSquared != 0.0F ? m_config.gravityMetersPerSecondSquared
                                                        : -9.81F;
}

auto PhysicsWorld::ensureBodyLocked(std::uint64_t id, float massHint) -> RigidBody& {
  auto it = m_bodies.find(id);
  if (it != m_bodies.end()) {
    return it->second;
  }
  RigidBody body;
  body.mass = massHint > 0.0F ? massHint : 1.0F;
  return m_bodies.emplace(id, body).first->second;
}

void PhysicsWorld::applyIntentLocked(const PhysicsIntent& intent) {
  RigidBody& body = ensureBodyLocked(intent.bodyId, intent.massKg);
  switch (intent.kind) {
  case PhysicsIntentKind::kSpawnProjectile:
    body.mass = intent.massKg > 0.0F ? intent.massKg : 1.0F;
    body.position = {intent.spawnPosition.x, intent.spawnPosition.y, intent.spawnPosition.z};
    body.velocity = {intent.impulseOrVelocity.x, intent.impulseOrVelocity.y,
                     intent.impulseOrVelocity.z};
    break;
  case PhysicsIntentKind::kApplyImpulse:
    // Impulse changes velocity by impulse / mass (delta-v); with the default
    // unit mass this matches gameplay callers that pass a velocity delta.
    body.velocity[0] += intent.impulseOrVelocity.x / body.mass;
    body.velocity[1] += intent.impulseOrVelocity.y / body.mass;
    body.velocity[2] += intent.impulseOrVelocity.z / body.mass;
    break;
  }
}

void PhysicsWorld::queueIntent(PhysicsIntent intent) {
  if (intent.sequenceId == 0) {
    intent.sequenceId = m_nextSequenceId++;
  }
  std::scoped_lock lock(m_mutex);
  m_pendingIntents.push_back(intent);
}

void PhysicsWorld::consumeQueuedIntents() {
  std::deque<PhysicsIntent> intentsToConsume;
  {
    std::scoped_lock lock(m_mutex);
    intentsToConsume.swap(m_pendingIntents);
  }

  m_lastConsumedIntents.clear();
  m_lastConsumedIntents.reserve(intentsToConsume.size());

  const std::size_t batchSize = intentsToConsume.size();
  {
    std::scoped_lock lock(m_mutex);
    while (!intentsToConsume.empty()) {
      PhysicsIntent intent = intentsToConsume.front();
      intentsToConsume.pop_front();
      m_lastConsumedIntents.push_back(intent);
      ++m_totalConsumedIntents;
      applyIntentLocked(intent);

      if (batchSize <= 8) {
        switch (intent.kind) {
        case PhysicsIntentKind::kApplyImpulse:
          NEXUS_LOG_INFO(LogChannel::kPhysics,
                         "Apply impulse to body " + std::to_string(intent.bodyId));
          break;
        case PhysicsIntentKind::kSpawnProjectile:
          NEXUS_LOG_INFO(LogChannel::kPhysics,
                         "Spawn projectile body " + std::to_string(intent.bodyId));
          break;
        }
      }
    }
  }

  if (batchSize > 8) {
    NEXUS_LOG_INFO(LogChannel::kPhysics,
                   "Consumed " + std::to_string(batchSize) + " physics intents (total " +
                       std::to_string(m_totalConsumedIntents) + ")");
  } else if (batchSize > 0) {
    NEXUS_LOG_INFO(LogChannel::kPhysics,
                   "Consumed " + std::to_string(batchSize) + " physics intent(s)");
  }
}

void PhysicsWorld::step(double fixedDeltaSeconds) {
  consumeQueuedIntents();

  const auto dt = static_cast<float>(fixedDeltaSeconds);
  const float gravity = effectiveGravity();
  {
    std::scoped_lock lock(m_mutex);
    for (auto& [id, body] : m_bodies) {
      // Semi-implicit (symplectic) Euler: integrate velocity first, then position.
      body.velocity[1] += gravity * dt;
      body.position[0] += body.velocity[0] * dt;
      body.position[1] += body.velocity[1] * dt;
      body.position[2] += body.velocity[2] * dt;
    }
  }

  m_simulationTimeSeconds += fixedDeltaSeconds;
}

auto PhysicsWorld::lastConsumedIntents() const -> const std::vector<PhysicsIntent>& {
  return m_lastConsumedIntents;
}

auto PhysicsWorld::simulationTimeSeconds() const -> double {
  return m_simulationTimeSeconds;
}

auto PhysicsWorld::pendingIntentCount() const -> std::size_t {
  std::scoped_lock lock(m_mutex);
  return m_pendingIntents.size();
}

auto PhysicsWorld::totalConsumedIntents() const -> std::uint64_t {
  return m_totalConsumedIntents;
}

auto PhysicsWorld::bodyState(std::uint64_t id) const -> std::optional<BodyState> {
  std::scoped_lock lock(m_mutex);
  auto it = m_bodies.find(id);
  if (it == m_bodies.end()) {
    return std::nullopt;
  }
  const RigidBody& body = it->second;
  return BodyState{id, body.position, body.velocity, body.mass};
}

auto PhysicsWorld::bodyCount() const -> std::size_t {
  std::scoped_lock lock(m_mutex);
  return m_bodies.size();
}

void PhysicsWorld::shutdown() {
  std::scoped_lock lock(m_mutex);
  m_pendingIntents.clear();
  m_lastConsumedIntents.clear();
  m_bodies.clear();
  NEXUS_LOG_INFO(LogChannel::kPhysics, "Physics world shutdown");
}

} // namespace nexus::physics
