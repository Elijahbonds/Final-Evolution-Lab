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

void gravity_integrates_falling_body() {
  nexus::physics::PhysicsWorld world;
  require(world.init({}).isOk(), "physics init");

  nexus::physics::PhysicsIntent spawn{};
  spawn.kind = nexus::physics::PhysicsIntentKind::kSpawnProjectile;
  spawn.bodyId = 1;
  spawn.spawnPosition = {0.0F, 10.0F, 0.0F};
  spawn.impulseOrVelocity = {0.0F, 0.0F, 0.0F};
  world.queueIntent(spawn);

  for (int step = 0; step < 10; ++step) {
    world.step(1.0 / 120.0);
  }

  const auto body = world.bodyState(1);
  require(body.has_value(), "body exists");
  require(body->position.y < 10.0F, "gravity lowered body");
  require(body->velocity.y < 0.0F, "downward velocity");
}

void velocity_clamped_to_spec_max() {
  nexus::physics::PhysicsWorld world;
  require(world.init({}).isOk(), "physics init");

  nexus::physics::PhysicsIntent setVelocity{};
  setVelocity.kind = nexus::physics::PhysicsIntentKind::kSetVelocity;
  setVelocity.bodyId = 42;
  setVelocity.impulseOrVelocity = {100.0F, 0.0F, 0.0F};
  world.queueIntent(setVelocity);
  world.step(1.0 / 120.0);

  const auto body = world.bodyState(42);
  require(body.has_value(), "body exists");
  const float magnitude = std::sqrt(body->velocity.x * body->velocity.x +
                                    body->velocity.y * body->velocity.y +
                                    body->velocity.z * body->velocity.z);
  require(magnitude <= 14.01F, "velocity clamped to 14 m/s");
}

void integrate_gravity_intent_is_consumed() {
  nexus::physics::PhysicsWorld world;
  require(world.init({}).isOk(), "physics init");

  nexus::physics::PhysicsIntent gravityIntent{};
  gravityIntent.kind = nexus::physics::PhysicsIntentKind::kIntegrateGravity;
  gravityIntent.bodyId = 7;
  world.queueIntent(gravityIntent);
  world.step(1.0 / 60.0);

  require(!world.lastConsumedIntents().empty(), "gravity intent consumed");
  require(world.lastConsumedIntents().front().kind ==
              nexus::physics::PhysicsIntentKind::kIntegrateGravity,
          "gravity intent kind preserved");
}

void rigid_body_registration_and_throw_coupling() {
  nexus::physics::PhysicsWorld world;
  require(world.init({}).isOk(), "physics init");
  require(world.backendKind() == nexus::physics::PhysicsBackendKind::kIntentQueueStub,
          "default stub backend");

  constexpr std::uint64_t kBodyId = 1;
  nexus::physics::RigidBodyDescriptor body{};
  body.bodyId = kBodyId;
  body.initialPosition = {0.0F, 1.5F, 0.0F};
  body.massKg = 0.6F;
  require(world.registerRigidBody(body).isOk(), "register throw body");
  require(world.isBodyRegistered(kBodyId), "body registered");

  nexus::physics::PhysicsIntent impulse{};
  impulse.kind = nexus::physics::PhysicsIntentKind::kApplyImpulse;
  impulse.bodyId = kBodyId;
  impulse.impulseOrVelocity.y = 4.8F;
  world.queueIntent(impulse);
  world.step(1.0 / 120.0);

  const auto state = world.bodyState(kBodyId);
  require(state.has_value(), "registered body state");
  require(state->velocity.y > 0.0F, "throw impulse applied to body_id");
  require(state->position.y >= 1.5F, "body still near spawn height after one step");
}

void jolt_backend_falls_back_to_stub() {
  nexus::physics::PhysicsConfig config{};
  config.backend = nexus::physics::PhysicsBackendKind::kJolt;
  nexus::physics::PhysicsWorld world;
  require(world.init(config).isOk(), "jolt init falls back");
  require(world.backendKind() == nexus::physics::PhysicsBackendKind::kIntentQueueStub,
          "jolt request uses stub backend");
}

} // namespace

auto main() -> int {
  gravity_integrates_falling_body();
  velocity_clamped_to_spec_max();
  integrate_gravity_intent_is_consumed();
  rigid_body_registration_and_throw_coupling();
  jolt_backend_falls_back_to_stub();
  std::fprintf(stderr, "PASS: nexus_physics_test\n");
  return 0;
}
