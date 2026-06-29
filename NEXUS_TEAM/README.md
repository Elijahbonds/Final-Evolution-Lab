# NEXUS Team — Operating Model

This directory defines how a coordinating **PM agent** plus **specialist agents** build the
NEXUS engine + Final Evolution Lab app in parallel without stepping on each other.

It is documentation only. Nothing here changes engine code, `CMakeLists.txt`, JSON configs,
or any other agent's files.

## Core principle: disjoint file ownership + one integrator

Parallel agents are safe and cheap **only** when their write-sets do not overlap.

- Every specialist role owns a **disjoint set of files/directories**. An agent writes only
  inside the dirs it owns and treats everything else as read-only.
- The **PM/Integrator** is the single owner of shared build glue: root `CMakeLists.txt`,
  CI workflow files, and cross-cutting docs. Specialists never edit these; they hand the PM
  a one-line note ("new source file `engine/physics/src/foo.cpp` needs adding to
  `nexus_physics`") and the PM integrates.
- Branching: one feature branch per role, PM merges. This keeps merge conflicts to the
  integration layer only.

## Build/test reality (verify before claiming "done")

| Capability | Where | Command |
|---|---|---|
| Headless engine libs + unit tests | **VM** ✅ | `cmake -S . -B build-headless -DNEXUS_ENABLE_RENDERER=OFF -DNEXUS_BUILD_RUNTIME=OFF` → `cmake --build build-headless` → `ctest --test-dir build-headless --output-on-failure` (4/4 pass) |
| Vulkan `nexus_runtime` preview | **Mac only** ❌ (no GPU in VM) | `cmake -S . -B build-full -DNEXUS_ENABLE_RENDERER=ON` → `cmake --build build-full --target nexus_runtime` → `./build-full/nexus_runtime` |
| iOS app | **Mac only** ❌ (Xcode/macOS) | `FinalEvolutionLab.xcodeproj` |
| UE 5.7 venue content | **Mac only** ❌ (UE editor) | `UnrealStarter/`, `fel_ue5_mac_package.sh` |
| Web frontend (CRA) | **VM** ✅ | `frontend/` (`npm`/`craco`) |
| Python backend | **VM** ✅ | `backend/server.py` + `backend_test.py` |

## Roles

Each role lists **responsibilities**, **owned files/dirs** (disjoint), and **build target**
(VM-buildable vs Mac-only).

### PM / Integrator
- **Responsibilities:** task routing, branch merges, owns the build graph and CI, arbitrates
  cross-module changes, keeps `STATUS.md` and this directory current.
- **Owns:** root `CMakeLists.txt`, `.github/` workflows, `NEXUS_TEAM/`.
- **Build:** VM.

### Engine / Core
- **Responsibilities:** main loop, logging, engine lifecycle (`Engine::tick`).
- **Owns:** `engine/core/` (`engine.cpp`, `log.cpp`).
- **Build:** VM (loop logic) — note `engine.cpp` is only compiled into `nexus_engine` when the
  renderer is ON (Mac), so core lifecycle changes get full link-test on Mac.

### Physics
- **Responsibilities:** deterministic integrator (`nexus_physics`), collision/step math.
- **Owns:** `engine/physics/`. Tests: `tests/unit/physics/physics_test.cpp`.
- **Build:** VM ✅ (real integrator, unit-tested headless).

### Renderer
- **Responsibilities:** Vulkan/SDL3 renderer, arena scene, camera, mesh, swapchain; GLSL shaders.
- **Owns:** `engine/renderer/`, `scripts/compile_nexus_shaders.sh`.
- **Build:** Mac only ❌ — VM has no GPU; scene is static after init. VM can only compile-check
  isolated logic, not run the window.

### Generative / Assets
- **Responsibilities:** procedural mesh generation, generative pipeline, external adapter
  integration (Meshy/Tripo are **stubs**, no API keys in repo), asset manifest + importers.
- **Owns:** `engine/generative/`, `engine/assets/`, `scripts/nexus_import_assets.py`,
  `scripts/nexus_convert_mesh.sh`, `assets/nexus/`.
- **Build:** VM ✅ for procedural + `.nexusmesh.json` import and unit tests. glTF/FBX import is a
  stub deferring to the Python script; real FBX art authoring is Mac-only (source on remote CDN).

### Gameplay / App (C++)
- **Responsibilities:** fitness data, throw-catch demo, Basketball Dunk Contest mode, voxel
  command parsing, gameplay application.
- **Owns:** `app/gameplay/`. Tests: `tests/unit/gameplay/gameplay_test.cpp`.
- **Build:** VM ✅ (`libnexus_gameplay`, headless unit-tested).

### AI Bridge
- **Responsibilities:** TCP agent protocol (127.0.0.1:9090), command routing/schema, response
  channel, transport.
- **Owns:** `engine/ai_interface/`. Tests: `tests/unit/ai_interface/command_test.cpp`.
- **Build:** VM ✅.

### Backend
- **Responsibilities:** Python API server, economy/IAP verification, DB migrations, mode/venue
  registries.
- **Owns:** `backend/`, `dataconnect/`, `supabase/` (DB + Edge Functions), `backend_test.py`.
- **Build:** VM ✅ (Supabase local needs Docker; app degrades gracefully without it).

### Web
- **Responsibilities:** CRA web frontend (marketing/app shell).
- **Owns:** `frontend/`.
- **Build:** VM ✅.

### iOS / Swift
- **Responsibilities:** SceneKit product shell (~85%, most complete client), ObjC++ bridge to
  `libnexus_gameplay`.
- **Owns:** `FinalEvolutionLab/`, `FinalEvolutionLabTests/`, `FinalEvolutionLabUITests/`,
  `FinalEvolutionLab.xcodeproj`, `scripts/build-nexus-ios.sh`, `scripts/ios_archive.sh`,
  `fastlane/`.
- **Build:** Mac only ❌ (Xcode). The bridge `FinalEvolutionLab/Bridge/NexusGameplayBridge.mm`
  links the VM-built `libnexus_gameplay.a`.

### UE Content
- **Responsibilities:** UE 5.7 venues, Pixel Streaming, cooked content.
- **Owns:** `UnrealStarter/`, `UnrealIntegration/`, `fel_ue5_*.sh`.
- **Build:** Mac only ❌ (UE 5.7 editor).

### QA / Test
- **Responsibilities:** unit + smoke tests, readiness audits, screenshot harness specs.
- **Owns:** `tests/`, `scripts/smoke_test_modes.py`, `test_reports/`, `docs/audit/` (read-heavy).
- **Build:** VM ✅ for headless ctest + Python smoke; GPU/visual verification is Mac-only.

### Docs
- **Responsibilities:** architecture/spec docs, integration manuals, this operating model.
- **Owns:** `docs/`, `NEXUS_TEAM/`.
- **Build:** VM ✅.

## Collision-avoidance summary

- `CMakeLists.txt`, `.github/` → **PM only**.
- Each `engine/<module>/` → its named role only.
- `app/gameplay/` → Gameplay only; iOS consumes its built `.a`, never edits it.
- Renderer/iOS/UE work that needs a GPU or macOS toolchain is routed to the Mac mini via
  `MAC_HANDOFF.md`; the VM agents do everything that is headless-buildable first.
