# NEXUS Gameplay Test Report

**Date:** 2026-07-02 (cloud app/game quality pass)  
**Repo:** `/workspace`  
**Role:** Senior Gameplay Tester + Senior Error Editor — ship-quality verification gate  
**Artifacts:** `artifacts/playtest/gameplay_regression.json`, `artifacts/playtest/latest.json`

---

## Executive summary

| Gate | Result |
|------|--------|
| `./scripts/nexus_headless_gate.sh` | **PASS** — registry/descriptor/smoke/cooked validations + headless 11/11 ctest + `nexus_gameplay_test` |
| `./scripts/nexus_mobile_mesh_gate.sh` | **PASS** — renderer test + strict mobile sidecar validation (requires Vulkan + SDL3) |
| `./scripts/nexus_build_gate.sh` | **PASS** — full renderer/production validation when renderer dependencies are installed |
| `./scripts/smoke_v1.sh --skip-build` | **PASS** — ctest + dunk/karate validate-only + `nexus_gameplay_test` |
| `./scripts/nexus_playtest.sh --duration 0 --skip-build` | **PASS** — validate + gameplay smoke artifact |
| `./scripts/nexus_validate_production_modes.sh` | **PASS** — 18/18 C++ runtime production modes |
| `./scripts/nexus_gameplay_regression.sh` | **PASS** — 11/11 headless ctest + integration suite → `gameplay_regression.json` |
| `./scripts/build-nexus-ios.sh` | **PASS** (with `DEVELOPER_DIR` / Xcode toolchain) — `NexusPrebuilt/libnexus_*.a` refreshed |
| `xcodebuild` iOS Simulator (iPhone 17, Debug) | **PASS** — `** BUILD SUCCEEDED **` after DerivedData lock retry |

**Sprint LIVE modes (10):** all covered in `tests/unit/gameplay/gameplay_test.cpp` via per-mode flagship integrations + consolidated `nexus_sprint_live_modes_agent_contract_integration()` (agent router, nested JSON contracts, safe `.value()` access). Registry validation covers 20 production entries / 19 launchable backend modes; iOS runtime launch validation covers the 10 Swift sprint modes against 18 C++ runtime production modes.

---

## Error-editor fixes (2026-06-19)

| ID | Fix | Tests |
|----|-----|-------|
| EE-1 | `applyFitnessScalar` helper — full `fel.fitness.update` no longer calls `.value()` on failed validation | existing `fitness_update_rejects_non_finite_values` |
| EE-2 | Snowboarding `jump`/`butter`/`wipeout` payloads use object-first `merge_patch` (parity with `carve`; prevents `json.exception.type_error.305`) | `snowboarding_action_payloads_are_objects` |
| EE-3 | `fel.snow.*` / `fel.scene.*` reject null/array params with error envelopes (no abort) | `mode_runtime_rejects_non_object_snow_and_scene_params` |
| EE-4 | `voxel_command_parser` copies painted result before mutation (no in-place `.value()` side effect) | existing creative parser tests |
| EE-5 | Swift `TrainingLabSocialBridgeError` + `ScanToGenerationBridge` honest PREVIEW labels | `GameLogicTests.trainingLabSocialBridgeErrorsAreHonest` |
| EE-6 | `handleGameplayCommand` + `CommandRouter` coerce null/malformed params (no `.find()` on JSON null) | `mode_runtime_rejects_non_object_snow_and_scene_params` |

**Note:** `docs/NEXUS_DEBUG_RUNBOOK.md` not present yet (Senior Debugging Agent deliverable).

---

## P0 — ship blockers

| ID | Issue | Status | Notes |
|----|-------|--------|-------|
| P0-1 | `nexus_gameplay_test` abort on `snowboarding` session (`json.exception.type_error.305`) | **FIXED** | `snowboarding_mode.cpp` returns object payloads via `merge_patch(stateJson())`; rebuild required stale `build-headless` binary |
| P0-2 | iOS Simulator compile (`sprintPriorityBadge` scope) | **FIXED** (prior pass) | `xcodebuild` Debug @ iPhone 17 succeeds 2026-06-19 |
| P0-3 | Signed TestFlight / archive artifact | **OPEN** | `archive-ios-testflight.sh` not executed this pass |

