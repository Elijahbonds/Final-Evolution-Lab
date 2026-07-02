# NEXUS Simulator Product Test — 2026-06-19 FR

**Repo:** `/Users/elijahbonds/Final-Evolution-Lab`  
**Lead:** `[sim-fr-lead]` — full simulator regression (build → install → UI smoke → headless)  
**Device:** iPhone 17 simulator (iOS 26.5), UDID `1B67D9BE-90BE-4206-8CA5-1747CBEDC4AB`  
**Build:** `xcodebuild` Debug → `/tmp/FEL-DD-NEXUS/Build/Products/Debug-iphonesimulator/FinalEvolutionLab.app`  
**Firebase:** Placeholder plist (`FEL_FIREBASE_PREVIEW=1`) — offline preview lane  
**Handoff:** `artifacts/coord/gameplay_handoff.json` (2026-06-19T21:52:53Z)

**Sim FR cross-ref (2026-06-19T21:52Z):** Independent gate + validate **PASS** — `artifacts/coord/support_gate_handoff.json` + `quality_handoff.json`; fleet/matrix updated by `[support-docs-fr]`. Full UI FR retest timestamp pending sim-lead refresh of this doc.

---

## Build & headless gates

| Step | Result | Evidence |
|------|--------|----------|
| `./scripts/build-nexus-ios.sh` | **PASS** | `NexusPrebuilt/iphonesimulator` refreshed (2026-06-19T17:49-0400) |
| `xcodebuild` Debug simulator | **PASS** | `** BUILD SUCCEEDED **` — DerivedData `/tmp/FEL-DD-NEXUS` (2026-06-19T17:50-0400) |
| `./scripts/nexus_playtest.sh --duration 0` | **PASS** | `basketball_dunk @ venice_beach`, validate tris=80000 (2026-06-19T21:50:14Z) |
| `./scripts/nexus_gameplay_regression.sh --skip-build` | **PASS** | 100% ctest + 10/10 sprint live modes (2026-06-19T21:50:21Z) |
| `simctl install` + `launch` | **PASS** | PID launch OK; bundle **28** imported `.nexusmesh.json` |

**DerivedData note:** Use a **single** path (`/tmp/FEL-DD-NEXUS`) for both `build` and `test`. A separate test DerivedData (e.g. `/tmp/FEL-DD-NEXUS-TEST`) can trigger Firebase Firestore SPM `ExprBridge` compile failures on a cold resolve. If `xcodebuild build` fails on Firestore Swift with `cannot find type 'ExprBridge'`, wipe DerivedData and resolve packages once before rebuilding.

---

## Product smoke matrix (UI)

Automated: `GameModeScreenshotUITests/testProductSmoke_KeySimulatorFlows` (90.3s, **PASS** 2026-06-19T17:52-0400).

| Flow | Result | Notes |
|------|--------|-------|
| Launch → Arena tab (sim default) | **PASS** | Onboarding skipped on simulator |
| **PREVIEW · FIREBASE OFFLINE** banner | **PASS** | Top safe-area inset when placeholder plist |
| **PREVIEW · NEXUS ARENA** label | **PASS** | Arena modes grid |
| Dunk Contest → GamePlayView → EXIT | **PASS** | Metal auto-path when Venice mesh bundled |
| Karate Endless → GamePlayView → EXIT | **PASS** | Fixed SceneKit re-entry crash (see fixes) |
| Court Carnival → GamePlayView → EXIT | **PASS** | SceneKit viewport |
| Arena **Create** → generator template + Generate | **PASS** | `PREVIEW · NEXUS GAME GENERATOR` |
| Generator **Play now** → gameplay → EXIT | **PASS** | Template parser MVP |
| Status → **OPEN NEXUS STUDIO** | **PASS** | Full-screen IDE; file tree + **Run** panel |
| Studio **Close** → tab shell | **PASS** | Toolbar Close dismisses fullScreenCover |
| **Agent** tab (More overflow on iPhone 17) | **PASS** | **PREVIEW · TOOL CHIPS** visible |
| Agent **List Modes** whitelisted chip | **PASS** | Quick-tool tap; chat surface updates |
| `testMainApp_ArenaModesGridFromTabs` | **PASS** | Separate UI test (12.6s) |

Manual screenshot at launch: Arena modes grid with sprint row P0/P1 cards visible.

---

## Fixes applied this session

| Issue | Root cause | Fix |
|-------|------------|-----|
| C++ build failure (`Result<std::string>`) | Value/error ctor collision | `Result<std::string>` explicit specialization in `result.h` |
| Second arena mode would not open | `navigationDestination(isPresented:)` stuck after EXIT | Item-based route via `gameplayRoute: GameModeId?` in `GameModeSelectionView` |
| **Crash** opening Karate after Dunk | `scnView.prepare()` abort in dojo SceneKit graph | Removed eager `prepare`; rely on `warmSceneForDisplay` + continuous render |
| SceneKit teardown | Renderer kept running after pop | `scnView.isPlaying = false` in `teardown` |
| UI test Agent tab | 6 tabs → **More** overflow on iPhone 17 | `navigateToTab` helper + Studio **Close** button |
| Firebase Firestore `ExprBridge` on cold test DD | Separate `/tmp/FEL-DD-NEXUS-TEST` cold SPM resolve | Reuse `/tmp/FEL-DD-NEXUS` for build + test; wipe DD if needed |

---

## Remaining gaps (simulator ≠ ship)

| Gap | Severity |
|-----|----------|
| Production Firebase / live Auth-Firestore | **BLOCKED** — placeholder plist only |
| Session receipt live POST | **OPEN** — PREVIEW lane skips POST |
| Metal venue draw QA on physical device | **OPEN** — sim Metal path OK for dunk |
| 60 FPS Instruments proof | **OPEN** — not measured this pass |
| Agent tool chips beyond **List Modes** | **PARTIAL** — one chip smoke only |
| TestFlight / ASC upload | **BLOCKED** — user action |

---

## Re-run commands

```bash
cd ~/Final-Evolution-Lab
./scripts/build-nexus-ios.sh
ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1 xcodebuild -project FinalEvolutionLab.xcodeproj -scheme FinalEvolutionLab \
  -derivedDataPath /tmp/FEL-DD-NEXUS \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -configuration Debug build
./scripts/nexus_playtest.sh --duration 0
./scripts/nexus_gameplay_regression.sh
APP="/tmp/FEL-DD-NEXUS/Build/Products/Debug-iphonesimulator/FinalEvolutionLab.app"
xcrun simctl install booted "$APP" && xcrun simctl launch booted com.finalevolutionlab.app
# UI smoke — reuse same DerivedData as build (do not use a separate -TEST path)
ALLOW_GOOGLE_SERVICE_PLACEHOLDER=1 xcodebuild test -project FinalEvolutionLab.xcodeproj -scheme FinalEvolutionLab \
  -derivedDataPath /tmp/FEL-DD-NEXUS \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -only-testing:FinalEvolutionLabUITests/GameModeScreenshotUITests/testProductSmoke_KeySimulatorFlows
```

See also `FinalEvolutionLab/IOS_RUNBOOK.md` § Simulator smoke.

---

## Product verdict

**Ship-ready for simulator product QA** — build green, headless gates green, automated product smoke **PASS** across Arena (3 modes), Create generator, NEXUS Studio, and Agent tool chip. **Not** ship-ready for TestFlight/production: real Firebase, device Metal QA, receipt POST, and ASC upload remain open.
