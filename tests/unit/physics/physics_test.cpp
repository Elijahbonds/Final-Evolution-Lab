// Standalone unit test for the deterministic rigid-body integrator in
// nexus::physics::PhysicsWorld. Links nexus_physics + nexus_core.
#include "nexus/physics/physics_world.h"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

namespace {

int g_failures = 0;

void check(bool condition, const char* message) {
  if (condition) {
    std::printf("PASS: %s\n", message);
  } else {
    std::printf("FAIL: %s\n", message);
    ++g_failures;
  }
}

bool approx(float a, float b, float tolerance = 1e-3F) {
  return std::fabs(a - b) <= tolerance;
}

// A projectile launched straight up should decelerate, peak, then fall, with
// its Y velocity dropping by exactly gravity*dt each fixed step.
void projectile_rises_then_falls_under_gravity() {
  nexus::physics::PhysicsWorld world;
  nexus::physics::PhysicsConfig config;
  config.gravityMetersPerSecondSquared = -10.0F; // round number for clean asserts
  check(world.init(config).isOk(), "physics init with custom gravity");

  constexpr std::uint64_t kBodyId = 7;
  constexpr float kLaunchVy = 20.0F;
  const double dt = 0.1;
  const float dtF = static_cast<float>(dt);

  nexus::physics::PhysicsIntent spawn{};
  spawn.kind = nexus::physics::PhysicsIntentKind::kSpawnProjectile;
  spawn.bodyId = kBodyId;
  spawn.spawnPosition = {0.0F, 0.0F, 0.0F};
  spawn.impulseOrVelocity = {0.0F, kLaunchVy, 0.0F};
  spawn.massKg = 2.0F;
  world.queueIntent(spawn);

  // First step consumes the spawn intent and integrates one tick.
  world.step(dt);
  check(world.bodyCount() == 1, "spawn created exactly one body");

  auto state = world.bodyState(kBodyId);
  check(state.has_value(), "spawned body is queryable");
  check(approx(state->mass, 2.0F), "spawned body keeps its mass");

  // After one step the velocity dropped by g*dt and the body has risen.
  float expectedVy = kLaunchVy + (-10.0F * dtF);
  check(approx(state->velocity[1], expectedVy), "vy decreases by g*dt after first step");
  check(state->position[1] > 0.0F, "projectile rises above origin");

  // Step until the projectile peaks and starts descending.
  float previousY = state->position[1];
  bool sawDescent = false;
  float prevVy = state->velocity[1];
  for (int i = 0; i < 60; ++i) {
    world.step(dt);
    auto s = world.bodyState(kBodyId);
    expectedVy -= 10.0F * dtF;
    check(approx(s->velocity[1], expectedVy), "vy keeps decreasing by g*dt each step");
    if (s->position[1] < previousY) {
      sawDescent = true;
    }
    previousY = s->position[1];
    check(s->velocity[1] < prevVy, "vy strictly decreasing under gravity");
    prevVy = s->velocity[1];
  }
  check(sawDescent, "projectile eventually falls back down");
  check(world.bodyState(kBodyId)->velocity[1] < 0.0F, "projectile ends moving downward");
}

// Applying an impulse to an id that was never referenced auto-creates a body
// at the origin and changes its velocity (delta-v = impulse / mass).
void impulse_to_fresh_body_changes_velocity() {
  nexus::physics::PhysicsWorld world;
  check(world.init({}).isOk(), "physics init with default gravity");

  constexpr std::uint64_t kBodyId = 99;
  check(!world.bodyState(kBodyId).has_value(), "body absent before any intent");

  nexus::physics::PhysicsIntent impulse{};
  impulse.kind = nexus::physics::PhysicsIntentKind::kApplyImpulse;
  impulse.bodyId = kBodyId;
  impulse.impulseOrVelocity = {3.0F, 0.0F, -4.0F};
  impulse.massKg = 1.0F;
  world.queueIntent(impulse);

  // Use a zero dt step so we can assert the impulse effect in isolation.
  world.step(0.0);

  auto state = world.bodyState(kBodyId);
  check(state.has_value(), "impulse auto-created the body");
  check(approx(state->velocity[0], 3.0F), "impulse changed x velocity");
  check(approx(state->velocity[2], -4.0F), "impulse changed z velocity");
  check(approx(state->position[0], 0.0F) && approx(state->position[1], 0.0F) &&
            approx(state->position[2], 0.0F),
        "auto-created body starts at origin");
}

// A body at rest must accelerate and move downward once gravity is applied.
void body_dropped_from_rest_falls() {
  nexus::physics::PhysicsWorld world;
  nexus::physics::PhysicsConfig config;
  config.gravityMetersPerSecondSquared = -9.81F;
  check(world.init(config).isOk(), "physics init for drop test");

  constexpr std::uint64_t kBodyId = 3;
  nexus::physics::PhysicsIntent spawn{};
  spawn.kind = nexus::physics::PhysicsIntentKind::kSpawnProjectile;
  spawn.bodyId = kBodyId;
  spawn.spawnPosition = {0.0F, 100.0F, 0.0F};
  spawn.impulseOrVelocity = {0.0F, 0.0F, 0.0F}; // at rest
  world.queueIntent(spawn);

  const double dt = 1.0 / 60.0;
  for (int i = 0; i < 30; ++i) {
    world.step(dt);
  }

  auto state = world.bodyState(kBodyId);
  check(state.has_value(), "dropped body queryable");
  check(state->velocity[1] < 0.0F, "body at rest gains downward velocity");
  check(state->position[1] < 100.0F, "body at rest moves below its start height");
}

// Existing diagnostics must keep working alongside the integrator.
void diagnostics_still_track_intents() {
  nexus::physics::PhysicsWorld world;
  check(world.init({}).isOk(), "physics init for diagnostics");

  nexus::physics::PhysicsIntent impulse{};
  impulse.kind = nexus::physics::PhysicsIntentKind::kApplyImpulse;
  impulse.bodyId = 1;
  impulse.impulseOrVelocity = {0.0F, 8.0F, 0.0F};
  world.queueIntent(impulse);

  check(world.pendingIntentCount() == 1, "intent pending before step");
  world.step(1.0 / 60.0);
  check(world.pendingIntentCount() == 0, "intent consumed on step");
  check(world.totalConsumedIntents() == 1, "total consumed counted");
  check(world.lastConsumedIntents().size() == 1, "last consumed recorded");
}

} // namespace

auto main() -> int {
  projectile_rises_then_falls_under_gravity();
  impulse_to_fresh_body_changes_velocity();
  body_dropped_from_rest_falls();
  diagnostics_still_track_intents();

  if (g_failures == 0) {
    std::printf("ALL PHYSICS TESTS PASSED\n");
    return 0;
  }
  std::printf("%d PHYSICS TEST(S) FAILED\n", g_failures);
  return 1;
}
