# NEXUS System Specifications

> Source of truth: live code under `engine/`, `app/gameplay/`, `runtime/`, and root `CMakeLists.txt`.

## Purpose

NEXUS (Neural EXecution Unified System) is a C++20 engine with a JSON agent bridge for LLM-driven terrain editing and FEL gameplay hooks. Phase 1 delivers a runnable dev runtime (SDL3 + Vulkan smoke test), fixed-timestep loop, voxel creative mode, and headless protocol tests.

## Project layout

```
Final-Evolution-Lab/
├── CMakeLists.txt                 # Root build; all nexus_* targets
├── runtime/src/main.cpp           # Dev entry: wires subsystems, runs Engine
├── engine/
│   ├── core/                      # Engine loop, Result, Log
│   ├── ai_interface/              # AgentServer, AgentTransport, CommandRouter
│   ├── creative/                  # VoxelWorld, WorldManipulator
│   ├── physics/                   # PhysicsWorld (intent-queue stub)
│   └── renderer/                  # VulkanRenderer + embedded SPIR-V shaders
├── app/gameplay/                  # FEL app layer (fitness, throw-catch, creative parser)
├── tests/unit/
│   ├── ai_interface/              # Protocol smoke test
│   └── gameplay/                  # Gameplay layer smoke test
└── docs/architecture/             # This folder
```

Shaders live at `engine/renderer/shaders/` (`triangle.vert`, `triangle.frag`) with precompiled SPIR-V in `triangle_shader_spv.h`.

## CMake targets

| Target | Role | Key links |
|--------|------|-----------|
| `nexus_core` | `Result`, `Log` | — |
| `nexus_physics` | Fixed-step intent queue stub | `nexus_core` |
| `nexus_creative` | Voxel storage + terrain commands | `nexus_core`, `nlohmann_json` |
| `nexus_ai_interface` | JSON queue, router, transport | `nexus_core`, `nexus_creative`, `nlohmann_json` |
| `nexus_gameplay` | FEL fitness / throw-catch / creative parser | above + `nexus_physics` |
| `nexus_renderer` | SDL3 window + Vulkan swapchain | `nexus_core`, `SDL3`, `Vulkan` |
| `nexus_engine` | Main loop (`Engine::tick`) | `nexus_core`, `nexus_physics`, `nexus_renderer`, `nexus_ai_interface` |
| `nexus_runtime` | Dev executable | `nexus_engine`, `nexus_gameplay` |

**CMake options**

- `NEXUS_BUILD_TESTS` (default ON)
- `NEXUS_BUILD_RUNTIME` (default ON; requires renderer)
- `NEXUS_ENABLE_RENDERER` (default ON; OFF disables runtime)

**External dependencies:** Vulkan, SDL3, nlohmann/json (package or FetchContent v3.11.3).

**Future (not wired):** Jolt Physics, VMA, WebSocket library, Catch2, Dear ImGui, meshoptimizer.

## Coding patterns

1. **Errors:** `Result<T>` / `Result<void>` — no exceptions for engine control flow.
2. **Logging:** `NEXUS_LOG_INFO/WARN/ERROR(LogChannel::k*, "...")`.
3. **JSON:** `nlohmann::json`; serializable structs use `NLOHMANN_DEFINE_TYPE_INTRUSIVE` where applicable.
4. **Namespaces:** `nexus::core`, `nexus::ai`, `nexus::creative`, `nexus::physics`, `nexus::renderer`, `nexus::gameplay`.
5. **Lifecycle:** subsystems expose `init(...) -> Result<void>` and `shutdown()`.
6. **Separation:** engine never depends on `app/`; gameplay hooks in via `ApplicationUpdateHook` and `GameplayCommandHandler` interfaces.

## Core loop order

Authoritative order in `engine/core/src/engine.cpp`:

1. **Input** — `VulkanRenderer::pollInput()`
2. **Agent drain** — `AgentServer::processQueuedCommands(maxCommandsPerFrame)` *(before physics)*
3. **Fixed-step physics** — accumulator at `fixedTimestepSeconds` (default 1/60 s)
4. **Application hook** — `ApplicationUpdateHook::update()` (gameplay reads agent responses, queues physics intents)
5. **Render** — `VulkanRenderer::renderFrame()`

**Default `EngineConfig`**

| Field | Default | Purpose |
|-------|---------|---------|
| `fixedTimestepSeconds` | 0.0167 | 60 Hz physics |
| `maxFrameTimeSeconds` | 0.25 | Spiral-of-death cap |
| `maxCommandsPerFrame` | 32 | AI budget per frame |

## Runtime wiring (`runtime/src/main.cpp`)

Boot order: renderer → physics → voxel world + manipulator → command router → gameplay app → agent server → transport (stdin + TCP :9090) → engine.

Shutdown reverses that order.

## Performance constraints (Phase 1)

| System | Budget | Enforcement |
|--------|--------|-------------|
| AI command processing | ≤ 32 cmds/frame | `EngineConfig::maxCommandsPerFrame` |
| Physics | 60 Hz fixed | Accumulator independent of render rate |
| Terrain fill | ≤ 32,768 voxels/cmd | `WorldManipulator::fillRegion` |
| Creative radius | ≤ 16 voxels | `VoxelCommandParser::kMaxCreativeRadius` |
| Frame catch-up | ≤ 250 ms | `maxFrameTimeSeconds` |

## Subsystem maturity

| Subsystem | Status |
|-----------|--------|
| Core loop + Result + Log | **Implemented** |
| Agent queue + TCP/stdin transport | **Implemented** |
| Terrain routing (`terrain.*`) | **Implemented** |
| FEL gameplay commands (`fel.*`, `fitness.*`) | **Implemented** (app layer) |
| Creative voxel storage + dirty chunks | **Implemented** |
| Vulkan swapchain + triangle smoke test | **Implemented** |
| Physics | **Stub** (intent queue, no Jolt) |
| Voxel meshing / GPU terrain | **Not started** |
| ECS, undo/redo, chunk streaming | **Not started** |

## Build & test

```bash
# Headless (no Vulkan/SDL3 required)
cmake -S . -B build-headless -DNEXUS_ENABLE_RENDERER=OFF
cmake --build build-headless
cd build-headless && ctest

# Full dev runtime
cmake -S . -B build-full
cmake --build build-full
./build-full/nexus_runtime
```

Expected: `ctest` reports 2/2 (`nexus_protocol_test`, `nexus_gameplay_test`).
