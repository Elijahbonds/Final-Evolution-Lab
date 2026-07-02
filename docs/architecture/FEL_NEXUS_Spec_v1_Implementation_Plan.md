# FEL NEXUS Spec v1 — Implementation Plan

> Maps **FEL_NEXUS_Cursor_Spec_v1.pdf** (2026-06-19) to this repo on branch `anti-gravity-fel`.
> Repo layout differs from PDF (`engine/` + `app/gameplay/` + `runtime/` vs `nexus_runtime/app/`).

## Sprint goals (§1)

| Goal | Status | Notes |
|------|--------|-------|
| P0 Dunk Contest on device | **Partial** | C++ sim + SceneKit iOS UI; Metal renderer **deferred** |
| P1 Karate Endless | **Partial** | C++ wave/combat sim; SceneKit UI |
| Menu → mode → play → receipt | **Partial** | SwiftUI flow exists; NEXUS Metal embed **deferred** |
| 60 FPS Venice Beach | **Partial** | Vulkan runtime loads ~106k tri mesh; iOS uses SceneKit |
| Session receipt + Firebase | **Partial** | Receipt JSON + queue; curl stub; Swift Firebase **existing** |

## Phase gate checklist (§9.1)

| # | Criterion | DoD | Verify |
|---|-----------|-----|--------|
| 1 | Dunk Contest playable on iPhone 12 simulator | ❌ | SceneKit path works; NEXUS Metal embed not shipped |
| 2 | Venice Beach renders at 60 FPS | ❌ | Vulkan runtime OK; device GPU profiling pending |
| 3 | Touch → jump → dunk → score | ✅ | C++ `fel.dunk.*` + iOS touch via `NexusGameplayBridge` / `GamePlayView` (Phase 4) |
| 4 | Session receipt sent to Firebase | ❌ | ✅ Receipt queued (`~/.fel/pending_receipts/`); ❌ live Firebase POST |
| 5 | Karate Endless functional | ✅ | `fel.karate.action` + wave spawner; ctest + smoke |
| 6 | Mode menu navigates both modes | ✅ | `GameModeSelectionView` + 19-mode registry |
| 7 | No exceptions in engine code | ✅ | Result\<T\> throughout gameplay/engine |
| 8 | ctest passes | ✅ | **4/4** (protocol, gameplay, generative, renderer) |
| 9 | TestFlight candidate builds | ❌ | Requires signing + archive; not run in Phase 2 |

**Legend:** ✅ met · ❌ not met · ⚠️ partial

---

## Path to 9/9 (DoD closure plan)

Maps each open §9.1 criterion to owning agent, concrete next file/task, and verify command. Target: **v1.1** for device/Metal/Firebase/TestFlight gates.

| # | Criterion | Status | Owner | Next file / task | Verify |
|---|-----------|--------|-------|------------------|--------|
| 1 | Dunk Contest playable on iPhone 12 simulator | ❌ | **b783814d** (iOS) + **2c499563** (Metal) | Embed NEXUS venue in `GameSceneHostView` via `metal_renderer.mm` / `CAMetalLayer`; replace SceneKit-only dunk preview for P0 | `xcodebuild … build` + manual dunk on simulator |
| 2 | Venice Beach renders at 60 FPS | ❌ | **2c499563** + **f7eb525d** | Consume manifest `mobile_mesh` in `asset_manifest.cpp`; profile draw path in `vulkan_renderer.cpp` / future Metal backend | Instruments GPU frame time on device; `NEXUS_MESH_PROFILE=mobile ./build-full/nexus_runtime --validate-only` |
| 3 | Touch → jump → dunk → score | ✅ | — | Done — `GamePlayView.swift` → `NexusGameplayBridge.mm` → `fel.dunk.*`; HUD poll via `nexus_gameplay_session_hud_poll_json()` (iOS Phase 4) | iOS manual dunk loop + `smoke_v1.sh` |
| 4 | Session receipt sent to Firebase | ❌ | **fd7a0191** + **b783814d** | Implement live POST in `session_receipt_client.cpp` (curl desktop); Swift drain in `GameplaySessionReceiptCoordinator.swift` → `Config.gameplaySessionReceiptURL` with Firebase JWT | POST returns 200; receipt removed from `~/.fel/pending_receipts/` |
| 5 | Karate Endless functional | ✅ | — | Done (`karate_endless_mode.*`, `fel.karate.action`) | `ctest -R nexus_gameplay_test` |
| 6 | Mode menu navigates both modes | ✅ | — | Done (`GameModeSelectionView`, `arena_mode_registry.cpp`) | iOS menu → Dunk + Karate |
| 7 | No exceptions in engine code | ✅ | — | Done (`Result<T>` pattern) | `./scripts/smoke_v1.sh` |
| 8 | ctest passes | ✅ | — | Done (**4/4**) | `ctest --test-dir build-full --output-on-failure` |
| 9 | TestFlight candidate builds | ❌ | **b783814d** | Archive checklist in `IOS_RUNBOOK.md` + `FEL_NEXUS_v1.1_Metal_Firebase.md` M3; signing team **7KJ6G7HLL4** | `xcodebuild archive` + upload to App Store Connect |

