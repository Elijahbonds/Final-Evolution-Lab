## File Addresses

### Confirmed present in Seele workspace (/assets/games/final_evolution_lab/workspace/):
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameModeBase.h
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameplayManager.h
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameplayManager.cpp
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELSessionReceiptComponent.h
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/FELHud.tsx
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_ScoreBar.tsx
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_PRQMeter.tsx
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_MRIMeter.tsx
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_ShardCounter.tsx
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_AICoachPrompt.tsx
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_ComboFeed.tsx
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/BPFL_HUDManager.h
/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/BPFL_HUDManager.cpp
/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_MainMenu.h
/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_ModeSelect.h
/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_MarketBrowse.h
/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_MatchResult.h
/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_ModeDetail.h
/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_EconomyDashboard.h
/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_Profile.h
/assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_Settings.h
/assets/games/final_evolution_lab/workspace/Config/DefaultGame.ini
/assets/games/final_evolution_lab/workspace/Config/DefaultEngine.ini
/assets/games/final_evolution_lab/workspace/infra/ios/fel_ios_shipping_build.sh
/assets/games/final_evolution_lab/workspace/infra/android/fel_android_shipping_build.sh
/assets/games/final_evolution_lab/workspace/infra/android/fel_keystore.properties
/assets/games/final_evolution_lab/workspace/infra/distribution/FEL_DISTRIBUTION_CHECKLIST.md
/assets/games/final_evolution_lab/workspace/infra/distribution/Fastfile
/assets/games/final_evolution_lab/workspace/infra/hud/ws_hud_server.py
/assets/games/final_evolution_lab/workspace/infra/fel_gate1_fix.sh
/assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/court_carnival_environment_layout.json
/assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/court_carnival_environment_layout.md
/assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/who_scene_it_environment_layout.json
/assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/who_scene_it_environment_layout.md
/assets/games/final_evolution_lab/workspace/create_fel_migration.sh
/assets/games/final_evolution_lab/workspace/publish_status_report.json
/assets/games/final_evolution_lab/final_evolution_lab.json

### Present on macOS only (created by create_fel_migration.sh heredocs):
[macOS]/backend/FEL_ModeManager.production.json
[macOS]/backend/ue_mode_maps.json
[macOS]/backend/server.py
[macOS]/infra/ue5_config/DefaultGame.ini  (contains [FELPlayMap] for all 19 modes)
[macOS]/FinalEvolutionLab/Models/GameMode.swift
[macOS]/FinalEvolutionLab/Services/MentalResiliencyEngine.swift
[macOS]/UnrealIntegration/Source/FinalEvolutionLab/FELDeepLinkSubsystem.h
[macOS]/UnrealIntegration/Source/FinalEvolutionLab/FELEmergentDeepLinkSubsystem.cpp
[macOS]/UnrealIntegration/Source/FinalEvolutionLab/FELNeuroCognitiveSubsystem.h
[macOS]/UnrealIntegration/Source/FinalEvolutionLab/FELNeuroCognitiveSubsystem.cpp
[macOS]/UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json
[macOS]/infra/ios/ExportOptions.plist  (has REPLACE_WITH_* placeholders — NOT yet filled)
[macOS]/infra/fel_prebuild_ci_check.sh
[macOS]/infra/ios/fel_reexport_ipa.sh
[macOS]/infra/ios/fel_appstore_connect.sh
[macOS]/infra/android/upload_to_google_play.sh

### Confirmed ABSENT from Seele workspace:
- backend/FEL_ModeManager.production.json  (DOES NOT EXIST in /assets/.../workspace/)
- Any .umap / .uasset / .uproject / .uplugin files
- DefaultGame.ini [FELPlayMap] section (workspace DefaultGame.ini has only [GeneralProjectSettings])
- infra/ue5_config/DefaultGame.ini (macOS only)
- All UnrealIntegration/Source/ files
- FinalEvolutionLab/Models/GameMode.swift
- FinalEvolutionLab/Services/MentalResiliencyEngine.swift

---

## Summary

