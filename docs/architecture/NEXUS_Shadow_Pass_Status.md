# NEXUS Shadow Pass Status

**Updated:** 2026-06-19  
**Phase:** Engine Phase 5 (Lighting + shadow pass)

## Current state

| Capability | Status |
|------------|--------|
| Directional sun + ambient hemisphere | **Active** in `arena.frag` |
| Shadow light view-projection stub | **Active** in `lighting.cpp` |
| Frame-graph shadow pass slot | **Reserved** — `VulkanRenderer::recordShadowPassStub()` |
| GPU depth resolve (`VkFramebuffer`) | **Deferred** — preview mode |
| PCF sampling in fragment shader | **Deferred** |

## Runtime flags

`ShadowPassRuntimeFlags` (`engine/renderer/include/nexus/renderer/shadow_runtime.h`):

- Default: `gpuDepthResolveEnabled=false`, `previewShadowStub=true`
- Preview label: `PREVIEW: shadow-map pass stub — GPU depth resolve deferred (set NEXUS_GPU_SHADOW=1 when wired)`
- Environment override: `NEXUS_GPU_SHADOW=1` opts into future GPU resolve path (still logs extension until framebuffer lands)

## Honest labeling

Desktop Vulkan runtime logs **preview-stub** in init when shadows are enabled. This is intentional — no fake GPU shadow claim in dev HUD or matrix docs.

## Next extension (world-class bar)

1. Allocate 1024² depth image + `VkFramebuffer`
2. Record `shadow_pass.frag` SPIR-V into offscreen pass before main pass
3. Bind shadow map in `arena.frag` with PCF
4. Flip `gpuDepthResolveEnabled` when ctest + visual check pass
