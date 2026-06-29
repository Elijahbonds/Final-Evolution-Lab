#include "nexus/physics/physics_world.h"

#include "nexus/core/engine_scale_policy.h"
#include "nexus/core/job_system.h"
#include "nexus/core/log.h"
#include "nexus/core/perf_monitor.h"

#include <algorithm>
#include <cmath>
#include <mutex>
#include <string>

namespace nexus::physics {

namespace {

auto speed(const Vec3& v) -> float {
  return std::sqrt(v.x * v.x + v.y * v.y + v.z * v.z);
}

} // namespace

auto PhysicsWorld::init(PhysicsConfig config) -> Result<void> {
  m_config = config;
  m_simulationTimeSeconds = 0.0;
  m_pendingIntents.clear();
  m_lastConsumedIntents.clear();
  m_bodies.clear();
  m_registeredBodyIds.clear();
  m_constraints.clear();
  m_nextSequenceId = 1;
  m_totalConsumedIntents = 0;
  m_ccdResolutions = 0;

  if (m_config.constraintIterations == 0) {
    m_config.constraintIterations = 1;
  }

  if (m_config.backend == PhysicsBackendKind::kJolt) {
    NEXUS_LOG_WARN(LogChannel::kPhysics,
                   "Request for Engine API Extension: Jolt Physics rigid-body backend "
                   "(kJolt selected — falling back to intent-queue stub)");
    m_config.backend = PhysicsBackendKind::kIntentQueueStub;
  }

  NEXUS_LOG_INFO(LogChannel::kPhysics,
                 "Physics world initialized (intent-queue stub; CCD + multi-body "
                 "constraint solver; Jolt-ready registerRigidBody API)");
  return Result<void>::ok();
}

auto PhysicsWorld::registerRigidBody(RigidBodyDescriptor descriptor) -> Result<void> {
  if (descriptor.bodyId == 0) {
    return Result<void>::err("Rigid body bodyId must be non-zero");
  }
  if (isBodyRegistered(descriptor.bodyId)) {
    return Result<void>::err("Rigid body already registered");
  }

  PhysicsBodyState body{};
  body.bodyId = descriptor.bodyId;
  body.position = descriptor.initialPosition;
  body.massKg = descriptor.massKg > 0.0F ? descriptor.massKg : 1.0F;
  body.dynamic = descriptor.dynamic;
  m_bodies.push_back(body);
  m_registeredBodyIds.push_back(descriptor.bodyId);
  return Result<void>::ok();
}

auto PhysicsWorld::addConstraint(PhysicsConstraint constraint) -> Result<void> {
  if (constraint.bodyA == constraint.bodyB) {
    return Result<void>::err("Constraint must link two distinct bodies");
  }
  if (findBody(constraint.bodyA) == nullptr || findBody(constraint.bodyB) == nullptr) {
    return Result<void>::err("Constraint references unregistered body");
  }
  if (constraint.constraintId == 0) {
    constraint.constraintId = static_cast<std::uint64_t>(m_constraints.size()) + 1;
  }
  constraint.stiffness = std::clamp(constraint.stiffness, 0.0F, 1.0F);
  if (constraint.restLength < 0.0F) {
    constraint.restLength = 0.0F;
  }
  m_constraints.push_back(constraint);
  return Result<void>::ok();
}

auto PhysicsWorld::constraintCount() const -> std::size_t {
  return m_constraints.size();
}

auto PhysicsWorld::ccdResolutionCount() const -> std::uint64_t {
  return m_ccdResolutions;
}

auto PhysicsWorld::backendKind() const -> PhysicsBackendKind {
  return m_config.backend;
}

auto PhysicsWorld::isBodyRegistered(std::uint64_t bodyId) const -> bool {
  for (const std::uint64_t id : m_registeredBodyIds) {
    if (id == bodyId) {
      return true;
    }
  }
  return false;
}

void PhysicsWorld::queueIntent(PhysicsIntent intent) {
  if (intent.sequenceId == 0) {
    intent.sequenceId = m_nextSequenceId++;
  }
  std::scoped_lock lock(m_mutex);
  m_pendingIntents.push_back(intent);
}

auto PhysicsWorld::findBody(std::uint64_t bodyId) -> PhysicsBodyState* {
  for (PhysicsBodyState& body : m_bodies) {
    if (body.bodyId == bodyId) {
      return &body;
    }
  }
  return nullptr;
}

auto PhysicsWorld::findOrCreateBody(std::uint64_t bodyId) -> PhysicsBodyState& {
  for (PhysicsBodyState& body : m_bodies) {
    if (body.bodyId == bodyId) {
      return body;
    }
  }
  PhysicsBodyState body{};
  body.bodyId = bodyId;
  body.massKg = 1.0F;
  m_bodies.push_back(body);
  return m_bodies.back();
}

void PhysicsWorld::attachJobSystem(nexus::core::JobSystem* jobSystem) {
  m_jobSystem = jobSystem;
}

void PhysicsWorld::clampVelocities() {
  const auto clampIndex = [this](std::size_t index) {
    PhysicsBodyState& body = m_bodies[index];
    const float magnitude = speed(body.velocity);
    if (magnitude > kMaxSpeedMetersPerSecond && magnitude > 0.0F) {
      const float scale = kMaxSpeedMetersPerSecond / magnitude;
      body.velocity.x *= scale;
      body.velocity.y *= scale;
      body.velocity.z *= scale;
    }
  };

  const std::size_t bodyCount = m_bodies.size();
  if (m_jobSystem != nullptr && bodyCount >= 64) {
    const nexus::core::EngineScalePlan plan = nexus::core::activeScalePlan();
    const std::size_t workers =
        nexus::core::effectiveWorkerCount(plan, m_jobSystem->workerCount());
    if (workers > 1) {
      m_jobSystem->parallelFor(bodyCount, 16, clampIndex);
      return;
    }
  }

  for (std::size_t i = 0; i < bodyCount; ++i) {
    clampIndex(i);
  }
}

void PhysicsWorld::integrateBodies(double fixedDeltaSeconds) {
  const float dt = static_cast<float>(fixedDeltaSeconds);
  const float floorLevel = 0.0F;
  for (PhysicsBodyState& body : m_bodies) {
    if (!body.dynamic) {
      continue; // static/kinematic anchors hold position (ragdoll pins)
    }
    // Apply air resistance (linear drag)
    body.velocity.x *= (1.0F - m_config.linearDrag * dt);
    body.velocity.y *= (1.0F - m_config.linearDrag * dt);
    body.velocity.z *= (1.0F - m_config.linearDrag * dt);

    // Apply gravity
    body.velocity.y += m_config.gravityMetersPerSecondSquared * dt;

    // Integrate position (cache previous for CCD time-of-impact)
    const float prevY = body.position.y;
    body.position.x += body.velocity.x * dt;
    body.position.y += body.velocity.y * dt;
    body.position.z += body.velocity.z * dt;

    // --- Floor collision ---
    if (m_config.continuousCollision && prevY >= floorLevel &&
        body.position.y < floorLevel && body.velocity.y < 0.0F) {
      // Continuous collision: resolve at the exact time-of-impact, then advance
      // the remainder of the step with the reflected velocity (no tunnelling).
      const float travel = prevY - body.position.y; // > 0 (downward)
      const float toi = travel > 1e-6F ? (prevY - floorLevel) / travel : 0.0F;
      const float remaining = std::clamp(1.0F - toi, 0.0F, 1.0F);
      body.position.y = floorLevel;
      body.velocity.y = -body.velocity.y * m_config.bounceElasticity;
      body.velocity.x *= 0.85F;
      body.velocity.z *= 0.85F;
      // Advance the post-bounce remainder of the timestep.
      body.position.x += body.velocity.x * dt * remaining;
      body.position.y += body.velocity.y * dt * remaining;
      body.position.z += body.velocity.z * dt * remaining;
      if (body.position.y < floorLevel) {
        body.position.y = floorLevel;
      }
      ++m_ccdResolutions;
    } else if (body.position.y < floorLevel) {
      // Discrete fallback.
      body.position.y = floorLevel;
      body.velocity.y = -body.velocity.y * m_config.bounceElasticity;
      body.velocity.x *= 0.85F;
      body.velocity.z *= 0.85F;
    }

    // Collision detection with venue boundaries (e.g. walls at x = ±8.0, z = ±7.0)
    const float wallX = 8.0F;
    const float wallZ = 7.0F;
    if (body.position.x > wallX) {
      body.position.x = wallX;
      body.velocity.x = -body.velocity.x * m_config.bounceElasticity;
    } else if (body.position.x < -wallX) {
      body.position.x = -wallX;
      body.velocity.x = -body.velocity.x * m_config.bounceElasticity;
    }

    if (body.position.z > wallZ) {
      body.position.z = wallZ;
      body.velocity.z = -body.velocity.z * m_config.bounceElasticity;
    } else if (body.position.z < -wallZ) {
      body.position.z = -wallZ;
      body.velocity.z = -body.velocity.z * m_config.bounceElasticity;
    }

    // Hoop collision (e.g. hoop rim at x = 3.0, y = 3.05, z = 0.0)
    // Hoop ring radius is 0.225F. Let's check collision with hoop rim!
    const float hoopX = 3.0F;
    const float hoopY = 3.05F;
    const float hoopZ = 0.0F;
    const float hoopRadius = 0.225F;

    // Distance from body to hoop center in Y
    float dy = body.position.y - hoopY;
    if (std::abs(dy) < 0.15F) {
      // Distance in XZ plane from hoop center
      float dx = body.position.x - hoopX;
      float dz = body.position.z - hoopZ;
      float distXZ = std::sqrt(dx * dx + dz * dz);
      // If the ball hits the hoop rim
      if (std::abs(distXZ - hoopRadius) < 0.15F) {
        // Bounce off the rim!
        body.position.y = hoopY + (dy > 0.0F ? 0.15F : -0.15F);
        body.velocity.y = -body.velocity.y * m_config.bounceElasticity;
        body.velocity.x = -body.velocity.x * m_config.bounceElasticity;
        body.velocity.z = -body.velocity.z * m_config.bounceElasticity;
      }
    }
  }

  // Dynamic collision check reduction based on performance tier
  float collisionFactor = nexus::core::PerfMonitor::instance().getCollisionCheckFactor();
  bool skipCollisions = false;
  if (collisionFactor == 0.0F) {
    skipCollisions = true;
  } else if (collisionFactor < 1.0F) {
    static std::uint64_t frameCounter = 0;
    if (++frameCounter % 2 != 0) {
      skipCollisions = true;
    }
  }

  if (!skipCollisions) {
    // Inter-body collisions (e.g. player avatar vs ball, or player vs player)
    for (size_t i = 0; i < m_bodies.size(); ++i) {
      for (size_t j = i + 1; j < m_bodies.size(); ++j) {
        PhysicsBodyState& b1 = m_bodies[i];
        PhysicsBodyState& b2 = m_bodies[j];

        float r1 = (b1.bodyId == 1) ? 0.2F : 0.4F;
        float r2 = (b2.bodyId == 1) ? 0.2F : 0.4F;
        float minDist = r1 + r2;

        float dx = b2.position.x - b1.position.x;
        float dy = b2.position.y - b1.position.y;
        float dz = b2.position.z - b1.position.z;
        float dist = std::sqrt(dx * dx + dy * dy + dz * dz);

        if (dist < minDist && dist > 0.0F) {
          // Collision detected! Push them apart (penetration resolution)
          float overlap = minDist - dist;
          float nx = dx / dist;
          float ny = dy / dist;
          float nz = dz / dist;

          // Mass weights
          float m1 = b1.massKg;
          float m2 = b2.massKg;
          float totalMass = m1 + m2;

          // Separate based on mass
          b1.position.x -= nx * overlap * (m2 / totalMass);
          b1.position.y -= ny * overlap * (m2 / totalMass);
          b1.position.z -= nz * overlap * (m2 / totalMass);

          b2.position.x += nx * overlap * (m1 / totalMass);
          b2.position.y += ny * overlap * (m1 / totalMass);
          b2.position.z += nz * overlap * (m1 / totalMass);

          // Elastic collision response (velocity change)
          float kx = b1.velocity.x - b2.velocity.x;
          float ky = b1.velocity.y - b2.velocity.y;
          float kz = b1.velocity.z - b2.velocity.z;
          float relativeVelocityNormal = kx * nx + ky * ny + kz * nz;

          if (relativeVelocityNormal > 0.0F) {
            // Moving towards each other
            float restitution = m_config.bounceElasticity;
            float impulseScalar = (1.0F + restitution) * relativeVelocityNormal / (1.0F / m1 + 1.0F / m2);

            b1.velocity.x -= (impulseScalar / m1) * nx;
            b1.velocity.y -= (impulseScalar / m1) * ny;
            b1.velocity.z -= (impulseScalar / m1) * nz;

            b2.velocity.x += (impulseScalar / m2) * nx;
            b2.velocity.y += (impulseScalar / m2) * ny;
            b2.velocity.z += (impulseScalar / m2) * nz;
          }
        }
      }
    }
  }

  clampVelocities();
}

void PhysicsWorld::solveConstraints() {
  if (m_constraints.empty()) {
    return;
  }
  // Position-based dynamics: project bodies toward rest-length over several
  // iterations (Jolt-style stiff joints / ragdoll links). Mass-weighted so the
  // heavier body moves less. Deterministic fixed iteration order.
  for (std::uint32_t iter = 0; iter < m_config.constraintIterations; ++iter) {
    for (const PhysicsConstraint& c : m_constraints) {
      PhysicsBodyState* a = findBody(c.bodyA);
      PhysicsBodyState* b = findBody(c.bodyB);
      if (a == nullptr || b == nullptr) {
        continue;
      }
      const float wA = (a->dynamic && a->massKg > 0.0F) ? 1.0F / a->massKg : 0.0F;
      const float wB = (b->dynamic && b->massKg > 0.0F) ? 1.0F / b->massKg : 0.0F;
      const float wSum = wA + wB;
      if (wSum <= 0.0F) {
        continue; // both effectively static
      }

      float dx = b->position.x - a->position.x;
      float dy = b->position.y - a->position.y;
      float dz = b->position.z - a->position.z;
      float dist = std::sqrt(dx * dx + dy * dy + dz * dz);
      if (dist <= 1e-6F) {
        continue;
      }
      const float diff = dist - c.restLength;
      const float relax = (c.kind == ConstraintKind::kSpring) ? c.stiffness : 1.0F;
      const float corr = relax * diff / dist;

      const float ax = corr * (wA / wSum) * dx;
      const float ay = corr * (wA / wSum) * dy;
      const float az = corr * (wA / wSum) * dz;
      const float bx = corr * (wB / wSum) * dx;
      const float by = corr * (wB / wSum) * dy;
      const float bz = corr * (wB / wSum) * dz;

      a->position.x += ax;
      a->position.y += ay;
      a->position.z += az;
      b->position.x -= bx;
      b->position.y -= by;
      b->position.z -= bz;
    }
  }
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

    PhysicsBodyState& body = findOrCreateBody(intent.bodyId);
    switch (intent.kind) {
    case PhysicsIntentKind::kApplyImpulse: {
      const float invMass = body.massKg > 0.0F ? 1.0F / body.massKg : 1.0F;
      body.velocity.x += intent.impulseOrVelocity.x * invMass;
      body.velocity.y += intent.impulseOrVelocity.y * invMass;
      body.velocity.z += intent.impulseOrVelocity.z * invMass;
      break;
    }
    case PhysicsIntentKind::kSetVelocity:
      body.velocity = intent.impulseOrVelocity;
      break;
    case PhysicsIntentKind::kSpawnProjectile:
      body.position = intent.spawnPosition;
      body.velocity = intent.impulseOrVelocity;
      body.massKg = intent.massKg > 0.0F ? intent.massKg : body.massKg;
      break;
    case PhysicsIntentKind::kIntegrateGravity:
      break;
    }
  }

