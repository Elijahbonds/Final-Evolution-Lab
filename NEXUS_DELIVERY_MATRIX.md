# NEXUS Delivery Matrix — Production Ship Track

**Audit date:** 2026-06-19 (simulator product test loop; SceneKit re-entry + arena navigation fixes)  
**Repo:** `/Users/elijahbonds/Final-Evolution-Lab`  
**Scope:** NEXUS C++20 engine + Metal/SceneKit iOS host — **sole production ship target** (UE/Unity not in scope)  
**Authority:** `NEXUS_RESUME.md`, `docs/architecture/NEXUS_Engine_10_Phase_Pass.md`, `docs/architecture/FEL_NEXUS_Spec_v1_Implementation_Plan.md`

> **Ship claim bar:** Simulator `xcodebuild` green + `archive-ios-testflight.sh --dry-run` green does **not** equal TestFlight live. Requires real `GoogleService-Info.plist`, Release archive, IPA export, and device QA.

---

## Canonical ship commands

Run from repo root (`/Users/elijahbonds/Final-Evolution-Lab`):

| Step | Command | Purpose |
|------|---------|---------|
| **1 — Engine gate** | `./scripts/nexus_build_gate.sh` | Headless + full Vulkan renderer cmake/ctest matrix |
| **2 — iOS static libs** | `./scripts/build-nexus-ios.sh` | Cross-compile iOS `.a` libs → `build-ios/` + refresh `NexusPrebuilt/` |
| **3 — Simulator app** | `xcodebuild -project FinalEvolutionLab.xcodeproj -scheme FinalEvolutionLab -derivedDataPath /tmp/FEL-DD-NEXUS -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' -configuration Debug build` | Full Swift + ObjC++ bridge compile/link |
| **4 — TestFlight preflight** | `./scripts/archive-ios-testflight.sh --dry-run --preview-firebase` | Preflight + NEXUS lib staging (placeholder plist OK — V-003 workaround) |
| **4b — Production preflight** | `./scripts/archive-ios-testflight.sh --dry-run` | Requires real Firebase plist (no `--preview-firebase`) |
| **5 — Preview archive (V-003 workaround)** | `./scripts/archive-ios-testflight.sh --preview-firebase` | Release archive with placeholder plist; Crashlytics skipped; Firebase offline at runtime |
| **5b — TestFlight archive (production Firebase)** | `./scripts/archive-ios-testflight.sh` | Release archive → `build/FEL.xcarchive` (requires real Firebase plist + signing) |
| **6 — IPA export (App Store)** | `./scripts/archive-ios-testflight.sh --export` or `--preview-firebase --export` | App Store distribution IPA → `build/FEL-export/` (upload via Transporter) |
| **6b — IPA export (ad-hoc)** | `./scripts/archive-ios-testflight.sh --export-adhoc` | Ad-hoc IPA for Firebase App Distribution / sideload (no ASC app record) |

**Notes:**
- Xcode run script copies `NexusPrebuilt/${PLATFORM_NAME}/*.a` → `DERIVED_FILE_DIR/nexus-ios/` (user script sandbox disabled on app target for NEXUS staging). **2026-06-19:** platform-specific prebuilts (`iphonesimulator/` vs `iphoneos/`) + SDK verification in `build-nexus-ios.sh` — fixes Simulator link mismatch (`ld: building for 'iOS-simulator', but linking ... built for 'iOS'`).
- `third_party/nlohmann/` + `NexusPrebuilt/_deps/nlohmann_json-src/include` + `build-ios/nexus-ios/_deps/...` cover `nlohmann/json.hpp` for bridge `.mm` units.
- Enable Metal viewport: **Dunk Contest auto-selects Metal** when bundled manifest + Venice mobile mesh resolve; override with `NEXUS_USE_METAL=1` / `NEXUS_USE_SCENEKIT=1` / compile flag `NEXUS_USE_METAL`. See `FinalEvolutionLab/IOS_RUNBOOK.md` § Metal viewport.

---

## Preflight scripts (2026-06-19 audit)

