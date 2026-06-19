#include "nexus/physics/physics_world.h"

#include "nexus/core/log.h"

#include <mutex>
#include <string>

namespace nexus::physics {

auto PhysicsWorld::init(PhysicsConfig config) -> Result<void> {
  m_config = config;
  m_simulationTimeSeconds = 0.0;
  m_pendingIntents.clear();
  m_lastConsumedIntents.clear();
  m_nextSequenceId = 1;
  m_totalConsumedIntents = 0;
  NEXUS_LOG_INFO(LogChannel::kPhysics, "Physics world initialized (intent-queue stub backend)");
  return Result<void>::ok();
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
  while (!intentsToConsume.empty()) {
    PhysicsIntent intent = intentsToConsume.front();
    intentsToConsume.pop_front();
    m_lastConsumedIntents.push_back(intent);
    ++m_totalConsumedIntents;

    if (batchSize <= 8) {
      switch (intent.kind) {
      case PhysicsIntentKind::kApplyImpulse:
        NEXUS_LOG_INFO(LogChannel::kPhysics,
                       "Stub apply impulse to body " + std::to_string(intent.bodyId));
        break;
      case PhysicsIntentKind::kSpawnProjectile:
        NEXUS_LOG_INFO(LogChannel::kPhysics,
                       "Stub spawn projectile body " + std::to_string(intent.bodyId));
        break;
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

void PhysicsWorld::shutdown() {
  m_pendingIntents.clear();
  m_lastConsumedIntents.clear();
  NEXUS_LOG_INFO(LogChannel::kPhysics, "Physics world shutdown");
}

} // namespace nexus::physics
