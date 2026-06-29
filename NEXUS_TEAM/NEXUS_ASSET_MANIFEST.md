# Nexus Engine Asset Manifest
**Final Evolution Lab — Sprint 1**  
Branch: `claude/nexus-engine-setup-2qgkik`  
Last Updated: 2026-06-29  

---

## Overview

This manifest defines every 3D model, animation, UI widget, audio asset, and Blueprint required by the **Nexus Engine** for all 19 game modes. It supersedes the Seele/anti-gravity-fel Android manifest with iOS-first, Nexus Engine-native specifications.

**Asset Sources:**
- **Meshy.ai** — AI-generated 3D models (characters, venues, props). Slot IDs prefixed `MESHY_`.
- **Seele AI** — UE5 Blueprints, animation rigs, UI widgets, audio. Slot IDs follow Seele naming conventions.

**Render Mode Key:**
| Mode | Description |
|------|-------------|
| `3D_UE5` | Full 3D Unreal Engine 5.7 video game |
| `2D` | 2D canvas battle-of-wits (Brain Brawl only) |
| `IRL` | Real-world HealthKit-tracked (basketball_h2h only) |

---

## Game Mode Render Architecture

```
19 Total Modes
├── 3D_UE5 (17 modes) — Full Nexus Engine video games with Meshy + Seele assets
│   ├── Production (11): basketball_dunk, basketball_3v3, karate_h2h, karate_endless,
│   │                     baseball, football, soccer, golf, tennis, volleyball, surfing
│   ├── Staging (3):      skateboarding, snowboarding, gymnastics
│   ├── Preview (2):      who_scene_it, court_carnival
│   └── Non-game (1):     market_browse
├── 2D (1 mode)
│   └── Staging:          brain_brawl — Big Brain Academy × Triumph quiz battle
└── IRL (1 mode)
    └── Production:       basketball_h2h — Regulation rim, HealthKit PRQ tracking
```

---

## Basketball H2H — IRL Competitive Mode

**Mode ID:** `basketball_h2h`  
**Render Mode:** `IRL` — No UE5 venue map required  
**Venue:** Regulation Court (any real-world court)  
**Rim Height:** 10 feet / 120 inches (regulation NBA/FIBA/NCAA)  
**Description:** Competitive head-to-head dunk contest on a regulation rim. This is FEL's flagship SCAN pillar mode — real-world athletic performance is tracked via HealthKit and fed into the Nexus Engine PRQ avatar system.

### How It Works
1. Player opens FEL on iOS, starts `basketball_h2h` session
2. Apple Watch / iPhone HealthKit records: jump height, heart rate, power output, movement speed
3. NexusEngine receives PRQ scan data via `HealthKitService.swift`
4. Session ends → `NexusEngine.syncPRQToAvatar()` updates digital avatar stats
5. PRQ delta computed from real athletic performance, not simulated gameplay

### Assets Required
| Slot ID | Type | Description |
|---------|------|-------------|
| `MESHY_hud_irl_basketball` | UI overlay | In-session HUD showing live HealthKit metrics |
| `MESHY_athlete_basketball_irl` | Avatar icon | Player avatar displayed on session result screen |
| `WBP_HUD_IRL_Basketball.uasset` | Seele widget | UMG overlay for IRL session stats |
| `ABP_Athlete_IRL_Sync.uasset` | Seele animation | Avatar animation played on PRQ sync completion |

---

## Basketball Dunk Contest — Venice Beach Video Game

**Mode ID:** `basketball_dunk`  
**Render Mode:** `3D_UE5`  
**Venue:** Venice Beach Court (Outdoor) — `/Game/FEL/Venues/VeniceBeach/VeniceBeach`  
**Description:** 3D Nexus Engine video game dunk contest at the iconic Venice Beach outdoor basketball court. Players perform aerial combos for a judging panel in a cinematic UE5 environment. Distinct from basketball_h2h (which is IRL).

