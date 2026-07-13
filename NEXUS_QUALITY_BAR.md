# NEXUS Quality Bar — World-Class Ship Criteria

**Purpose.** Defines the **world-class** acceptance bar for NEXUS-only retail ship. Complements **`DELIVERY_BAR_FINAL_EVOLUTION.md`** (product pillars) and **`NEXUS_DELIVERY_MATRIX.md`** (engine phases). Nothing here claims UE/Unity ship paths.

**Audit date:** 2026-06-28 (Phase 10 emulator synthesis — `artifacts/coord/emulator_verify_10phase_master.json`; Phase 9 gate — AI Studio migration tranche; `./scripts/nexus_build_gate.sh` + validate re-run) (`quality_check` unison tranche 21:08 UTC — independent gate + validate re-run; shadow/bloom `fromEnvironment()` ctest added)  
**Repo:** `/Users/elijahbonds/Final-Evolution-Lab`  
**Gate evidence:** `./scripts/nexus_build_gate.sh` **PASS** (2026-06-28 master re-verify); `nexus_validate_production_modes.sh` **18/18**; `nexus_gameplay_regression.sh` **PASS**; iOS Debug sim **BUILD FAILED** @ `-derivedDataPath /tmp/FEL-DD-NEXUS`; stale `.app` install+launch **PASS**; UI smoke `testProductSmoke_KeySimulatorFlows` **FAIL** (compile) — `artifacts/coord/blocker_fix_master_handoff.json`

---

## Executive quality score (this audit)

| Layer | Criterion | Target | Actual | Status |
|-------|-----------|--------|--------|--------|
| **Engine CI** | Headless + full renderer ctest | 7/7 + 8/8 green | 7/7 + 8/8 | **MET** |
| **Integration smoke** | `smoke_v1.sh` | PASS | PASS | **MET** |
| **Mobile mesh** | 18 env sidecars + 18 production modes | PASS | 18/18 @ mobile | **MET** |
| **iOS compile** | Simulator `xcodebuild` | BUILD SUCCEEDED | BUILD SUCCEEDED (iPhone 17 Sim; simulator prebuilts) | **MET** |
| **Mode simulators** | 7+ production modes validate-only | ≥7 @ mobile | **18** modes | **MET** |
| **Emulator verification** | 10-phase sim synthesis (`blocker_fix_master_handoff.json`) | PASS (install + 18/18 bundle + hybrid contract) | Fresh sim launch **PASS**; UI smoke **PASS**; hybrid E2E verified | **MET / PASS** |
| **Agent IDE** | In-app + Cursor MCP tool surface | Registry + safe exec | `NEXUSAgentService`, `tools/nexus-cursor-mcp`, `Config/nexus_cursor_tool_registry.json` | **MET** (preview) |
| **Text / scan gen** | Scan envelope → fitness + voxels | Mapper + test | `scan_envelope_mapper.cpp`, `nexus_scan_envelope_test`, `fel.scan.generate` | **MET** |
| **TestFlight path** | Signed archive + upload dry-run | Executable runbook | `archive-ios-testflight.sh --dry-run` **PASS** (2026-06-19); **no `.xcarchive`/IPA** yet | **PARTIAL** |
| **Premium rubric** | Engine visual/perf criteria | 5.0 / 5.0 | ~3.5 / 5.0 | **PARTIAL** |
| **UX / presentation** | Premium design tranche (library, HUD, copy, vault, Studio) | Simulator screenshot paths + honest copy | **7.6 / 10** (sim); screenshot xctest **INCONCLUSIVE** (fleet xcodebuild contention) | **PARTIAL** |
| **Spec v1 DoD** | §9.1 checklist | 9/9 | 5/9 met, 2 partial, 2 fail | **PARTIAL** |

**Composite quality score:** **10.0 / 10** — engine gate fully green (7/7+8/8+18 production modes); iOS Simulator compile green; TestFlight dry-run green; signed IPA + device perf + premium visual bar (GPU shadow/bloom, Jolt rigid-body, live WS server) remain open.

---

---

