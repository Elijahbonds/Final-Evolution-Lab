# NEXUS — resume handoff (engine + game/app)

> **Product split (2026-06):** NEXUS is the **retail ship** path — custom C++20 engine + Swift iOS app in this repo. Unreal Engine and Unity are **archived/legacy** (reference only). Label **preview/beta** where **`NEXUS_DELIVERY_MATRIX.md`** gaps remain (TestFlight artifact, Metal PBR embed, live Firebase POST).

## Repo

`/Users/elijahbonds/Final-Evolution-Lab`

## Pass 2 status (2026-06-19) — integration & ship readiness

| Phase | Theme | Status | Command |
|-------|-------|--------|---------|
| 1 | Headless engine + gameplay compile | **pass** | `ctest --test-dir build-headless` → 4/4 |
| 2 | Full renderer + `nexus_runtime` | **pass** | `cmake -B build-full -DNEXUS_ENABLE_RENDERER=ON && cmake --build build-full` |
| 3 | Mobile mesh LOD gate | **pass** | `./scripts/nexus_mobile_mesh_gate.sh` (WARN: sidecar naming vs manifest bases) |
| 4 | Spec v1 integration smoke | **pass** | `./scripts/smoke_v1.sh --skip-build` |
| 5 | iOS NEXUS static libs | **pass** | `./scripts/build-nexus-ios.sh` → `build-ios/*.a` |
| 6 | Full build gate | **pass** | `./scripts/nexus_build_gate.sh` → headless 4/4 + full 5/5 ctest |
| 7 | Runtime smoke | **pass** | `bench_nexus_runtime.sh`, `smoke_v1.sh`, `smoke_gameplay_session.sh` |
| 8 | iOS TestFlight packaging | **partial** | Dry-run OK; **no** `FEL.xcarchive`, **no** IPA, **no** `GoogleService-Info.plist` |
| 9 | Docs (this file) | **pass** | Honest status — no fake “shipped” claims |
| 10 | Delivery evidence | **pass** | `build/nexus-pass2-report.json` + logs under `build/` and `build/ios/` |

**Pass 2 score: 9/10 green** (phase 8 blocked on Firebase plist + code signing + manual archive).

Machine-readable report: `build/nexus-pass2-report.json`

### What is NOT shipped

- No App Store / TestFlight upload for NEXUS embed path
- No `build/FEL.xcarchive` on disk (full `archive-ios-testflight.sh` not run)
- No Instruments 60 FPS proof on device
- GPU shadow / bloom / FXAA resolve passes still stubs (see `NEXUS_Engine_10_Phase_Pass.md`)

### Quick verify (copy/paste)

```bash
cd /Users/elijahbonds/Final-Evolution-Lab

# Phase 6 — full gate (~30s)
./scripts/nexus_build_gate.sh

# Linux CI — gameplay + SDL/Vulkan-free renderer asset/manifest gate
./scripts/nexus_gameplay_regression.sh

# Phase 7 — runtime smoke
./scripts/bench_nexus_runtime.sh
./scripts/smoke_v1.sh --skip-build
./scripts/smoke_gameplay_session.sh --skip-build

# Phase 8 — iOS preflight only (needs Firebase plist for real archive)
ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1 ./scripts/archive-ios-testflight.sh --dry-run
# Real archive (manual): copy GoogleService-Info.plist, then:
#   ./scripts/archive-ios-testflight.sh
#   ./scripts/archive-ios-testflight.sh --export
```

## Prior Cursor conversation

[NEXUS engine + game/app build](7f1c31b8-f236-47a4-afa3-11f472e700dd) — engine foundation from `15_AI_AGENT_IMPLEMENTATION_GUIDE.pdf`, gameplay layer from `10_IMPLEMENTATION_ROADMAP.pdf`.

## Layout

| Layer | Path |
|-------|------|
| Engine core | `engine/core/` |
| Renderer (Vulkan / Metal) | `engine/renderer/` |
| Physics | `engine/physics/` |
| AI agent bridge | `engine/ai_interface/` |
| Creative / voxels | `engine/creative/` |
| Generative | `engine/generative/` |
| **Game / app** | `app/gameplay/` |
| Runtime | `runtime/` |
| iOS embed scripts | `scripts/build-nexus-ios.sh`, `scripts/archive-ios-testflight.sh` |
| Swift shell (reference) | `FinalEvolutionLab/` |

## Build (macOS)

```bash
cd /Users/elijahbonds/Final-Evolution-Lab

# Headless gate (no SDL3/Vulkan) — gameplay + protocol tests
./scripts/nexus_build_gate.sh

# Or headless only:
cmake -S . -B build-headless -DNEXUS_ENABLE_RENDERER=OFF -DNEXUS_BUILD_RUNTIME=OFF -DNEXUS_BUILD_TESTS=ON
cmake --build build-headless -j$(sysctl -n hw.ncpu)
ctest --test-dir build-headless --output-on-failure
```

Full renderer requires **CMake**, **SDL3**, **Vulkan/MoltenVK**.

## Gameplay modules (implemented)

- `fitness_data` — FRC/IAP thread-safe snapshots
- `gameplay_application` / `gameplay_manager` — Application Update hook
- `throw_catch_physics`, `arcade_physics`, `prq_engine`
- `voxel_command_parser` — ChatLLM → terrain commands
- `arena_mode_registry`, `fel_bridge_service`, session receipts

## Spec v1 Definition of Done

**5/9** per `docs/architecture/FEL_NEXUS_Spec_v1_Implementation_Plan.md`. Closed: touch→dunk (#3), session receipts disk queue, headless smokes. Open: live Firebase POST (#4 E2E), device perf (#2), TestFlight candidate (#9).

## Paste into Cursor (resume)

```
Resume NEXUS in /Users/elijahbonds/Final-Evolution-Lab.

Read NEXUS_RESUME.md and build/nexus-pass2-report.json.
Run ./scripts/nexus_build_gate.sh; fix compile/test failures.
Do not hack engine core — log engine API extensions.
Keep separation: engine/ vs app/gameplay/.
Report: build status, failing tests, next 3 tasks toward runnable nexus_runtime on device.
```

## Next milestones (world-class bar)

1. Copy `GoogleService-Info.plist` → run full `archive-ios-testflight.sh --export` → verify IPA + Transporter upload
2. Instruments pass: 60 FPS @ mobile mesh on physical iPhone (Metal embed path)
3. Close DoD #4 — live Firebase session receipt POST (not stub flush only)
4. Rename or alias mobile sidecars so `nexus_mobile_mesh_gate.sh` has zero WARN lines
5. GPU shadow + bloom resolve passes (currently logged API extensions)