### Meshy Assets
| Slot ID | Type | Description |
|---------|------|-------------|
| `MESHY_venice_beach_outdoor_court` | Venue | Venice Beach basketball court, boardwalk, palm trees, ocean backdrop |
| `MESHY_regulation_backboard_venice` | Prop | Regulation backboard + rim at the Venice court |
| `MESHY_athlete_basketball_dunk` | Character | Athlete character with dunk contest outfit variants |
| `MESHY_venice_beach_crowd` | Environment | Crowd spectators at Venice Beach court |
| `MESHY_basketball_official` | Prop | Official NBA-spec basketball |

### Seele Assets
| Slot ID | Type | Description |
|---------|------|-------------|
| `VeniceBeach.umap` | Map | Venice Beach venue level |
| `BP_BasketballDunk.uasset` | Blueprint | Dunk contest game mode BP |
| `ABP_Basketball_Dunk.uasset` | Animation BP | Full dunk animation set (alley-oop, reverse, 360, windmill, etc.) |
| `SFX_Basketball_Dunk_Crowd.uasset` | Audio | Crowd reaction SFX triggered by dunk score |
| `AMB_VeniceBeach.uasset` | Ambient | Venice Beach ambient loop (ocean, boardwalk, seagulls) |

---

## Brain Brawl — 2D Battle of Wits

**Mode ID:** `brain_brawl`  
**Render Mode:** `2D` — 2D canvas, no 3D physics engine  
**Venue:** Neuro Arena (2D background)  
**Description:** A 2D battle-of-wits quiz game modeled after Big Brain Academy (Nintendo), Triumph (sports game show), and Brain Age. Players compete in sports knowledge, logic puzzles, and reaction speed challenges. No 3D game physics — purely 2D interactive canvas rendered by the Nexus Engine's 2D subsystem.

### Game Inspirations
- **Big Brain Academy** (Nintendo DS/Wii/Switch) — multiplayer brain challenge minigames
- **Triumph** (sports quiz show format) — head-to-head buzzer rounds
- **Brain Age** (Nintendo DS) — speed-based cognitive challenges
- **Who Wants to Be a Millionaire** — escalating difficulty question structure

### Question Categories
1. Sports Knowledge (30%) — rules, records, athletes, history
2. Biomechanics & Kinesiology (25%) — anatomy, movement, training science
3. FEL Creator Cards (20%) — player cards, stats, FEL lore
4. Logic & Pattern Recognition (15%) — quick math, sequences
5. Reaction Challenges (10%) — tap-when-you-see-it speed rounds

### Meshy Assets
| Slot ID | Type | Description |
|---------|------|-------------|
| `MESHY_brain_brawl_2d_arena_bg` | UI background | Animated 2D Neuro Arena background for quiz battles |
| `MESHY_brain_avatar_2d` | Character icon | Player avatar rendered as 2D chibi-style icon |
| `MESHY_brain_brawl_question_panel` | UI component | 2D question card with sport imagery |

### Seele Assets
| Slot ID | Type | Description |
|---------|------|-------------|
| `NeuroArena.umap` | Map | Neuro Arena background environment |
| `BP_BrainBrawl2D.uasset` | Blueprint | 2D quiz battle game mode BP with canvas rendering |
| `WBP_BrainBrawl_2D_Canvas.uasset` | Widget | Full 2D game canvas — question display, timer, score |
| `T_BrainBrawl_AvatarIcon.uasset` | Texture | Player avatar icon set (all sport types) |
| `SFX_BrainBrawl_Correct.uasset` | Audio | Correct answer fanfare SFX |
| `SFX_BrainBrawl_Wrong.uasset` | Audio | Wrong answer buzz SFX |
| `SFX_BrainBrawl_Countdown.uasset` | Audio | Timer countdown SFX |

---

## All 3D Modes — Complete Meshy Asset Slots

### Venice Beach Venue (Shared: basketball_dunk, basketball_3v3, surfing, court_carnival)

