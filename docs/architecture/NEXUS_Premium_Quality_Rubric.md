# NEXUS Premium Quality Rubric — Engine Section

> Branch: `anti-gravity-fel` · Target: **5/5 ship** on every criterion · Baseline audit: **2026-06-19**

Score each criterion **1–5** (1 = prototype, 3 = shippable beta, 5 = mobile AAA tier).

| # | Criterion | Before | After | Target |
|---|-----------|--------|-------|--------|
| 1 | **Build & CI gate** — headless + GPU matrix, ctest green | 4 | 5 | 5 |
| 2 | **Frame pacing** — stable dt, no spiral-of-death | 3 | 4 | 5 |
| 3 | **Crash resilience** — mesh/load failures never abort runtime | 3 | 4 | 5 |
| 4 | **Error diagnostics** — structured `Result<T>` messages | 3 | 4 | 5 |
| 5 | **Visual fidelity — PBR shading** | 3 | 4 | 5 |
| 6 | **Visual fidelity — ACES tonemap** | 2 | 4 | 5 |
| 7 | **Anti-aliasing** — MSAA or FXAA post path | 2 | 3 | 5 |
| 8 | **Lighting** — directional sun + ambient hemisphere | 3 | 4 | 5 |
| 9 | **Shadow pass** — depth map wired in frame graph | 2 | 2 | 5 |
| 10 | **Post-process chain** — bloom + tonemap GPU passes | 2 | 3 | 5 |
| 11 | **Draw budget** — ≤130k tris mobile venue | 4 | 4 | 5 |
| 12 | **Draw call budget** — ≤750 visible draws | 3 | 3 | 5 |
| 13 | **Memory budget** — ≤400 MB RAM mobile embed | 2 | 2 | 5 |
| 14 | **GPU buffer reuse** — pooled vertex/index uploads | 2 | 3 | 5 |
| 15 | **Dev observability** — FPS / draws / tris HUD | 3 | 4 | 5 |
| 16 | **Metal iOS renderer** — CAMetalLayer pipeline | 2 | 2 | 5 |
| 17 | **Animation / skinning** — GPU UBO + shader hook | 3 | 3 | 5 |
| 18 | **Scene graph & culling** — frustum + multi-venue | 4 | 4 | 5 |
| 19 | **Mobile LOD** — profile sidecars + runtime decimation | 4 | 4 | 5 |
| 20 | **Architecture seams** — physics/render/app boundaries clean | 4 | 4 | 5 |

**Before average:** 3.0 / 5 · **After average:** 3.5 / 5 · **Ship target:** 5.0 / 5

---

## Top 10 gaps to premium (remaining)

1. **GPU shadow-map pass** — `shadow_pass.frag` stub only; no VkFramebuffer depth resolve.
2. **GPU bloom + FXAA resolve** — ACES now in `arena.frag`; full-screen passes still CPU-logged stubs.
3. **MSAA swapchain** — `VK_SAMPLE_COUNT_1_BIT` everywhere; enable 4× MSAA on capable devices.
4. **Metal full pipeline** — iOS embed needs parity with Vulkan PBR + post chain.
5. **GPU skeletal skinning shader** — bone matrices exported; vertex shader hook pending.
6. **Buffer pool implementation** — pattern documented; per-upload `vkCreateBuffer` still hot path.
7. **RAM budget enforcement** — 400 MB target documented; no runtime telemetry gate yet.
8. **Draw-call batching / instancing** — single draw per mesh instance; no MDI.
9. **Texture / ASTC runtime** — material albedo still vertex-color weighted stub.
10. **Device Instruments gate** — authoritative 60 FPS @ 1080p validation on A17/M-series hardware.

---

## Premium upgrades delivered (this pass)

| Upgrade | Location |
|---------|----------|
| EMA frame-time smoothing (`FramePacer`) | `engine/core/perf_monitor.*`, `engine.cpp` |
| ACES + hemisphere ambient PBR in fragment shader | `engine/renderer/shaders/arena.frag` |
| FXAA post-process stub (default on) | `post_process.h`, `vulkan_renderer.cpp` |
| Fallback placeholder mesh + `ensureValidGeometry` | `mesh.h`, `scene.cpp`, `uploadSceneMeshes` |
| Dev HUD overlay (`NEXUS_DEV_HUD=1`) | `dev_stats.*`, `Engine::tick` |
| Structured engine errors | `result.h`, `mesh_importer.cpp`, `vulkan_renderer.cpp` |
| Buffer pool pattern doc | `NEXUS_Buffer_Pool_Pattern.md` |
| Benchmark stub script | `scripts/bench_nexus_runtime.sh` |

---

## Acceptance

```bash
./scripts/compile_nexus_shaders.sh
cmake --build build-full
ctest --test-dir build-full --output-on-failure
NEXUS_MESH_PROFILE=mobile ./build-full/nexus_runtime --validate-only --mode basketball_dunk
NEXUS_DEV_HUD=1 ./build-full/nexus_runtime --mode basketball_dunk   # optional HUD logs
./scripts/bench_nexus_runtime.sh
```