**Phase 4 (2026-06-19):** Agent **b783814d** closed DoD **#3** (iOS dunk touch bridge). Remaining open: **#1, #2, #4, #9**.

**Critical path:** M1 Metal embed (DoD #1, #2) → M2 Firebase receipt (DoD #4) → M3 TestFlight archive (DoD #9).

---

## Phase 2 — Cross-agent reconciliation (Integration Lead)

### Agent ownership

| Agent | Focus | Key deliverables |
|-------|-------|------------------|
| **Agent 1** (2c499563) | Renderer / assets | `mesh_lod.*`, `frustum.*`, PBR vertex layout, manifest mesh profiles, mobile decimation budgets, `nexus_renderer_test` |
| **Agent 2** (fd7a0191) | Gameplay dedup | Single dunk path: `dunk_contest_mode` ← `mode_runtime` (no duplicate sim files) |
| **Agent 3** (61458eb4 / Phase 1) | P0/P1 sims | `ModeRuntime`, QTE, PRQ, karate combat stack, iOS bridge helpers |
| **Agent 4** (parallel) | iOS / receipts | `NexusGameplayEngine.swift`, receipt disk queue, `IOS_RUNBOOK.md`, Swift UI wiring |

### Conflicts resolved (Phase 2)

| Issue | Resolution |
|-------|------------|
| Duplicate dunk sim files | **None found** — canonical: `dunk_contest_mode.*` + `mode_runtime.*` only |
| `frustum.cpp` missing from CMake | Added to `nexus_renderer` target |
| `VK_FORMAT_R32G32_FLOAT` typo | → `VK_FORMAT_R32G32_SFLOAT` in `vulkan_renderer.cpp` |
| `string_view` log concat in `scene.cpp` | Wrapped `activeMeshProfileName()` in `std::string()` |
| `validate-only` hardcoded Venice path | `runtime/main.cpp` now uses manifest `resolveImportedPath()` |
| Renderer test vs frustum cull | `collectDrawCommands(false)` in hierarchy unit test |
| `session_receipt_client` Result\<string\> ambiguity | Uses `std::optional<std::string>` for temp path |

### Smoke harness

```bash
./scripts/smoke_v1.sh          # configure + build + ctest + validate + gameplay
./scripts/smoke_v1.sh --skip-build
```

**Phase 2 validate output (2026-06-19):**
- Venice: 40,076 verts / 80,000 tris (desktop profile, within §6 budget)
- Zen Dojo: 38,251 verts / 39,584 tris
- Dunk lifecycle → receipt queued to `~/.fel/pending_receipts/`

---

## Spec section → repo mapping

### §2 Product scope

| Spec | Repo | Status |
|------|------|--------|
| P0 `basketball_dunk` | `app/gameplay/dunk_contest_mode.*`, `mode_runtime.cpp` | **Done** |
| P1 `karate_endless` | `app/gameplay/karate_endless_mode.*`, combat/wave/health | **Done** |
| P2 modes (17) | `arena_mode_registry.cpp`, Swift `GameMode.swift` | Stub / SceneKit |
| Dunk styles + QTE | `qte_system.*`, `dunk_contest_mode.*` | **Done** |
| PRQ stub 75 | `prq_engine.*` | **Done** |
| Arcade physics map | `arcade_physics.*` | **Done** |

### §3 UE → NEXUS port matrix

| UE subsystem | NEXUS target | Status |
|--------------|--------------|--------|
| EFELArenaMode | `arena_mode_registry.cpp` | **Done** (19 modes) |
| BP_DunkContest | `dunk_contest_mode.cpp` | **Done** |
| BP_Karate_Endless | `karate_endless_mode.cpp` | **Done** |
| FELGameplayManager | `gameplay_manager.cpp`, `arena_session_manager.cpp` | **Done** |
| FELBridgeSubsystem | `fel_bridge_service.cpp`, agent TCP :9090 | **Done** |
| FELVenueVolume | `venue_volume_registry.cpp` | **Done** |
| FELHudRelaySubsystem | `hud_relay_service.cpp` | Stub (log extension) |
| UFELEmergentBridge | `NexusGameplayBridge.mm`, `NexusGameplayEngine.swift` | **Done** (headless C++) |
| UFELPerformanceManager | — | **Todo** (P2) |
| MRI / HealthKit | Swift `PRQScoring.swift` | Swift-side; C++ stub |

### §4 iOS architecture

| Spec file | Repo file | Status |
|-----------|-----------|--------|
| `NexusGameplayBridge.swift` | `FinalEvolutionLab/Services/NexusGameplayEngine.swift` + `.mm` | **Done** |
| `GamePlayView.swift` | `FinalEvolutionLab/Views/GamePlayView.swift` | SceneKit (not MTKView/Metal) |
| `NexusMetalView` / Metal renderer | — | **Deferred** — log: *Request for Engine API Extension* |
| `SessionReceiptView.swift` | Via `GameplaySessionReceiptCoordinator.swift` | **Partial** |
| Firebase services | Existing Swift services | **Partial** |

### §5 Engine roadmap

| Phase | Deliverable | Repo | Status |
|-------|-------------|------|--------|
| A1 Scene graph | `engine/renderer/scene.cpp` | **Done** |
| A2 GLB load | `engine/assets/mesh_importer.cpp` | JSON mesh **Done**; GLB stub |
| A3 Metal renderer | — | Vulkan/MoltenVK dev runtime only |
| A4 Camera | `engine/renderer/camera.cpp` | **Done** |
| A5 Venice venue | manifest-driven `RenderScene::createFromManifest` | **Done** (80k tris LOD, frustum cull) |
| A6 Touch input | iOS `InputManager.swift` | Swift-side; no `app/input/touch_input.cpp` |
| A7 Player entity | SceneKit nodes | **Partial** |
| A8 Engine tick | `engine/core/engine.cpp`, `runtime/src/main.cpp` | **Done** |
| B1–B9 Physics/gameplay | `physics_world`, dunk/karate/prq/qte | **Done** (Jolt **deferred**) |
| C1–C7 Karate | combat/wave/enemy/health | **Done** |
| D1–D9 Polish | receipt client, pause/resume, ImGui menu | **Partial** |

### §6 Assets

| Item | Path | Status |
|------|------|--------|
| Manifest | `assets/nexus/manifests/nexus_asset_manifest.json` | **Done** |
| Venice mesh (desktop) | `assets/nexus/imported/venice_beach_court_model_fbx.nexusmesh.json` | **Done** (65,884 verts / 105,992 tris) |
| Venice mesh (mobile) | `assets/nexus/imported/venice_beach_court_model_fbx_mobile.nexusmesh.json` | **Done** (40,076 verts / 80,000 tris) |
| Zen dojo | `zen_dojo_environment_model_fbx.nexusmesh.json` | **Done** (~40k tris) |
| `.nexusmesh` binary | — | **Todo** (JSON runtime OK) |
| ASTC textures | — | **Todo** |
| `nexus_asset_convert` CLI | `scripts/nexus_import_assets.py` | **Partial** |

### §7 Backend

| Item | Repo | Status |
|------|------|--------|
| Receipt POST | `session_receipt_client.cpp` | curl stub |
| Offline queue | `gameplay_manager.cpp` pending receipts | **Done** |
| Firebase JWT | Swift `AuthService` | Existing |
| HUD WebSocket :8080 | `hud_relay_service.cpp` | Stub |

### §8 Menu (ImGui)

| Item | Status |
|------|--------|
| ImGui menu_system | **Deferred** — SwiftUI mode picker used |
| Coming soon P2 | Registry + Swift UI grey-out |

### §10 Coding standards

| Rule | Status |
|------|--------|
| Result\<T\> | **Done** |
| NEXUS_LOG_* | **Done** |
| Agent bridge :9090 | **Done** |
| Engine/game separation | **Done** |

---

## Implemented (Agents 1–4 + Phase 2 integration)

### Engine / renderer (Agent 1)

- `engine/renderer/mesh_lod.*` — vertex budget decimation, LOD policy
- `engine/renderer/frustum.*` — frustum culling in `collectDrawCommands(true)` (AABB vs 6 clip planes)
- PBR vertex channels (`normal[3]`, `uv[2]`) in `MeshVertex` + Vulkan pipeline; fragment shader uses flat color + simple normal shading (no textures yet)
- **`NEXUS_MESH_PROFILE=mobile`** — `AssetManifest::resolveMeshPath()` loads `imported_mesh_mobile` (`*_mobile.nexusmesh.json`), falls back to desktop with warn
- **`scripts/nexus_import_assets.py --mobile`** — desktop full mesh + trimesh quadric decimation → mobile sidecar; Venice: **40,076 verts / 80,000 tris** (≤50k vert spec target met)
- `tests/unit/renderer/renderer_test.cpp` — decimation, PBR import, frustum cull, manifest load, LOD policy

### Gameplay (Agents 2–3)

- `dunk_contest_mode.*` + `mode_runtime.*` — single source of truth for P0 dunk
- `karate_endless_mode.*` + combat/wave/health/enemy stack — P1
- `prq_engine.*`, `arcade_physics.*`, `qte_system.*`
- `session_receipt_client.cpp` — curl POST stub + disk queue
- `runtime/src/main.cpp` — CLI + manifest-based validate-only

### iOS (Agent 4)

- `NexusGameplayEngine.swift` — mode-aware `fel.arena.start_session`
- `FinalEvolutionLab/IOS_RUNBOOK.md` — device run instructions

### Phase 2 integration fixes

- CMake: `frustum.cpp` in `nexus_renderer`
- Renderer compile fixes (Vulkan format, string concat)
- `scripts/smoke_v1.sh` — end-to-end smoke harness

### Tests

- **4/4 ctest pass** after Phase 2 reconciliation

---

## v1.1 / post-sprint backlog

1. **Metal renderer + MTKView** for iOS (replace SceneKit path per §4.5)
2. **Jolt Physics** integration (§B1)
3. **Mobile LOD for remaining venues** — run `--mobile` on 11 stub environments (Venice + Zen partial)
4. **GLB runtime loader** (tinygltf) or `.nexusmesh` binary
5. **ImGui in-engine menu** (§8) or unify on SwiftUI
6. **Firebase receipt sync** wire-up from C++ queue to Swift
7. **HUD WebSocket** real transport (§7.3)
8. **HealthKit → PRQ** real pipeline (§7.4)
9. **VFX / audio / skeletal animation** (§9.2 stubs)
10. **17 P2 modes** full sims
11. **TestFlight** archive + device perf profiling

---

## Commands

```bash
# Build + test (macOS)
cmake -S . -B build-full -DNEXUS_ENABLE_RENDERER=ON
cmake --build build-full
ctest --test-dir build-full --output-on-failure

# Validate + smoke (recommended)
./scripts/smoke_v1.sh

# Runtime with Venice mesh (Vulkan window)
NEXUS_MESH_PROFILE=mobile ./build-full/nexus_runtime   # mobile LOD sidecar
./build-full/nexus_runtime                              # desktop mesh (default)

# Validate mesh without GPU window
./build-full/nexus_runtime --validate-only --mode basketball_dunk

# Agent bridge (while runtime running)
# TCP localhost:9090 — JSON fel.arena.start_session / fel.dunk.charge_begin / etc.

# iOS (physical device or simulator)
cd FinalEvolutionLab
xcodebuild -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
# Run from Xcode: Menu → Dunk Contest → GamePlayView
```

---

## Engine API extensions logged

- Metal renderer + CAMetalLayer embed for iOS
- HUD WebSocket relay (port 8080)
- HTTP client for session receipts (curl stub in place)
- GLB/FBX direct import at runtime
- Jolt Physics backend
- **Runtime venue mesh LOD swap** — `NEXUS_DISTANCE_LOD=1` selects mobile/desktop sidecar at load; orbit crossing 25 m logs hot-reload extension (Phase 3; no mid-session mesh swap yet)

---

## Agent 1 Renderer — Phase 3 complete (2026-06-19)

**Delivered**

| Task | Status | Notes |
|------|--------|-------|
| Multi-venue mobile | ✅ | `createFromManifest` + `createFromVenueKey`; inferred `*_mobile.nexusmesh.json` for zen_dojo |
| Distance LOD hook | ✅ | `MeshLodSelector`, `NEXUS_DISTANCE_LOD=1`, `resolveMeshPathAtDistance()` |
| Draw stats log | ✅ | One-line `NEXUS_LOG` per frame when `NEXUS_DEV_DRAW_STATS` ≠ 0/false |
| Tests | ✅ | `nexus_renderer_test` — zen dojo mobile, LOD selector, draw stats, all venues |
| Validate | ✅ | `NEXUS_MESH_PROFILE=mobile ./build-full/nexus_runtime --validate-only --mode karate_endless --venue zen_dojo` |

**Env vars**

| Variable | Purpose |
|----------|---------|
| `NEXUS_MESH_PROFILE=mobile` | Load mobile sidecar at scene build |
| `NEXUS_DISTANCE_LOD=1` | Pick profile by camera distance (25 m threshold) |
| `NEXUS_DEV_DRAW_STATS=0` | Disable per-frame draw stats log |

**Deferred (Phase 4+):** shadows, post-process GPU passes, skeletal GPU skinning, full PBR texture bindings.

---

## Agent 3 handoff — Metal iOS embed checklist

Replace SceneKit-only `GamePlayView` path with NEXUS Metal backend. Files to create or wire:

| File | Purpose |
|------|---------|
| `engine/renderer/src/metal_renderer.mm` | **Extend stub** — `MTLDevice`, `MTLCommandQueue`, render pass from `RenderScene::collectDrawCommandBatch()` |
| `engine/renderer/include/nexus/renderer/metal_renderer.h` | Public C++ API; `initialize(CAMetalLayer*, …)` |
| `ios/FinalEvolutionLab/Views/NexusMetalView.swift` | `UIViewRepresentable` wrapping `MTKView` or raw `CAMetalLayer` |
| `ios/FinalEvolutionLab/Bridge/NexusMetalBridge.mm` | Obj-C++ bridge: create layer, forward resize/orbit to `MetalRenderer` |
| `ios/FinalEvolutionLab/Bridge/NexusMetalBridge.h` | C header for Swift `@_silgen_name` or bridging header |
| `engine/renderer/shaders/metal/` | `.metal` vertex/fragment (match PBR vertex layout from Phase 2) |
| `FinalEvolutionLab.xcodeproj` | Link `libnexus_renderer.a`, `-framework Metal`, `-framework QuartzCore` |

**Integration steps (Agent 3)**

1. Swap `GameSceneHostView` SceneKit path for `NexusMetalView` when `NEXUS_USE_METAL=1` or P0 dunk mode.
2. Pass manifest path + mode id (`basketball_dunk` / `karate_endless`) into `MetalRenderer::loadVenue()`.
3. Set `NEXUS_MESH_PROFILE=mobile` in iOS scheme for iPhone 12-class targets.
4. Triple-buffer uniform ring (view-projection) — mirror `vulkan_renderer.cpp` orbit camera.
5. Verify: `xcodebuild -scheme FinalEvolutionLab -destination 'platform=iOS Simulator,name=iPhone 16' build` + 60 FPS Venice on device.

**Existing stubs to reuse:** `metal_renderer.mm` (null-layer test), `RenderScene`, `MeshLodSelector`, `devDrawStatsEnabled()`.

---

## Engine 10-Phase Pass — complete (2026-06-19)

**Owner:** Engine Pass Agent 5/5 · Plan: [NEXUS_Engine_10_Phase_Pass.md](./NEXUS_Engine_10_Phase_Pass.md)

| Phase | Theme | Status |
|-------|-------|--------|
| 1–10 | Build gate → perf ship gate | ✅ **10/10 complete** |

**Integration verify (Integration Lead, 2026-06-19)**

| Check | Result |
|-------|--------|
| `cmake --build build-full` (renderer ON) | ✅ clean |
| `ctest --test-dir build-full --output-on-failure` | ✅ **5/5** (protocol, gameplay, generative, physics, renderer) |
| `NEXUS_MESH_PROFILE=mobile ./build-full/nexus_runtime --validate-only --mode basketball_dunk` | ✅ 80k tris, budget ok |
| `./build-full/nexus_runtime --validate-only --mode basketball_dunk` (desktop) | ✅ 52,996 tris, budget ok |
| Parallel agent merge conflicts (`<<<<<<<` markers, broken CMake) | ✅ none found; no fixes required |

**Ship gate still manual:** Device Instruments GPU frame time on iOS Metal embed (Phase 8 stub compiles; full PBR pipeline deferred).

**Handoff**

| Next owner | Work |
|------------|------|
| **App Pass Agent 5** | iOS `GameSceneHostView` → `NexusMetalView` / `CAMetalLayer`; dunk P0 on device |
| **Engine Premium Agent** | Metal PBR draw path, GPU skinning shader hook, Instruments 60 FPS Venice profiling |

**Related:** App 10-Phase Pass — **10/10 done** per [FEL_App_10_Phase_Pass.md](./FEL_App_10_Phase_Pass.md) (DoD #9 partial until App Store Connect upload).