1. **19 modes defined, 14 have C++ game mode classes** — skateboarding, snowboarding, who_scene_it, court_carnival (+ market_browse as non-game-module) have NO C++ implementation; they are registry-only stubs.
2. **Gate 1 FAILING**: publish_status_report.json confirms production_modes=12 on macOS; who_scene_it and court_carnival remain "preview" status. Fix via `infra/fel_gate1_fix.sh` on macOS.
3. **FEL_ModeManager.production.json is NOT in this Seele workspace** — it lives at `backend/FEL_ModeManager.production.json` relative to the macOS UE project root, created by `create_fel_migration.sh`.
4. **14 concrete C++ game mode classes are fully implemented** in FELGameModeBase.h (basketball×3, karate×2, baseball, football, soccer, golf, tennis, volleyball, surfing, gymnastics, brain_brawl).
5. **Phase 6 HUD**: 7 TSX files fully present and implemented (FELHud + 6 subcomponents), WebSocket relay server written, BPFL_HUDManager C++ bridge present.
6. **Phase 7/8 infra fully present**: iOS + Android build scripts, Fastfile, distribution checklist, gate1 fix script — all in workspace.
7. **Comprehensive environment layout specs** for court_carnival (Venice_Beach_Court) and who_scene_it (Neuro_Arena) exist as both JSON and Markdown with full coordinate tables, spawn points, camera zones, and collision volumes.
8. **Config/DefaultGame.ini in workspace** contains only GeneralProjectSettings (Phase 8 appended); the [FELPlayMap] block is in the macOS-only infra/ue5_config/DefaultGame.ini.

---

## Project Overview

- **Purpose**: "Final Evolution AI Coach" — 19-mode multi-sport mobile game with a neurocognitive coaching engine (MRI/ARV/ESI), shard economy, AI coach HUD, UE5 C++ gameplay, and React TSX HUD overlay.
- **Stack**:
  - Engine: Unreal Engine 5.5 (UE5.5 at `/Applications/UE_5.5` on Mac)
  - C++: UE5 UCLASS hierarchy — FELGameModeBase → 14 sport subclasses; UFELGameplayManager (UGameInstanceSubsystem); UFELSessionReceiptComponent (UActorComponent)
  - Frontend HUD: React/TSX over UE5 WebBrowserWidget, served at http://localhost:3000/hud, connected to ws://localhost:8080/ws/hud
  - Backend: Flask + MongoDB (server.py at macOS), session receipt POST to https://finalevolutiongroup.com/games/session
  - iOS native: Swift — GameMode.swift enum (19 cases), MentalResiliencyEngine.swift (HRV/RMSSD)
  - Deep link: `finalevolution://launch?map={venue}&mode={mode_id}&session={uuid}`
  - Infra: bash build scripts (UE RunUAT), Fastlane, Python CI gate check
- **Key directories** (macOS UE project root):
  - `FinalEvolutionLab/Gameplay/` — C++ game mode + session receipt
  - `FinalEvolutionLab/UI/HUD/` — React TSX HUD bundle
  - `Content/FEL/UI/Menus/` — CommonUI WBP widget headers (8 widgets)
  - `backend/` — Flask server, FEL_ModeManager, ue_mode_maps
  - `infra/` — CI gates, build scripts, environment layouts
  - `Config/` — DefaultGame.ini (GeneralProjectSettings), DefaultEngine.ini (iOS/Android runtime)
  - `UnrealIntegration/Source/FinalEvolutionLab/` — DeepLink + NeuroCognitive subsystems
- **Relevant configs**:
  - DefaultEngine.ini: bundle=com.finalevolutionlab.app, iOS 16+, Android API 26–34 (ARM64, Vulkan)
  - DefaultGame.ini: ProjectVersion=1.0.0, ProjectName="Final Evolution AI Coach"
  - [FELPlayMap] entries: macOS only in infra/ue5_config/DefaultGame.ini (all 19 modes mapped)
- **Architecture**:
  - All 19 modes registered in FEL_ModeManager.production.json and ue_mode_maps.json
  - 14 production modes have C++ AFELGameMode subclass + outcome evaluator + arena settings
  - 5 non-production modes (skateboarding, snowboarding, who_scene_it, court_carnival, market_browse) lack C++ implementation
  - Session flow: GameMode → AFELGameModeBase::EndMatch → UFELGameplayManager::OnMatchEnd → ComputeSessionResult → DispatchSessionReceipt (HTTP POST) + UFELSessionReceiptComponent::ProcessMatchResult (HUD broadcast)

---

## Relevant Files — Detail

### FELGameModeBase.h
- Path: `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameModeBase.h`
- Role: Abstract base + 14 concrete C++ game mode subclasses
- Key detail: Contains AFELGameMode_BasketballH2H through AFELGameMode_BrainBrawl (14 classes). Abstract base declares: StartMatch(), EndMatch(), GetModeId(), GetMatchDuration(), OnMatchEnd delegate. Protected: VenueId (EditDefaultsOnly), GameplayManager ptr, ComputeMRI().
- MISSING: skateboarding, snowboarding, who_scene_it, court_carnival, market_browse subclasses.

