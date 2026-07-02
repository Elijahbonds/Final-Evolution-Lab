## File Addresses

### C++ Gameplay
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameModeBase.h
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameModeBase.cpp
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameplayManager.h
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELGameplayManager.cpp
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/Gameplay/FELSessionReceiptComponent.h

### HUD (TSX / C++)
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/FELHud.tsx
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_ScoreBar.tsx
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_PRQMeter.tsx
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_ShardCounter.tsx
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_MRIMeter.tsx
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_AICoachPrompt.tsx
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/HUD_ComboFeed.tsx
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/BPFL_HUDManager.h
- /assets/games/final_evolution_lab/workspace/FinalEvolutionLab/UI/HUD/BPFL_HUDManager.cpp

### UMG Menu Headers
- /assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_MainMenu.h
- /assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_ModeSelect.h
- /assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_ModeDetail.h
- /assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_MatchResult.h
- /assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_MarketBrowse.h
- /assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_EconomyDashboard.h
- /assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_Profile.h
- /assets/games/final_evolution_lab/workspace/Content/FEL/UI/Menus/WBP_Settings.h

### Backend / Config
- /assets/games/final_evolution_lab/workspace/backend/FEL_ModeManager.production.json
- /assets/games/final_evolution_lab/workspace/Config/DefaultGame.ini
- /assets/games/final_evolution_lab/workspace/Config/DefaultEngine.ini
- /assets/games/final_evolution_lab/workspace/infra/hud/ws_hud_server.py

### Environment Layout Specs
- /assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/court_carnival_environment_layout.json
- /assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/court_carnival_environment_layout.md
- /assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/who_scene_it_environment_layout.json
- /assets/games/final_evolution_lab/workspace/infra/fel_environment_layouts/who_scene_it_environment_layout.md

### Infra Scripts
- /assets/games/final_evolution_lab/workspace/infra/fel_gate1_fix.sh
- /assets/games/final_evolution_lab/workspace/infra/ios/fel_ios_shipping_build.sh
- /assets/games/final_evolution_lab/workspace/infra/android/fel_android_shipping_build.sh
- /assets/games/final_evolution_lab/workspace/infra/android/fel_keystore.properties
- /assets/games/final_evolution_lab/workspace/infra/android/upload_to_google_play.sh
- /assets/games/final_evolution_lab/workspace/infra/ios/fel_appstore_connect.sh
- /assets/games/final_evolution_lab/workspace/infra/distribution/FEL_DISTRIBUTION_CHECKLIST.md
- /assets/games/final_evolution_lab/workspace/infra/distribution/Fastfile

### Project Metadata
- /assets/games/final_evolution_lab/final_evolution_lab.json
- /assets/games/final_evolution_lab/workspace/publish_status_report.json
- /assets/games/final_evolution_lab/workspace/create_fel_migration.sh

---

## Summary

1. **All 19 mode C++ subclasses exist** in FELGameModeBase.h — 14 production fully implemented, 5 Phase 7 as constructor-only stubs.
2. **All 19 outcome evaluators exist** in FELGameplayManager — production 14 have full logic; Phase 7 five have stub logic (Score≥50, Score≥7, etc.).
3. **Gate 1 is resolved in the Seele workspace** (FEL_ModeManager.production.json shows production_modes=14); publish_status_report.json records the macOS clone still at 12 — `infra/fel_gate1_fix.sh` must be run on Mac.
4. **Full environment layout specs exist only for court_carnival and who_scene_it** (complete coordinate tables, spawn points, camera zones, collision volumes, sublevel composition); skateboarding and snowboarding have NO layout specs.
5. **No .umap or .uasset files exist in the workspace** — all venue path references in DefaultGame.ini point to assets on the M4 Pro Mac Mini UE project; the workspace holds only C++, configs, scripts, and layout docs.
6. **Two structural gaps** in FELGameModeBase.cpp Phase 7 constructors: `bScoringEnabled` and `DefaultMatchDuration` are used but not declared in the base class header as read — they may live in a missing `FELTypes.h` or need to be added to AFELGameModeBase.
7. **Venue path inconsistency**: brain_brawl → `/Game/FEL/Venues/Neuro_Arena/Neuro_Arena`; who_scene_it → `/Game/FEL/Venues/NeuroArena/NeuroArena` (different paths, no underscore). May be intentional sublevel split but requires verification.

