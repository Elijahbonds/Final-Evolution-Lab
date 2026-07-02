# NEXUS Playtest for Cursor Agents

Cursor agents need **machine-readable environment visibility** (venue mesh, FPS, triangle budget, mode state, agent responses) without opening Xcode or a game window manually. This doc describes the playtest pipeline in the canonical NEXUS repo.

**Repo:** `~/Final-Evolution-Lab`  
**Entry script:** `./scripts/nexus_playtest.sh`  
**Primary artifact:** `artifacts/playtest/latest.json`

## Quick start

```bash
cd ~/Final-Evolution-Lab

# Full playtest (build + validate + gameplay + 5s runtime window)
./scripts/nexus_playtest.sh

# Fast CI path — no GPU window (validate + headless gameplay only)
./scripts/nexus_playtest.sh --duration 0 --skip-build

# Karate mode, 8s runtime
./scripts/nexus_playtest.sh --mode karate_endless --venue neuro_arena --duration 8
```

Human + machine summary:

```bash
./scripts/nexus_playtest_report.sh
./scripts/nexus_playtest_report.sh --json   # stdout JSON for agents
```

## What each phase does

| Phase | Binary | Purpose |
| --- | --- | --- |
| **validate-only** | `build-full/nexus_runtime --validate-only` | Loads venue mesh from manifest; reports verts/tris/profile (same gate as `smoke_v1.sh`) |
| **gameplay_test** | `build-headless/nexus_gameplay_test` | Headless dunk lifecycle + receipt queue (same as `smoke_gameplay_session.sh`) |
| **runtime window** | `build-full/nexus_runtime` | SDL/Vulkan preview; agent stdin commands; `NEXUS_PLAYTEST_EXPORT=1` tick JSON |

Patterns align with:

- `./scripts/smoke_v1.sh` — validate-only + gameplay_test
- `./scripts/bench_nexus_runtime.sh` — timed runtime window
- `./scripts/smoke_gameplay_session.sh` — headless `nexus_gameplay_test`

## Engine export (`NEXUS_PLAYTEST_EXPORT=1`)

When the runtime window runs, the engine tick writes the latest frame snapshot to:

`artifacts/playtest/dev_stats_tick.json` (override with `NEXUS_PLAYTEST_EXPORT_PATH`)

Each tick includes:

- `dev_stats`: `fps`, `frame_time_ms`, `visible_draws`, `culled_draws`, `triangle_count`, `within_draw_budget`
- `agent_responses`: serialized responses from stdin/TCP agent messages processed that frame
- `mode_id` / `venue_id` from `NEXUS_PLAYTEST_MODE` / `NEXUS_PLAYTEST_VENUE`

Implementation: `engine/core/src/dev_stats.cpp` (`exportPlaytestTickSnapshot`) called from `Engine::tick()`.

## `latest.json` schema (agents read this)

```json
{
  "schema_version": "1",
  "generated_at": "ISO-8601",
  "overall_status": "pass|fail",
  "playtest": { "mode", "venue", "duration_sec", "build_dir", "mesh_profile" },
  "environment": { "validate_status", "venue_key", "mesh_path", "triangle_count", ... },
  "runtime": { "status", "fps_last", "visible_draws", "triangle_count", ... },
  "gameplay_test": { "status" },
  "mode_state": { ... },
  "agent_responses": [ ... ],
  "artifacts": { "latest_json", "dev_stats_tick", "validate_log", ... }
}
```

Committed template (not live output): `artifacts/playtest/latest.json.template`  
Runtime `*.json` outputs are gitignored; only `.gitkeep` + template are tracked.

## Agent TCP / stdin commands (runtime window)

`nexus_playtest.sh` feeds these JSON lines on stdin after a 2s startup delay:

```json
{"type":"command","id":"pt1","payload":{"command":"fel.arena.start_session","params":{"mode_id":"basketball_dunk","user_id":"playtest"}}}
{"type":"command","id":"pt2","payload":{"command":"fel.dunk.charge_begin","params":{}}}
{"type":"command","id":"pt3","payload":{"command":"fel.dunk.charge_release","params":{"power":0.85}}}
{"type":"command","id":"pt4","payload":{"command":"fel.dunk.apex_tap","params":{}}}
{"type":"query","id":"pt5","payload":{"query":"fel.query.get_mode_state"}}
{"type":"query","id":"pt6","payload":{"query":"fel.query.get_session_state"}}
```

Manual QA (same as `smoke_v1.sh` footer): start runtime, then `nc localhost 9090` or paste into stdin.

## iOS Swift shell playtest (simulator)

For the **product UI shell** (not headless C++ runtime), use Simulator launch + log stream so Cursor can read HUD/session lines.

### One-time build

```bash
./scripts/build-nexus-ios.sh
xcodebuild \
  -project FinalEvolutionLab.xcodeproj \
  -scheme FinalEvolutionLab \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

### Boot simulator + install (if needed)

```bash
DEVICE="iPhone 17 Pro"
xcrun simctl boot "${DEVICE}" 2>/dev/null || true
open -a Simulator

# Install built .app (path varies by DerivedData; example):
# xcrun simctl install booted build/DerivedData-smoke/Build/Products/Debug-iphonesimulator/FinalEvolutionLab.app
```

### Launch + log stream (Cursor reads stdout)

```bash
BUNDLE_ID="com.finalevolutionlab.app"
xcrun simctl launch --console booted "${BUNDLE_ID}" 2>&1 | tee artifacts/playtest/ios_sim.log
```

Background log stream (subsystem / process filter):

```bash
xcrun simctl spawn booted log stream \
  --predicate 'process == "FinalEvolutionLab"' \
  --style compact 2>&1 | tee artifacts/playtest/ios_logstream.log
```

Look for NEXUS bridge lines: session start, `mode_state`, HUD poll, receipt queue.

### Environment for agent tab (optional)

```bash
export NEXUS_REPO_ROOT="$HOME/Final-Evolution-Lab"
export NEXUS_AGENT_GEMINI_KEY="..."   # optional Gemini planner
```

See `docs/NEXUS_AGENT_TOOLS.md` for in-app agent tools (`launch_mode`, `run_build_gate`, etc.).

## Cursor agent workflow

1. Run `./scripts/nexus_playtest.sh --duration 0 --skip-build` for a fast gate (no window).
2. Read `artifacts/playtest/latest.json` (or `./scripts/nexus_playtest_report.sh --json`).
3. If venue/tris fail → inspect `artifacts/playtest/validate.log`.
4. If gameplay fails → inspect `artifacts/playtest/gameplay_test.log`.
5. For visual/runtime regressions → rerun with `--duration 8` and read `dev_stats_tick.json`.
6. For Swift UI → simctl launch + log stream above; cross-check `mode_state` in `latest.json` vs iOS logs.

## Related scripts

| Script | Role |
| --- | --- |
| `scripts/nexus_playtest.sh` | Orchestrates playtest phases; writes `latest.json` |
| `scripts/nexus_playtest_report.sh` | Human + `artifacts/playtest/report.json` summary |
| `scripts/smoke_v1.sh` | Integration smoke (ctest + validate + gameplay_test) |
| `scripts/smoke_gameplay_session.sh` | Headless receipt smoke |
| `scripts/bench_nexus_runtime.sh` | Timed runtime bench stub |
