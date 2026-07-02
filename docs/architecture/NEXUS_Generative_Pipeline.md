# NEXUS Generative Pipeline

Agent-facing mesh generation and scan import for NEXUS runtime. Object-scale imports use `ScanImporter`; **environment-scale** captures (Luma, ARKit, photogrammetry) use `EnvironmentScanImporter` with chunked venue tiles aligned to `VoxelWorld::kChunkEdge` (32).

## Module layout

| Path | Role |
|------|------|
| `engine/generative/` | `GenerativePipeline`, `ScanImporter`, `EnvironmentScanImporter`, `EnvironmentChunkMerger`, `ModelGenerator`, manifest registration |
| `engine/luma/` | `ILumaAdapter` + `StubLumaAdapter` (no API keys in repo) |
| `assets/nexus/manifests/` | Asset + `environment_scans[]` entries |
| `assets/nexus/imported/environments/` | Chunked venue `.nexusmesh.json` tiles |

## Commands

### Object scan (existing)

| Command | Purpose |
|---------|---------|
| `fel.scan.import_mesh` | Single mesh / nexusmesh / stub for glTF/FBX |
| `fel.scan.import_point_cloud` | PLY/PCD/LAS → stub mesh |

### Environment scan (Luma parity)

| Command | Purpose |
|---------|---------|
| `fel.scan.import_environment` | Gaussian splat / photogrammetry mesh / point cloud → chunked venue tiles + manifest |
| `fel.scan.import_chunk` | Incremental chunk upload (streaming capture) |

Register `GenerativePipeline` on `CommandRouter::init(..., &pipeline)` so `fel.scan.*` and `fel.generate.*` route correctly.

### Example: full environment import (Luma)

```json
{
  "type": "command",
  "id": "env_luma_001",
  "payload": {
    "command": "fel.scan.import_environment",
    "params": {
      "input_path": "assets/nexus/source/luma/venice_shop_splat.ply",
      "venue_id": "luma_venice_shop",
      "source": "luma",
      "name": "Luma Venice Shop Scan",
      "chunk_edge": 32,
      "bounds": {
        "min": [-32, 0, -32],
        "max": [32, 8, 32]
      }
    }
  }
}
```

**Success payload:** `venue_id`, `environment_asset_id`, `source`, `chunk_edge`, `bounds`, `chunks[]`, `manifest_path`, `metadata.merged_mesh`.

### Example: incremental chunk (ARKit streaming)

```json
{
  "type": "command",
  "id": "env_chunk_002",
  "payload": {
    "command": "fel.scan.import_chunk",
    "params": {
      "venue_id": "arkit_training_room",
      "coord": [0, 0, 1],
      "mesh_path": "assets/nexus/imported/environments/arkit_training_room_chunk_0_0_1.nexusmesh.json",
      "source_format": "photogrammetry_mesh"
    }
  }
}
```

Omit `mesh_path` to emit a procedural stub tile for the given coord.

## Luma parity for environments

Environment capture parity checklist:

| Capability | Status | Notes |
|------------|--------|-------|
| Multi-format ingest (splat / mesh / point cloud) | Stub | `input_path` accepted; offline conversion pipeline TBD |
| Spatial chunking (32³ tiles) | Done | `EnvironmentChunkIndex` + manifest `chunk_edge` |
| Manifest `environment_scans[]` | Done | `venue_id`, `bounds`, `chunks`, `source` |
| Incremental chunk upload | Done | `fel.scan.import_chunk` |
| Merged venue mesh stub | Done | `EnvironmentChunkMerger` → `{venue_id}_merged.nexusmesh.json` |
| VoxelWorld chunk registry | Done | `registerEnvironmentChunk` marks dirty tiles |
| RenderScene chunk attach | Stub | `RenderScene::attachEnvironmentChunks` |
| Luma API adapter | Stub | `engine/luma/luma_adapter.h` — configure keys out-of-repo |
| iOS ARKit export path | Documented | See `docs/ios/EnvironmentScanCapture.md` |

## iOS capture path

ARKit / RealityKit scene capture exports (USDZ/OBJ/ point cloud) should be placed under `assets/nexus/source/` and imported via `fel.scan.import_environment` with `"source": "arkit"`.

Optional Luma flow: resolve capture via `ILumaAdapter`, download export, then call the same import command with `"source": "luma"`.

See [EnvironmentScanCapture.md](../ios/EnvironmentScanCapture.md).

## Runtime wiring

1. `EnvironmentScanImporter` writes chunk meshes and updates manifest.
2. `VoxelWorld::registerEnvironmentChunk` indexes tiles for creative/physics overlap.
3. `RenderScene::attachEnvironmentChunks` (renderer builds) places chunk meshes at `coord * chunk_edge`.
4. `createFromManifest` continues to load single imported environment markers; chunked venues use attach step when `environment_scans` entry matches active venue.

## Tests

`tests/unit/generative/generative_test.cpp` covers:

- Environment import → manifest + VoxelWorld registration
- Chunk upsert
- Agent router round-trip for `fel.scan.import_environment`

Run: `ctest --test-dir build-headless --output-on-failure`