---

## Project Overview

- **Purpose:** Final Evolution AI Coach — multi-sport mobile game with 19 modes, neurocognitive coaching engine (MRI = ARV×0.40 + (100−ESI)×0.35 + Pacing×0.25), shard economy (P1), React HUD overlay, UE5 C++ backend dispatch.
- **Stack:** Unreal Engine 5.5 (C++ / Blueprints / CommonUI), React TSX (HUD overlay via WebBrowserWidget), Python WebSocket server (HUD relay), iOS + Android deployment, FastAPI backend at `https://finalevolutiongroup.com/games/session`.
- **Bundle ID:** `com.finalevolutionlab.app`
- **Actual UE project on disk:** M4 Pro Mac Mini at `/Users/elijahbonds/Documents/Unreal Projects/MyProject/` (referenced as `SimpleGame.uproject`).
- **Seele workspace (Windows):** `/assets/games/final_evolution_lab/workspace/` — C++ headers, infra scripts, layout docs, config files. No .umap/.uasset. UE Editor bridge OFFLINE (Win32).

### Key Directories
```
workspace/
├── FinalEvolutionLab/
│   ├── Gameplay/           ← C++ game mode classes + session receipt
│   └── UI/HUD/             ← React TSX HUD + BPFL_HUDManager C++
├── Content/FEL/UI/Menus/   ← WBP_* CommonUI widget headers (8 menus)
├── Config/
│   ├── DefaultGame.ini     ← [FELPlayMap] 19 venue route entries
│   └── DefaultEngine.ini   ← iOS/Android runtime settings
├── backend/
│   └── FEL_ModeManager.production.json  ← Mode registry, 19 modes
└── infra/
    ├── fel_environment_layouts/          ← court_carnival + who_scene_it specs
    ├── hud/ws_hud_server.py              ← WebSocket HUD relay
    ├── ios/                              ← iOS shipping build scripts
    ├── android/                          ← Android shipping build scripts
    ├── distribution/                     ← Fastfile + checklist
    └── fel_gate1_fix.sh                  ← Gate 1 JSON patch
```

---

## Relevant Files

### FELGameModeBase.h
- **Role:** Defines `AFELGameModeBase` abstract base + all 19 mode subclasses in one header.
- **Key detail:** 14 production modes defined inline with sport-specific UPROPERTYs and overrides. 5 Phase 7 modes (skateboarding, snowboarding, who_scene_it, court_carnival, market_browse) defined as minimal UCLASS stubs at the bottom with only `GetModeId()` overrides. Base declares `VenueId`, `MatchTimer`, `bMatchActive`, `ComputeMRI()`, `OnMatchEnd` delegate. `StartMatch()`/`EndMatch()` are BlueprintCallable virtuals.

### FELGameModeBase.cpp
- **Role:** Phase 7 constructors ONLY — sets `bScoringEnabled` and `DefaultMatchDuration`.
- **Key detail:** These two fields (`bScoringEnabled`, `DefaultMatchDuration`) are NOT in the base class header as confirmed read. This is a structural gap — they need to be in the base or an intermediate class. Production mode constructors (1–14) have no .cpp equivalents in this workspace (their UE defaults apply).

### FELGameplayManager.h
- **Role:** `UGameInstanceSubsystem` — all outcome evaluators, P1 economy computation, session receipt dispatch.
- **Key detail:**
  - `FFELSessionResult` struct: 16 fields (UserId, ModeId, Outcome, Score, OpponentScore, MRIScore, ARV, ESI, PacingScore, XPEarned, ShardsEarned, PRQDelta, SessionId, VenueId).
  - All 19 mode weights in `TMap<FString,float>` literal: market_browse=0.0 (no economy), skateboarding=snowboarding=0.9, production range 0.9–1.5.
  - Economy constants: XP_CAP=500, SHARD_WIN=50/DRAW=25/LOSS=15, PRQ_WIN=2.0/DRAW=0.5/LOSS=0.2.