| Slot ID | Asset |
|---------|-------|
| `MESHY_venice_beach_outdoor_court` | Full Venice Beach outdoor basketball court with boardwalk backdrop |
| `MESHY_venice_beach_surf_break` | Venice Beach surf zone with ocean waves for surfing mode |
| `MESHY_venice_beach_carnival_board` | Venice Beach carnival game board setup for Court Carnival |
| `MESHY_venice_beach_crowd` | Crowd spectators appropriate to each mode |
| `AMB_VeniceBeach` | Ocean + boardwalk ambient loop (shared) |

### Martial Arts Dojo (Shared: karate_h2h, karate_endless)

| Slot ID | Asset |
|---------|-------|
| `MESHY_martial_arts_dojo` | Traditional tatami dojo with sliding shoji walls |
| `MESHY_dojo_tatami_floor` | High-detail tatami mat surface |
| `MESHY_karate_opponent_variants` | 5 enemy character variants for endless wave mode |
| `AMB_Dojo` | Dojo ambient (wooden floor, ambient silence, distant birds) |

### Baseball Stadium

| Slot ID | Asset |
|---------|-------|
| `MESHY_baseball_stadium` | Outdoor baseball diamond with grandstands |
| `MESHY_athlete_baseball_batter` | Batter character with batting stance variants |
| `MESHY_athlete_baseball_pitcher` | Pitcher character with wind-up animation |
| `MESHY_baseball_official` | Official baseball |

### Gridiron Stadium

| Slot ID | Asset |
|---------|-------|
| `MESHY_gridiron_stadium` | NFL-style gridiron stadium with end zones |
| `MESHY_athlete_football` | Football player with pads and helmet |
| `MESHY_football_official` | Official NFL-spec football |

### Soccer Stadium

| Slot ID | Asset |
|---------|-------|
| `MESHY_soccer_stadium` | Large soccer stadium with pitch and goals |
| `MESHY_athlete_soccer` | Soccer player character |
| `MESHY_soccer_ball_official` | Official FIFA-spec soccer ball |
| `MESHY_soccer_goal_net` | Full-size goal with net physics |

### Golf Links

| Slot ID | Asset |
|---------|-------|
| `MESHY_golf_links_course` | Scenic links golf course, fairway + green |
| `MESHY_athlete_golf` | Golfer character with swing stance |
| `MESHY_golf_ball_official` | Golf ball with dimple detail |
| `MESHY_golf_club_set` | Full club set (driver, irons, putter) |

### Tennis Court

| Slot ID | Asset |
|---------|-------|
| `MESHY_tennis_court_hard` | Hard court surface (blue/green) |
| `MESHY_athlete_tennis` | Tennis player character |
| `MESHY_tennis_ball_official` | Official tennis ball |
| `MESHY_tennis_racket` | Tennis racket with string detail |

### Beach Volleyball Court

| Slot ID | Asset |
|---------|-------|
| `MESHY_beach_volleyball_sand_court` | Sand volleyball court with net |
| `MESHY_athlete_volleyball` | Volleyball player character |
| `MESHY_volleyball_official` | Official volleyball |
| `MESHY_volleyball_net` | Regulation volleyball net with poles |

### Skate Park

| Slot ID | Asset |
|---------|-------|
| `MESHY_skate_park_outdoor` | Outdoor skate park with ramps, rails, ledges |
| `MESHY_athlete_skateboarding` | Skateboarder character with helmet/pads |
| `MESHY_skateboard_deck_complete` | Complete skateboard (deck, trucks, wheels) |
| `MESHY_skatepark_rails_ledges` | Modular obstacle set (rails, ledges, boxes) |

### Mountain Slope

| Slot ID | Asset |
|---------|-------|
| `MESHY_mountain_slope_halfpipe` | Mountain slope with halfpipe and terrain |
| `MESHY_athlete_snowboarding` | Snowboarder character with winter gear |
| `MESHY_snowboard_park_deck` | Park-style snowboard |
| `MESHY_mountain_snow_terrain` | Snow terrain with trees and mountain backdrop |

