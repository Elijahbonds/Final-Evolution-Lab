# 04 — Creative Mode Protocol

**Spec:** Phase 4 Creative Mode  
**Implementation:** `app/gameplay/include/nexus/gameplay/voxel_command_parser.h`, `voxel_command_parser.cpp`

`VoxelCommandParser` maps **`fel.creative.*`** agent commands onto safe terrain edits via `WorldManipulator`. High-level creative ops are implemented as validated `terrain.fill_region` / `terrain.set_voxels` calls.

## Safety limits

| Constraint | Value |
|------------|-------|
| Max radius (`radius` param) | 16 (clamped) |
| Max height (`height` param) | 1–16 (clamped) |
| Material ID | 0–65535 (0 = air / non-solid) |
| Default material | 1 |

## Command reference

### `fel.creative.set_voxels`

Passthrough to `terrain.set_voxels`.

**Params:**

```json
{
  "voxels": [
    {
      "position": [x, y, z],
      "voxel": { "material": 11, "solid": true }
    }
  ]
}
```

### `fel.creative.fill_region`

Passthrough to `terrain.fill_region`.

**Params:**

```json
{
  "min": [x0, y0, z0],
  "max": [x1, y1, z1],
  "voxel": { "material": 6, "solid": true }
}
```

### `fel.creative.raise_terrain`

Builds a vertical column (or padded cube when `radius` > 0) upward from `position`.

| Param | Required | Default | Notes |
|-------|----------|---------|-------|
| `position` | yes | — | `[x, y, z]` integers |
| `radius` | no | 1 | Horizontal pad in X/Z |
| `height` | no | 1 | Voxels stacked upward |
| `material` | no | 1 | Fill material |

### `fel.creative.lower_terrain`

Clears voxels downward from `position` (material 0 = air). Same params as raise.

### `fel.creative.flatten_terrain`

1. Clears all solids above `position.y` within radius (up to +16 Y).
2. Sets the layer at `position.y` to `material`.

| Param | Required | Default |
|-------|----------|---------|
| `position` | yes | — |
| `radius` | no | 1 |
| `material` | no | 1 |

### `fel.creative.paint_terrain`

Repaints **existing solid** voxels on the horizontal plane at `position.y` within radius. Does not create new geometry.

**Response (ok, no solids):** `{ "edited_voxels": 0, "painted_voxels": 0 }`  
**Response (ok, painted):** includes `painted_voxels` count.

## Error responses

| Condition | Error message |
|-----------|---------------|
| Missing `position` | `creative command requires position [x, y, z]` |
| Invalid position type | `creative command position values must be integers` |
| Bad integer param | `creative command integer parameter has invalid type` |
| Material out of range | `creative material must be between 0 and 65535` |
| Unknown command | `Unsupported FEL creative command` |

## Routing

`GameplayApplication::handleGameplayCommand` delegates `fel.creative.*` to `VoxelCommandParser`. The parser logs each applied command on channel `kCreative`.

Direct engine commands (`terrain.*`) remain available through `CommandRouter` without the `fel.creative` prefix for low-level tooling.

## Example: raise then paint

```json
{
  "type": "command",
  "id": "c1",
  "payload": {
    "command": "fel.creative.raise_terrain",
    "params": {
      "position": [0, 0, 0],
      "radius": 1,
      "height": 1,
      "material": 3
    }
  }
}
```

```json
{
  "type": "command",
  "id": "c2",
  "payload": {
    "command": "fel.creative.paint_terrain",
    "params": {
      "position": [0, 0, 0],
      "radius": 1,
      "material": 8
    }
  }
}
```