### FELGameplayManager.cpp
- **Role:** Full implementation — economy math, HTTP session receipt dispatch, 19 evaluators.
- **Key detail:** Session receipt POSTs to `https://finalevolutiongroup.com/games/session`. Phase 7 evaluators are genuine stubs (threshold literals, opponent score ignored for skateboarding/snowboarding). `Initialize()` log says "14 production modes armed."

### FELSessionReceiptComponent.h
- **Role:** Pawn-attached component; bridges C++ match results to HUD (OnRewardReady delegate → HUD_ShardCounter; OnPRQUpdate → HUD_PRQMeter).
- **Key detail:** `BroadcastEconomyHUDUpdate(int32 NewShards, int32 NewXP, float NewPRQ)` is the HUD push interface. `BuildMatchResultDeepLink()` generates payload for WBP_MatchResult.

### FEL_ModeManager.production.json
- **Role:** Runtime mode registry — source of truth for status, venue_id, prq_weight.
- **Key detail (AS FOUND IN WORKSPACE):**
  - `production_modes: 14` — Gate 1 fix already applied in workspace copy.
  - `who_scene_it`: status=production, venue_id=Neuro_Arena, prq_weight=1.1
  - `court_carnival`: status=production, venue_id=VeniceBeach, prq_weight=1.0
  - `skateboarding`: status=staging, venue_id=Skate_Park, prq_weight=0.9
  - `snowboarding`: status=staging, venue_id=Mountain_Slope, prq_weight=0.9
  - `market_browse`: status=non_game, venue_id=Luma_Venice_Shop, prq_weight=0.0
  - `cooked_runtime_note` confirms Gate 1 fix applied.
  - **NOTE:** `publish_status_report.json` (timestamped 2026-05-24) still shows Gate 1 failing with production_modes=12 — this is stale; reflects macOS clone state before `fel_gate1_fix.sh` is run.

### DefaultGame.ini `[FELPlayMap]`
- **Role:** Venue routing table — maps mode_id → UE map path string.
- **All 19 entries present:**
  ```
  basketball_h2h/dunk/3v3 → /Game/FEL/Venues/VeniceBeach/VeniceBeach
  karate_h2h/endless       → /Game/FEL/Venues/ZenDojo/ZenDojo
  baseball                 → /Game/FEL/Venues/BaseballPark/BaseballPark
  football                 → /Game/FEL/Venues/GridironStadium/GridironStadium
  soccer                   → /Game/FEL/Venues/Soccer_Stadium/Soccer_Stadium
  golf                     → /Game/FEL/Venues/Links_Golf_Course/Links_Golf_Course
  tennis                   → /Game/FEL/Venues/Tennis_Court/Tennis_Court
  volleyball               → /Game/FEL/Venues/Sand_Court/Sand_Court
  surfing                  → /Game/FEL/Venues/VeniceBeach/VeniceBeach
  gymnastics               → /Game/FEL/Venues/Training_Floor/Training_Floor
  brain_brawl              → /Game/FEL/Venues/Neuro_Arena/Neuro_Arena      ← underscore
  skateboarding            → /Game/FEL/Venues/Skate_Park/Skate_Park
  snowboarding             → /Game/FEL/Venues/Mountain_Slope/Mountain_Slope
  who_scene_it             → /Game/FEL/Venues/NeuroArena/NeuroArena         ← no underscore
  court_carnival           → /Game/FEL/Venues/VeniceBeach/VeniceBeach
  market_browse            → /Game/FEL/Venues/Luma_Venice_Shop/Luma_Venice_Shop
  ```