### FELGameplayManager.h + .cpp
- Path: `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameplayManager.h`
- Role: UGameInstanceSubsystem — win/loss evaluation + P1 economy computation + HTTP session receipt dispatch
- Key detail:
  - ModeWeights map: 14 entries (football 1.5, karate 1.4, basketball_3v3 1.3 … golf 0.9). Missing 5 staging/preview modes.
  - Economy constants: PRQ_WIN=2.0, PRQ_DRAW=0.5, PRQ_LOSS=0.2; SHARD_WIN=50, SHARD_DRAW=25, SHARD_LOSS=15; XP_CAP=500
  - MRI formula: ARV×0.40 + (100−ESI)×0.35 + PacingScore×0.25
  - HTTP endpoint: https://finalevolutiongroup.com/games/session (production URL in C++)
  - 11 mode-specific outcome evaluators (basketball, karate, baseball, football, soccer, golf, tennis, volleyball, surfing, gymnastics, brain_brawl). NO evaluators for skateboarding/snowboarding/who_scene_it/court_carnival.

### FELSessionReceiptComponent.h
- Path: `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELSessionReceiptComponent.h`
- Role: UActorComponent attached to APawn; broadcasts FFELRewardReadyDelegate (XP, Shards) and FFELPRQUpdateDelegate (PRQDelta) to HUD
- Key detail: ProcessMatchResult() called by GameMode; BuildMatchResultDeepLink() builds payload for WBP_MatchResult; BroadcastEconomyHUDUpdate() pushes to ws_hud_server.py.

### Phase 6 HUD TSX files
- Path: `/assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/`
- All 7 files present and complete:
  - FELHud.tsx — master bundle; loaded by BPFL_HUDManager::LoadFELHud(WebBrowserWidget, "http://localhost:3000/hud")
  - HUD_ScoreBar.tsx — WS type "score_update" → {home_score, away_score, timer_seconds, period}; fixed at top-center
  - HUD_PRQMeter.tsx — WS type "prq_update" → {prq_score, mode_weight_label, max_prq}; circular SVG; right side
  - HUD_MRIMeter.tsx — WS type "mri_update" → {mri_score, arv, esi, pacing}; 3-segment bar; left side
  - HUD_ShardCounter.tsx — WS type "economy_update" → {shards, xp, xp_cap}; top-right
  - HUD_AICoachPrompt.tsx — WS type "coach_tip" → {tip_text, mode_name}; bottom-center; 5s auto-dismiss
  - HUD_ComboFeed.tsx — WS type "game_event" → {event_type, description, timestamp}; bottom-left; last 5 events
  - All components: auto-reconnect WebSocket (3s retry), WS_URL hardcoded as 'ws://localhost:8080/ws/hud'
- BPFL_HUDManager.h/.cpp: LoadFELHud(), BroadcastHUDMessage(), SetHUDVisible() — bridge between UE and WebBrowserWidget

### infra/hud/ws_hud_server.py
- Path: `/assets/games/final_evolution_lab/workspace/infra/hud/ws_hud_server.py`
- Role: asyncio WebSocket relay; listens on ws://localhost:8080/ws/hud; broadcasts messages from any sender to all other connected clients
- Requires: `pip install websockets`; start with `python ws_hud_server.py [--port 8080]`

### Phase 7/8 Infra Scripts
- `infra/ios/fel_ios_shipping_build.sh` — RunUAT BuildCookRun for iOS Shipping; requires UE5.5 at /Applications/UE_5.5; auto-calls fel_reexport_ipa.sh if present
- `infra/android/fel_android_shipping_build.sh` — RunUAT BuildCookRun for Android Shipping; ARM64 only; requires ANDROID_HOME/ANDROID_SDK_ROOT
- `infra/distribution/Fastfile` — Fastlane 2.220.0; iOS lanes: build_ipa, upload_testflight, promote_appstore; Android lanes: build_aab, upload_internal, promote_production
- `infra/fel_gate1_fix.sh` — Python3 script to promote who_scene_it + court_carnival from "preview" → "production" and set production_modes=14; run on macOS

### Config files
- `Config/DefaultGame.ini` — ONLY has [/Script/EngineSettings.GeneralProjectSettings]: ProjectID, ProjectName, ProjectVersion=1.0.0, CompanyName. NO [FELPlayMap] section.
- `Config/DefaultEngine.ini` — iOS: bundle com.finalevolutionlab.app, iOS 16 min, landscape only. Android: com.finalevolutionlab.app, API 26 min/34 target, ARM64, Vulkan.
- [FELPlayMap] lives at [macOS]/infra/ue5_config/DefaultGame.ini (all 19 modes mapped to /Game/FEL/Venues/ paths)

