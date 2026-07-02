# NEXUS Creative Mode Logic

> Source of truth: `engine/creative/` and `app/gameplay/src/voxel_command_parser.cpp`.

## Coordinate & chunk model

- **World space:** integer voxel coordinates `Vec3i { x, y, z }`.
- **Chunk edge:** `VoxelWorld::kChunkEdge = 32` → 32³ = 32,768 voxels per chunk.
- **Chunk key:** `floorDiv(position, 32)` per axis (negative-safe).
- **Local index:** `x + y*32 + z*32*32` with positive modulo for negatives.
- **Storage:** sparse `unordered_map<ChunkCoord, Chunk>`; chunks allocated on first write.

## Voxel representation

```cpp
struct Voxel {
  std::uint16_t material;  // 0 = air / default
  bool solid;              // JSON default: solid = (material != 0)
};
```

Missing chunks read as `{ material: 0, solid: false }`.

## Dirty-chunk propagation

On every `setVoxel(position, voxel)`:

1. Mark the owning chunk dirty.
2. If the voxel lies on a chunk boundary (local x, y, or z == 0), mark the adjacent neighbor chunk in that axis dirty (face visibility crosses boundaries).

`dirtyChunkCount()` returns the number of chunks with `dirty == true`.

### `serializeDirtyChunks(maxChunks)`

- Returns `[{ "coord": [cx, cy, cz] }, ...]` for up to `maxChunks` dirty entries.
- **Clears the dirty flag** on returned chunks (mesher ack).
- Does not include voxel payload — coordinates only.

Queried via agent message `world.dirty_chunks` (limit 8 in router).

## Engine terrain commands

Implemented in `WorldManipulator`:

### `terrain.set_voxels`

- Requires `params.voxels[]` with `position` (3-int array) and `voxel` (object).
- Iterates edits; first validation or apply error aborts the batch (**no rollback** of prior edits in the same call).

### `terrain.fill_region`

- Requires `min`, `max`, `voxel`.
- Normalizes min/max to an inclusive axis-aligned box.
- Rejects volume > 32,768 (`kMaxFillVoxels`).
- Writes every voxel in the box via `setVoxel` (dirty propagation per voxel).

**Success payload (both commands):**

```json
{ "edited_voxels": <count>, "dirty_chunks": <count> }
```

## FEL creative commands (app layer)

`VoxelCommandParser` translates LLM-friendly names into engine `terrain.*` calls:

| Command | Behavior |
|---------|----------|
| `fel.creative.set_voxels` | passthrough to `terrain.set_voxels` |
| `fel.creative.fill_region` | passthrough to `terrain.fill_region` |
| `fel.creative.raise_terrain` | fill column `position ± radius` from `y` to `y+height-1` |
| `fel.creative.lower_terrain` | fill same footprint with material `0` (air) |
| `fel.creative.flatten_terrain` | clear voxels above plane, then fill plane at `y` |
| `fel.creative.paint_terrain` | `set_voxels` on solid voxels in `y` plane within radius |

**Guards**

- `radius` clamped to `[0, 16]` (`kMaxCreativeRadius`).
- `height` clamped to `[1, 16]`.
- `material` clamped to `[0, 65535]`; default `1`.

## Undo / redo

**Not implemented.** Recommended future design:

```
UndoRedoManager
  push(EditBatch{ inverse voxel ops })
  undo() / redo()
```

AI commands `terrain.undo` / `terrain.redo` would route through this manager. Each terrain command should snapshot affected voxels before apply.

## Meshing (planned)

- Greedy meshing per dirty chunk; neighbor chunks already marked dirty on boundary edits.
- Regenerate off main thread via future job system; double-buffer GPU meshes.
- Cap mesh jobs per frame.
- **Current state:** no mesher; renderer draws a brand triangle smoke test only.

## Chunk streaming (planned)

- Load/unload by camera radius; LRU eviction for non-dirty chunks.
- **Current state:** all touched chunks remain in the hash map indefinitely.

## Material registry (TBD)

Material IDs are opaque `uint16` values. Architect confirmation needed for:

- Canonical material table (enum vs data-driven JSON)
- Whether `solid` is always derived from `material != 0`
- Texture / PBR mapping for meshed output

## Open design questions

1. Should `terrain.set_voxels` roll back on mid-batch failure?
2. Should dirty-flag clearing happen on query vs explicit ack command?
3. Persistence format and save/load for edited chunks.
4. Brush shapes and `terrain.sculpt` schema.