### court_carnival_environment_layout.md
- **Role:** Full Level Design Document — venue: Venice_Beach_Court.
- **Key detail — Spawn Points (11):**
  | ID | Label | Position (X,Y,Z) | Capacity |
  |---|---|---|---|
  | SP_SOCIAL_01 | Center Hub North | (−200, 0, 0) | 2 |
  | SP_SOCIAL_02 | Center Hub South | (200, 0, 0) | 2 |
  | SP_SOCIAL_03 | East Apron Social | (0, 600, 0) | 2 |
  | SP_SOCIAL_04 | West Apron Social | (0, −600, 0) | 2 |
  | SP_ATW_START | ATW Circuit Entry | (680, 700, 0) | 1 |
  | SP_CARNIVAL_A | East Carnival Apron | (−350, 680, 0) | 2 |
  | SP_CARNIVAL_B | West Carnival Apron | (−350, −680, 0) | 2 |
  | SP_RESET_01 | Baseline Reset North | (−730, 0, 0) | 4 |
  | SP_RESET_02 | Baseline Reset South | (730, 0, 0) | 4 |
  | SP_SPECTATE_01 | Bleacher Row A | (−820, 350, 120) | 4 |
  | SP_SPECTATE_02 | Bleacher Row B | (−820, −350, 120) | 4 |

- **Key detail — ATW Landmarks (7):**
  | ID | Position (X,Y,Z) | Shot Dist (cm) | Score |
  |---|---|---|---|
  | ATW_01 | (620, 660, 0) | 680 | 3pts |
  | ATW_02 | (480, 520, 0) | 540 | 2pts |
  | ATW_03 | (300, 310, 0) | 360 | 2pts |
  | ATW_04 | (0, 0, 0) | 490 | 2pts |
  | ATW_05 | (300, −310, 0) | 360 | 2pts |
  | ATW_06 | (480, −520, 0) | 540 | 2pts |
  | ATW_07 | (620, −660, 0) | 680 | 3pts |
  Circuit bonus: SHARD_BONUS_ATW=75; partial (≥4 stations)=30.

- **Key detail — Carnival Mini-Game Pads (6):** CMP_01–06 with positions, footprints, facing vectors.
- **Key detail — Collectible Nodes (6):** ITM_01–06, Z=80 (in-air), respawn 12–18s.
- **Key detail — Camera Zones (7):** CAM_DEFAULT, CAM_ATW_WIDE, CAM_ATW_HERO, CAM_CARNIVAL_E/W, CAM_TRICKTSHOT, CAM_RESULT.
- **Key detail — Collision Volumes (11):** COL_COURT_FLOOR, COL_NORTH/SOUTH_WALL, COL_EAST/WEST_FENCE, COL_BLEACHER_E/W, RST_NORTH/SOUTH/EAST/WEST_OOB.
- **Key detail — Sublevels (4):** SL_VeniceBeach_Shell (always), SL_CourtCarnival_Dressing (load), SL_Basketball_Dressing (UNLOAD), SL_CourtCarnival_FX (load, ≤8 emitters iOS).
- **iOS Budget:** Tier B, ≤950k triangles peak.
- **Gamemode class:** `/Script/FEL.BP_CourtCarnival`

### who_scene_it_environment_layout.md
- **Role:** Full Level Design Document — venue: Neuro_Arena.
- **Key detail — Spawn Points (8):**
  | ID | Label | Position (X,Y,Z) | Type |
  |---|---|---|---|
  | SP_CONTESTANT_01 | Contestant 1 Entry | (480, 560, 0) | Type A |
  | SP_CONTESTANT_02 | Contestant 2 Entry | (480, 0, 0) | Type A |
  | SP_CONTESTANT_03 | Contestant 3 Entry | (480, −560, 0) | Type A |
  | SP_CONTESTANT_04 | Contestant 4 Entry | (480, −840, 0) | Type A (conditional) |
  | SP_HOST | Host Position | (−320, 0, 0) | Type A — Host |
  | SP_RESET_STAGE | Stage Reset | (500, 0, 0) | Type B |
  | SP_SPECTATE_01 | Outer Ring A | (0, 920, 200) | Type C |
  | SP_SPECTATE_02 | Outer Ring B | (0, −920, 200) | Type C |

