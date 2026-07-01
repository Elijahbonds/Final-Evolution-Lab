#include "nexus/core/perf_monitor.h"
#include "nexus/physics/physics_world.h"

#include <cmath>
#include <cstdio>
#include <cstdlib>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

auto distance(const nexus::physics::Vec3& a, const nexus::physics::Vec3& b) -> float {
  const float dx = a.x - b.x;
  const float dy = a.y - b.y;
  const float dz = a.z - b.z;
  return std::sqrt(dx * dx + dy * dy + dz * dz);
}

void ccd_prevents_floor_tunnelling() {
  nexus::core::PerfMonitor::instance().setTier(nexus::core::PerformanceTier::kHigh);
  nexus::physics::PhysicsConfig cfg{};
  cfg.continuousCollision = true;
  nexus::physics::PhysicsWorld world;
  require(world.init(cfg).isOk(), "physics init");

  // Body just above the floor moving downward fast enough to cross in one step.
  nexus::physics::PhysicsIntent spawn{};
  spawn.kind = nexus::physics::PhysicsIntentKind::kSpawnProjectile;
  spawn.bodyId = 9;
  spawn.spawnPosition = {0.0F, 0.05F, 0.0F};
  spawn.impulseOrVelocity = {0.0F, -14.0F, 0.0F};
  world.queueIntent(spawn);
  world.step(1.0 / 120.0);

  const auto body = world.bodyState(9);
  require(body.has_value(), "ccd body exists");
  require(body->position.y >= -0.001F, "body did not tunnel below floor");
  require(world.ccdResolutionCount() >= 1, "CCD time-of-impact resolved");
  require(body->velocity.y > 0.0F, "velocity reflected upward after bounce");
}

void distance_constraint_pulls_to_rest_length() {
  nexus::core::PerfMonitor::instance().setTier(nexus::core::PerformanceTier::kHigh);
  nexus::physics::PhysicsConfig cfg{};
  cfg.gravityMetersPerSecondSquared = 0.0F; // isolate the constraint
  cfg.constraintIterations = 12;
  nexus::physics::PhysicsWorld world;
  require(world.init(cfg).isOk(), "physics init");

  nexus::physics::RigidBodyDescriptor a{};
  a.bodyId = 1;
  a.initialPosition = {0.0F, 5.0F, 0.0F};
  a.massKg = 1.0F;
  nexus::physics::RigidBodyDescriptor b{};
  b.bodyId = 2;
  b.initialPosition = {3.0F, 5.0F, 0.0F};
  b.massKg = 1.0F;
  require(world.registerRigidBody(a).isOk(), "register a");
  require(world.registerRigidBody(b).isOk(), "register b");

  nexus::physics::PhysicsConstraint c{};
  c.bodyA = 1;
  c.bodyB = 2;
  c.restLength = 1.0F;
  c.kind = nexus::physics::ConstraintKind::kDistance;
  require(world.addConstraint(c).isOk(), "add distance constraint");
  require(world.constraintCount() == 1, "constraint registered");

  for (int i = 0; i < 30; ++i) {
    world.step(1.0 / 120.0);
  }
  const auto sa = world.bodyState(1);
  const auto sb = world.bodyState(2);
  require(sa.has_value() && sb.has_value(), "constraint bodies exist");
  const float d = distance(sa->position, sb->position);
  require(std::abs(d - 1.0F) < 0.05F, "distance converged to rest length");
}