### Environment Layout Specs (both in workspace)
- `infra/fel_environment_layouts/court_carnival_environment_layout.md` — Venice_Beach_Court: 7 ATW landmark coordinates (ATW_01–07 with cm positions), 6 carnival mini-game pads (CMP_01–06), 6 pickup nodes (ITM_01–06), 11 social spawn points (SP_SOCIAL_01–04, SP_ATW_START, SP_CARNIVAL_A/B, SP_RESET_01/02, SP_SPECTATE_01/02), 7 camera zones (CAM_DEFAULT, CAM_ATW_WIDE, CAM_ATW_HERO, CAM_CARNIVAL_E/W, CAM_TRICKTSHOT, CAM_RESULT), 11 collision volumes, 4 sublevels (SL_VeniceBeach_Shell + SL_CourtCarnival_Dressing + SL_CourtCarnival_FX; SL_Basketball_Dressing UNLOADED)
- `infra/fel_environment_layouts/who_scene_it_environment_layout.md` — Neuro_Arena: 9 media screens (MSC_HERO_01 1024×576, MSC_FLANK_L/R 512×288, MSC_CTX_01–04 512×288, MSC_AMB_01–04 flipbook), 4 contestant platforms (PLT_C1–C4 at X=320 with Y offsets 560/0/−560/−840), 5 spawn points (SP_CONTESTANT_01–04, SP_HOST, SP_RESET_STAGE, SP_SPECTATE_01/02), 4 buzz-in triggers (BZZ_01–04 with box extents 100×100×160), 7 cinematic camera sweeps (SWP_INTRO through SWP_FINAL_WINNER), 13 collision volumes, 5 sublevels (SL_NeuroArena_Shell + SL_WhoSceneIt_Dressing + SL_WhoSceneIt_Sequences + SL_WhoSceneIt_FX; SL_BrainBrawl_Dressing UNLOADED)
- Media screen activation state machine: IDLE → BRIEFING → REVEAL → BUZZ_IN → RESULT → ROUND_END