- **Key detail — Contestant Platforms (4):**
  | ID | Position (X,Y,Z) | Height | Spotlight |
  |---|---|---|---|
  | PLT_C1 | (320, 560, 0) | +60cm | Cyan #00E5FF |
  | PLT_C2 | (320, 0, 0) | +60cm | Cyan #00E5FF |
  | PLT_C3 | (320, −560, 0) | +60cm | Cyan #00E5FF |
  | PLT_C4 | (320, −840, 0) | +60cm | Magenta #FF00C8, conditional |

- **Key detail — Media Screens (9 total):**
  - MSC_HERO_01 — hero reveal screen at (−860, 0, 480), 640×360cm, 1024×576 render target
  - MSC_FLANK_L/R — flanking commentary screens at (−820, ±520, 420), 512×288 render targets
  - MSC_CTX_01–04 — contestant answer previews at (300, 560/0/−560/−840, 300), 512×288
  - MSC_AMB_01–04 — atmosphere panels, UTexture2D flipbook (no render target), iOS safe
  - Activation state machine: IDLE → BRIEFING → REVEAL → BUZZ_IN → RESULT → ROUND_END

- **Key detail — Buzz-In Triggers (4):** BZZ_01–04 linked to PLT_C1–C4, UBoxComponent extent (100,100,160), lock-out via BP_WhoSceneIt_GameMode.OnBuzzInReceived().

- **Key detail — Camera Sweeps (7):**
  | ID | Trigger | Duration |
  |---|---|---|
  | SWP_INTRO | Round load complete | 4.0s |
  | SWP_HERO_REVEAL | REVEAL state begins | 2.5s |
  | SWP_BUZZIN_HERO | OnBuzzIn fires | 1.8s |
  | SWP_CORRECT | OnCorrectAnswer fires | 3.2s |
  | SWP_WRONG | OnWrongAnswer fires | 1.4s |
  | SWP_SCORE_REVEAL | OnRoundEnd fires | 3.5s |
  | SWP_FINAL_WINNER | Match end | 5.0s |
  Priority: SWP_CORRECT overrides SWP_BUZZIN_HERO within 0.3s window.

- **Key detail — Collision Volumes (13):** COL_STAGE_FLOOR, COL_HERO_SCREEN_WALL, COL_EAST/WEST/SOUTH_WALL, COL_PLT_C1–C4 (hard boxes), COL_HOST_STAND (soft capsule), RST_STAGE_OOB, RST_BACK_OOB.
- **Key detail — Sublevels (5):** SL_NeuroArena_Shell (always), SL_WhoSceneIt_Dressing (load), SL_BrainBrawl_Dressing (UNLOAD), SL_WhoSceneIt_Sequences (7 LevelSequenceActors), SL_WhoSceneIt_FX (≤6 GPU emitters iOS).
- **iOS Budget:** Tier B; max 1 concurrent UMediaPlayerComponent (hero screen only); all cine cameras pooled, only active sweep ticked.
- **Gamemode class:** `BP_WhoSceneIt_GameMode`

### HUD System
- **FELHud.tsx** — Master bundle composing 6 sub-components; loaded by BPFL_HUDManager at `http://localhost:3000/hud`.
- **WebSocket endpoint:** `ws://localhost:8080/ws/hud` — all 6 components connect independently with 3s auto-reconnect.
- **Message types → Component:**
  - `score_update` → HUD_ScoreBar (home/away scores, timer, period)
  - `prq_update` → HUD_PRQMeter (circular SVG gauge, mode_weight_label)
  - `economy_update` → HUD_ShardCounter (💎 count + XP progress bar, XP_CAP=500)
  - `mri_update` → HUD_MRIMeter (3-segment bar: ARV 40%, ESI 35%, Pacing 25%)
  - `coach_tip` → HUD_AICoachPrompt (auto-dismiss 5s, bottom-center float)
  - `game_event` → HUD_ComboFeed (last 5 events)