### Gymnastics Training Floor

| Slot ID | Asset |
|---------|-------|
| `MESHY_gymnastics_training_floor` | Olympic gymnastics arena with sprung floor |
| `MESHY_athlete_gymnastics` | Gymnast character with leotard variants |
| `MESHY_gymnastics_vault` | Vaulting table apparatus |
| `MESHY_gymnastics_parallel_bars` | Parallel bars apparatus |
| `MESHY_gymnastics_spring_floor` | Spring floor mat with boundaries |

### Neuro Arena (Shared: brain_brawl, who_scene_it)

| Slot ID | Asset |
|---------|-------|
| `MESHY_neuro_arena_stage` | Futuristic stage set for Who Scene It |
| `MESHY_who_scene_it_host` | Host character for Who Scene It |
| `MESHY_wsi_multimedia_panel` | Large multimedia display panel for clips |
| `MESHY_brain_brawl_2d_arena_bg` | 2D animated background for Brain Brawl |

### Luma Venice Shop

| Slot ID | Asset |
|---------|-------|
| `MESHY_luma_venice_shop_interior` | Luma Venice Shop 3D interior environment |
| `MESHY_creator_card_3d_display` | 3D display rack for Creator Cards |
| `MESHY_creator_card_holo_shader` | Holographic shader material for rare/legendary cards |

---

## Global Assets (All Modes)

### Character Base Rigs
| Slot ID | Asset |
|---------|-------|
| `MESHY_athlete_base_skeleton` | Universal base athlete mesh with 12 sport variant rigs |
| `SK_Athlete_Base.uasset` | UE5 base skeleton (Seele) |
| `ABP_Athlete_Universal.uasset` | Universal animation Blueprint with sport overrides |

### HUD / UI Kit
| Slot ID | Asset |
|---------|-------|
| `WBP_HUD_Main.uasset` | Main in-game HUD (score, timer, PRQ meter) |
| `WBP_ScoreOverlay.uasset` | Score display overlay |
| `WBP_PRQMeter.uasset` | PRQ gauge widget |
| `WBP_ShardCounter.uasset` | Shard counter widget |
| `WBP_XPBar.uasset` | XP bar widget |
| `WBP_SessionReceipt.uasset` | Post-session receipt (PRQ delta, shards, XP) |

### Creator Card System
| Slot ID | Asset |
|---------|-------|
| `WBP_CreatorCard.uasset` | 3D card viewer widget |
| `SK_CreatorCard_Base.uasset` | Base 3D card mesh |
| `M_CreatorCard_Holographic.uasset` | Holographic card material (epic/legendary) |
| `SFX_CardReveal_Common.uasset` | Common card reveal SFX |
| `SFX_CardReveal_Legendary.uasset` | Legendary card reveal SFX (extra dramatic) |

### Venue Skyboxes
| Slot ID | Asset |
|---------|-------|
| `HDRi_VeniceBeach_Day.uasset` | Venice Beach HDRi skybox (daytime) |
| `HDRi_VeniceBeach_Sunset.uasset` | Venice Beach sunset variant |
| `HDRi_Dojo_Interior.uasset` | Dojo interior HDRi |
| `HDRi_Stadium_Night.uasset` | Night stadium HDRi (football, soccer, baseball) |
| `HDRi_Golf_Links.uasset` | Golf course skybox |
| `HDRi_Mountain_Morning.uasset` | Mountain slope morning skybox |
| `HDRi_NeuroArena_Neon.uasset` | Neuro Arena neon/sci-fi HDRi |

### Loading Screens
| Slot ID | Asset |
|---------|-------|
| `T_Loading_VeniceBeach.uasset` | Venice Beach loading art |
| `T_Loading_Dojo.uasset` | Dojo loading art |
| `T_Loading_Stadium.uasset` | Generic stadium loading art |
| `T_Loading_NexusEngine.uasset` | Nexus Engine boot splash screen |

