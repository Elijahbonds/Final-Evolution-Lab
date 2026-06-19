# NEXUS Agent Interface

> Source of truth: `engine/ai_interface/` and `tests/unit/ai_interface/command_test.cpp`.

## Overview

External agents (LLMs, tools, scripts) send newline-delimited JSON to NEXUS. Messages are queued thread-safely, drained on the main engine thread, routed by prefix, and return structured responses.

## Transport

| Channel | Config flag | Address | Notes |
|---------|-------------|---------|-------|
| Stdin | `enableStdinReader` | process stdin | One JSON object per line |
| TCP | `enableTcpListener` | `127.0.0.1:9090` | Newline-framed; one client at a time per accept |

Started via `AgentServer::startTransport()` from `runtime/src/main.cpp`. Transport threads only call `receiveJson()`; they never route or mutate world state.

### Threading model

```
[I/O thread]   receiveJson()  →  mutex-protected queue push
[Main thread]  processQueuedCommands(N)  →  CommandRouter::route()  →  subsystem mutation
```

Never call `route()` from transport threads. Never block the main thread on socket I/O.

## Inbound envelope

```json
{
  "type": "auth" | "command" | "query",
  "id": "<correlation-id, optional>",
  "payload": { }
}
```

Parsed by `parseAgentMessage()` in `command_schema.cpp`.

| `type` | Required payload |
|--------|------------------|
| `auth` | any object (token validation not implemented) |
| `command` | `{ "command": "<name>", "params": { } }` |
| `query` | `{ "query": "<name>" }` |

Parse failures return `Result::err` from `receiveJson()` — no `AgentResponse` is produced.

## Outbound envelope

```json
{
  "id": "<echo of request id>",
  "status": "ok" | "error",
  "payload": { },
  "error": "<present when status=error>"
}
```

Serialized by `AgentResponse::serialize()`.

## Routing (`CommandRouter::route`)

| Prefix / name | Handler |
|---------------|---------|
| `auth` | Always `ok` + `{ "authenticated": true }` |
| `query: world.dirty_chunks` | `VoxelWorld::serializeDirtyChunks(8)` |
| `query: fel.*` | `GameplayCommandHandler::handleGameplayQuery` (if registered) |
| `command: terrain.*` | `WorldManipulator::applyCommand` |
| `command: fel.*` or `fitness.*` | `GameplayCommandHandler::handleGameplayCommand` |
| other | `error: "Unsupported command"` or `"Unsupported query"` |

## Engine commands

### `terrain.set_voxels`

```json
{
  "type": "command",
  "id": "cmd_001",
  "payload": {
    "command": "terrain.set_voxels",
    "params": {
      "voxels": [
        { "position": [1, 2, 3], "voxel": { "material": 7, "solid": true } }
      ]
    }
  }
}
```

**Success:** `{ "edited_voxels": N, "dirty_chunks": M }`

### `terrain.fill_region`

```json
{
  "command": "terrain.fill_region",
  "params": {
    "min": [0, 0, 0],
    "max": [3, 3, 3],
    "voxel": { "material": 1, "solid": true }
  }
}
```

**Constraints:** inclusive AABB; min/max order independent; volume ≤ 32,768.

## Queries

### `world.dirty_chunks`

Returns up to 8 dirty chunk coordinates and **clears their dirty flags** (ack side effect for future mesher).

```json
{ "chunks": [ { "coord": [cx, cy, cz] } ] }
```

## FEL gameplay commands (app layer)

Registered when `CommandRouter::setGameplayHandler(&gameplay)` is called.

### Fitness updates

| Command | Params |
|---------|--------|
| `fel.fitness.update` / `fitness.update` | `frc_mobility`, `frc_active_range`, `frc_control`, `iap_engagement`, `iap_confidence`, `breath_phase` |
| `fel.fitness.update_frc` / `fitness.update_frc` | FRC fields only |
| `fel.fitness.update_iap` / `fitness.update_iap` | IAP fields only |

All float scores clamped to `[0, 1]`; `breath_phase` to `[-1, 1]`.

**Success:** `{ "fitness_revision": <uint64> }`

### Creative (LLM-friendly aliases)

| Command | Maps to |
|---------|---------|
| `fel.creative.set_voxels` | `terrain.set_voxels` |
| `fel.creative.fill_region` | `terrain.fill_region` |
| `fel.creative.raise_terrain` | fill above position |
| `fel.creative.lower_terrain` | fill with air below |
| `fel.creative.flatten_terrain` | clear above + fill plane |
| `fel.creative.paint_terrain` | material swap on solid voxels |

Params: `position` `[x,y,z]`, optional `radius` (≤ 16), `height`, `material`.

### Gameplay query

`fel.query.get_session_state` — returns fitness snapshot, throw-catch phase, agent stats.

## Error conventions

| Stage | Delivery | Example |
|-------|----------|---------|
| JSON parse | `receiveJson` Err | `"Invalid JSON"` |
| Schema | `receiveJson` Err | `"Agent message requires string field 'type'"` |
| Routing | `status: "error"` | `"Unsupported command"` |
| Domain | `status: "error"` | `"terrain.fill_region exceeds maximum edit volume"` |

## Planned (not routed)

- `entity.create` / `entity.modify` / `entity.delete`
- `terrain.sculpt` (brush)
- `visual.set_post_process` / `visual.set_lighting`
- `terrain.undo` / `terrain.redo`
- Push event stream back to connected agents

## Integration test

`tests/unit/ai_interface/command_test.cpp` validates:

1. `terrain.set_voxels` round-trip
2. `world.dirty_chunks` query

Run via `ctest` in any build with `NEXUS_BUILD_TESTS=ON`.