  if (batchSize > 8) {
    NEXUS_LOG_INFO(LogChannel::kPhysics,
                   "Consumed " + std::to_string(batchSize) + " physics intents (total " +
                       std::to_string(m_totalConsumedIntents) + ")");
  }
}

void PhysicsWorld::step(double fixedDeltaSeconds) {
  consumeQueuedIntents();

  float substepFactor = nexus::core::PerfMonitor::instance().getPhysicsSubstepFactor();

  if (substepFactor <= 0.25F) {
    // Low power tier: skip physics simulation on alternate frames to save CPU!
    static bool skipFrame = false;
    skipFrame = !skipFrame;
    if (skipFrame) {
      m_simulationTimeSeconds += fixedDeltaSeconds;
      return;
    }
    // Run 1 step with double delta time to keep simulation speed consistent
    integrateBodies(fixedDeltaSeconds * 2.0);
    solveConstraints();
  } else if (substepFactor <= 0.5F) {
    // Balanced tier or budget exceeded: 1 substep
    integrateBodies(fixedDeltaSeconds);
    solveConstraints();
  } else {
    // High performance tier: 2 substeps for maximum accuracy
    double stepDt = fixedDeltaSeconds / 2.0;
    integrateBodies(stepDt);
    solveConstraints();
    integrateBodies(stepDt);
    solveConstraints();
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

auto PhysicsWorld::bodyState(std::uint64_t bodyId) const -> std::optional<PhysicsBodyState> {
  for (const PhysicsBodyState& body : m_bodies) {
    if (body.bodyId == bodyId) {
      return body;
    }
  }
  return std::nullopt;
}

auto PhysicsWorld::bodies() const -> const std::vector<PhysicsBodyState>& {
  return m_bodies;
}

void PhysicsWorld::shutdown() {
  m_pendingIntents.clear();
  m_lastConsumedIntents.clear();
  m_bodies.clear();
  m_registeredBodyIds.clear();
  m_constraints.clear();
  NEXUS_LOG_INFO(LogChannel::kPhysics, "Physics world shutdown");
}

} // namespace nexus::physics
