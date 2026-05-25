## File Addresses

### Present in workspace
- `/backend/FEL_ModeManager.production.json`
- `/assets/games/final_evolution_lab/workspace/create_fel_migration.sh`
- `/assets/games/final_evolution_lab/workspace/Config/DefaultGame.ini`
- `/assets/games/final_evolution_lab/workspace/Config/DefaultEngine.ini`
- `/assets/games/final_evolution_lab/workspace/infra/ios/fel_ios_shipping_build.sh`
- `/assets/games/final_evolution_lab/workspace/infra/ios/fel_appstore_connect.sh`
- `/assets/games/final_evolution_lab/workspace/infra/android/fel_android_shipping_build.sh`
- `/assets/games/final_evolution_lab/workspace/infra/android/fel_keystore.properties`
- `/assets/games/final_evolution_lab/workspace/infra/android/upload_to_google_play.sh`
- `/assets/games/final_evolution_lab/workspace/infra/distribution/FEL_DISTRIBUTION_CHECKLIST.md`
- `/assets/games/final_evolution_lab/workspace/infra/distribution/Fastfile`
- `/assets/games/final_evolution_lab/workspace/infra/fel_gate1_fix.sh`
- `/assets/games/final_evolution_lab/workspace/infra/hud/ws_hud_server.py`
- `/assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/court_carnival_environment_layout.json`
- `/assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/court_carnival_environment_layout.md`
- `/assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/who_scene_it_environment_layout.json`
- `/assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/who_scene_it_environment_layout.md`
- `/assets/games/final_evolution_lab/workspace/publish_status_report.json`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameplayManager.h`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameplayManager.cpp`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameModeBase.h`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELSessionReceiptComponent.h`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/FELHud.tsx`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_AICoachPrompt.tsx`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_ComboFeed.tsx`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_MRIMeter.tsx`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_PRQMeter.tsx`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_ScoreBar.tsx`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_ShardCounter.tsx`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/BPFL_HUDManager.h`
- `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/BPFL_HUDManager.cpp`
- `/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_MainMenu.h`
- `/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_ModeSelect.h`
- `/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_ModeDetail.h`
- `/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_EconomyDashboard.h`
- `/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_MarketBrowse.h`
- `/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_MatchResult.h`
- `/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_Profile.h`
- `/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_Settings.h`
- `/assets/games/final_evolution_lab/final_evolution_lab.json`
- `/assets/games/final_evolution_lab/p1_economy_patch.py`
- `/assets/games/final_evolution_lab/apply_p1_economy.sh`
- `/assets/fel_environment_layouts_ue57_ios_plan.md`
- `/assets/fel_mode_implementation_package_ue57_ios.md`
- `/assets/proposal/fel_environment_layouts_ue57_ios_plan/fel_environment_layouts_ue57_ios_plan.json`
- `/assets/proposal/fel_mode_implementation_package_ue57_ios/fel_mode_implementation_package_ue57_ios.json`
- `/logs/2026-05-22.md`
- `/logs/2026-05-23.md`
- `/logs/2026-05-24.md`
- `/.env` (at workspace root — contents unread; likely API keys)

### Files defined in create_fel_migration.sh (to be written to macOS UE project root, NOT present in workspace)
These files are heredoc targets in the migration script and **do not yet exist as standalone files** in `/assets/games/final_evolution_lab/workspace/`:
- `backend/server.py` — Flask + MongoDB backend (see heredoc in create_fel_migration.sh)
- `backend/ue_mode_maps.json` — Unreal map token registry
- `infra/ue5_config/DefaultGame.ini` — [FELPlayMap] entries (this is distinct from `Config/DefaultGame.ini`)
- `UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json` — arena settings per mode
- `UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json` — NOT in migration script; absent
- `FinalEvolutionLab/Models/GameMode.swift`
- `FinalEvolutionLab/Services/MentalResiliencyEngine.swift`
- `UnrealIntegration/Source/FinalEvolutionLab/FELDeepLinkSubsystem.h`
- `UnrealIntegration/Source/FinalEvolutionLab/FELEmergentDeepLinkSubsystem.cpp`
- `UnrealIntegration/Source/FinalEvolutionLab/FELNeuroCognitiveSubsystem.h`
- `UnrealIntegration/Source/FinalEvolutionLab/FELNeuroCognitiveSubsystem.cpp`
- `infra/fel_prebuild_ci_check.sh`
- `frontend/` directory tree (src/hud, src/stores, src/hooks) — no files written to this path in workspace