- **BPFL_HUDManager** — static BlueprintFunctionLibrary: `LoadFELHud(UWebBrowser*, URL)`, `BroadcastHUDMessage(type, payload)`, `SetHUDVisible(widget, bool)`. Note: `BroadcastHUDMessage` is currently a log stub — no actual WS send from C++.

---

## Mode Implementation Status (All 19)

### ✅ FULLY IMPLEMENTED — C++ class + sport-specific state + outcome evaluator (14 Production)

| Mode | Class | Match Duration | Key Properties | Evaluator Logic |
|---|---|---|---|---|
| basketball_h2h | AFELGameMode_BasketballH2H | 240s | PlayerPoints, OpponentPoints | P>O=Win, P<O=Loss |
| basketball_dunk | AFELGameMode_BasketballDunk | 90s | DunksCompleted, StyleScore | Same basketball eval |
| basketball_3v3 | AFELGameMode_Basketball3v3 | 300s | TArray<int32> TeamScores | Same basketball eval |
| karate_h2h | AFELGameMode_KarateH2H | 120s | PlayerHP/OpponentHP=100, ApplyDamage() | HP comparison + timeout draw |
| karate_endless | AFELGameMode_KarateEndless | 999s | WaveNumber, KillCount | HP comparison |
| baseball | AFELGameMode_Baseball | 180s (default) | PlayerRuns, OpponentRuns, CurrentInning, Outs | Inning≥9: run comparison |
| football | AFELGameMode_Football | 300s | PlayerTDs, OpponentTDs, Down, YardsToGo | TD comparison |
| soccer | AFELGameMode_Soccer | 270s | PlayerGoals, OpponentGoals | Goal comparison |
| golf | AFELGameMode_Golf | 180s (default) | PlayerStrokes, ParStrokes=72, CurrentHole | Strokes≤Par-2=Win, ≤Par+2=Draw |
| tennis | AFELGameMode_Tennis | 180s (default) | PlayerSets, OpponentSets, TArray Games arrays | Sets comparison |
| volleyball | AFELGameMode_Volleyball | 180s (default) | PlayerPoints, OpponentPoints | ≥25 pts AND 2pt margin |
| surfing | AFELGameMode_Surfing | 180s (default) | WaveScore, BestWaveScore, WavesRidden | ≥threshold=Win, ≥70%thresh=Draw |
| gymnastics | AFELGameMode_Gymnastics | 180s (default) | JudgeScore, RoutinesCompleted | ≥85=Win, ≥72.25=Draw |
| brain_brawl | AFELGameMode_BrainBrawl | 180s (default) | PlayerCorrect, OpponentCorrect, RoundNumber, TimePerQuestion=10s, SubmitAnswer() | Correct count comparison |

GOLD_THRESHOLD: surfing=75.f, gymnastics=85.f (static constexpr)

### ⚠️ REGISTRY PRODUCTION + CONSTRUCTOR STUB — No gameplay Blueprint/logic yet (2)

| Mode | Class | bScoringEnabled | Duration | Evaluator | Layout Spec | Venue Map Path |
|---|---|---|---|---|---|---|
| who_scene_it | AFELGameMode_WhoSceneIt | false (trivia) | 120s | Score≥7=Win else Loss | ✅ FULL SPEC (who_scene_it_environment_layout.md) | /Game/FEL/Venues/NeuroArena/NeuroArena |
| court_carnival | AFELGameMode_CourtCarnival | false (party) | 0s | P>O=Win, P=O=Draw, P<O=Loss | ✅ FULL SPEC (court_carnival_environment_layout.md) | /Game/FEL/Venues/VeniceBeach/VeniceBeach |

These two are marked "production" in FEL_ModeManager.production.json and have full environment layout specs, but NO implemented Blueprint game logic, no BP_WhoSceneIt_GameMode or BP_CourtCarnival implementation in workspace.

### 🔶 STAGING STUB — Constructor + evaluator threshold only, no layout spec (2)

