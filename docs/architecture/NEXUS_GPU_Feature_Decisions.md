# NEXUS GPU Feature Decisions — Sprint 1 (nexus/engine-gfx)

Audit date: 2026-07-01. Scope: GPU skinning, GPU particles, draw-call
instancing on the actual NEXUS runtime (`engine/renderer/`, `MetalRenderer`,
`console_tier_lod`, `JobSystem` — LOD + job system already wired into
`Engine::tick`).

## Audit findings (what actually exists)

| Capability | State on `integration/nexus-aaa` |
|---|---|
| Skeletal animation | `AnimationPlayer`: CPU keyframe sampling, translation-only bone matrices, flat buffer sized for a skinning UBO — but **no consumer skins vertices**; `MeshVertex` has no bone indices/weights |
| Particles | **None** (no particle code anywhere in `engine/`) |
| Instancing | **None** — `RenderScene::DrawCommand` is one mesh × one matrix; both backends submit per-command |
| Job system | Real work-stealing scheduler (`JobSystem::parallelFor`), already driving physics |
| Mesh LOD / tiers | `mesh_lod` + `console_tier_lod` wired into tick; 130k-tri scene budget enforced in `DrawStats` |

## Shipped this sprint (real, headless-tested)

1. **Draw-call instancing groundwork** — `RenderScene::collectInstancedDrawBatch()`
   groups visible draws by mesh into per-instance transform arrays
   (`nexus_gfx_batch_test`: 7 draws → 2 instanced draws). Backend upload
   (Metal `drawIndexedPrimitives(instanceCount:)`) is the remaining half; the
   instance-buffer contract is fixed by this API.
2. **Batched CPU skinning** — `SkinningBatch::advanceAll()` advances N
   `AnimationPlayer`s via `JobSystem::parallelFor`, bit-stable vs serial.
3. **Particle system phase 1** — CPU sim (SoA, deterministic xorshift, swap-
   remove expiry) + `ParticleSpriteBatch` flattening each emitter to ONE
   instanced-quad payload (32-byte `ParticleInstanceData` stride). Budgets
   clamp per `infra/asset_spec.md` tier (512/2048/8192). Flipbook sheets come
   from `scripts/assets/particle_sheet_gen.py`.

## Capabilities that can NOT reach AAA in-engine yet, with options

Unreal is retired; both options below are NEXUS-native. Option B is phased
NEXUS work, not an external-engine bridge.

### 1. GPU skinning

Blocker: vertex format has no bone influences; importer emits none; no skinning
shader in either backend.

- **Option A — native GPU skinning (vertex shader path)**
  1. Extend `MeshVertex` + `.nexusmesh.json` with `boneIndices[4]`/`boneWeights[4]`
     and thread through `mesh_importer` (1.5 w)
  2. Metal vertex-function skinning with bone-matrix argument buffer;
     `AnimationPlayer::skinningMatrixData()` already provides the upload blob (1.5 w)
  3. Vulkan parity + LOD-aware bone-count clamp for `console_tier_lod` (1 w)
  - **Estimate: ~4 engineer-weeks** to parity on both backends.
- **Option B — phased NEXUS path (recommended for Sprint 2)**
  1. Keep `SkinningBatch` CPU path (done, parallel) for ≤8 characters (0 w)
  2. Add compute-pass CPU→GPU pose palette upload only (no vertex format
     change) so HUD/preview characters animate on-GPU (1 w)
  3. Fold full Option A steps in when character art with real rigs lands (4 w later)
  - **Estimate: 1 w now, defers format break** until rigged assets exist.

### 2. GPU-compute particles

Blocker: no compute pipeline abstraction in either backend yet.

- **Option A — Metal compute integration**: particle integrate/expire in a
  compute kernel over the same 32-byte instance buffer; indirect draw for
  instance count. Requires compute pipeline + buffer pool work in
  `MetalRenderer` (see `NEXUS_Buffer_Pool_Pattern.md`). **Estimate: 3 w**
  (2 w compute infra reusable by other passes + 1 w particle kernel/tests).
- **Option B — phased NEXUS path (recommended)**: ship phase-1 CPU sim (done;
  2048 particles integrate in well under 0.5 ms on A14-class cores, JobSystem-
  parallel across emitters) → Sprint 2 adds the instanced-quad draw in
  `MetalRenderer` (1 w) → Sprint 3 promotes integration to compute using the
  unchanged instance-buffer contract (2 w). **Estimate: 1 w next sprint, 3 w
  total to full GPU.**

### 3. Instanced rendering in backends

Not blocked — half-done by design this sprint. Remaining: per-instance buffer
upload + `instanceCount` submission in `MetalRenderer` (0.5 w) and Vulkan
(0.5 w), then switch `arena_scene`/venue props to shared meshes to actually
benefit (0.5 w). **Estimate: 1.5 w, no decision needed.**

## Gate status

`./scripts/nexus_build_gate.sh` run after these changes — results recorded in
`infra/AGENT_STATUS.md` (headless suite + full suite including the new
`nexus_gfx_batch_test`, plus production/staging mode validation).
