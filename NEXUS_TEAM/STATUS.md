# NEXUS Status Snapshot

Status: ✅ implemented · 🟡 partial · ⬜ stub/absent. Build: **[VM]** headless-buildable ·
**[MAC]** needs Mac/GPU/Xcode/UE. Verified against root `CMakeLists.txt` and a headless
`ctest` run (4/4 passing) on this Linux VM.

## Engine modules

| Module | Path | Status | Build | One concrete next action |
|---|---|---|---|---|
| core | `engine/core/` | ✅ loop implemented | [VM] (full link [MAC]) | Couple `Engine::tick` to fixed-timestep physics; add headless loop test |
| physics | `engine/physics/` | ✅ deterministic integrator | [VM] | Add restitution/multi-body cases to `physics_test.cpp` |
| creative / voxels | `engine/creative/` | ✅ implemented | [VM] | Expose more edit ops through the agent command schema |
| renderer | `engine/renderer/` | 🟡 builds; scene static after init | [MAC] | Drive per-frame scene/camera update; validate on GPU |
| ai_interface | `engine/ai_interface/` | ✅ protocol/routing + response channel | [VM] | Add scene/entity edit commands + schema tests |
| generative | `engine/generative/` | 🟡 procedural placeholder; external adapters stubbed | [VM] | Expand procedural venue generation + tests |
| assets | `engine/assets/` | 🟡 only `.nexusmesh.json` import; glTF/FBX deferred to script | [VM] | Harden `nexus_import_assets.py` path + sample CI check |
| luma | `engine/luma/` | ⬜ stub | [VM] | Decide scope; implement or mark deprecated |

## App / game layer

| Layer | Path | Status | Build | One concrete next action |
|---|---|---|---|---|
| C++ gameplay | `app/gameplay/` | ✅ fitness + throw-catch + Dunk Contest | [VM] | Define shared gameplay/state contract for clients |
| iOS Swift/SceneKit | `FinalEvolutionLab/` | 🟡 ~85% (most complete shell) | [MAC] | Finish mode coverage; verify bridge link in Xcode |
| ObjC++ bridge | `FinalEvolutionLab/Bridge/NexusGameplayBridge.mm` | ✅ links `libnexus_gameplay` | [MAC] | Run `scripts/build-nexus-ios.sh`; confirm no undefined symbols |
| UE 5.7 venues | `UnrealStarter/`, `UnrealIntegration/` | 🟡 content + Pixel Streaming | [MAC] | Cook/package via `fel_ue5_mac_package.sh` |
| Web frontend (CRA) | `frontend/` | 🟡 shell | [VM] | Run dev server; wire to backend API |
| Backend API | `backend/` | 🟡 server + economy/IAP | [VM] | Run `backend_test.py`; sync mode/venue registries |
| Supabase | `supabase/` | 🟡 DB + Edge Functions | [VM] (Docker for local) | `supabase start` when Docker available |

## Tooling / process

| Item | Status | Build | Next action |
|---|---|---|---|
| Vulkan `nexus_runtime` preview | 🟡 builds; GPU-only, prior SIGSEGV | [MAC] | Run `./build-full/nexus_runtime`; debug MoltenVK init |
| Shader pipeline | ✅ `compile_nexus_shaders.sh` | [MAC] (`glslc`) | Regenerate SPIR-V headers on shader change |
| Level/scene editor | ⬜ none (TCP voxel commands only) | [VM] model, [MAC] viewport | Build headless edit-state model first (see roadmap Phase 2) |
| Real 3D assets | 🟡 Venice Beach only; no API keys, source on CDN | [MAC] | Author/import via Meshy/Tripo/Blender on Mac |
| Headless CI tests | ✅ 4/4 pass | [VM] | Keep `ctest` green on every PR |

## At a glance
- **Solid in VM:** core loop, physics, creative/voxels, ai_interface, C++ gameplay, headless tests.
- **Blocked on Mac/GPU:** renderer runtime, editor viewport, iOS app, UE venues, real art.
- **Biggest gaps:** no engine/level editor; three gameplay paths not unified; external
  generative + FBX art blocked on credentials/source assets (not on repo code).
