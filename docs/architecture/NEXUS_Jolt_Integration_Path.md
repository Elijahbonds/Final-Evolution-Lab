# NEXUS Jolt Physics Integration Path

**Updated:** 2026-06-19  
**Phase:** Engine Phase 7 (Physics backend)  
**Scope:** `engine/physics/` only — gameplay throw-catch stays in `app/gameplay/`

## Current state (production stub)

| Capability | Status | Location |
|------------|--------|----------|
| Intent-queue physics step | **Active** | `engine/physics/src/physics_world.cpp` |
| Rigid-body registration API | **Active** | `PhysicsWorld::registerRigidBody()` |
| Throw-catch coupling | **Active** | `app/gameplay/src/throw_catch_physics.cpp` → `kApplyImpulse` intents |
| Gravity integration + velocity clamp (14 m/s) | **Active** | `integrateBodies()` + `clampVelocities()` |
| Jolt backend selection | **Deferred** | `PhysicsBackendKind::kJolt` falls back to stub with WARN log |

The intent-queue stub is **honest and test-covered** (`nexus_physics_test`, `nexus_gameplay_test`). It is sufficient for dunk throw-catch rhythm and HUD telemetry until full rigid-body collision is required for flagship sports sims.

## Jolt integration plan (engine-only)

### Step 1 — CMake opt-in

```cmake
option(NEXUS_ENABLE_JOLT "Link Jolt Physics rigid-body backend" OFF)
if(NEXUS_ENABLE_JOLT)
  FetchContent_Declare(JoltPhysics ...)
  target_compile_definitions(nexus_physics PRIVATE NEXUS_JOLT_BACKEND=1)
endif()
```

### Step 2 — Backend seam (no gameplay changes)

Keep `PhysicsIntent` as the gameplay-facing API. Add `JoltPhysicsBackend` private to `PhysicsWorld`:

1. `init()` — create `JPH::PhysicsSystem`, broad-phase layers, gravity from `PhysicsConfig`
2. `registerRigidBody()` — map `bodyId` → `JPH::BodyID`, box/sphere from descriptor
3. `consumeQueuedIntents()` — translate intents to Jolt impulses / velocity sets before `Update()`
4. `step()` — fixed 1/120 s sub-steps, sync `PhysicsBodyState` from Jolt transforms

### Step 3 — Throw-catch validation

Extend `nexus_physics_test`:

- Register ball body at y=1.5, apply upward impulse, assert peak height > spawn within 60 steps
- Ground plane body (static) — ball returns below rim height after apex (collision response)

### Step 4 — CI matrix

| Build | Tests |
|-------|-------|
| Headless default (`NEXUS_ENABLE_JOLT=OFF`) | 5/5 ctest — stub backend |
| Full + Jolt (`-DNEXUS_ENABLE_JOLT=ON`) | `nexus_physics_test` + optional `nexus_jolt_smoke_test` |

## Acceptance commands

```bash
# Stub backend (current ship path)
./scripts/nexus_build_gate.sh

# After Jolt lands
cmake -S . -B build-jolt -DNEXUS_ENABLE_JOLT=ON -DNEXUS_BUILD_TESTS=ON
cmake --build build-jolt && ctest --test-dir build-jolt -R nexus_physics_test
```

## UE parity gap

| UE 5.7 | NEXUS today | After Jolt |
|--------|-------------|------------|
| Chaos rigid bodies + CCD | Intent queue + clamp | Jolt bodies + impulses |
| Complex mesh colliders | None | Convex hull / compound (Phase 2) |
| Physics sub-stepping | Fixed 1/120 via gameplay | Jolt internal sub-steps |

**Verdict:** Throw-catch **playable today** via intent queue. Jolt unlocks ball-rim collision, props, and multi-body arena modes required for flagship parity.
