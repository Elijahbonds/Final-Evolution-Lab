# NEXUS Debug Runbook

**Repo:** `~/Final-Evolution-Lab`  
**Purpose:** Reproduce failures, find logs, apply known fixes.

---

## Quick gates (run in order)

```bash
cd ~/Final-Evolution-Lab

# 1. Engine matrix (headless + GPU + 18 production mode validates)
./scripts/nexus_build_gate.sh

# 2. Gameplay regression artifact
./scripts/nexus_gameplay_regression.sh --skip-build

# 3. Agent playtest snapshot
./scripts/nexus_playtest.sh --duration 0 --skip-build

# 4. iOS static libs + Simulator compile
export DEVELOPER_DIR="$(xcode-select -p)"
./scripts/build-nexus-ios.sh
xcodebuild -project FinalEvolutionLab.xcodeproj -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

Skip production mode validate during engine iteration:

```bash
NEXUS_SKIP_PRODUCTION_MODE_VALIDATE=1 ./scripts/nexus_build_gate.sh
```

---

## Log and artifact paths

| Artifact | Path | When written |
|----------|------|--------------|
| Build gate (terminal) | stdout / `/tmp/nexus_build_gate.log` | `./scripts/nexus_build_gate.sh` |
| ctest headless | `build-headless/Testing/Temporary/LastTest.log` | ctest |
| ctest headless failures | `build-headless/Testing/Temporary/LastTestsFailed.log` | failed ctest |
| ctest full renderer | `build-full/Testing/Temporary/LastTest.log` | ctest |
| ctest full failures | `build-full/Testing/Temporary/LastTestsFailed.log` | failed ctest |
| Playtest snapshot | `artifacts/playtest/latest.json` | `nexus_playtest.sh` |
| Playtest validate | `artifacts/playtest/validate.log` | validate-only phase |
| Playtest gameplay | `artifacts/playtest/gameplay_test.log` | headless gameplay smoke |
| Playtest runtime | `artifacts/playtest/runtime.log` | SDL/Vulkan window phase |
| Playtest tick export | `artifacts/playtest/dev_stats_tick.json` | runtime window w/ export |
| Gameplay regression | `artifacts/playtest/gameplay_regression.json` | `nexus_gameplay_regression.sh` |
| Gameplay regression log | `artifacts/playtest/gameplay_regression_run.log` | integration suite stdout |
| xcodebuild | `/tmp/xcodebuild_nexus.log` (if tee'd) | iOS compile |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData/FinalEvolutionLab-*` | Xcode builds |
| Session receipt pickup | `~/.fel/pending_receipts/*.json` | gameplay session POST queue |

---

## Debug environment flags

### Engine / playtest

| Flag | Values | Effect |
|------|--------|--------|
| `NEXUS_PLAYTEST_EXPORT` | `1` / `true` | Write per-tick JSON snapshot from `nexus_runtime` |
| `NEXUS_PLAYTEST_EXPORT_PATH` | file path | Override export path (default `artifacts/playtest/dev_stats_tick.json`) |
| `NEXUS_PLAYTEST_MODE` | mode id | Default arena mode for playtest/runtime |
| `NEXUS_PLAYTEST_VENUE` | venue token | Default venue hint |
| `NEXUS_PLAYTEST_DURATION` | seconds | Runtime window length in `nexus_playtest.sh` |
| `NEXUS_MESH_PROFILE` | `mobile` / `desktop` | Mesh sidecar profile (default `mobile`) |
| `NEXUS_DEV_STATS` | `0` / `1` | Frame stats logging (`dev_stats` lines) |
| `NEXUS_DEV_DRAW_STATS` | `0` / `1` | Draw-call detail logging |
| `NEXUS_DEV_HUD` | `1` | Overlay HUD log lines |
| `NEXUS_SKIP_PRODUCTION_MODE_VALIDATE` | `1` | Skip Phase 1b in build gate |
| `NEXUS_LOG_VERBOSE` | `1` / `true` | Reserved for extended engine logging |

**Playtest export example:**

```bash
export NEXUS_PLAYTEST_EXPORT=1
export NEXUS_PLAYTEST_EXPORT_PATH=artifacts/playtest/dev_stats_tick.json
./build-full/nexus_runtime --mode basketball_dunk --venue venice_beach
# Agent commands on stdin; last tick written to export path on shutdown
```

### Agent CLI (`build-headless/nexus_agent_cli`)

| Flag / env | Effect |
|------------|--------|
| `--verbose` / `-v` | Echo stdin lines; sets `NEXUS_LOG_VERBOSE=1` |
| `--serve-http` | HTTP listener on `127.0.0.1:8765/nexus/agent` |
| `--json '{...}'` | Batch mode (single object or `messages` array) |
| `--port N` | HTTP port (default 8765) |

```bash
./build-headless/nexus_agent_cli --verbose --json \
  '{"type":"command","id":"1","payload":{"command":"fel.dunk.charge_begin","params":{}}}'
```

### iOS / Xcode

| Flag / env | Effect |
|------------|--------|
| `DEVELOPER_DIR` | Required for `./scripts/build-nexus-ios.sh` outside Xcode |
| `PLATFORM_NAME` | `iphonesimulator` or `iphoneos` — selects prebuilt subdir |
| `-derivedDataPath /tmp/fel-dd` | Avoid DerivedData lock when parallel xcodebuild |

Prebuilt layout (after fix):

```
NexusPrebuilt/iphonesimulator/libnexus_*.a   # Simulator Debug/Run
NexusPrebuilt/iphoneos/libnexus_*.a        # Device Archive / TestFlight
```

---

## Common failures and fixes

### 1. `ld: building for 'iOS-simulator', but linking ... built for 'iOS'`