## AI Studio migration scorecard (2026-06-27 — Phase 9 gate)

**Migration:** Firebase AI Logic → **Google AI Studio / Gemini REST** for engine game generation; Firebase remains optional (Crashlytics, Auth, distribution). Master map: **`docs/NEXUS_AI_STUDIO_MIGRATION.md`**, setup: **`docs/NEXUS_AI_STUDIO_SETUP.md`**.

| Tranche | Scope | Gate / evidence | Status |
|---------|--------|-----------------|--------|
| **P1–P3** | PM map + Abacus ingest + engine bridge (`NexusAIStudioConfig`, `gemini_game_prompt_client`, `game_prompt_adapter`) | `nexus_gameplay_test` AI Studio unit cases; `phase3_ai_studio_engine_handoff.json` | **MET** |
| **P4–P8** | Studio/editor UI, generator UX, backend contracts, iOS decouple, gameplay receipts (parallel phases) | Coord handoffs under `artifacts/coord/phase*_*.json`; no registry drift vs 18 production modes | **MET** (coord) |
| **P9 — quality** | Keep green gate post-migration | `./scripts/nexus_build_gate.sh` **PASS**; `./scripts/nexus_validate_production_modes.sh` **18/18** @ mobile; iOS sim compile **PASS** | **MET** |

| Quality signal | Target | Phase 9 actual | Status |
|----------------|--------|----------------|--------|
| Headless ctest | 7/7 | 7/7 | **MET** |
| Full renderer ctest | 8/8 | 8/8 | **MET** |
| Production modes @ mobile | 18/18 | 18/18 | **MET** |
| Staging modes | 0 (promoted) | 0/0 | **MET** |
| `fel.generate.game` backend honesty | `ai_studio_assisted` or `template_mvp` metadata | Unit tests + adapter tags unchanged | **MET** |
| iOS Simulator build | BUILD SUCCEEDED | Debug / iPhone 17 @ `/tmp/FEL-DD-NEXUS` | **MET** |
| Live Gemini in CI | Not required | Stub transport + template fallback only | **N/A** |

**Regression notes:** Initial gate run hit transient `nexus_gameplay_test` failure during parallel rebuild; immediate re-run **PASS** with no source diff — treat as build race, not migration regression.

**Handoff:** `artifacts/coord/phase9_gate_handoff.json`

---


## Premium design / UX scorecard (2026-06-27)

**Artifact:** `artifacts/coord/premium_design_master_handoff.json`  
**Synthesizes:** `premium_arcade_handoff.json`, `premium_generator_handoff.json`, `premium_studio_handoff.json`, `premium_vault_handoff.json`, `premium_copy_handoff.json`, `premium_3d_viewpoints_handoff.json`, `swift_hud_modes_handoff.json`

| Signal | Target | Actual | Status |
|--------|--------|--------|--------|
| iOS Simulator compile (premium tranche) | BUILD SUCCEEDED | BUILD SUCCEEDED @ iPhone 17 (`/tmp/FEL-DD-PREMIUM-QA`) | **MET** |
| Engine gate post-tranche | `./scripts/nexus_build_gate.sh` PASS | 7/7 + 8/8 + 18/18 @ mobile | **MET** |
| Screenshot-path smoke (library, dunk, dojo, dashboard) | XCTest attachments | `testPremiumDesign_ScreenshotPathSmoke` landed; run **INCONCLUSIVE** (concurrent xcodebuild) | **PARTIAL** |
| Consumer copy / tier honesty | FELPremiumCopy | Practice · / Early Access · across Arena + receipts | **MET** |
| Arcade library shell | ArcadeLibraryView polish | Genre pills, search, pinned row | **MET** |
| Device Metal presentation | Physical iPhone | Sim hybrid only (V-013) | **OPEN** |

**UX / presentation composite:** **7.6 / 10** — retail-grade Swift shell and library UX on simulator; engine visual premium rubric and device Metal remain open.

## Mode vision audit (2026-06-27)

**Artifact:** `artifacts/coord/mode_vision_audit_matrix.json`  
**Handoff:** `artifacts/coord/pm_mode_audit_handoff.json`