| Script | Result | Evidence |
|--------|--------|----------|
| `./scripts/nexus_build_gate.sh` | **PASS** | Headless **7/7** ctest + full **8/8** ctest + **18/18** production + **0/0** staging modes @ mobile — sim FR re-verify **PASS** 2026-06-19T21:52Z (`support_gate_handoff.json`; parallel flake retried green) |
| `ctest -R nexus_renderer_test` (V-013 re-run) | **PASS** | Venice `basketball_dunk` manifest mesh load + mobile budget; **25.15s** (2026-06-19 V-013) |
| `./scripts/nexus_gameplay_regression.sh` | **PASS** | 100% ctest + `nexus_gameplay_test` incl. `flagship_outcome_sport_validate_only_integration` |
| `./scripts/nexus_validate_production_modes.sh` | **PASS** | 18/18 production modes @ mobile mesh profile — sim FR independent **PASS** 2026-06-19T21:52Z (`support_gate_handoff.json` + `quality_handoff.json`) |
| `./scripts/nexus_validate_staging_modes.sh` | **PASS** | 0/0 staging — all promoted to production (`c8d0c619`) |
| `./scripts/build-nexus-ios.sh` | **PASS** | Platform prebuilts refreshed 2026-06-19; `Result<std::string>` specialization unblocks `nexus_ai_interface` |
| `xcodebuild` iOS Simulator (iPhone 17, Debug) | **PASS** | `** BUILD SUCCEEDED **` — `/tmp/FEL-DD-NEXUS`; product smoke UI test **PASS** (see below) |
| **Simulator product smoke** (`testProductSmoke_KeySimulatorFlows`) | **PASS** | Arena dunk/karate/court + Create generator + Studio Run + Agent List Modes chip — prior run `docs/NEXUS_SIMULATOR_PRODUCT_TEST.md` (17:46Z); sim FR gate tranche **PASS** 2026-06-19T21:52Z — UI FR refresh pending sim-lead |
| `./scripts/nexus_playtest.sh --duration 0` | **PASS** | Re-run 2026-06-19T21:11Z after C++ fix |
| `./scripts/nexus_gameplay_regression.sh` | **PASS** | Re-run 2026-06-19T21:11Z — 10/10 sprint modes |
| `archive-ios-testflight.sh --dry-run --preview-firebase` | **PASS** (PREVIEW) | Preflight OK with placeholder plist; Crashlytics skip path verified |
| `archive-ios-testflight.sh --preview-firebase` (Release archive) | **PASS** (PREVIEW) | `build/FEL.xcarchive` signed (`Apple Distribution`, `FEL_TestFlight_Distribution`); Crashlytics upload skipped |
| `archive-ios-testflight.sh --preview-firebase --export` | **PASS** (PREVIEW) | `build/FEL-export/FinalEvolutionLab.ipa` (~82 MB, App Store distribution signed). **Fix:** `ExportOptions.testflight.plist` `destination=export` (was `upload`, failed with `missingApp`) |
| `archive-ios-testflight.sh --preview-firebase --export-adhoc` | **PASS** (PREVIEW) | `build/FEL-export-adhoc/FinalEvolutionLab.ipa` (~71 MB, ad-hoc signed) — no ASC app record required |
| **TestFlight upload (Transporter)** | **BLOCKED** | ASC app record missing for `com.finalevolutionlab.app` — create in App Store Connect (see `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt`) |
| `xcodebuild` Release Simulator | **PASS** (PREVIEW) | `** BUILD SUCCEEDED **` with placeholder plist |
| `archive-ios-testflight.sh --dry-run` (real plist) | **NOT RUN** | Blocked on real `GoogleService-Info.plist` |
| `./scripts/nexus_mobile_mesh_gate.sh` | **NOT RE-RUN** | Prior audit: PASS (WARN sidecar naming) |
| `./scripts/smoke_v1.sh --skip-build` | **NOT RE-RUN** | Prior audit: PASS |
| **Device bundle proof** (`Debug-iphoneos` `.app` on disk + install `78a4333f`) | **PASS (partial)** | `/tmp/FEL-DD-device/Build/Products/Debug-iphoneos/FinalEvolutionLab.app`: **1** manifest (`nexus_asset_manifest.json`) + **28** `imported/*.nexusmesh.json` (matches repo `assets/nexus/imported/`); **0** missing manifest mesh refs; Venice beach + Luma shop mobile/desktop sidecars present; `devicectl install` **SUCCESS** on Elijah's iPhone (`77E005FC-16AB-55D3-A702-81D118AB3992`, `com.finalevolutionlab.app`). **OPEN:** runtime Venice mesh draw on **physical device** (Dunk Contest + Metal) — `devicectl launch` blocked (`device locked`); headless `./build-full/nexus_runtime --validate-only --mode basketball_dunk --venue venice_beach` **OK** on host only |
| **Simulator Metal path (V-013)** | **PASS (partial)** | `xcodebuild` Debug sim **BUILD SUCCEEDED** (`/tmp/FEL-DD-NEXUS-V013`); bundle manifest + Venice mobile mesh **OK**; `NEXUS_USE_METAL=1 simctl launch` → pid **29611** (no crash). **Dunk Contest auto-Metal** when bundled mesh resolves (`GameSceneHostView.prefersMetalRenderer(for:)` + `nexus_metal_bridge_bundled_venue_mesh_loadable`). **OPEN:** visual mesh draw confirmation (screenshot/Instruments); Metal path lacks SceneKit camera/player UX |

