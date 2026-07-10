# Nexus Runtime Graphics Audit + Performance Plan

Agent: A9 (nexus/engine-gfx) — audit of `integration/nexus-aaa` @ `1c1b68f`.
Scope: what the Nexus runtime can actually render today, where the 60fps/A15 risks are
for `basketball_dunk` / `h2h` / `3v3`, and a costed decision between augmenting Nexus
vs. an Unreal-bridge fallback. This is an audit + plan; the only code change on this
branch is a <100-line, env-gated instanced-draw prototype (see §6).

---

## 1. What renders venues today

Two paths, both driven by precooked `.nexusmesh.json` sidecars — **no USDZ, no .scn
anywhere on this branch** (the textured `.scn` venue work lives in the FEL-app repo,
PR #111, and has not landed here):

1. **Hybrid Metal viewport** (preferred when bundled mesh exists):
   `NexusHybridGameplayContainerView` stacks an `MTKView` venue backdrop under a
   transparent `SCNView` gameplay overlay —
   `FinalEvolutionLab/Views/GameSceneHostView.swift:26-66`. Gate:
   `Nexus3DGameplayCoordinator.shouldUseHybridMetal`
   (`FinalEvolutionLab/Services/Nexus3DGameplayCoordinator.swift:9-17`) →
   `nexus_metal_bridge_bundled_venue_mesh_loadable()`
   (`FinalEvolutionLab/Bridge/NexusMetalBridge.mm`). The bridge instantiates the
   C++ `nexus::renderer::MetalRenderer` (`NexusMetalBridge.mm:81-83`, solid fill:
   `config.validateOnlyWireframe = false` at `NexusMetalBridge.mm:213`).
2. **SceneKit fallback**: `NexusBundledMeshLoader`
   (`FinalEvolutionLab/Utilities/NexusBundledMeshLoader.swift:4-7`) parses the same
   `.nexusmesh.json` into `SCNGeometry`, hard-capped at
   `sceneKitVertexBudget = 18_000` vertices — i.e. the fallback venue is ~45% of the
   mobile mesh's 40k verts.

**Asset reality** (`assets/nexus/imported/*.nexusmesh.json`): mobile LODs are
~6.8-8 MB JSON each, e.g. `venice_beach_court_model_fbx_mobile.nexusmesh.json`:
`vertex_count=40076, tri_count=80000`, decimated from 105,992 source tris via
`assimp-cli+trimesh+decimate`. Vertices carry `position / color / normal` only —
**no UVs, no textures**; colors are flat gray `[0.4, 0.4, 0.4]`. Venues therefore
render as untextured vertex-color geometry regardless of path.

Characters, ball, FX are **not** Nexus-rendered: they are SceneKit procedural rigs
and `SCNParticleSystem` emitters in the Swift views (9 game views use SceneKit
particles; `NexusProject.json` declares `"skeletonAnimations": "canvas_procedural"`,
`"renderBackend": "canvas"` — `NexusStarter/NexusProject.json:6,24`).

## 2. Capability matrix (with evidence)

| Capability | Status | Evidence |
|---|---|---|
| GPU skinning | **Absent** | No shader has bone attributes. Metal inline shader is position+color MVP only (`engine/renderer/src/metal_renderer.mm:144-168`); Vulkan `arena.vert` is position/normal/color/uv, no joints (`engine/renderer/shaders/arena.vert:13-16`). |
| CPU skinning | **Orphaned** | `AnimationPlayer` computes translation-only bone matrices into `m_skinningFlat` (`engine/renderer/src/animation_player.cpp:180-193`) but `grep` finds **zero consumers** outside its own translation unit/tests. Dead scaffolding. |
| Instanced / batched draws | **Plan-only** | `batchDrawCommands()` groups draw commands into `InstancedBatch` lists (`engine/renderer/src/console_tier_lod.cpp:13-36`) — but the output is used **only for stats/degrade decisions** (`evaluateConsoleTierFrame`, `:38-61`). The actual Metal draw loop issues one `drawIndexedPrimitives` per command with a per-draw `setVertexBytes` MVP (`engine/renderer/src/metal_renderer.mm:353-372`). No `instanceCount` anywhere. §6 prototype closes this gap behind a flag. |
| Particle systems | **None in Nexus** | Zero hits for "particle" in `engine/` or `app/`. All FX are SceneKit `SCNParticleSystem` on the Swift overlay. |
| Shader pipeline | **Vulkan: precompiled SPIR-V; Metal: runtime source compile** | `scripts/compile_nexus_shaders.sh` embeds SPIR-V into headers (`arena_shader_spv.h`). The iOS Metal path compiles from an inline source string at init via `newLibraryWithSource:` (`metal_renderer.mm:170-175`) — **no precompiled `.metallib`**, so first-frame init pays an MSL compile (~100-300 ms class hitch). |
| Materials / textures | **Factors only, no sampling** | `arena.frag` mixes vertex color with albedo/metallic/roughness/AO scalars — no texture bind points (`engine/renderer/shaders/arena.frag`). Metal shader is unlit vertex color. Meshes have no UVs anyway (§1). |
| Shadows | **Log-only stub** | Shadow pass is a "depth stub" that logs its config; GPU depth resolve is a *requested* engine extension, not implemented (`engine/renderer/src/vulkan_renderer.cpp:924-935`). Metal path: nothing. |
| Bloom / post | **CPU planning only** | `PostProcessChain` computes pass order and scalar ACES tonemap on floats (`engine/renderer/src/post_process.cpp:21-48`) — no GPU passes exist. Bloom "resolve" is likewise a logged request (`vulkan_renderer.cpp:954-956`). |
| Frustum culling | **Present (CPU)** | `RenderScene::collectDrawCommandBatch(true)` (`engine/renderer/src/scene.cpp:242-275`). |
| LOD / dynamic scaling | **Present (CPU, coarse)** | Tier plans with triangle/draw budgets (130k/750 high → 71.5k/450 low-power) driven by `PerfMonitor` (`engine/core/src/engine_scale_policy.cpp:8-53`); distance-based LOD cull + furthest-first budget drop (`console_tier_lod.cpp:95-165`). Degrade *drops whole draws*, it does not swap LOD meshes. |
| Depth testing (Metal) | **Broken/unbound** | A depth-stencil state is created (`metal_renderer.mm:201-207`) but `render()` never attaches a depth texture to the pass descriptor nor calls `setDepthStencilState:` (`:333-372`). Venue triangles draw in submission order — correct-looking only while the venue is a single mesh. |
| Bench harness | **Stub** | `scripts/bench_nexus_runtime.sh:2` says "bench stub"; it runs the desktop runtime under a timeout, no headless GPU capture, no FPS assertion. Targets documented: ≥60 fps, <400 MB, <750 draws, ≤130k tris (`:22-26`). |

## 3. Bottleneck analysis — basketball_dunk / h2h / 3v3 @ 60fps on A15

No device numbers exist (bench is a stub), so these are engineering estimates from
the measured asset/draw shapes above.

**What the GPU actually does per frame (hybrid path):** clear + draw one venue mesh
(~80k tris mobile LOD, 1-N submeshes) unlit, then composite a full-screen transparent
`SCNView` on top. The A15 GPU rasterizes 80k unlit vertex-color triangles in well
under 2 ms — **the Nexus Metal pass is not the bottleneck.**

Ranked real risks:

1. **Two stacked full-screen render passes** (MTKView + transparent SCNView,
   `GameSceneHostView.swift:33-51`): a full extra load/store plus compositor blend of
   a non-opaque layer every frame. On A15 at native scale this is the largest fixed
   GPU tax in the design (~1.5-3 ms + memory bandwidth), paid in *all three modes*.
2. **SceneKit overlay CPU cost, scales with characters**: `dunk`/`h2h` animate 1-2
   procedural rigs — fine. `3v3` animates 6 rigs + ball + 9 views' worth of
   `SCNParticleSystem` on the SceneKit thread. SceneKit's per-node transform +
   action evaluation is the first thing that will push past 16.6 ms in `3v3`;
   estimate 4-8 ms CPU on A15 with current per-limb node counts.
3. **Load-time hitches, not frame-rate**: (a) runtime MSL compile at init
   (`metal_renderer.mm:170`); (b) parsing a 7-8 MB `.nexusmesh.json` through
   nlohmann into vectors (hundreds of ms, main-thread-adjacent); (c) full mesh
   re-upload whenever `meshCount != uploadedMeshCount` (`metal_renderer.mm:308-314`).
4. **Missing depth attachment** (§2): today a latent correctness bug; the moment a
   second venue mesh or backdrop lands, sorting artifacts appear and the "fix" (depth
   pass) adds bandwidth that should be budgeted now.
5. **Per-draw `setVertexBytes` MVP loop**: irrelevant at ~1-10 draws/venue, but the
   130k-tri/750-draw budget in `engine_scale_policy.cpp` implies future scenes where
   per-draw encoding at 750 draws costs ~1-2 ms CPU; instancing (§6) removes it.

**Verdict:** all three modes can hold 60 fps on A15 *as currently scoped*, with
`3v3` at risk from SceneKit overlay CPU, not from Nexus. The fidelity ceiling — not
the frame rate — is the real problem: untextured gray venues, no shadows, no GPU
post, characters outside the engine.

## 4. Decision: augment Nexus (A) vs Unreal-bridge fallback (B)

### Option A — Augment Nexus (estimates in engineer-days)

| Task | Est. | Notes |
|---|---|---|
| Precompile Metal shaders to `.metallib` in build (extend `compile_nexus_shaders.sh`, load with `newLibraryWithData`) | 1.5 d | Kills init hitch; enables shader variants. |
| Depth attachment + `setDepthStencilState` in Metal pass | 0.5 d | Correctness prerequisite for everything below. |
| Binary mesh format (`.nexusmesh.bin`) + UV/texture support in importer & vertex layout | 3 d | Fixes 7 MB JSON parse + unlocks textured venues. |
| Textured venue pipeline (UV-preserving decimation, basis/ASTC textures, sampler in shader) | 4 d | Biggest visible fidelity win. |
| Instanced draws (promote §6 prototype: default-on, per-instance buffer instead of `setVertexBytes` chunks) | 1 d | Prototype already on this branch. |
| GPU skinning: joint indices/weights in mesh format, bone-palette vertex shader, revive `AnimationPlayer` (full transforms, not translation-only) | 6 d | Only pays off if characters *move into* the Metal pass. |
| Port characters from SceneKit overlay into Nexus pass (removes 2nd full-screen pass) | 8 d | High risk — re-implements SceneKit rig behavior. |
| GPU particles (simple TBDR-friendly quad emitter) | 4 d | Replaces `SCNParticleSystem` only if characters move too. |
| Shadow map pass (single cascade) + bloom (extract/blur/composite) on Metal | 5 d | Post stack currently CPU-planning-only. |
| Real bench: headless offscreen render + `PerfMonitor` FPS assertion on device via XCTest | 2 d | Turns `bench_nexus_runtime.sh` stub into a gate. |
| **Total to "AAA-ish" parity** | **~35 d** | **Minimal fidelity-first slice (rows 1-5): ~10 d.** |

### Option B — Unreal-bridge fallback for highest-fidelity modes

Context from repo history: an Unreal project exists at the owner's
`~/Developer/FinalEvolutionLab57` (UE 5.7, last iOS IPA May 2026), and this repo
still carries `UnrealIntegration/`, `UnrealStarter/`, `infra/SWIFT_UNREAL_CONTAINER.md`,
and `fel_ue5_ios_shipping_package.sh`. But `NexusProject.json:24-29` records that the
UE5 embedded runtime was **explicitly replaced** by Nexus on 2026-06-30
(`"previousRuntime": "UnrealEngine5"`).

| Task | Est. | Notes |
|---|---|---|
| Resurrect UE 5.7 iOS build from `FinalEvolutionLab57` (cert/profile refresh, engine update since May 2026 IPA) | 3 d | Unverified rot risk; last known-good is ~14 months of Xcode/UE churn ago. |
| Re-embed UE view in Swift shell (revive `SWIFT_UNREAL_CONTAINER.md` bridge, input + lifecycle) | 5 d | The old bridge handshake (`FEL-SOVEREIGN-BRIDGE-v3`) was retired. |
| Re-author venues/characters in UE for dunk/h2h/3v3 | 8 d | Assets exist as FBX; materials/lighting redo. |
| Gameplay state sync Swift↔UE (score, biometrics HUD, mode routing) | 5 d | Duplicate of logic already working in SceneKit. |
| App size + review risk management (UE adds ~150-300 MB IPA; dual runtimes shipped) | 2 d | Ongoing cost, not one-time. |
| **Total** | **~23 d** | Plus permanent dual-runtime maintenance and a second content pipeline. |

**Risks unique to B:** contradicts the recorded UE5→Nexus migration decision;
doubles the runtime surface QA must cover; the July ship-the-app pivot ships the
SceneKit shell *today*, and B delivers nothing shippable until the full chain works.

### Recommendation: **Option A, minimal slice first (~10 days), staged.**

Rationale tied to the ship-the-app pivot:

- The SceneKit shell **currently ships and holds 60 fps** for the shipping modes;
  nothing here is frame-rate-blocked, so a 23-day engine swap buys zero shipping
  velocity.
- The visible quality gap is *textures and load hitches*, and Option A's first five
  rows (metallib, depth, binary meshes, textured venues, instancing) fix exactly
  that in ~10 days without touching the gameplay overlay that already works.
- Defer the expensive rows (GPU skinning, character port, particles, shadows —
  ~23 d) until a mode demonstrably breaks 60 fps on device or design demands
  fidelity SceneKit can't hit. Re-evaluate B only at that point, and only for a
  flagship mode — the UE artifact at `FinalEvolutionLab57` is a genuine option
  but it is a *product pivot reversal*, not a graphics tweak.
- Prerequisite either way: make `bench_nexus_runtime.sh` real (Option A row 10)
  so this decision gets device numbers instead of estimates.

## 5. Prioritized next actions

1. Land depth attachment fix (0.5 d — correctness).
2. `.metallib` precompile in `compile_nexus_shaders.sh` (1.5 d).
3. Binary mesh + textured venue slice (7 d).
4. Promote instancing prototype to default-on (1 d).
5. Device bench gate on A15-class hardware (2 d) → re-baseline this document
   with measured numbers.

## 6. Prototype included on this branch

`NEXUS_METAL_INSTANCED=1` (env, default **off**) switches `MetalRenderer::render`
to consume the previously stats-only `batchDrawCommands()` output and issue one
instanced `drawIndexedPrimitives:...instanceCount:` per unique mesh, with per-instance
MVPs passed in ≤4 KB `setVertexBytes` chunks (64 instances/chunk) to a new
`nexus_vertex_instanced` entry point. Off by default: zero behavior change for the
shipping path; identical visual output when enabled (same MVPs, same meshes).
Files: `engine/renderer/src/metal_renderer.mm`,
`engine/renderer/include/nexus/renderer/metal_renderer.h`.
