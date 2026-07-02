# NEXUS Performance Targets

Ship-gate constants for the NEXUS engine runtime (Vulkan dev preview + future Metal iOS embed).

## FPS targets

| Platform | Target FPS | Tolerance | Constant |
|----------|------------|-----------|----------|
| iOS / mobile embed | 60 | ±1 FPS | `nexus::core::kTargetFpsMobile` |
| Desktop dev runtime | 60 | ±1 FPS | `nexus::core::kTargetFpsDesktop` |

`PerfMonitor::withinFpsTarget()` samples smoothed FPS over 0.5 s windows. Device profiling with Instruments / Xcode GPU frame capture remains the authoritative mobile check.

## Draw budget

| Metric | Budget | Constant / API |
|--------|--------|----------------|
| Visible scene triangles (mobile profile) | ≤ 130,000 | `RenderScene::DrawStats::kSceneTriangleBudget()` |
| Visible draw calls (mobile @ 1080p) | < 750 | `nexus::core::kMaxDrawCallsMobile` |
| Process RAM (mobile embed) | < 400 MB | `nexus::core::kMaxRamBudgetMbMobile` |
| Mobile mesh sidecar | ≤ 80,000 tris | `NEXUS_MESH_PROFILE=mobile` + `scripts/nexus_mobile_mesh_gate.sh` |

Gate helpers:

- `RenderScene::DrawStats::withinBudget()` — per-frame scene collect
- `nexus::core::sceneTriangleBudgetExceeded()` — perf monitor module check

## Dev stats logging

| Env var | Default | Output |
|---------|---------|--------|
| `NEXUS_DEV_STATS` | on | Combined FPS + draw stats via `logFrameDevStats()` (engine every 120 frames; validate-only once) |
| `NEXUS_DEV_DRAW_STATS` | on | Per-frame draw line from Vulkan renderer |
| `NEXUS_DEV_HUD` | off | Compact HUD line every 30 frames: fps, frame_ms, draws, tris, budget (`dev_hud` log tag) |

Disable noisy logs in CI:

```bash
export NEXUS_DEV_STATS=0
export NEXUS_DEV_DRAW_STATS=0
export NEXUS_DEV_HUD=0
```

## Mobile ship gate (1080p)

| Target | Value | Verification |
|--------|-------|----------------|
| FPS | ≥ 60 ±1 | `PerfMonitor::withinFpsTarget()`, Instruments on device |
| Resolution | 1080p | iOS embed / runtime window profile |
| RAM | < 400 MB | Xcode Memory Gauge / `bench_nexus_runtime.sh` stub |
| Draw calls | < 750 | `DrawStats::visibleDraws` via `NEXUS_DEV_HUD=1` |
| Triangles | ≤ 130k | `--validate-only` + frustum-off batch |

## Acceptance commands

```bash
# Mobile mesh + draw budget ship gate
NEXUS_MESH_PROFILE=mobile ./build-full/nexus_runtime --validate-only --mode basketball_dunk

# Unit gates (animation + perf + draw budget)
ctest --test-dir build-full -R nexus_renderer_test --output-on-failure
```

## Reference venue

Venice Beach (`basketball_dunk`) is the canonical profiling venue. Mobile sidecar `venice_beach_court_model_fbx_mobile.nexusmesh.json` must stay within the 130k tri draw budget after frustum cull is disabled (validate-only uses `collectDrawCommandBatch(false)`).
