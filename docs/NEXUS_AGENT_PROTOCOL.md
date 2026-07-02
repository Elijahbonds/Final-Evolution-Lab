# NEXUS Agent Protocol — External Clients

> **Source of truth:** `engine/ai_interface/` · **Related:** [AgentInterface.md](./architecture/AgentInterface.md)

External tools (Cursor, MCP servers, shell scripts) can drive the NEXUS engine AI layer without launching the SDL/Vulkan runtime.

## Transports

| Transport | Entry point | Address | Use case |
|-----------|-------------|---------|----------|
| **Stdin JSON lines** | `nexus_agent_cli` | process stdin/stdout | Pipes, subprocess, shell automation |
| **HTTP POST** | `nexus_agent_cli --serve-http` | `http://127.0.0.1:8765/nexus/agent` | Cursor MCP, REST clients |
| **TCP (runtime only)** | `nexus_runtime` | `127.0.0.1:9090` | Live game session while venue is running |
| **Stdin (runtime only)** | `nexus_runtime` | process stdin | Same envelope; responses drained on main thread each frame |

Run the headless CLI from the repo root so generative paths resolve:

```bash
cd ~/Final-Evolution-Lab
cmake --build build-headless --target nexus_agent_cli
```

## CLI usage

### Stdin mode (default)

One JSON object per line on stdin; one or more JSON response lines on stdout.

```bash
echo '{"type":"auth","id":"1","payload":{}}' | ./build-headless/nexus_agent_cli
# {"id":"1","payload":{"authenticated":true},"status":"ok"}
```

Options:

| Flag | Default | Description |
|------|---------|-------------|
| `--queue-budget N` | `8` | Max commands drained per inbound line |
| `--import-root PATH` | `assets/nexus/imported` | Generative mesh output root |
| `--manifest PATH` | `assets/nexus/manifests/nexus_asset_manifest.json` | Asset manifest |
| `--serve-http` | off | Start HTTP listener instead of stdin loop |
| `--port N` | `8765` | HTTP listen port (with `--serve-http`) |

### Batch mode (Cursor MCP / `tools/nexus-cursor-mcp`)

The TypeScript MCP server invokes the CLI with `--json`:

```bash
./build-headless/nexus_agent_cli --json '{"type":"command","id":"c1","payload":{...}}'
```

Batch input accepts a single envelope, a JSON array, or `{"messages":[...]}`. Output is a JSON array (pretty-printed).

```bash
./build-headless/nexus_agent_cli --serve-http --port 8765
```

```bash
curl -s -X POST http://127.0.0.1:8765/nexus/agent \
  -H 'Content-Type: application/json' \
  -d '{"type":"command","id":"c1","payload":{"command":"fel.creative.raise_terrain","params":{"position":[0,0,0],"radius":2,"height":1}}}'
```

Single-command responses return the standard envelope directly. Multi-response batches wrap as `{"status":"ok","responses":[...]}`.

## Message envelopes

### Inbound

```json
{
  "type": "auth" | "command" | "query",
  "id": "<correlation-id, optional>",
  "payload": { }
}
```

| `type` | Required payload |
|--------|------------------|
| `auth` | any object |
| `command` | `{ "command": "<name>", "params": { } }` |
| `query` | `{ "query": "<name>", ...extra fields }` |

Parsed by `parseAgentMessage()` in `engine/ai_interface/src/command_schema.cpp`.

### Outbound

```json
{
  "id": "<echo of request id>",
  "status": "ok" | "error",
  "payload": { },
  "error": "<present when status=error>"
}
```

Serialized by `AgentResponse::serialize()`.

## Queue budget

`AgentServer::processQueuedCommands(maxCommands)` drains at most `maxCommands` messages per call.

| Context | Default budget | Notes |
|---------|----------------|-------|
| `nexus_agent_cli` | `8` (`--queue-budget`) | One stdin/HTTP request → enqueue 1 → drain up to budget |
| `nexus_runtime` engine tick | `32` (`EngineConfig::maxCommandsPerFrame`) | Drained before physics/gameplay each frame |

Transport threads only call `receiveJson()`; routing never runs on I/O threads.

## Error envelopes

| Stage | Delivery | Example |
|-------|----------|---------|
| JSON parse | CLI/HTTP synthetic envelope | `{"status":"error","error":"Invalid JSON"}` |
| Schema | CLI/HTTP synthetic envelope | `{"status":"error","error":"Agent message requires string field 'type'"}` |
| Routing | `status: "error"` | `{"status":"error","error":"Unsupported command"}` |
| Domain | `status: "error"` | `{"status":"error","error":"terrain.fill_region exceeds maximum edit volume"}` |

Runtime TCP/stdin transport logs parse errors via `NEXUS_LOG_WARN` and does not emit a response line (responses are only available through the engine drain path).

## Text-to-generation commands

Registered via `GameplayApplication` on the CLI session stack.

| Command / query | Params | Description |
|-----------------|--------|-------------|
| `query: fel.generate.parse_prompt` | `text` | Returns planned steps without executing |
| `command: fel.generate.from_text` | `text` or `prompt` | Parse + execute creative + generative steps |
| `command: fel.creative.from_text` | `text` or `prompt` | Parse + execute creative terrain steps only |

Example:

```json
{
  "type": "command",
  "id": "gen_1",
  "payload": {
    "command": "fel.generate.from_text",
    "params": { "text": "Flatten court and add orange hoop prop" }
  }
}
```

**Success payload** includes `steps_applied`, `step_results`, `jobs`, `intent`, `agent_summary`.

Direct generative commands (`fel.generate.create_model`, `fel.scan.*`) route through `GenerativePipeline`. Creative aliases (`fel.creative.raise_terrain`, etc.) route through `VoxelCommandParser`.

## Studio control-plane queries (`fel.studio.*`)

Headless `nexus_agent_cli` exposes Studio / Cursor artifact paths without launching the iOS app:

| Query | Params | Description |
|-------|--------|-------------|
| `fel.studio.list_artifacts` | — | Returns repo-relative artifact paths (playtest, HUD snapshot, build gate log) |
| `fel.studio.open_file` | `path`, optional `line` | Returns `relative_path` + `cursor_uri_hint` for IDE navigation |
| `fel.studio.run_playtest` | optional `mode_id` (default `basketball_dunk`) | Returns `manual_command` + MCP tool name `studio_run_playtest` |

Example:

```bash
./build-headless/nexus_agent_cli --json \
  '{"type":"query","id":"s1","payload":{"query":"fel.studio.list_artifacts"}}'
```

MCP equivalents: `list_artifacts`, `studio_open_file`, `studio_run_playtest` (see `docs/CURSOR_NEXUS_CONTROL.md`).

## Routing reference

See [AgentInterface.md](./architecture/AgentInterface.md) for the full prefix table (`terrain.*`, `fel.fitness.*`, `world.dirty_chunks`, etc.).

## Tests

| Test | Command |
|------|---------|
| Protocol unit | `ctest -R nexus_protocol_test` |
| CLI session integration | `ctest -R nexus_agent_cli_test` |

`nexus_agent_cli_test` exercises auth, `fel.creative.*`, `fel.generate.parse_prompt`, `fel.generate.from_text`, parse/routing error envelopes, and queue drain behavior.

## Cursor integration sketch

1. Start `nexus_agent_cli --serve-http` in a background terminal.
2. Point an MCP HTTP tool at `POST http://127.0.0.1:8765/nexus/agent`.
3. Send the same JSON envelopes documented above.

For subprocess integration, pipe JSON lines to `nexus_agent_cli` without HTTP.