void static_anchor_holds_ragdoll_link() {
  nexus::core::PerfMonitor::instance().setTier(nexus::core::PerformanceTier::kHigh);
  nexus::physics::PhysicsConfig cfg{};
  cfg.constraintIterations = 12;
  nexus::physics::PhysicsWorld world;
  require(world.init(cfg).isOk(), "physics init");

  // Static anchor (pin) above; dynamic body hangs below via a 1m link.
  nexus::physics::RigidBodyDescriptor anchor{};
  anchor.bodyId = 100;
  anchor.initialPosition = {0.0F, 5.0F, 0.0F};
  anchor.massKg = 1.0F;
  anchor.dynamic = false;
  nexus::physics::RigidBodyDescriptor hanging{};
  hanging.bodyId = 101;
  hanging.initialPosition = {0.0F, 4.0F, 0.0F};
  hanging.massKg = 1.0F;
  hanging.dynamic = true;
  require(world.registerRigidBody(anchor).isOk(), "register anchor");
  require(world.registerRigidBody(hanging).isOk(), "register hanging");

  nexus::physics::PhysicsConstraint c{};
  c.bodyA = 100;
  c.bodyB = 101;
  c.restLength = 1.0F;
  c.kind = nexus::physics::ConstraintKind::kDistance;
  require(world.addConstraint(c).isOk(), "add ragdoll link");

  for (int i = 0; i < 120; ++i) {
    world.step(1.0 / 120.0);
  }
  const auto sAnchor = world.bodyState(100);
  const auto sHang = world.bodyState(101);
  require(sAnchor.has_value() && sHang.has_value(), "ragdoll bodies exist");
  // Anchor must not move (static); link length preserved under gravity.
  require(std::abs(sAnchor->position.y - 5.0F) < 1e-3F, "static anchor stayed put");
  const float d = distance(sAnchor->position, sHang->position);
  require(std::abs(d - 1.0F) < 0.1F, "hanging body holds link length");
  require(sHang->position.y < sAnchor->position.y, "body hangs below anchor");
}

void ragdoll_chain_stays_linked() {
  nexus::core::PerfMonitor::instance().setTier(nexus::core::PerformanceTier::kHigh);
  nexus::physics::PhysicsConfig cfg{};
  cfg.constraintIterations = 16;
  nexus::physics::PhysicsWorld world;
  require(world.init(cfg).isOk(), "physics init");

  for (std::uint64_t id = 1; id <= 4; ++id) {
    nexus::physics::RigidBodyDescriptor d{};
    d.bodyId = id;
    d.initialPosition = {static_cast<float>(id) * 0.5F, 6.0F, 0.0F};
    d.massKg = 1.0F;
    d.dynamic = (id != 1); // first link pinned
    require(world.registerRigidBody(d).isOk(), "register chain body");
  }
  for (std::uint64_t id = 1; id < 4; ++id) {
    nexus::physics::PhysicsConstraint c{};
    c.bodyA = id;
    c.bodyB = id + 1;
    c.restLength = 0.5F;
    require(world.addConstraint(c).isOk(), "add chain link");
  }
  require(world.constraintCount() == 3, "three chain links");

  for (int i = 0; i < 200; ++i) {
    world.step(1.0 / 120.0);
  }
  for (std::uint64_t id = 1; id < 4; ++id) {
    const auto sa = world.bodyState(id);
    const auto sb = world.bodyState(id + 1);
    require(sa.has_value() && sb.has_value(), "chain body exists");
    const float d = distance(sa->position, sb->position);
    require(d < 0.75F, "adjacent chain links remain close to rest length");
  }
}

void rejects_invalid_constraint() {
  nexus::physics::PhysicsWorld world;
  require(world.init({}).isOk(), "physics init");
  nexus::physics::PhysicsConstraint c{};
  c.bodyA = 1;
  c.bodyB = 1;
  require(world.addConstraint(c).isErr(), "self-link rejected");
  c.bodyB = 2;
  require(world.addConstraint(c).isErr(), "unregistered body rejected");
}

} // namespace

auto main() -> int {
  ccd_prevents_floor_tunnelling();
  distance_constraint_pulls_to_rest_length();
  static_anchor_holds_ragdoll_link();
  ragdoll_chain_stays_linked();
  rejects_invalid_constraint();
  std::fprintf(stderr, "PASS: nexus_physics_advanced_test\n");
  return 0;
}