**Cause:** `NexusPrebuilt` static libs compiled for device (`iphoneos`) while Xcode targets Simulator.

**Fix:**

```bash
export DEVELOPER_DIR="$(xcode-select -p)"
PLATFORM_NAME=iphonesimulator ./scripts/build-nexus-ios.sh
# Rebuild Xcode — script stages NexusPrebuilt/iphonesimulator/
```

For device archive:

```bash
PLATFORM_NAME=iphoneos ./scripts/build-nexus-ios.sh
```

### 2. `nexus_gameplay_test` — `json.exception.type_error.305`

**Cause:** Mode handler returned JSON `null` where object expected (e.g. snowboarding `stateJson()`).

**Fix:** Ensure mode uses `merge_patch` with object payloads; rebuild headless binary:

```bash
cmake --build build-headless --target nexus_gameplay_test
ctest --test-dir build-headless -R nexus_gameplay_test --output-on-failure
```

Stale binary symptom: `LastTestsFailed.log` lists test but manual rerun passes after rebuild.

### 2b. `nexus_gameplay_test` — `mode inferred for volleyball` (or other sport)

**Cause:** Stale `build-headless/nexus_gameplay_test` linked before `kModeKeywordRules` included the sport, or the catch-all `basketball_dunk` rule matched bare `"court"` in prompts like `sand court` / `hard court`.

**Fix:** Reconfigure + rebuild gameplay test; ensure catch-all uses `"basketball court"` not bare `"court"`:

```bash
cmake -S . -B build-headless -DNEXUS_ENABLE_RENDERER=OFF -DNEXUS_BUILD_RUNTIME=OFF -DNEXUS_BUILD_TESTS=ON
cmake --build build-headless --target nexus_gameplay_test
./build-headless/nexus_gameplay_test 2>&1 | grep '^FAIL:'
```

### 2c. `nexus_gameplay_test` — `Undefined symbols: sanitizeLlmJsonText`

**Cause:** Static link order — `libnexus_ai_interface.a` references `nexus::ai::*` helpers implemented in `libnexus_gameplay.a`; incremental relink without `-force_load` drops gameplay symbols.

**Fix:** Re-run `cmake -S . -B build-headless` (CMakeLists already sets `LINKER:-force_load` for `nexus_gameplay_test` on Apple). Then rebuild target.

### 3. `CMAKE_CXX_COMPILER not set` (iOS cross-compile)

**Cause:** `build-nexus-ios.sh` run without Xcode toolchain.

**Fix:**

```bash
export DEVELOPER_DIR="$(xcode-select -p)"
./scripts/build-nexus-ios.sh
```

### 4. xcodebuild — device not found (`iPhone 16`)

**Cause:** Simulator name mismatch (Xcode 26 ships iPhone 17 family).

**Fix:** List simulators and pick an available name:

```bash
xcodebuild -project FinalEvolutionLab.xcodeproj -scheme FinalEvolutionLab -showdestinations
xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 5. DerivedData `build.db` locked

**Cause:** Parallel `xcodebuild` on same DerivedData path.

**Fix:**

```bash
xcodebuild ... -derivedDataPath /tmp/fel-xcodebuild-$$ build
# Or wait / kill other xcodebuild
```

### 6. `nexus_renderer_test` slow (~65s)

**Not a failure** — dominates gate wall time. Run single test while iterating:

```bash
ctest --test-dir build-full -R nexus_renderer_test --output-on-failure
```

### 7. Playtest passes but ctest fails

**Cause:** Previously `nexus_playtest.sh` treated partial dunk log as pass. Now requires `nexus_gameplay_test` exit code 0.

**Fix:** Run full regression:

```bash
./scripts/nexus_gameplay_regression.sh --skip-build
grep '^FAIL:' artifacts/playtest/gameplay_regression_run.log
```

### 8. Missing venue mesh / validate-only fail

**Fix:**

```bash
./build-full/nexus_runtime --validate-only --mode basketball_dunk --venue venice_beach
cat artifacts/playtest/validate.log
# Regenerate meshes: ./scripts/nexus_import_assets.py (see NEXUS_SCAN_TO_GENERATION.md)
```

---

## Minimal repro cheatsheet

| Symptom | Minimal repro |
|---------|----------------|
| Gameplay JSON crash | `./build-headless/nexus_gameplay_test` |
| Renderer regression | `ctest --test-dir build-full -R nexus_renderer_test -V` |
| iOS link mismatch | `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 \| tail -20` |
| Agent dispatch | `./build-headless/nexus_agent_cli --verbose --json '{"type":"query","id":"q1","payload":{"query":"fel.query.get_mode_state"}}'` |
| Mesh budget | `./build-full/nexus_runtime --validate-only --mode who_scene_it` |

---

## Open P0 (ship blockers)

| ID | Issue | Status |
|----|-------|--------|
| P0-3 | Signed TestFlight / archive artifact | **OPEN** — run `./scripts/archive-ios-testflight.sh` with signing profile |

Fixed this pass:

| ID | Issue | Fix |
|----|-------|-----|
| P0-4 | iOS Simulator link — device prebuilts staged for Simulator | Platform-specific `NexusPrebuilt/{iphonesimulator,iphoneos}/` + SDK verification in `build-nexus-ios.sh` |
| P1-1 | Playtest masked gameplay_test abort | Require exit code 0 in `nexus_playtest.sh` |

---

## Related docs

- `docs/NEXUS_GAMEPLAY_TEST_REPORT.md` — latest gate matrix
- `docs/NEXUS_PLAYTEST_FOR_CURSOR.md` — playtest schema for agents
- `NEXUS_DELIVERY_MATRIX.md` — phase audit
- `AGENTS.md` — repo sub-projects and CI commands