| Mode | Class | bScoringEnabled | Duration | Evaluator | Layout Spec | Venue Map Path |
|---|---|---|---|---|---|---|
| skateboarding | AFELGameMode_Skateboarding | true | 180s | Score≥50=Win else Loss (opponent ignored) | ❌ None | /Game/FEL/Venues/Skate_Park/Skate_Park |
| snowboarding | AFELGameMode_Snowboarding | true | 180s | Score≥50=Win else Loss (opponent ignored) | ❌ None | /Game/FEL/Venues/Mountain_Slope/Mountain_Slope |

### 🏪 NON-GAME MODULE (1)

| Mode | Class | bScoringEnabled | Duration | Evaluator | Notes |
|---|---|---|---|---|---|
| market_browse | AFELGameMode_MarketBrowse | false | 0s | Always Draw | 3D shop browser; prq_weight=0.0; WBP_MarketBrowse.h fully spec'd; map: Luma_Venice_Shop |

---

## Execution Path

### Match Flow
```
Player selects mode (WBP_ModeSelect → OnModeTileSelected)
  → WBP_ModeDetail displayed
  → [FELPlayMap] looked up from DefaultGame.ini → UE map load
  → AFELGameModeBase::BeginPlay()
      → UFELGameplayManager::Initialize() (subsystem)
  → AFELGameModeBase::StartMatch()
      → bMatchActive = true; MatchTimer starts
  → [Mode-specific gameplay tick / sport events]
  → AFELGameModeBase::EndMatch(PlayerScore, OpponentScore)
      → UFELGameplayManager::OnMatchEnd(ModeId, ...)
          → Outcome computed (Win/Draw/Loss)
          → ComputeSessionResult() → FFELSessionResult
              → ComputeXP(), ComputeShards(), ComputePRQDelta()
          → DispatchSessionReceipt() → HTTP POST to finalevolutiongroup.com/games/session
      → OnMatchEnd delegate broadcast → UFELSessionReceiptComponent::ProcessMatchResult()
          → OnRewardReady.Broadcast(XP, Shards) → HUD_ShardCounter update
          → OnPRQUpdate.Broadcast(PRQDelta) → HUD_PRQMeter update
          → BroadcastEconomyHUDUpdate() → WS message to ws://localhost:8080/ws/hud
  → WBP_MatchResult.NativeOnActivated()
      → PlayRewardAnimation() (BlueprintImplementableEvent)
```

### HUD Feed Path
```
Gameplay event occurs in UE
  → BPFL_HUDManager::BroadcastHUDMessage(type, JSON)  [C++ → WS relay — currently log stub]
  OR
  → UFELSessionReceiptComponent::BroadcastEconomyHUDUpdate() → ws_hud_server.py relay
      → WebSocket broadcast to all connected HUD overlay clients
          → FELHud.tsx sub-component parses message type
          → React state update → re-render
```

---

## Guidance for the Modifying Agent

### Where to add/change things:

1. **Adding mode gameplay logic to who_scene_it / court_carnival:**
   - C++ game mode classes exist in `FELGameModeBase.h` at bottom (AFELGameMode_WhoSceneIt, AFELGameMode_CourtCarnival).
   - Outcome evaluators exist in FELGameplayManager (stub threshold logic).
   - Environment layout specs are COMPLETE — use the `.md` files as the ground truth for all position data, spawn points, triggers, camera sweeps.
   - Blueprint implementations `BP_WhoSceneIt_GameMode` and `BP_CourtCarnival` must be created in the Mac UE project (not in this workspace).

2. **Fixing the base class structural gap (bScoringEnabled / DefaultMatchDuration):**
   - These are used in FELGameModeBase.cpp Phase 7 constructors but NOT declared in FELGameModeBase.h.
   - Add `bool bScoringEnabled = true;` and `float DefaultMatchDuration = 180.f;` to `AFELGameModeBase` protected section in `FELGameModeBase.h`.
   - This is a compile blocker for Phase 7 modes.

3. **Fixing Gate 1 on macOS:**
   - Run `bash infra/fel_gate1_fix.sh` from the project root on M4 Pro Mac Mini.
   - This promotes `who_scene_it` + `court_carnival` to production and sets `production_modes=14` in the macOS clone's `FEL_ModeManager.production.json`.