---

## P1 — regression / quality gaps

| ID | Issue | Impact |
|----|-------|--------|
| P1-1 | `nexus_playtest.sh` treats gameplay_test as pass when dunk lifecycle log line present even if process aborts later | Masks suite failures (observed during snowboarding crash before fix) |
| P1-2 | `build-nexus-ios.sh` fails without Xcode `DEVELOPER_DIR` (`CMAKE_CXX_COMPILER not set`) | CI/agents must export toolchain or run from Xcode shell |
| P1-3 | Parallel `xcodebuild` → DerivedData `build.db` locked | Retry required; consider `-derivedDataPath` isolation in CI |
| P1-4 | Live Firebase session POST (production JWT) | Disk queue + HTTP stub only; label preview until live POST verified |
| P1-5 | Metal PBR venue embed default off | SceneKit shell still primary play surface |

---

## P2 — polish / coverage

| ID | Issue |
|----|-------|
| P2-1 | `nexus_renderer_test` ~62–67s — dominates gate wall time |
| P2-2 | Device 60 FPS / Instruments proof not captured this pass |
| P2-3 | Production modes beyond sprint LIVE (baseball, soccer, …) have validate-only mesh gates but no flagship gameplay integration tests |
| P2-4 | PRQ engine still sprint stub (75, Primed) — not HealthKit-backed |

---

## Sprint LIVE mode matrix (integration)

| Mode ID | Agent command probed | Nested `mode_state` key | Flagship test |
|---------|---------------------|-------------------------|---------------|
| `basketball_dunk` | `fel.dunk.charge_begin` | `dunk` | ✓ |
| `karate_endless` | `fel.karate.action` | `karate` | ✓ |
| `basketball_h2h` | `fel.fitness.update` | `pickup` | ✓ |
| `court_carnival` | `fel.carnival.trigger_pad` | `carnival` | ✓ |
| `gymnastics` | `fel.gymnastics.tap` | `gymnastics` | ✓ |
| `brain_brawl` | `fel.brain.answer` | `brain_brawl` | ✓ |
| `skateboarding` | `fel.skate.trick` | `skateboarding` | ✓ |
| `snowboarding` | `fel.snow.carve` | `snowboarding` | ✓ |
| `surfing` | `fel.surf.pump` | `surfing` | ✓ |
| `who_scene_it` | `fel.scene.buzz_in` | `who_scene_it` | ✓ |

Consolidated agent contract: `nexus_sprint_live_modes_agent_contract_integration()` — exercises all ten via `AgentServer` + `CommandRouter`, asserts `agent_envelope.command` where emitted, validates HUD `payload.mode_state.{mode}` without unchecked `.get()` on missing keys.

---

## Commands (reproduce)

```bash
cd ~/Final-Evolution-Lab
./scripts/nexus_headless_gate.sh
./scripts/nexus_build_gate.sh
./scripts/smoke_v1.sh --skip-build
./scripts/nexus_playtest.sh --duration 0 --skip-build
./scripts/nexus_validate_production_modes.sh
./scripts/nexus_gameplay_regression.sh --skip-build
export DEVELOPER_DIR="$(xcode-select -p)"
./scripts/build-nexus-ios.sh
xcodebuild -project FinalEvolutionLab.xcodeproj -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 17' -configuration Debug build
```

---

## Related docs

- `NEXUS_DELIVERY_MATRIX.md` — phase/gap audit  
- `docs/NEXUS_GAMEPLAY_UX_BAR.md` — UX acceptance bar  
- `artifacts/playtest/gameplay_regression.json` — machine-readable regression snapshot