### Confirmed ABSENT from workspace
- `backend/server.py` (standalone)
- `backend/ue_mode_maps.json` (standalone)
- `backend/core.py`
- `backend/FEL_VenueRegistry.production.json`
- `UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json`
- `UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json`
- `infra/ue5_config/DefaultGame.ini` (the real [FELPlayMap] version)
- Any `felUE5Bridge.js`, `fel-bridge.js`, `docs/WEBKIT_BRIDGE.md`
- Any `LandingPage.js` or React routing files
- Any `firebase.json`, Postgres config, `wix` reference
- Any `seele/landing-v2` branch references (only mentioned obliquely in logs)

---

## Summary

1. **FEL is a 19-mode multi-sport mobile game** targeting iOS (primary) and Android, built on UE5.5 (spec targets UE5.7), with a React/TSX HUD overlay communicating via WebSocket to the game engine.
2. **`backend/FEL_ModeManager.production.json` is the only backend file in this Seele workspace.** `server.py`, `core.py`, `ue_mode_maps.json`, `ArenaSettings.json`, and both `VenueRegistry` files are defined exclusively inside `create_fel_migration.sh` as heredocs — they exist on the developer's **local macOS machine** (M4 Pro Mac Mini), not in this workspace.
3. **`production_modes` is currently `12`** in the workspace copy of `FEL_ModeManager.production.json`. `create_fel_migration.sh` targets `14` (the correct post-promotion value). Gate 1 of the CI check fails until `infra/fel_gate1_fix.sh` is run on the macOS clone.
4. **No frontend JS files exist in this workspace.** `frontend/src/hud`, `frontend/src/stores`, `frontend/src/hooks` directories are defined in `create_fel_migration.sh` but no React/JS files (including `LandingPage.js`) were written.
5. **No WebKit bridge files exist in this workspace.** `felUE5Bridge.js`, `fel-bridge.js`, and `docs/WEBKIT_BRIDGE.md` are absent. The WKWebView bridge architecture is referenced in the spec docs but no implementation files are present here.
6. **The "Emergent" name is a legacy term** — `UFELDeepLinkSubsystem` is the UE5 deep-link routing subsystem (handles `fel://play/` URLs → map paths). It is NOT a mock AI agent. The user confirmed (Round 21 log) they "replaced legacy emergent mock integrations with standard Google GenAI SDK calls in backend/core.py" — but `core.py` is on the macOS machine, not in this workspace.
7. **`infra/fel_environment_layouts/` contains 4 files** (2 JSON + 2 MD) with full staging spec data for `court_carnival` (VeniceBeach) and `who_scene_it` (NeuroArena), including all spawn point coordinates, interactive object definitions, collision volumes, camera zones, and iOS performance budgets.
8. **No references to Wix, seele/landing-v2, Firebase, Postgres, or MongoDB config files** exist in this workspace. MongoDB is referenced inside `server.py` (in the migration heredoc) but no config file for it is present.

---

## Project Overview

