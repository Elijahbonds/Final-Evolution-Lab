# NEXUS Bloom Pass Status

**Updated:** 2026-06-19  
**Phase:** Engine Phase 6 (Post-process)

## Current state

| Capability | Status |
|------------|--------|
| ACES tonemap in `arena.frag` | **Active** |
| CPU bloom threshold gate | **Active** in `PostProcessChain::exceedsBloomThreshold()` |
| Frame-graph bloom slots | **Reserved** — `VulkanRenderer::recordPostProcessStub()` |
| GPU bloom extract + mip blur | **Deferred** — preview mode |

## Runtime flags

`BloomPassRuntimeFlags` (`engine/renderer/include/nexus/renderer/bloom_runtime.h`):

- Default: `gpuBloomResolveEnabled=false`, `previewBloomStub=true`
- Preview label: `PREVIEW: bloom pass stub — GPU mip blur deferred (set NEXUS_GPU_BLOOM=1 when wired)`
- Environment override: `NEXUS_GPU_BLOOM=1` opts into future GPU resolve path (logs extension until passes land)

## Next extension

1. Half-res HDR offscreen target after main pass
2. Bright-pass extract + separable Gaussian blur (3 mips)
3. Composite bloom back in tonemap pass
4. Flip `gpuBloomResolveEnabled` when ctest + visual check pass