---

## Seele Re-Creation Protocol for Nexus Engine

The original Seele execution package targeted Android/Google Play (branch: `anti-gravity-fel`). All assets must be **re-created for iOS Nexus Engine** with the following changes:

### Key Differences from anti-gravity-fel Seele Assets

| Aspect | anti-gravity-fel (Android) | Nexus Engine iOS |
|--------|---------------------------|-------------------|
| Target platform | Android arm64 + ASTC textures | iOS arm64 + ASTC + Metal |
| Texture format | ASTC only | ASTC + Metal-optimized |
| Distribution | Google Play (AAB) | App Store (IPA) |
| basketball_h2h | 3D UE5 game | IRL HealthKit mode |
| brain_brawl | 3D UE5 game | 2D canvas quiz battle |
| BP class prefix | Same | Same — just retarget platform |

### Seele Creation Checklist for Nexus Engine

For each 3D mode (17 modes):
- [ ] `.umap` venue file targeting iOS cooked path format
- [ ] `BP_<ModeName>.uasset` with iOS input scheme (swipe/touch)
- [ ] `ABP_<Sport>.uasset` animation Blueprint
- [ ] `AM_<Sport>_<Action>.uasset` animation montages
- [ ] `SFX_<Sport>_<Action>.uasset` sport SFX
- [ ] `AMB_<Venue>.uasset` ambient audio loop
- [ ] Meshy mesh integrated as `SK_<AssetName>.uasset` via static mesh import

For Brain Brawl (2D mode):
- [ ] `WBP_BrainBrawl_2D_Canvas.uasset` — full 2D game canvas
- [ ] `BP_BrainBrawl2D.uasset` — 2D game mode Blueprint
- [ ] Question database structure (JSON or DataTable)
- [ ] 5 category icon textures

For Basketball H2H (IRL mode):
- [ ] `WBP_HUD_IRL_Basketball.uasset` — HealthKit metrics HUD overlay
- [ ] `ABP_Athlete_IRL_Sync.uasset` — post-session avatar sync animation
- [ ] NO venue map required — HealthKit drives the session

---

## Meshy Asset Import Pipeline

When Meshy.ai generates assets:

1. Export as `.glb` or `.fbx`
2. Import into UE5 at `Content/FEL/Meshy/<MeshySlotId>/`
3. Create `SK_<MeshySlotId>.uasset` from import
4. Wire into corresponding `BP_<ModeName>.uasset`
5. Update `FEL_VenueRegistry.production.json` `meshyAssets` field to mark slot as `"status": "imported"`
6. Run validation suite: `python3 scripts/smoke_test_modes.py`

### Import Path Convention
```
Content/FEL/Meshy/
├── MESHY_venice_beach_outdoor_court/
│   ├── SK_venice_beach_outdoor_court.uasset
│   └── T_venice_beach_outdoor_court_*.uasset
├── MESHY_athlete_basketball_dunk/
│   ├── SK_athlete_basketball_dunk.uasset
│   └── T_athlete_basketball_dunk_*.uasset
└── ...
```

---

## Validation Checklist

After all assets are created and imported:

```bash
# Registry alignment (must: 0 failures)
python3 scripts/smoke_test_modes.py

# Economy validation (must: 0 failures)
python3 scripts/test_economy_transactions.py

# JSON validity
python3 -m json.tool backend/FEL_ModeManager.production.json
python3 -m json.tool backend/FEL_VenueRegistry.production.json
python3 -m json.tool UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json
python3 -m json.tool backend/ue_mode_maps.json

# All 19 modes present, render mode assigned
python3 -c "
import json
data = json.load(open('backend/FEL_ModeManager.production.json'))
modes = data['mode_manager']['modes']
for m in modes:
    print(f\"{m['id']:30} render_mode={m.get('render_mode', 'MISSING'):8} irl={m.get('irl_mode', False)}\")
"
```