---

## Master matrix — 10 engine phases (summary)

| Phase | Goal | Pass 1 | Pass 2 | Actual (2026-06-19) |
|-------|------|:------:|:------:|---------------------|
| **1** | Build gate | **PASS** | **PASS** | Headless **7/7** + full **8/8** ctest + **18/18** production + **0/0** staging validate-only @ mobile |
| **8** | Metal iOS renderer | **PARTIAL** | **PARTIAL** | Wireframe/solid mesh draw + manifest load; `nexus_metal_bridge_bundled_venue_mesh_loadable`; Dunk auto-Metal when bundle OK; SceneKit default elsewhere |
| **10** | Performance ship gate | **PASS** | **PARTIAL** | Desktop validate-only OK; no Instruments proof on device |

**Integration Phase 8 (TestFlight packaging):** **PARTIAL** — signed App Store + ad-hoc IPAs evidenced (PREVIEW Firebase); TestFlight upload blocked on ASC app record creation (user action).

## Spec v1 DoD tracker (§9.1)

**Composite quality score:** **8.0 / 10** per `NEXUS_QUALITY_BAR.md` — engine gate fully green (headless **7/7** + full **8/8** ctest + **18/18** production modes @ `NEXUS_MESH_PROFILE=mobile`); iOS Simulator compile green; signed preview IPA evidenced; device perf, live Firebase POST, and premium visual bar remain open. **NEXUS-only — no UE/Unity ship claims.**

**DoD score:** **5/9 met · 3 partial · 1 open**

| # | Criterion | Status | Drift / evidence |
|---|-----------|--------|------------------|
| 1 | Dunk Contest playable (Metal venue on sim/device) | **PARTIAL** | **V-013** — bundled manifest + Venice mobile mesh in app bundle; Dunk auto-Metal when mesh resolves; SceneKit default elsewhere; physical device draw unproven |
| 2 | Venice Beach 60 FPS @ mobile mesh | **OPEN** | **V-013** — desktop `nexus_runtime --validate-only` OK; no Instruments GPU frame-time proof on physical iPhone |
| 3 | Touch → dunk → score | **MET** | `NexusGameplayBridge` + `fel.dunk.*`; simulator product smoke PASS |
| 4 | Session receipt → Firebase (live POST) | **PARTIAL** | **V-012** — C++ disk queue (`~/.fel/pending_receipts/`) + Swift drain wired; preview lane queue-only; production JWT POST + 2xx proof open |
| 5 | Karate Endless functional | **MET** | `fel.karate.action` + wave spawner; ctest + smoke |
| 6 | Mode menu navigates production modes | **MET** | `GameModeSelectionView` + `arena_mode_registry.cpp` — **18** production modes (`nexus_validate_production_modes.sh`) |
| 7 | No exceptions in engine code | **MET** | `Result<T>` throughout gameplay/engine |
| 8 | ctest passes | **MET** | Headless **7/7** + full renderer **8/8** (`nexus_build_gate.sh`) |
| 9 | TestFlight candidate (production Firebase) | **PARTIAL** | **V-003** — `--preview-firebase` signed App Store + ad-hoc IPA PASS; real `GoogleService-Info.plist`, ASC app record, live Auth/Crashlytics open |

**Partial drift map:** **V-003** → DoD #9 · **V-012** → DoD #4 · **V-013** → DoD #1–2

---

## Renderer path inventory

| Path | Stack | Pass 2 | Notes |
|------|-------|:------:|-------|
| iOS embed | Metal + static `.a` | **PARTIAL** | Vertex-color venue mesh draw; mode-aware `NexusMetalBridge`; Dunk auto-select when bundled; override `NEXUS_USE_METAL` / `NEXUS_USE_SCENEKIT` |
| iOS gameplay UI | SceneKit + SwiftUI | **PASS** | SceneKit for non-dunk / explicit opt-out; Metal for P0 dunk + bundled mesh or `NEXUS_USE_METAL=1` |
| Desktop runtime | Vulkan + SDL3 | **PASS** | Dev/CI runtime |

---

## Top 5 remaining blockers for TestFlight

