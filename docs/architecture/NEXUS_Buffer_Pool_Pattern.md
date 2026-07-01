# NEXUS GPU Buffer Pool Pattern

> Status: **documented pattern** — full pool not yet wired into `VulkanRenderer` (premium pass scope).

## Problem

`VulkanRenderer::uploadSceneMeshes()` allocates a fresh `VkBuffer` + `VkDeviceMemory` pair per mesh on every venue reload. Mobile AAA engines reuse device-local staging buffers to avoid allocation churn and driver overhead.

## Target pattern

```
MeshBufferPool (device-local, ring of N slots)
├── acquire(slot) → {vertexBuffer, indexBuffer, capacity}
├── upload(slot, MeshVertex[], indices[]) — memcpy + optional staging copy
└── release(slot) — mark free; defer destroy until pool reset

Venue reload:
  pool.reset()           // or bump generation counter
  for mesh in scene:
    slot = pool.acquire(max(vertices, indices))
    pool.upload(slot, mesh)
    gpuMeshes[i] = slot.handles
```

## Sizing (mobile 1080p)

| Resource | Initial pool | Max slot size |
|----------|--------------|---------------|
| Vertex buffers | 16 slots | 80k verts × 44 B ≈ 3.5 MB |
| Index buffers | 16 slots | 240k indices × 4 B ≈ 960 KB |

## Integration seam

- Add `engine/renderer/include/nexus/renderer/buffer_pool.h` when implementing.
- `VulkanRenderer::destroyGpuMeshes()` → `m_bufferPool.releaseAll()` instead of per-buffer destroy.
- iOS Metal path mirrors with `MTLBuffer` pool keyed by length bucket.

## Ship gate

Pool hit rate ≥ 90% on venue hot-reload stress test (`bench_nexus_runtime.sh --reload 50`).