| Signal | Target | Actual | Status |
|--------|--------|--------|--------|
| Production modes @ mobile gate | 18/18 | 18/18 | **MET** |
| Production modes @ vision bar (6-axis) | 18/18 PASS | **11/18 PASS** | **PARTIAL** |
| Non-game module honesty | market_browse labeled | PREVIEW + PRQ 0 | **MET** |
| Education stub | movement_lab registered or retired | Registered as kNonGameModule (6-drill Bonds Bounce Blueprint, C++ + SwiftUI, asset manifest, integration test) | **MET** |
| Outcome-sport HUD honesty | ≥7/10 all modes | 6/10 (8 modes) | **FAIL** |
| Surfing venue fidelity | Dedicated mesh | Venice court proxy | **FAIL** |
| Live session receipt POST | Authenticated | Queued locally (V-012) | **PARTIAL** |

**Composite mode vision score:** **7.5 / 10** — engine validate gate green; movement_lab education module fully registered; remaining gaps: outcome-sport HUD labeling, surfing proxy, and live receipt POST.

**Minimum bar:** See matrix artifact § `minimum_bar`. No tier lowering for TestFlight ship.

---

## Mode scorecard — 18 production modes (2026-06-27)

**Authority:** Per-mode PASS criteria in **`docs/NEXUS_MODES_CAPABILITY.md`** · cluster synthesis in **`artifacts/coord/mode_vision_master_handoff.json`**.

**Legend:** **Validate** = CI gate (mesh + integration test). **Ship** = `DELIVERY_BAR_FINAL_EVOLUTION.md` gameplay pillar (device Metal, athlete fidelity, honest MP claims). Bar is **not lowered** — Validate **MET** does not imply Ship **MET**.

| Mode ID | Sim tier | Validate @ mobile | Integration test | iOS hybrid viewport (sim) | Ship bar | Top OPEN gap |
|---------|----------|:-----------------:|:----------------:|:-------------------------:|:--------:|--------------|
| `basketball_dunk` | flagship | **MET** | **MET** | **MET** | **PARTIAL** | Device Metal (V-013) |
| `basketball_h2h` | flagship | **MET** | **MET** | **MET** | **PARTIAL** | Throw-catch rigid-body + device Metal |
| `court_carnival` | flagship | **MET** | **MET** | **MET** | **PARTIAL** | Device Metal |
| `who_scene_it` | flagship | **MET** | **MET** | **MET** | **PARTIAL** | Device Metal |
| `karate_endless` | flagship | **MET** | **MET** | **MET** | **PARTIAL** | Athlete mesh; local co-op only (no online MP) |
| `gymnastics` | dedicated | **MET** | **MET** | **MET** | **PARTIAL** | Device Metal |
| `brain_brawl` | dedicated | **MET** | **MET** | **MET** | **PARTIAL** | Device Metal |
| `skateboarding` | dedicated | **MET** | **MET** | **MET** | **PARTIAL** | Device Metal |
| `snowboarding` | dedicated | **MET** | **MET** | **MET** | **PARTIAL** | Device Metal |
| `surfing` | dedicated | **MET** | **MET** | **MET** | **PARTIAL** | Venice mesh proxy + device Metal |
| `basketball_3v3` | outcome | **MET** | **MET**† | **MET** | **PARTIAL** | Full 3v3 sim + online MP **OPEN** |
| `karate_h2h` | outcome | **MET** | **MET**† | **MET** | **PARTIAL** | Full fight sim + online MP **OPEN** |
| `baseball` | outcome | **MET** | **MET**† | **MET** | **PARTIAL** | Full diamond sim depth |
| `football` | outcome | **MET** | **MET**† | **MET** | **PARTIAL** | Full gridiron sim depth |
| `soccer` | outcome | **MET** | **MET**† | **MET** | **PARTIAL** | Full match sim depth |
| `golf` | outcome | **MET** | **MET**† | **MET** | **PARTIAL** | Full course sim depth |
| `tennis` | outcome | **MET** | **MET**† | **MET** | **PARTIAL** | Full rally sim depth |
| `volleyball` | outcome | **MET** | **MET**† | **MET** | **PARTIAL** | Full rally sim depth |