4. **Adding layout specs for skateboarding / snowboarding:**
   - Create `infra/fel_environment_layouts/skateboarding_environment_layout.md` and `snowboarding_environment_layout.md` matching the schema of the existing two specs.
   - Venues: `Skate_Park` and `Mountain_Slope`.

5. **Completing BroadcastHUDMessage C++ implementation:**
   - `BPFL_HUDManager::BroadcastHUDMessage()` is currently a log stub. Needs to send via WebSocket to `ws://localhost:8080/ws/hud` or invoke JS in the browser widget. Full implementation is pending.

6. **court_carnival gamemode class mismatch:**
   - JSON spec references `/Script/FEL.BP_CourtCarnival` (Blueprint class).
   - C++ class is `AFELGameMode_CourtCarnival` in `FinalEvolutionLab/Gameplay/`.
   - Both need to coexist; the BP class should inherit from the C++ class.

### Places NOT to change directly:

- **FELGameplayManager P1 economy constants** — PRQ_WIN/DRAW/LOSS, SHARD_WIN/DRAW/LOSS, XP_CAP are stable production values. Apply changes only via `apply_p1_economy.sh`.
- **DefaultGame.ini FELPlayMap** — all 19 entries are complete and correct. Do not add or rename without updating both the macOS project and the registry.
- **FEL_ModeManager.production.json on Seele** — the workspace copy is already correct (14 production). Gate 1 fix only needs to run on macOS clone.

---

## Risks / Unknowns

1. **FELTypes.h referenced but not in workspace** — `FELGameplayManager.h` includes `FELTypes.h`; this file was NOT found in the workspace tree. It likely exists only on the Mac UE project. Any modifying agent must verify its contents before editing FELGameplayManager.

2. **bScoringEnabled / DefaultMatchDuration compile gap** — As noted above, Phase 7 constructors reference fields not in the confirmed base class header. If the actual Mac UE project already has these declared (in a more complete version of FELGameModeBase.h), it's fine; if not, this is a compile blocker.

3. **Venue path inconsistency: Neuro_Arena vs NeuroArena** — `brain_brawl` maps to `Neuro_Arena` (underscore), `who_scene_it` maps to `NeuroArena` (no underscore). Could be intentional (shared shell with separate sublevel composition) or a typo. Needs confirmation against the Mac UE Content Browser.

4. **No .uproject in workspace** — `SimpleGame.uproject` exists only on Mac at `/Users/elijahbonds/Documents/Unreal Projects/MyProject/`. Workspace has no UE module definitions (Build.cs, Target.cs). Any C++ changes made in the Seele workspace must be manually mirrored to the Mac project.

5. **HUD_ComboFeed.tsx** — File confirmed present in directory listing but not read. Presumed to consume `game_event` messages (per FELHud.tsx comment). Verify its WS subscription message type before relying on it.

6. **WBP_ModeDetail.h, WBP_Profile.h, WBP_Settings.h** — Confirmed present but not read. Their surface APIs are unknown beyond their CommonUI widget inheritance.

7. **iOS build blocked** — `final_evolution_lab.json` records `export_status: "BLOCKED_PROVISIONING_PROFILE"` for bundle ID `com.finalevolutionlab.app`. An App Store distribution provisioning profile must be downloaded and installed before IPA export can succeed.

8. **Android keystore** — `infra/android/fel_keystore.properties` has REPLACE_WITH_* placeholders. Must be filled before any Play Store upload.

9. **Production modes 12 vs 14 discrepancy** — `publish_status_report.json` shows Gate 1 failing (12 modes). The Seele workspace JSON shows 14. The discrepancy is purely between the Seele workspace (updated) and the macOS clone (not yet updated by running the fix script). Not a code bug — just a sync task.

10. **skateboarding/snowboarding evaluator opponent score ignored** — Both Phase 7 evaluators check only `Score >= 50` and ignore `OpponentScore`. For staging this is acceptable but will need proper head-to-head logic before production promotion.