### Menu WBP headers (stub headers only, no .cpp implementations)
- WBP_MainMenu.h — OnPlayPressed/OnMarketPressed/OnProfilePressed
- WBP_ModeSelect.h — FFELModeEntry struct (ModeId, DisplayName, VenueId, ThumbnailPath, bLocked), OnModeTileSelected, PopulateModeEntries
- WBP_ModeDetail.h — OnStartMatchPressed (fires deep link: finalevolution://launch?map={venue}&mode={mode_id}&session={uuid}), GenerateSessionUUID
- WBP_MatchResult.h — EFELMatchOutcome enum, XPEarned/ShardsEarned/PRQDelta, PlayRewardAnimation (BlueprintImplementableEvent)
- WBP_MarketBrowse.h — FFELMarketItem struct (ItemId, ShardCost, bOwned), OnFilterChanged, OnItemPurchasePressed
- WBP_EconomyDashboard.h — FFELSessionRecord struct, SessionHistory TArray (last 10), FetchSessionHistory
- WBP_Profile.h — FFELProfileData (DisplayName, TotalXP, PRQScore, ShardBalance, PRQHistory7Day), FetchProfile
- WBP_Settings.h — BGMVolume, SFXVolume, bHapticsEnabled, bNeurocognitiveEngineEnabled (default=false), ApplySettings, PersistSettings

### FEL_ModeManager.production.json (NOT in Seele workspace)
- Expected macOS path: `[macOS project root]/backend/FEL_ModeManager.production.json`
- Canonical content (per create_fel_migration.sh heredoc):
  - total_modes: 19
  - production_modes: 14 (field value; but publish_status_report says actual=12 on macOS)
  - mode_registry: 19 entries — 14 with status "production", skateboarding/snowboarding "staging", who_scene_it "preview", court_carnival "preview" + gamemode_class "/Script/FEL.BP_CourtCarnival", market_browse type "non-game-module"
  - Gate 1 CI check counts actual "production" status values from registry; requires PC≥14

### ue_mode_maps.json (NOT in Seele workspace)
- Expected macOS path: `[macOS project root]/backend/ue_mode_maps.json`
- Unreal map names (from create_fel_migration.sh heredoc):
  - basketball_h2h/dunk/3v3/surfing → Venice_Beach
  - karate_h2h/endless → Dojo
  - baseball → Baseball_Park
  - football → Gridiron
  - soccer → Soccer_Stadium
  - golf → Links
  - tennis → Tennis_Court
  - volleyball → Sand_Court
  - gymnastics → Training_Floor
  - brain_brawl/who_scene_it → Neuro_Arena
  - skateboarding → Skate_Park
  - snowboarding → Mountain_Slope
  - court_carnival → Venice_Beach_Court
  - market_browse → Vault_Shop

### ArenaSettings.json (NOT in Seele workspace)
- Expected macOS path: `[macOS project root]/UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json`
- All 19 modes have entries; who_scene_it, court_carnival, market_browse all have bScoringEnabled=false, ballCount=0 (no gameplay configuration beyond stub)

---

## Mode Implementation Status (All 19 Modes)

| Mode | C++ Class | Outcome Evaluator | ModeWeight | Arena Settings | Environment Layout | [FELPlayMap] Entry |
|---|---|---|---|---|---|---|
| basketball_h2h | ✅ AFELGameMode_BasketballH2H (240s) | ✅ EvaluateBasketballOutcome | 1.2 | ✅ | — | ✅ /Game/FEL/Venues/VeniceBeach/VeniceBeach |
| basketball_dunk | ✅ AFELGameMode_BasketballDunk (90s) | ✅ EvaluateBasketballOutcome | 1.0 | ✅ | — | ✅ same |
| basketball_3v3 | ✅ AFELGameMode_Basketball3v3 (300s) | ✅ EvaluateBasketballOutcome | 1.3 | ✅ | — | ✅ same |
| karate_h2h | ✅ AFELGameMode_KarateH2H (120s) | ✅ EvaluateKarateOutcome | 1.4 | ✅ | — | ✅ /Game/FEL/Venues/Dojo/Dojo |
| karate_endless | ✅ AFELGameMode_KarateEndless (999s) | ✅ EvaluateKarateOutcome | 1.4 | ✅ bEndlessMode | — | ✅ same |
| baseball | ✅ AFELGameMode_Baseball | ✅ EvaluateBaseballOutcome (at inning≥9) | 1.0 | ✅ 9 rounds | — | ✅ /Game/FEL/Venues/BaseballPark/BaseballPark |
| football | ✅ AFELGameMode_Football (300s) | ✅ EvaluateFootballOutcome | 1.5 | ✅ | — | ✅ /Game/FEL/Venues/Gridiron/Gridiron |
| soccer | ✅ AFELGameMode_Soccer (270s) | ✅ EvaluateSoccerOutcome | 1.1 | ✅ | — | ✅ /Game/FEL/Venues/SoccerStadium/SoccerStadium |
| golf | ✅ AFELGameMode_Golf | ✅ EvaluateGolfOutcome (≤par−2=win, ≤par+2=draw) | 0.9 | ✅ 18 holes | — | ✅ /Game/FEL/Venues/Links/Links |
| tennis | ✅ AFELGameMode_Tennis | ✅ EvaluateTennisOutcome | 1.1 | ✅ | — | ✅ /Game/FEL/Venues/TennisCourt/TennisCourt |
| volleyball | ✅ AFELGameMode_Volleyball | ✅ EvaluateVolleyballOutcome (≥25 pts, ≥2 gap) | 1.2 | ✅ | — | ✅ /Game/FEL/Venues/SandCourt/SandCourt |
| gymnastics | ✅ AFELGameMode_Gymnastics (GOLD_THRESHOLD=85) | ✅ EvaluateGymnasticsOutcome | 1.0 | ✅ 90s routines | — | ✅ /Game/FEL/Venues/TrainingFloor/TrainingFloor |
| brain_brawl | ✅ AFELGameMode_BrainBrawl (10s/Q, SubmitAnswer) | ✅ EvaluateBrainBrawlOutcome | 1.0 | ✅ 20 questions | — | ✅ /Game/FEL/Venues/NeuroArena/NeuroArena |
| surfing | ✅ AFELGameMode_Surfing (GOLD_THRESHOLD=75) | ✅ EvaluateSurfingOutcome | 1.05 | ✅ 60s waves | — | ✅ /Game/FEL/Venues/VeniceBeach/VeniceBeach |
| skateboarding | ❌ No C++ class | ❌ No evaluator | ❌ Not in weights | ✅ stub only | ❌ | ✅ /Game/FEL/Venues/Skate_Park/Skate_Park (STAGING) |
| snowboarding | ❌ No C++ class | ❌ No evaluator | ❌ Not in weights | ✅ stub only | ❌ | ✅ /Game/FEL/Venues/Mountain_Slope/Mountain_Slope (STAGING) |
| who_scene_it | ❌ No C++ class (class named in JSON as BP_WhoSceneIt_GameMode) | ❌ No evaluator | ❌ Not in weights | ✅ bScoringEnabled=false | ✅ Full spec (Neuro_Arena) | ✅ /Game/FEL/Venues/NeuroArena/NeuroArena (PREVIEW) |
| court_carnival | ❌ No C++ class (gamemode_class=/Script/FEL.BP_CourtCarnival) | ❌ No evaluator | ❌ Not in weights | ✅ bScoringEnabled=false | ✅ Full spec (Venice_Beach_Court) | ✅ /Game/FEL/Venues/VeniceBeach/VeniceBeach (PREVIEW) |
| market_browse | ❌ Non-game-module | ❌ N/A | ❌ N/A | ✅ bScoringEnabled=false | ❌ | ✅ /Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop |

**Bottom line**: 14 modes fully implemented in C++ (classes + evaluators). 5 modes stub-only (registry + ArenaSettings + FELPlayMap only).

---

## Spawn Point / Coordinate Data (from environment layout specs)

### court_carnival (Venice_Beach_Court) — FULL COORDINATE TABLE EXISTS
Origin: center-court logo; +X toward north backboard; +Y toward player-right; cm units.

**ATW Shooting Landmarks (world coordinates)**:
- ATW_01 Right Corner: (620, 660, 0) — 3pts, 680cm shot distance, 8° aim assist
- ATW_02 Right Wing: (480, 520, 0) — 2pts, 540cm
- ATW_03 Right Elbow: (300, 310, 0) — 2pts, 360cm
- ATW_04 Top of Key: (0, 0, 0) — 2pts, 490cm
- ATW_05 Left Elbow: (300, −310, 0) — 2pts
- ATW_06 Left Wing: (480, −520, 0) — 2pts
- ATW_07 Left Corner: (620, −660, 0) — 3pts

**Spawn Points**: SP_SOCIAL_01 (−200,0,0), SP_SOCIAL_02 (200,0,0), SP_SOCIAL_03 (0,600,0), SP_SOCIAL_04 (0,−600,0), SP_ATW_START (680,700,0), SP_CARNIVAL_A (−350,680,0), SP_CARNIVAL_B (−350,−680,0), SP_RESET_01 (−730,0,0), SP_RESET_02 (730,0,0), SP_SPECTATE_01 (−820,350,120), SP_SPECTATE_02 (−820,−350,120)

**Mini-game Pads**: CMP_01 Ring Toss (−420,760,0), CMP_02 Free Throw Blitz (−560,0,0), CMP_03 Ring Toss (−420,−760,0), CMP_04 Trick Shot Ramp (650,0,0), CMP_05 Score Blitz (0,760,0), CMP_06 Score Blitz (0,−760,0)

**Collision volumes**: COL_COURT_FLOOR box (0,0,−2) ext (780,750,4); RST_NORTH/SOUTH/EAST/WEST_OOB kill volumes; COL_BLEACHER_E/W hard boxes; COL_NORTH/SOUTH_WALL; COL_EAST/WEST_FENCE soft

**Camera zones**: CAM_DEFAULT (0,0,120) ext (1200,1400,400); CAM_ATW_WIDE (400,0,200) ext (900,1400,300); CAM_ATW_HERO per-station 300cm behind approach vector; CAM_CARNIVAL_E/W (±760 Y); CAM_TRICKTSHOT (650,0,200); CAM_RESULT (0,0,300)

**Sublevel composition**: LOAD: SL_VeniceBeach_Shell, SL_CourtCarnival_Dressing, SL_CourtCarnival_FX. UNLOAD: SL_Basketball_Dressing.
iOS budget: ≤950k triangles, ≤8 FX emitters, ≤400 GPU particles.

### who_scene_it (Neuro_Arena) — FULL COORDINATE TABLE EXISTS
Origin: center stage floor; cm units.

**Contestant Platforms**: PLT_C1 (320,560,0), PLT_C2 (320,0,0), PLT_C3 (320,−560,0), PLT_C4 (320,−840,0) [conditional on bFourthContestantActive]
**Spawn Points**: SP_CONTESTANT_01 (480,560,0), SP_CONTESTANT_02 (480,0,0), SP_CONTESTANT_03 (480,−560,0), SP_CONTESTANT_04 (480,−840,0), SP_HOST (−320,0,0), SP_RESET_STAGE (500,0,0), SP_SPECTATE_01 (0,920,200), SP_SPECTATE_02 (0,−920,200)
**Buzz-in triggers**: BZZ_01–04 box extent (100,100,160) per platform; lock-out logic in BP_WhoSceneIt_GameMode.OnBuzzInReceived()

**Media screens**:
- MSC_HERO_01 (−860,0,480) — 640cm×360cm, 1024×576 render target, UMediaPlayerComponent
- MSC_FLANK_L (−820,520,420) yaw 25°, MSC_FLANK_R (−820,−520,420) yaw −25° — 512×288
- MSC_CTX_01–04 above each platform — 512×288, contestant answer preview
- MSC_AMB_01–04 — UTexture2D flipbook only (no render target, iOS safe)

**Camera sweeps (7 total)**: SWP_INTRO (4.0s), SWP_HERO_REVEAL (2.5s), SWP_BUZZIN_HERO (1.8s, runtime-parameterized to contestant Y), SWP_CORRECT (3.2s), SWP_WRONG (1.4s), SWP_SCORE_REVEAL (3.5s), SWP_FINAL_WINNER (5.0s, WinnerY runtime-resolved)
Priority: SWP_CORRECT overrides SWP_BUZZIN_HERO within 0.3s window. All sweep cameras non-ticking when idle.

**Sublevel composition**: LOAD: SL_NeuroArena_Shell, SL_WhoSceneIt_Dressing, SL_WhoSceneIt_Sequences, SL_WhoSceneIt_FX. UNLOAD: SL_BrainBrawl_Dressing.
iOS budget: ≤1 live render target (hero only during REVEAL), ≤2 active render targets total, ≤6 GPU emitters.

---

## Execution Path

### Match session flow (production modes):
```
WBP_ModeDetail::OnStartMatchPressed()
  → fires finalevolution://launch?map={venue}&mode={mode_id}&session={uuid}
  → UFELDeepLinkSubsystem::HandleDeepLink()
  → LaunchMode(ModeId) → UGameplayStatics::OpenLevel(venueMapPath)
  → AFELGameModeBase::BeginPlay() → StartMatch()
  → [mode-specific gameplay tick — scoring, HP, waves, questions, etc.]
  → AFELGameModeBase::EndMatch(PlayerScore, OpponentScore)
  → UFELGameplayManager::OnMatchEnd(ModeId, scores, MRI metrics)
  → ComputeSessionResult() → [XP/Shards/PRQ computed with ModeWeight]
  → DispatchSessionReceipt() → POST https://finalevolutiongroup.com/games/session
  → UFELSessionReceiptComponent::ProcessMatchResult()
  → OnRewardReady delegate → HUD_ShardCounter + HUD_PRQMeter update
  → BroadcastEconomyHUDUpdate() → ws://localhost:8080/ws/hud → React HUD components
  → WBP_MatchResult activated with Outcome/XP/Shards/PRQDelta
```

### HUD message flow:
```
Gameplay C++ event
  → BPFL_HUDManager::BroadcastHUDMessage(type, json)
  → ws_hud_server.py (asyncio relay) → all CONNECTED clients
  → React TSX component WebSocket.onmessage → setState → re-render
```

### Build/distribution flow:
```
[macOS] bash infra/ios/fel_ios_shipping_build.sh
  → UE RunUAT BuildCookRun -platform=IOS -clientconfig=Shipping
  → auto-calls fel_reexport_ipa.sh (xcarchive → IPA)
→ bash infra/ios/fel_appstore_connect.sh (upload to TestFlight)
    OR
bundle exec fastlane ios upload_testflight
```

---

## Guidance for the Modifying Agent

### To implement skateboarding / snowboarding:
1. Add `AFELGameMode_Skateboarding` and `AFELGameMode_Snowboarding` classes to `FELGameModeBase.h` following the pattern of AFELGameMode_Surfing (score-based, timed run).
2. Add `EvaluateSkateboarding/SnowboardingOutcome` to `FELGameplayManager.h/.cpp`.
3. Add to ModeWeights map in `FELGameplayManager.h` (suggested: 0.9 per GameMode.swift prqWeight).
4. Update ArenaSettings.json on macOS: add runDurationSeconds (already stubbed).
5. Change status from "staging" → "production" in `FEL_ModeManager.production.json` (requires running on macOS).

### To promote who_scene_it + court_carnival (fix Gate 1):
1. **Immediate**: Run `bash infra/fel_gate1_fix.sh` on macOS clone — this Python3 script promotes both modes and sets production_modes=14.
2. Alternatively: Directly edit `backend/FEL_ModeManager.production.json` on macOS, changing who_scene_it status "preview" → "production" and court_carnival status "preview" → "production", and set production_modes=14.
3. Then add C++ AFELGameMode_WhoSceneIt and AFELGameMode_CourtCarnival classes to FELGameModeBase.h.
4. who_scene_it uses BP_WhoSceneIt_GameMode (Blueprint class) — the spec already defines the full actor hierarchy (BP_ContestantPlatform, BP_WhoSceneIt_CameraDirector, BP_FEL_MediaScreen, etc.).
5. court_carnival uses /Script/FEL.BP_CourtCarnival (Blueprint class) — spec defines BP_ATW_LandmarkPost, BP_CarnivalPad_Trigger, BP_CarnivalItemSpawner, BP_ATW_Sequencer.
6. Both modes have bScoringEnabled=false in ArenaSettings — they do NOT plug into the standard outcome evaluator system.

### To fix DefaultGame.ini for [FELPlayMap]:
- The workspace Config/DefaultGame.ini has NO [FELPlayMap] entries — these are in the macOS-only `infra/ue5_config/DefaultGame.ini`.
- If the workspace DefaultGame.ini needs to be extended, add the [FELPlayMap] block from the heredoc in create_fel_migration.sh.

### To add VeniceBeach VenueRegistry / ArenaSettings entries:
- ArenaSettings.json is on macOS only (UnrealStarter/BasketballGame/Content/FEL/Config/).
- VenueRegistry files (FEL_VenueRegistry.production.json) do NOT exist anywhere in this workspace — they were requested in the previous recon but confirmed absent.

### Places NOT to change directly:
- FELGameplayManager ModeWeights: only add new entries — do not change existing 14 mode weights (they are balance-tested production values).
- DispatchSessionReceipt endpoint URL is hardcoded in .cpp as https://finalevolutiongroup.com/games/session — this matches the production backend. The Flask server.py endpoint is /api/games/session (different path — these may be proxied differently).
- Don't edit the workspace Config/DefaultGame.ini [GeneralProjectSettings] section — that's stamped by Phase 8.
- Don't change XP_CAP (500), SHARD base values, or PRQ_WIN/DRAW/LOSS — economy balance is finalized.

---

## Risks / Unknowns

1. **Gate 1 still failing on macOS**: publish_status_report.json confirmed production_modes=12 at time of writing. `fel_gate1_fix.sh` must be run on macOS before any CI can pass. The workspace JSON (from create_fel_migration.sh) sets production_modes=14, but the actual macOS file was behind.

2. **iOS provisioning still blocked**: final_evolution_lab.json confirms: "export_status: BLOCKED_PROVISIONING_PROFILE". ExportOptions.plist created by migration script has REPLACE_WITH_* placeholders — NOT yet populated with real provisioning profile / team ID. Distribution cannot proceed until this is resolved.

3. **FEL_VenueRegistry.production.json does not exist** anywhere in this workspace. The previous recon request asked for it; it appears to be a planned file not yet created.

4. **Endpoint mismatch**: C++ sends to https://finalevolutiongroup.com/games/session; Flask server.py defines @app.route("/api/games/session"). If the production server is reverse-proxied this may work, but needs verification.

5. **No actual UE map/level assets** (no .umap files, no .uasset files) exist in this workspace. All venue/map references are string tokens that must exist in the live UE editor project on macOS. The workspace only contains C++ source, config, TSX, and infrastructure scripts.

6. **Neurocognitive engine disabled by default**: FELFeatureFlags.enableNeurocognitiveEngine=false means MRI always returns defaults (ARV=0.5, ESI=50, PacingScore=50, MRI≈50). The HUD_MRIMeter will display these flat defaults unless enabled.

7. **BPFL_HUDManager::BroadcastHUDMessage** is a stub — it only UE_LOGs the message. Actual WebSocket relay requires a separate mechanism from C++ to send to ws_hud_server.py. The current .cpp does not actually open a WS connection; it likely relies on UFELSessionReceiptComponent::BroadcastEconomyHUDUpdate() for economy events, but the in-match score/MRI/combo events need a C++ → Python WS relay that is not yet implemented.

8. **court_carnival map token discrepancy**: infra/ue5_config/DefaultGame.ini (heredoc) maps court_carnival to `/Game/FEL/Venues/VeniceBeach/VeniceBeach`; but environment layout JSON says venue_id="Venice_Beach_Court" and map_token="/Game/FEL/Venues/VeniceBeach/VeniceBeach". The ue_mode_maps.json correctly uses "Venice_Beach_Court" as the short map name. These should resolve to the same asset but should be verified.

9. **FEL_ModeManager.production.json must be confirmed current**: The file's state on macOS may differ from the heredoc (which shows 14 production, who_scene_it/court_carnival as "preview"). The publish_status_report says 12 production at time of report. Needs re-reading on macOS.

10. **who_scene_it + court_carnival environment layout spec status is "staging" in JSON**: The `.json` metadata files use status="staging" but the markdown spec headers say "staging → preview". These modes should be confirmed as fully designed before promoting to production.