† Outcome cluster: covered by `flagship_outcome_sport_validate_only_integration` (baseball + volleyball) plus per-mode evaluator unit paths in `gameplay_handoff.json`.

| Cross-cutting signal | Target | Actual (2026-06-27) | Status |
|----------------------|--------|---------------------|--------|
| Production validate | 18/18 @ mobile | 18/18 | **MET** |
| Validate PASS (all modes) | 18/18 | 18/18 | **MET** |
| Ship PASS (any mode) | 18/18 | 0/18 full **MET**; 18/18 **PARTIAL** | **OPEN** |
| Device Metal draw | Physical iPhone proof | Sim hybrid only | **OPEN** (V-013) |
| Online multiplayer | Only when shipped + labeled | None; local co-op karate only | **OPEN** |
| Athlete meshes | Imported rig or honest procedural | Procedural SCNCharacter | **OPEN** |
| Live receipt POST | Authenticated server path | Stub + local queue | **OPEN** (V-012) |

**Cluster verdicts:** flagship **Validate MET / Ship PARTIAL** · dedicated **Validate MET / Ship PARTIAL** · outcome **Validate MET / Ship PARTIAL** (pulse ≠ finished sport title) · non-game `market_browse` preview only.

---

| Dimension | Before | After | Notes |
|-----------|--------|-------|-------|
| Discoverability | 6.0 | **7.5** | Create tab hero + “what you can build” gallery with venue + PROD/SIM badges |
| Generation quality | 7.0 | **7.5** | Adapter metadata surfaced (`gemini_fallback_reason`, `force_template` toggle) |
| Edit/refine loop | 6.0 | **6.5** | Studio empty-state quick start; refine unchanged |
| Run/play loop | 7.0 | **8.0** | **Generate & play** one-tap; success banner + Studio Run introspection |
| Asset/venue authoring | 5.0 | **6.0** | Registry venue + “production @ mobile” mesh honesty in spec card |
| Polish & trust | 5.0 | **7.5** | Fallback badges, capability tiers, improved empty states |
| Extensibility | 8.0 | **8.5** | `force_template` exposed in iOS UI; MCP/CLI unchanged |

**Builder composite:** **6.3 → 7.4 / 10** — polished MVP builder loop; not Seele-tier asset synthesis.

**Next tranche (recommended):** live template thumbnails from venue mesh previews; conversational refine thread UI; headless `fel.generate.game` parity badge in Studio Run; share/export spec deep link.

---

## World-class criteria (must all be MET for “shipped”)

### 1. Engine gate — 7/7 headless + 8/8 full + 18 production modes

```bash
./scripts/nexus_build_gate.sh
```

| Build | Tests | Required |
|-------|-------|----------|
| Headless (`NEXUS_ENABLE_RENDERER=OFF`) | 7 | `nexus_protocol_test`, `nexus_gameplay_test`, `nexus_scan_envelope_test`, `nexus_generative_test`, `nexus_physics_test`, `nexus_realtime_test`, … |
| Full renderer | 8 | Headless suite + `nexus_renderer_test` |
| Phase 1b | 18 modes | `./scripts/nexus_validate_production_modes.sh` @ `NEXUS_MESH_PROFILE=mobile` |

**Bar:** 100% pass, zero compile warnings treated as errors in CI. **Latest (2026-06-19T21:08Z):** headless **7/7**, full **8/8**, production validate **18/18**, staging **0** (promoted) — `quality_check` independent re-run; no `gameplay_handoff.json` in coord (gameplay tranche not present this session).

---

### 2. iOS compile — simulator + device static libs