1. **Production Firebase (V-003)** — **PARTIAL workaround in tree:** `--preview-firebase` archive skips Crashlytics + runs with `FirebaseBootstrap.isPreviewMode` (Auth/Firestore offline, PREVIEW banner). **Still blocked:** real `GoogleService-Info.plist` for live Firebase TestFlight + Crashlytics.
2. **TestFlight upload (ASC app record)** — **BLOCKED (user action):** signed App Store IPA exports successfully (`--export`); Transporter upload requires creating `com.finalevolutionlab.app` in App Store Connect. **Workaround:** `--export-adhoc` for Firebase App Distribution / sideload without ASC app.
3. ~~**NEXUS venue assets not in app bundle**~~ — **FIXED in tree / PARTIAL on device (2026-06-19):** `Bundle NEXUS venue assets` run script copies `assets/nexus/manifests/` + `imported/*.nexusmesh.json` into app resources; `NexusMetalBridge` sets `NEXUS_RESOURCE_ROOT` for manifest/mesh resolution. **Simulator (V-013):** bundle grep + `NEXUS_USE_METAL=1` launch OK; Dunk Contest auto-Metal in tree. **OPEN:** physical iPhone Metal draw (phone unlock for `devicectl`); visual mesh proof on sim/device |
4. **Session receipt live POST (DoD #4)** — C++ queues to `~/.fel/pending_receipts/`; Swift drain + authenticated POST stubbed.
5. **Device validation gap** — no Instruments 60 FPS @ mobile mesh profile on physical iPhone; Metal PBR/post parity with Vulkan deferred.

---

## Files touched in this ship sprint

| Area | Files |
|------|-------|
| Swift compile | `FinalEvolutionLab/Views/GameModeSelectionView.swift` (`gameplayRoute` item navigation); `GameSceneHostView.swift` (SceneKit re-entry crash fix) |
| C++ build | `engine/core/include/nexus/core/result.h` (`Result<std::string>` specialization) |
| UI test | `FinalEvolutionLabUITests/GameModeScreenshotUITests.swift` (`testProductSmoke_KeySimulatorFlows`) |
| Docs | `docs/NEXUS_SIMULATOR_PRODUCT_TEST.md`; `FinalEvolutionLab/IOS_RUNBOOK.md` (sim UDID + app path) |
| Swift compile (prior) | `FinalEvolutionLab/Views/GameModeSelectionView.swift` (`sprintPriorityBadge`); `NexusAgentChatView.swift` (`@Bindable` on `NEXUSAgentCoordinator.shared` for `$coordinator.backend` Picker) |
| Metal embed | `FinalEvolutionLab/Bridge/NexusMetalBridge.{h,mm}`, `GameSceneHostView.swift` (V-013: bundled mesh auto-Metal for dunk) |
| json headers | `third_party/nlohmann/json.hpp`, `FinalEvolutionLab.xcodeproj` `HEADER_SEARCH_PATHS` |
| iOS libs | `scripts/build-nexus-ios.sh`, `NexusPrebuilt/{iphonesimulator,iphoneos}/*.a`, `CMakeLists.txt` (renderer json link) |
| Debug / gate hygiene | `docs/NEXUS_DEBUG_RUNBOOK.md` (new); `scripts/nexus_playtest.sh` strict exit-0; `nexus_agent_cli --verbose` |
| Snowboarding gate | `gameplay_application.cpp` `safeParams` pass-through (defensive); resolution owned by **`debugging` `99dabc11`** — prior `merge_patch` / router fixes from `gameplay_tester` + `error_editor` duplicated scope |
| Game modes ship pass | `outcome_sport_mode.{h,cpp}` — `fel.sport.pulse` for 9 evaluator modes; `mode_runtime.cpp` `kOutcomeSport`; `scripts/nexus_validate_staging_modes.sh`; `docs/NEXUS_MODES_CAPABILITY.md`; `GameMode.swift` staging tier alignment |
| Xcode hygiene | Removed `FinalEvolutionLab/Bridge/prebuilt/` (cmake junk in synced folder); `engine/assets/include` on header path; `ENABLE_USER_SCRIPT_SANDBOXING=NO` on app target |
| NEXUS bundle assets | `FinalEvolutionLab.xcodeproj` — `Bundle NEXUS venue assets` script; `NexusMetalBridge.mm` + `asset_manifest.cpp` (`NEXUS_RESOURCE_ROOT`) |
| iOS Firebase preview | `FirebaseBootstrap.swift`, `ContentView.swift`, `GoogleService-Info.example.plist`, Crashlytics build phase, `scripts/archive-ios-testflight.sh`, `scripts/fetch-firebase-ios-plist.sh` |
| iOS export / ASC | `infra/ios/ExportOptions.{testflight,ad-hoc,development}.plist`, `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt` (ASC create-app steps) |

---

*Re-run canonical commands above before tagging any NEXUS milestone or uploading to TestFlight.*
