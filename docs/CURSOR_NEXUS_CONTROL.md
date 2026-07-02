# Cursor NEXUS Control

Control the **NEXUS** engine environment from **Cursor Desktop** via the canonical `nexus-cursor-mcp` MCP server.

**Canonical repo:** `/Users/elijahbonds/Final-Evolution-Lab`  
**MCP package:** `tools/nexus-cursor-mcp/`  
**Tool registry:** `Config/nexus_cursor_tool_registry.json`

## Prerequisites

1. **macOS** with Xcode CLI tools and CMake (same as `./scripts/nexus_build_gate.sh`).
2. **Node.js 20+** for the MCP server.
3. **Built NEXUS binaries:**
   ```bash
   cd ~/Final-Evolution-Lab
   ./scripts/nexus_build_gate.sh          # builds build-headless + build-full, runs ctest
   # Or minimal agent CLI only:
   cmake -S . -B build-headless -DNEXUS_ENABLE_RENDERER=OFF -DNEXUS_BUILD_TESTS=ON
   cmake --build build-headless --target nexus_agent_cli
   # Runtime for playtest:
   cmake -S . -B build-full -DNEXUS_ENABLE_RENDERER=ON -DNEXUS_BUILD_RUNTIME=ON
   cmake --build build-full --target nexus_runtime
   chmod +x scripts/nexus_playtest.sh
   ```

## Install MCP server

```bash
cd ~/Final-Evolution-Lab/tools/nexus-cursor-mcp
npm install
npm run build
```

## Cursor Desktop setup

Copy the example config and adjust paths if your repo lives elsewhere:

```bash
mkdir -p ~/.cursor
cp ~/Final-Evolution-Lab/.cursor/mcp.json.example ~/.cursor/mcp.json
# Or merge the "nexus" entry into your existing ~/.cursor/mcp.json
```

**Project-local** (recommended for this repo): create `.cursor/mcp.json` at the repo root:

```json
{
  "mcpServers": {
    "nexus": {
      "command": "node",
      "args": ["tools/nexus-cursor-mcp/dist/index.js"],
      "env": {
        "NEXUS_REPO_ROOT": "/Users/elijahbonds/Final-Evolution-Lab",
        "NEXUS_BUILD_DIR": "build-headless",
        "NEXUS_RUNTIME_BUILD_DIR": "build-full"
      }
    }
  }
}
```

Restart Cursor (or reload MCP servers in **Settings → MCP**) after building.

### Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `NEXUS_REPO_ROOT` | `~/Final-Evolution-Lab` | Repo root for scripts and docs |
| `FEL_NEXUS_REPO_ROOT` | (fallback) | Same as above when set by NEXUS Studio IDE |
| `NEXUS_BUILD_DIR` | `build-headless` | Directory containing `nexus_agent_cli` |
| `NEXUS_RUNTIME_BUILD_DIR` | `build-full` | Directory containing `nexus_runtime` |

## MCP tools

Tool names match `Config/nexus_cursor_tool_registry.json` (same as in-app NEXUS Agent):

| Tool | Description |
|------|-------------|
| `list_modes` | Arena modes from `arena_mode_registry.cpp` + `docs/NEXUS_MODES_CAPABILITY.md` tiers |
| `playtest` | `./scripts/nexus_playtest.sh` → `artifacts/playtest/latest.json` |
| `studio_run_playtest` | Alias of `playtest` — Studio-oriented naming |
| `studio_open_file` | Alias of `open_ide_file` — surface repo path + `cursor://file/…` URI |
| `list_artifacts` | Artifact paths for playtest, HUD snapshot, build gate logs |
| `nexus_scan_playtest` | `./build-headless/nexus_scan_envelope_test` (scan envelope smoke) |
| `build_gate` | Whitelisted `./scripts/nexus_build_gate.sh` or validate script; logs to `artifacts/cursor-nexus/last-build-gate.log` |
| `agent_command` | Route whitelisted sub-tools (`read_file`, `open_ide_file`, nested `list_modes`, etc.) |
| `read_state` | Delivery matrix summary, build log tail, ctest logs, last playtest artifact |

See also: `docs/NEXUS_CURSOR_BRIDGE.md` for the shared iOS + Cursor protocol.

## Security

- **No arbitrary shell.** Only these paths may execute:
  - `scripts/nexus_build_gate.sh`
  - `scripts/nexus_playtest.sh`
  - `scripts/bench_nexus_runtime.sh`
  - `scripts/nexus_validate_production_modes.sh`
  - `build-headless/nexus_agent_cli` (or `NEXUS_BUILD_DIR`)
  - `build-headless/nexus_scan_envelope_test` (or `NEXUS_BUILD_DIR`)
  - `build-full/nexus_runtime` (only via playtest scripts)
- Agent commands must use whitelisted prefixes: `terrain.`, `fel.`, `fitness.`, `world.`, `entity.`
- Artifacts: `artifacts/playtest/latest.json` (primary), mirror at `artifacts/cursor-nexus/last-playtest.json`, HUD mirror at `artifacts/cursor-nexus/last-hud-snapshot.json` (copied from `dev_stats_tick.json` after playtest)

## Example Cursor prompts

### Ship readiness

> Use the nexus MCP: `read_state`, then run `build_gate` if the last gate log is stale. Summarize NEXUS_DELIVERY_MATRIX blockers.

### Sprint playtest (P0 dunk)

> Call `playtest` with `mode_id` `basketball_dunk`. If tris exceed budget, point me to the manifest mesh path from the JSON stats.

### Cross-host read

> Call `agent_command` with `tool=read_file` and `arguments={"path":"NEXUS_ONLY_PIVOT.md"}`.

### Mode inventory

> List production-tier modes with `list_modes`, then validate-only each flagship sim via `playtest`.

### Timed bench

> Run `playtest` with `mode_id` `karate_endless`, `kind` `bench`, `duration_sec` 15. Report exit code and stderr highlights.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| MCP server not listed | `npm run build` in `tools/nexus-cursor-mcp`; check `~/.cursor/mcp.json` paths |
| `nexus_agent_cli not built` | `cmake --build build-headless --target nexus_agent_cli` |
| `nexus_runtime missing` | Build `build-full` with `NEXUS_BUILD_RUNTIME=ON` |
| Build gate timeout | Pass `timeout_minutes: 90` to `build_gate` |
| Playtest venue error | Pass explicit `venue` or check `docs/NEXUS_MODES_CAPABILITY.md` |
| `nexus_scan_envelope_test missing` | `cmake --build build-headless --target nexus_scan_envelope_test` |

## Related docs

- `docs/NEXUS_CURSOR_BRIDGE.md` — shared registry with iOS NEXUS Agent
- `docs/NEXUS_SCAN_TO_GENERATION.md` — scan envelope schema + `nexus_scan_envelope_test`
- `docs/NEXUS_PLAYTEST_FOR_CURSOR.md` — playtest pipeline + `latest.json` schema
- `docs/NEXUS_AGENT_TOOLS.md` — in-app agent sandbox (same whitelist philosophy)
- `NEXUS_DELIVERY_MATRIX.md` — ship matrix read by `read_state`
- `docs/NEXUS_MODES_CAPABILITY.md` — mode depth tiers for `list_modes`