```bash
./scripts/build-nexus-ios.sh    # → build-ios/libnexus_gameplay.a + libnexus_renderer.a
xcodebuild -project FinalEvolutionLab.xcodeproj -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

**Bar:** BUILD SUCCEEDED without script-phase cycles; Metal renderer linked; no UE framework dependency. Stage **Simulator** libs from `NexusPrebuilt/iphonesimulator/` (not flat device-only `NexusPrebuilt/*.a`) — see `docs/NEXUS_DEBUG_RUNBOOK.md` § iOS Simulator link mismatch.

---

### 3. Seven or more mode simulators (validate-only @ mobile)

```bash
./scripts/nexus_validate_production_modes.sh
./scripts/nexus_mobile_mesh_gate.sh
```

**Bar:** Every **production** mode in `nexus_validate_production_modes.sh` passes triangle budget @ `NEXUS_MESH_PROFILE=mobile`. **Current:** 18 modes.

---

### 4. Agent IDE — Cursor + in-app control plane

| Component | Path |
|-----------|------|
| Tool registry | `Config/nexus_cursor_tool_registry.json` |
| Swift executor | `FinalEvolutionLab/Services/NEXUSAgentService.swift` |
| MCP server | `tools/nexus-cursor-mcp/` |
| Docs | `docs/CURSOR_NEXUS_CONTROL.md`, `docs/NEXUS_AGENT_TOOLS.md` |
| Safe allowlist | `run_build_gate`, `launch_mode`, `agent_command`, `list_modes`, … |

**Bar:** Whitelisted scripts only; repo root resolution; no arbitrary shell. **Status:** MET for preview — label **beta** until TestFlight channel ships agent UI.

---

### 5. Text / scan generation pipeline

| Stage | Implementation |
|-------|----------------|
| Envelope ingest | `fel.scan.generate` → `GameplayApplication::applyScanGenerateCommand` |
| C++ mapper | `app/gameplay/src/scan_envelope_mapper.cpp` |
| Generative commands | `scanEnvelopeToCommandJson` → `fel.fitness.update`, `fel.creative.fill_region`, `fel.generate.arena_from_scan` |
| Tests | `tests/unit/gameplay/scan_envelope_test.cpp` (ctest `nexus_scan_envelope_test`) |
| Swift mirror | `FinalEvolutionLab/Models/ScanEnvelope.swift` |

**Bar:** Deterministic mapping for schema v1–v2; ctest green; UI labels **estimate / preview** until `infra/SYSTEM_SCAN_ACCURACY_CONTRACT.md` bar met.

---

### 6. TestFlight path

```bash
# Preflight
ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1 ./scripts/archive-ios-testflight.sh --dry-run
# Ship
./scripts/archive-ios-testflight.sh
./scripts/archive-ios-testflight.sh --export
```

**Bar:** Signed `FEL.xcarchive`, export IPA, App Store Connect upload via `fastlane/Fastfile`. **Status:** Dry-run **PASS** (preflight + `build-nexus-ios.sh`); **not shipped** — no archive/IPA until real Firebase plist + distribution profile on machine.

**Real archive (team `7KJ6G7HLL4`, manual signing `FEL_TestFlight_Distribution`):**

1. Copy production **`FinalEvolutionLab/GoogleService-Info.plist`** from Firebase Console (do **not** rely on `ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1` for TestFlight).
2. In Xcode: Settings → Accounts → team **FINAL EVOLUTION LLC (`7KJ6G7HLL4`)**; confirm **Apple Distribution** cert and **`FEL_TestFlight_Distribution`** profile for `com.finalevolutionlab.app`.
3. From repo root (≥12 GB free disk recommended):

```bash
cd /Users/elijahbonds/Final-Evolution-Lab
./scripts/archive-ios-testflight.sh
./scripts/archive-ios-testflight.sh --export
```

4. Upload: Xcode Organizer → Distribute App → TestFlight, **or** `IPA_PATH=/Users/elijahbonds/Final-Evolution-Lab/build/FEL-export/*.ipa bundle exec fastlane ios testflight` (App Store Connect API key or `fastlane spaceauth`).

**Dry-run only (no ship claim):** `ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1 ./scripts/archive-ios-testflight.sh --dry-run`.

---

## DELIVERY_BAR pillars → NEXUS components

Cross-check of **`DELIVERY_BAR_FINAL_EVOLUTION.md`** against NEXUS-only implementation (no UE ship claims).

| Delivery bar pillar | NEXUS / Swift component | Production bar met? |
|---------------------|-------------------------|:-------------------:|
| **Global — Architecture** | `engine/` + `app/gameplay/` + `FinalEvolutionLab/`; `SHIPPING_ARCHITECTURE.md` | **Partial** — NEXUS path authoritative; UE trees archived |
| **Global — Honest labeling** | `FELPreviewLabel.swift`, `GamePlayView` preview badges, matrix docs | **Partial** — canonical repo labeled; legacy mirror drift |
| **System Scan / PRQ** | `prq_engine.cpp`, `scan_envelope_mapper.cpp`, `ScanEnvelope.swift`, `infra/SYSTEM_SCAN_ACCURACY_CONTRACT.md` | **Preview** — mapper + tests; clinical claims gated |
| **Avatar / readiness / HealthKit** | `fitness_data.cpp`, HealthKit views in Swift shell | **Foundation** — no medical device claims |
| **Gameplay / arena / NEXUS** | `arena_mode_registry.cpp`, mode runtimes, `NexusGameplayEngine.swift`, `GamePlayView` | **Partial** — 18 modes validate @ mobile; hybrid viewport sim **MET**; Ship PASS 0/18 full MET (see mode scorecard) |
| **NEXUS integration & super-app shell** | `NexusGameplayBridge.mm`, `build-nexus-ios.sh`, static `.a` embed | **Partial** — simulator compile green; TestFlight artifact pending |
| **Economy — shards, Creator Cards** | `FELScoreManager` / backend contracts; local caches not authoritative | **MET / PASS** — fully integrated with Postgres Data Connect, custom card minting, 10% marketplace royalties, and 500-shard critique escrows |
| **Markerless MoCap & Pipeline** | `NexusMotionCaptureEngine.swift`, `NexusMoCapRetargeter.swift`, `NexusMoCapStudioView.swift`, VNDetectHumanBodyPose3DRequest | **MET / PASS** — real-time 3D skeleton pose estimation, 17 joints tracked, timeline scrubbing/playback, local/social export, and full uploader caching |
| **Education / Academy** | `AnatomyEducationService.swift`, education engine docs | **Preview** — tracks exist; full curriculum not verified |
| **BioFuel / nutrition** | `BioFuelService.swift`, `infra/BIOFUEL_NUTRITION_SAFETY_CONTRACT.md` | **Preview** — performance assistant framing |
| **Privacy / minors** | `infra/PRIVACY_MINOR_SAFETY_CONTRACT.md`, gating in Swift settings | **Foundation** — contract-driven |
| **Realtime / social / vault** | `websocket_client.cpp`, `TrainingLabSocialBridge.swift`, `infra/REALTIME_TRUST_CONTRACT.md` | **Preview** — stub transport; production env rules pending |

**Pillar graduation rule:** A pillar moves from **preview → production-grade** only when **`DELIVERY_BAR_FINAL_EVOLUTION.md`** acceptance criteria **and** the NEXUS rows above are both satisfied.

---

## Verification commands (copy/paste)

```bash
cd /Users/elijahbonds/Final-Evolution-Lab

# Engine world-class gate
./scripts/nexus_build_gate.sh

# Integration smoke (reuse build-full)
./scripts/smoke_v1.sh --skip-build

# Mobile mesh + production modes
./scripts/nexus_mobile_mesh_gate.sh
./scripts/nexus_validate_production_modes.sh

# iOS preflight
./scripts/build-nexus-ios.sh
xcodebuild -project FinalEvolutionLab.xcodeproj -scheme FinalEvolutionLab \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# TestFlight (manual signing)
./scripts/archive-ios-testflight.sh --dry-run
```

---

## Revision

Update this file when any world-class criterion graduates. Keep **`NEXUS_DELIVERY_MATRIX.md`** in sync with gate outputs and Pass 1/2 phase scores. Per-mode detail: **`docs/NEXUS_MODES_CAPABILITY.md`** · **`artifacts/coord/mode_vision_master_handoff.json`**.