- **Purpose**: Final Evolution AI Coach (FEL) — multi-sport iOS/Android mobile game with 19 game modes, a neurocognitive coaching engine (MRI/ARV/ESI/Pacing metrics), shard economy, React HUD overlay, and UE5 C++ subsystems.
- **Stack**:
  - **Game Engine**: Unreal Engine 5.5 (spec references UE 5.7) — C++ gameplay layer
  - **Backend**: Flask + MongoDB (`server.py`) — economy, session receipts, neurocognitive history
  - **LLM/AI**: Google GenAI SDK (gemini-2.5-flash) in `backend/core.py` — AI Coach logic
  - **HUD Overlay**: React/TSX components (`.tsx` files) running inside a WKWebView, communicating via WebSocket to `ws_hud_server.py` (ws://localhost:8080/ws/hud)
  - **Mobile Targets**: iOS 16+ (com.finalevolutionlab.app) + Android SDK 26+/API 34
  - **Distribution**: App Store (xcrun altool / Transporter) + Google Play (bundletool/fastlane)
- **Key directories** (workspace root = `/assets/games/final_evolution_lab/workspace/`):
  - `Config/` — `DefaultGame.ini` (project settings), `DefaultEngine.ini` (iOS/Android runtime settings)
  - `FinalEvolutionLab/Gameplay/` — C++ gameplay manager, game mode base, session receipt
  - `FinalEvolutionLab/UI/HUD/` — TSX HUD components (FELHud, AICoach, Combo, MRI, PRQ, ScoreBar, ShardCounter) + C++ BPFL_HUDManager
  - `Content/FEL/UI/Menus/` — UE Widget Blueprint headers (WBP_MainMenu, WBP_ModeSelect, WBP_ModeDetail, WBP_EconomyDashboard, WBP_MarketBrowse, WBP_MatchResult, WBP_Profile, WBP_Settings)
  - `infra/ios/` — iOS shipping build script, appstore connect script, export options plist
  - `infra/android/` — Android shipping build script, keystore properties, Play Store upload script
  - `infra/distribution/` — FEL_DISTRIBUTION_CHECKLIST.md, Fastfile (lanes for both platforms)
  - `infra/hud/` — `ws_hud_server.py` WebSocket relay
  - `infra/fel_environment_layouts/` — staging spec files for court_carnival and who_scene_it
  - `infra/fel_prebuild_ci_check.sh` — defined in migration script (Gates 1-6)
  - `create_fel_migration.sh` — master migration script (heredocs all backend/Swift/UE files)
- **Notable conventions**:
  - `[FELPlayMap]` in `infra/ue5_config/DefaultGame.ini` = cooked iOS runtime map path table. The term "Emergent" here means the deep-link routing subsystem, NOT a third-party service.
  - All venue paths use `/Game/FEL/Venues/{Venue}/{Venue}` pattern.
  - Backend lives on the macOS developer machine (anti-gravity-fel branch on GitHub), not in Seele workspace files.
  - CI has 6 gates; Gate 1 (production_modes ≥ 14) is currently FAILING in workspace copy.

---

## Relevant Files

### 1. `/backend/FEL_ModeManager.production.json`
- **Role**: Mode registry — source of truth for mode status
- **Why it matters**: Controls which modes are live vs staging; Gate 1 CI check validates `production_modes ≥ 14`
- **Current state**: `production_modes = 12`, `total_modes = 19`; `who_scene_it` and `court_carnival` both `status: "staging"`; `karate_endless` and `surfing` are missing from this copy (present in migration script version which has 14 production modes)
- **CRITICAL DISCREPANCY**: Migration script heredoc version has `production_modes: 14` with `karate_endless` and `surfing` as production; workspace file has `production_modes: 12` with only 12 modes listed
- **Fix script**: `infra/fel_gate1_fix.sh` — promotes `who_scene_it` + `court_carnival` to production and sets `production_modes = 14`

### 2. `backend/server.py` (NOT in workspace — defined in create_fel_migration.sh heredoc)
- **Role**: Flask API server — economy endpoints, neurocognitive session tracking
- **Key endpoints**: `POST /api/games/session`, `POST /api/modes/launch_stream_mode`, `POST /api/games/brain_brawl/submit`, `POST /api/neurocognitive/session`, `GET /api/neurocognitive/history`, `GET /api/neurocognitive/baseline`
- **Database**: MongoDB (`mongodb://localhost:27017/`) → `fel_db` — collections: `shard_transactions`, `neurocognitive_sessions`, `brain_brawl_sessions`, `game_sessions`
- **Economy constants**: `XP_CAP_PER_SESSION=500`, `SHARD_BASE = {win:50, draw:25, loss:15}`, `MODE_PRQ_WEIGHTS` (per mode)
- **Staging gate**: `launch_stream_mode` returns 403 for `skateboarding`, `snowboarding`, `who_scene_it`, `court_carnival`, `market_browse`
- **Location**: macOS machine at `/Users/elijahbonds/Documents/Unreal Projects/MyProject/backend/server.py` on `anti-gravity-fel` branch

### 3. `backend/core.py` (NOT in workspace — on macOS machine only)
- **Role**: Google GenAI SDK integration — gemini-2.5-flash LLM AI Coach interface, GEMINI_API_KEY mapping
- **State**: Confirmed by user (Round 21 log): "legacy emergent mock integrations replaced with standard Google GenAI SDK calls." 213 tests passing.
- **Location**: macOS machine, `anti-gravity-fel` branch on GitHub

### 4. `infra/ue5_config/DefaultGame.ini` (NOT in workspace — defined in create_fel_migration.sh heredoc)
- **Role**: [FELPlayMap] entries for all 19 modes — cooked iOS runtime map path source of truth
- **Key entries for staging modes**:
  - `who_scene_it=/Game/FEL/Venues/NeuroArena/NeuroArena`
  - `court_carnival=/Game/FEL/Venues/VeniceBeach/VeniceBeach`
  - `market_browse=/Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop`
- **Note**: The `Config/DefaultGame.ini` IN workspace is a DIFFERENT file — it only has `[/Script/EngineSettings.GeneralProjectSettings]` entries (project name, version, company). The [FELPlayMap] file lives at `infra/ue5_config/DefaultGame.ini` on the macOS machine.

### 5. `backend/ue_mode_maps.json` (NOT in workspace — defined in create_fel_migration.sh heredoc)
- **Role**: Backend-side map token registry mapping mode_id → Unreal map short name
- **Key entries**: `who_scene_it → Neuro_Arena`, `court_carnival → Venice_Beach_Court`, `market_browse → Vault_Shop`

### 6. `UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json` (NOT in workspace — defined in migration script heredoc)
- **Role**: Per-mode arena configuration (scoring, ball count, round count, duration)
- **Staging modes**: `who_scene_it: {bScoringEnabled: false, ballCount: 0}`, `court_carnival: {bScoringEnabled: false, ballCount: 0}`

### 7. `infra/fel_environment_layouts/court_carnival_environment_layout.md`
- **Role**: Full staging spec for court_carnival at Venice_Beach_Court
- **Spawn data**: 11 named spawn points (SP_SOCIAL_01–04, SP_ATW_START, SP_CARNIVAL_A/B, SP_RESET_01/02, SP_SPECTATE_01/02) with full XYZ coordinates
- **Interactive objects**: 7 ATW landmark posts (ATW_01–07) with coordinates, 6 carnival mini-game pads (CMP_01–06), 6 item spawn nodes (ITM_01–06), scoreboards, leaderboard pylons
- **Collision volumes**: Full table (COL_COURT_FLOOR, walls, fences, bleachers, OOB reset volumes)
- **Sublevels**: SL_VeniceBeach_Shell (always), SL_CourtCarnival_Dressing (load), SL_Basketball_Dressing (unload), SL_CourtCarnival_FX

### 8. `infra/fel_environment_layouts/who_scene_it_environment_layout.md`
- **Role**: Full staging spec for who_scene_it at Neuro_Arena
- **Media screens**: 9 total — MSC_HERO_01 (1024×576 hero), MSC_FLANK_L/R (512×288), MSC_CTX_01–04 (contestant answer screens), MSC_AMB_01–04 (ambient panels)
- **Activation state machine**: IDLE → BRIEFING → REVEAL → BUZZ_IN → RESULT → ROUND_END
- **Contestant platforms**: PLT_C1–C4 with coordinates, buzz-in triggers BZZ_01–04
- **Camera sweeps**: 7 named sweeps (SWP_INTRO, SWP_HERO_REVEAL, SWP_BUZZIN_HERO, SWP_CORRECT, SWP_WRONG, SWP_SCORE_REVEAL, SWP_FINAL_WINNER) with full cinematics parameters
- **Sublevels**: SL_NeuroArena_Shell, SL_WhoSceneIt_Dressing, SL_WhoSceneIt_Sequences, SL_WhoSceneIt_FX (load); SL_BrainBrawl_Dressing (unload)

### 9. `infra/hud/ws_hud_server.py`
- **Role**: WebSocket relay server for HUD overlay (ws://localhost:8080/ws/hud)
- **Protocol**: JSON messages — `score_update`, `prq_update`, `economy_update`, `mri_update`, `coach_tip`, `game_event`
- **Architecture**: Broadcast pattern — any connected client (UE5, backend, test) broadcasts to all other clients
- **Bridge**: This IS the backend side of the WKWebView HUD overlay bridge (not a WebKit JS bridge file)

### 10. `infra/ios/fel_ios_shipping_build.sh`
- **Role**: iOS Shipping build script (UE5.5 RunUAT BuildCookRun → xcarchive → IPA)
- **Target machine**: macOS M4 Pro Mac Mini only (`/Applications/UE_5.5`)
- **State**: xcarchive SUCCEEDED; exportArchive BLOCKED — no App Store provisioning profile for `com.finalevolutionlab.app`

### 11. `infra/android/fel_android_shipping_build.sh`
- **Role**: Android Shipping build script (UE5.5 RunUAT BuildCookRun → AAB/APK)
- **State**: Script written; ANDROID_HOME not set on Windows; keystore properties have placeholder values

### 12. `infra/fel_gate1_fix.sh`
- **Role**: Python script (embedded in bash) that promotes `who_scene_it` + `court_carnival` to `status: "production"` and sets `production_modes = 14` in `FEL_ModeManager.production.json`
- **Run location**: macOS clone, from `cd /Users/elijahbonds/Documents/rork-final-evolution-lab`

### 13. `create_fel_migration.sh`
- **Role**: Master migration script — writes all 15 source files as heredocs to a macOS UE project root
- **Entrypoint for all files NOT in workspace**: server.py, ue_mode_maps.json, ArenaSettings.json, GameMode.swift, MentalResiliencyEngine.swift, FELDeepLinkSubsystem.h/.cpp, FELNeuroCognitiveSubsystem.h/.cpp, infra/ue5_config/DefaultGame.ini, infra/ios/ExportOptions.plist, infra/fel_prebuild_ci_check.sh, and the 2 environment layout JSON files

### 14. `assets/fel_environment_layouts_ue57_ios_plan.md`
- **Role**: Master environment layout plan for all 14 venues across all 19 modes — full spawn standards, camera zone standards, collision volume standards, iOS budget tiers, venue-by-venue specs, smoke checklist
- **Critical reference**: Defines three-ring venue structure, Spawn Type A/B/C classifications, venue complexity tiers (A/B/C), per-map triangle budgets

### 15. `assets/fel_mode_implementation_package_ue57_ios.md`
- **Role**: Full implementation sheets for all 19 modes — sublevel names, spawn naming convention, camera names, collision names, trigger labels, interactable lists, iOS budgets, fallback logic, smoke tests
- **Naming convention**: `{Venue}_{Mode}_{Type}_{Index}` for all actors; SP_ / CZ_ / COL_ / TRG_ prefixes

### 16. `publish_status_report.json`
- **Role**: Current CI gate status + distribution prerequisites status
- **Gate 1**: FAILING (production_modes=12, required=14)
- **Gates 2–6**: All PASSING (confirmed in prior sessions)
- **iOS**: xcarchive SUCCEEDED on M4 Pro Mac Mini; exportArchive BLOCKED (no provisioning profile)
- **Android**: Build script written; keystore placeholders need filling

---

## Execution Path

### Backend Flow (economy/session)
```
iOS game client (UE5)
  → POST /api/games/session (backend/server.py Flask)
  → _calculate_xp(), _calculate_shards(), _calculate_prq_delta()
  → _pacing_bonus() [5% bonus if pacing_score ≥ 75]
  → MongoDB (fel_db.shard_transactions + game_sessions)
  → JSON response {session_id, xp_awarded, shards_awarded, prq_delta, neurocognitive{}}
```

### AI Coach Flow
```
iOS game client / HUD
  → backend/core.py (Google GenAI SDK, gemini-2.5-flash)
  → GEMINI_API_KEY (env var)
  → LLM generates coach_tip
  → ws_hud_server.py broadcast → WKWebView HUD overlay (FELHud.tsx, HUD_AICoachPrompt.tsx)
```

### Mode Launch / Deep Link Flow
```
iOS URL scheme: fel://play/{mode_id}
  → UFELDeepLinkSubsystem::HandleDeepLink()
  → GetModeToVenueMap().Find(ModeId) → /Game/FEL/Venues/{Venue}/{Venue}
  → UGameplayStatics::OpenLevel(GetWorld(), VenueMapPath)
```

### HUD WebSocket Flow
```
UE5 C++ subsystem (BPFL_HUDManager)
  → ws://localhost:8080/ws/hud
  → ws_hud_server.py (relay broadcast)
  → WKWebView JavaScript receives JSON
  → React TSX HUD components update (FELHud.tsx renders all overlay elements)
```

### Neurocognitive Flow
```
iOS session data (HRV samples, context switches, input lag, pacing events)
  → MentalResiliencyEngine.swift (TierA/B/C compute)
  → MRI score → WKWebView bridge payload JSON
  → UFELNeuroCognitiveSubsystem::UpdateFromBridgePayload()
  → Modifiers (ComboDecay, PerfectGuardWindow, QTEApexWindow) applied in gameplay
```

### Build / Distribution Flow
```
macOS M4 Pro Mac Mini:
  bash infra/ios/fel_ios_shipping_build.sh
    → /Applications/UE_5.5/Engine/Build/BatchFiles/RunUAT.sh BuildCookRun (iOS Shipping)
    → xcarchive → [BLOCKED] xcodebuild -exportArchive (needs provisioning profile)
    → bash infra/ios/fel_reexport_ipa.sh → IPA
    → bash infra/ios/fel_appstore_connect.sh → xcrun altool → TestFlight/App Store
```

---

## Guidance for the Modifying Agent

### 1. Gate 1 Fix — Priority Blocker
- **File to modify**: `/backend/FEL_ModeManager.production.json`
- **Change**: Promote `who_scene_it` and `court_carnival` from `status: "staging"` to `status: "production"`, set `production_modes = 14`
- **Script to run on macOS**: `bash infra/fel_gate1_fix.sh` (embedded Python does it safely)
- **Also needed**: Add `karate_endless` and `surfing` to the registry (currently missing from workspace copy but present in migration script version)
- **Do not** edit this file on Windows; `publish_status_report.json` confirms the bridge was offline on Windows

### 2. backend/server.py — Lives on macOS machine
- Source is the heredoc in `create_fel_migration.sh` (lines ~180–260)
- On the macOS machine at `/Users/elijahbonds/Documents/Unreal Projects/MyProject/backend/server.py`
- Also available on GitHub `anti-gravity-fel` branch
- The p1 economy patch (`p1_economy_patch.py` + `apply_p1_economy.sh`) modifies it with outcome-based PRQ delta, 5% pacing bonus, and mri_score parameter
- **MongoDB**: no separate config file — connection string hardcoded as `mongodb://localhost:27017/`
- **No Firebase**: Firebase is not used in this project anywhere

### 3. frontend/src — Does not exist in workspace
- `create_fel_migration.sh` creates `frontend/src/hud`, `frontend/src/stores`, `frontend/src/hooks` directories but writes NO files to them
- The HUD UI layer is the TSX files in `FinalEvolutionLab/UI/HUD/` (inside UE project), not a standalone React app
- There is no `LandingPage.js`, no React router, no web download page in this workspace
- No Wix integration anywhere

### 4. WebKit Bridge — No JS files exist
- The WebKit bridge between UE5 and the WKWebView HUD is described in specs but no `felUE5Bridge.js` or `fel-bridge.js` exists
- No `docs/WEBKIT_BRIDGE.md` exists
- The communication is handled via `ws_hud_server.py` WebSocket relay (Python side) and `BPFL_HUDManager.cpp` (UE5 C++ side)
- The HUD TSX components connect to `ws://localhost:8080/ws/hud` directly

### 5. VenueRegistry files — Do not exist in workspace
- `backend/FEL_VenueRegistry.production.json` — ABSENT from workspace and NOT in migration script
- `UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json` — ABSENT
- Venue routing is handled by `infra/ue5_config/DefaultGame.ini` [FELPlayMap] entries and `backend/ue_mode_maps.json` (both defined only in migration script heredocs)

### 6. ArenaSettings.json — Not in workspace
- `UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json` is defined in migration script heredoc only
- Staging modes (`who_scene_it`, `court_carnival`) have `bScoringEnabled: false, ballCount: 0` in that file

### 7. DefaultGame.ini — Two different files, don't confuse them
- `Config/DefaultGame.ini` (IN workspace) = project metadata only (ProjectID, Version, Company)
- `infra/ue5_config/DefaultGame.ini` (macOS only, in migration script) = [FELPlayMap] routing
- The [FELPlayMap] section referenced in the ModeManager JSON note lives in the SECOND file

### 8. iOS Distribution — Current blockers
- `infra/ios/ExportOptions.plist` needs three placeholders filled: `REPLACE_WITH_TEAM_ID`, `REPLACE_WITH_BUNDLE_ID`, `REPLACE_WITH_PROVISIONING_PROFILE_NAME`
- App Store Distribution provisioning profile must be downloaded from developer.apple.com for `com.finalevolutionlab.app`
- Run `bash infra/ios/fel_ios_shipping_build.sh` on M4 Pro Mac Mini ONLY

### 9. Android Distribution — Not ready
- `infra/android/fel_keystore.properties` has placeholder values that need real keystore credentials
- `GOOGLE_PLAY_JSON_KEY_PATH` in `upload_to_google_play.sh` needs to be filled

### 10. Emergent naming convention — Not a third-party service
- `FELEmergentDeepLinkSubsystem` = UE5 deep-link routing class (iOS URL scheme → map path)
- "emergent" in `[FELPlayMap]` = mode-to-venue routing table name, coined by this project
- The ONLY legacy "emergent" was mock AI stubs in `backend/core.py` — replaced by Google GenAI SDK (confirmed Round 21 log)

---

## Risks / Unknowns

1. **Gate 1 mismatch**: Workspace `FEL_ModeManager.production.json` has `production_modes=12` and is missing `karate_endless` and `surfing` entries entirely. Migration script targets `production_modes=14` with a different registry. The `fel_gate1_fix.sh` only promotes 2 modes — it does not add the 2 missing ones. This needs verification on the macOS machine.

2. **backend/core.py content**: Not readable from this workspace. The file is on the macOS machine. Its structure (GEMINI_API_KEY env var name, LLM chat interface, image scanning logic) is known only from the user's Round 21 log statement. Needs direct inspection on macOS.

3. **`[FELPlayMap]` scope**: The spec doc says this is the "cooked iOS runtime map path source of truth." But `infra/ue5_config/DefaultGame.ini` (migration script output) vs `Config/DefaultGame.ini` (workspace file with only project settings) — which one actually gets cooked into the iOS build? Needs verification that `RunUAT.sh` reads `infra/ue5_config/DefaultGame.ini` and not `Config/DefaultGame.ini`.

4. **WKWebView bridge implementation**: No JS bridge file exists. The mechanism by which the WKWebView receives data from UE5 (beyond WebSocket) is undocumented in workspace files. `UFELNeuroCognitiveSubsystem::UpdateFromBridgePayload()` suggests JSON is passed from the web layer INTO UE5 (WKWebView → UE5), not only the reverse.

5. **MongoDB vs alternative DB**: `server.py` heredoc uses MongoDB. But CI Gate 5 confirmation note says "confirmed_pass_server.py_utf16_XP_CAP_SHARD_BASE_prq_delta_neuro" — there may be a UTF-16 encoded version of server.py on the macOS machine that differs from the heredoc version.

6. **staging → production promotion logic**: `court_carnival.gamemode_class` = `/Script/FEL.BP_CourtCarnival` in the environment layout JSON, but `who_scene_it` has `gamemode_class: "BP_WhoSceneIt_GameMode"` (inconsistent format — one uses full path prefix, one doesn't). The migration script `FEL_ModeManager.production.json` version marks both as `status: "preview"`, while the workspace copy marks them as `status: "staging"`. The gate fix script promotes both to `status: "production"`. Confirm which status is intended before running.

7. **`infra/ios/fel_reexport_ipa.sh`**: Referenced in `fel_ios_shipping_build.sh` as a step but this file path is not in the workspace file list (it was mentioned as WRITTEN in the May 23 publish_status_report but not present in the current workspace scan). Needs verification.

8. **`UnrealStarter/` directory**: Referenced in migration script for ArenaSettings.json and VenueRegistry paths. Does not exist in workspace. These targets only make sense on the macOS project root where the UE project lives.

9. **No `.env` contents read**: `/.env` exists at workspace root but was not read. It likely contains API keys (GEMINI_API_KEY, MongoDB connection, etc.) — verify before any cloud deployment.

10. **Frontend completely absent**: If a web landing page, download page, or React app is planned, no code exists in this workspace. All "frontend" is the UE5 WKWebView HUD overlay (TSX files), not a standalone web project.
