## File Addresses

### Confirmed-Present Files
- `/backend/FEL_ModeManager.production.json`
- `/assets/fel_environment_layouts_ue57_ios_plan.md`
- `/assets/fel_mode_implementation_package_ue57_ios.md`
- `/assets/proposal/fel_environment_layouts_ue57_ios_plan/fel_environment_layouts_ue57_ios_plan.json`
- `/assets/proposal/fel_mode_implementation_package_ue57_ios/fel_mode_implementation_package_ue57_ios.json`
- `/assets/games/final_evolution_lab/final_evolution_lab.json`
- `/logs/2026-05-23.md`
- `/logs/2026-05-22.md`

### Remote CDN URLs (from proposal descriptors)
- `https://seelemedia.s3.us-east-1.amazonaws.com/media/d9746b2f899b41c5a74a83a8fa47dd16.md` — environment layouts plan (canonical published copy)
- `https://seelemedia.s3.us-east-1.amazonaws.com/media/a3bfb6462335498c9d118cc21976c6db.md` — mode implementation package (canonical published copy)

### Confirmed-Absent Files (zero matches across entire filesystem)
- `backend/FEL_VenueRegistry.production.json` — DOES NOT EXIST
- `UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json` — DOES NOT EXIST
- `UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json` — DOES NOT EXIST
- `infra/ue5_config/DefaultGame.ini` — DOES NOT EXIST (infra/ dir exists but is empty)
- `backend/ue_mode_maps.json` — DOES NOT EXIST

---

## Summary

1. **Only one of the six requested backend/config files exists**: `/backend/FEL_ModeManager.production.json`. 24 lines, status-only registry. Confirms `court_carnival` and `who_scene_it` are both `staging`.
2. **Five of the six requested files are absent**: FEL_VenueRegistry, ArenaSettings.json, DefaultGame.ini, ue_mode_maps.json, and the entire UnrealStarter subtree do not exist.
3. **`infra/` directory exists but is completely empty** — no DefaultGame.ini, no ue5_config subdirectory.
4. **Two comprehensive spec documents exist** under the `fel_environment_layouts` and `fel_mode_implementation_package` naming conventions.
5. **Spawn-point actor names exist** in the implementation package spec but no numeric world-space coordinates exist anywhere.
6. **Interactive object definitions for VeniceBeach and NeuroArena are well-specified** at design/naming level.

---

## Project Overview

- **Purpose**: Final Evolution Lab (FEL) — Multi-sport iOS mobile game, 19 game modes, UE 5.7 C++ with React HUD overlay, neurocognitive coaching engine, shard economy.
- **Stack**: Unreal Engine 5.7 (C++), WKWebView React HUD overlay, iOS Shipping target, Linux streaming target.
- **Key directories**:
  - `/assets/` — spec/plan documents and proposal descriptors (the main content)
  - `/backend/` — single production registry JSON (partial; one file only)
  - `/infra/` — intended for UE5 config but currently EMPTY
  - `/assets/games/final_evolution_lab/workspace/` — UE project workspace, currently EMPTY
  - `/logs/` — session activity log
- **Notable conventions**:
  - Actor naming: `{Venue}_{Mode}_{Type}_{Index}` — e.g., `VeniceBeachCourt_CourtCarnival_SP_Player_01`
  - Cooked level paths: `/Game/FEL/Venues/{Venue}/{Venue}`
  - Sublevel structure: persistent shell + Gameplay, Lighting, Audio, ModeProps, Fallback per venue
  - Spawn prefixes: SP_Player_, SP_Opponent_, SP_AI_, SP_Reset_
  - Camera prefixes: CZ_Gameplay_, CZ_Approach_, CZ_Hero_, CZ_Recovery_
  - Collision prefixes: COL_Hard_, COL_Soft_, COL_Reset_, COL_CamBlock_
  - Trigger prefixes: TRG_Start_, TRG_Score_, TRG_Objective_, TRG_Prompt_, TRG_Audio_, TRG_Fallback_

---

## Relevant Files

### `/backend/FEL_ModeManager.production.json`
- **Role**: Backend mode status registry (only backend file present)
- **Key detail**:
  - `court_carnival` -> `"status": "staging"`
  - `who_scene_it` -> `"status": "staging"`
  - `brain_brawl` -> `"status": "production"` (production sibling sharing Neuro Arena)
  - `market_browse` -> `"type": "non-game-module"` (not staging, not production)
  - cooked_runtime_note: "[EmergentPlayMap] in DefaultGame.ini is the cooked iOS runtime map path source of truth"
  - Lists only 15 named modes despite claiming total_modes: 19, production_modes: 12

### `/assets/fel_environment_layouts_ue57_ios_plan.md` (540 lines)
- **Role**: Venue layout design specification
- **Key detail for VeniceBeach / court_carnival**:
  - Section 4.1 Venice_Beach_Court
  - court_carnival subsumed under "mario_party_fever" handling (name ambiguity — see Risks)
  - Party spawn: central social spawn with branching access to mini-game pads
  - Interactables: party podiums, branded kiosks, tutorial hologram stand
  - Smoke note: "party props disabled cleanly when not in use"
  - Tier B mid-complexity arena map; iOS budget context
- **Key detail for NeuroArena / who_scene_it**:
  - Section 4.13 Neuro_Arena
  - who_scene_it inherits Neuro_Arena spatial logic until dedicated venue registered
  - Spawn types: Brain Brawl mirrored contestant spawns; Who Scene It host-facing + audience-facing reveal spawn
  - Interactables: Answer terminals, countdown pillars, reveal screens, category totems
  - Assumption: "who_scene_it should temporarily inherit Neuro_Arena spatial logic"

### `/assets/fel_mode_implementation_package_ue57_ios.md` (600 lines)
- **Role**: Implementation-ready per-mode layout sheets
- **Key detail for court_carnival (Section 4.18)**:
  - Venue: "Venice Beach Party layout staging variant"
  - Level path: `/Game/FEL/Venues/Venice_Beach_Court/Venice_Beach_Court`
  - Sublevels: SL_VBC_Shell, SL_VBC_CourtCarnival_Staging, SL_VBC_Lighting_DaySunset, SL_VBC_Audio_Court, SL_VBC_Fallback
  - Player spawns: VeniceBeachCourt_CourtCarnival_SP_Player_01 (social), SP_Player_02 (alternate party)
  - AI spawns: optional SP_AI_01 to SP_AI_04 (mini-event anchors)
  - Camera zones: social overview, mini-event hero, promenade recovery
  - Collision: court perimeter hard, kiosk hard, rope soft, off-pad reset
  - Triggers: party intro, mini-event start, reward reveal, prompt, fallback staging trigger
  - Interactables: mini-event kiosk, reward podium, social prompt beacon, reset beacon
  - Props: party banners, podiums, modular kiosks, light strings (all removable via CourtCarnival_Staging sublevel)
  - iOS budget: 375k visible triangles
  - Fallback: decal-only activity pads + one generic reward podium
- **Key detail for who_scene_it (Section 4.17)**:
  - Venue: "Neuro Arena staging variant"
  - Level path: `/Game/FEL/Venues/Neuro_Arena/Neuro_Arena`
  - Sublevels: SL_NA_Shell, SL_NA_WhoSceneIt_Staging, SL_NA_Lighting_Quiz, SL_NA_Audio_Arena, SL_NA_Fallback
  - Player spawns: NeuroArena_WhoSceneIt_SP_Player_01 (host-facing), SP_Player_02 (contestant-facing)
  - AI spawns: optional SP_AI_01 (presenter anchor)
  - Camera zones: reveal-stage gameplay, scene close-up hero, intro wide
  - Collision: stage edge hard, reveal wall hard, console soft, rear reset strip
  - Triggers: scene reveal, answer lock, preview transition, prompt, fallback staging trigger
  - Interactables: reveal console, answer podium, category screen, reset beacon
  - Props: preview curtains, scene frame panels, category totems (all in WhoSceneIt_Staging sublevel)
  - iOS budget: 300k visible triangles
  - Fallback: flat preview cards instead of scene-specific set pieces

---

## Execution Path

Intended data flow from spec to engine:

```
FEL_ModeManager.production.json  (mode status gate — EXISTS)
  -> [EmergentPlayMap] in DefaultGame.ini  (cooked iOS runtime path — ABSENT)
  -> ue_mode_maps.json  (backend-to-UE map name translation — ABSENT)
  -> /Game/FEL/Venues/{Venue}/{Venue}  (persistent level in UE)
    -> SL_{Venue}_Shell  (persistent shell sublevel)
    -> SL_{Venue}_{Mode}_Staging  (mode-specific staging sublevel)
    -> SL_{Venue}_Lighting_*
    -> SL_{Venue}_Audio_*
    -> SL_{Venue}_Fallback
      -> SP_Player_01 / SP_AI_01 / SP_Reset_01  (spawn actors)
      -> CZ_Gameplay_01 / CZ_Hero_01 / CZ_Recovery_01  (camera zones)
      -> COL_Hard_01 / COL_Soft_01 / COL_Reset_01  (collision volumes)
      -> TRG_Start_01 / TRG_Score_01 / TRG_Fallback_01  (triggers)
      -> Interactable actors (kiosk / podium / reveal console / answer terminal)
```

Missing critical links: DefaultGame.ini, ue_mode_maps.json, FEL_VenueRegistry.production.json, ArenaSettings.json, UnrealStarter project tree.

---

## Guidance for the Modifying Agent

### Files to Create (all currently absent)

1. **`backend/ue_mode_maps.json`**
   Maps mode IDs -> Unreal map names:
   - `court_carnival` -> `Venice_Beach_Court`, level path `/Game/FEL/Venues/Venice_Beach_Court/Venice_Beach_Court`
   - `who_scene_it` -> `Neuro_Arena`, level path `/Game/FEL/Venues/Neuro_Arena/Neuro_Arena`

2. **`backend/FEL_VenueRegistry.production.json`**
   Venue descriptors for at minimum VeniceBeach and NeuroArena:
   - `Venice_Beach_Court`: tier B, level path, sublevel names, mode associations (basketball_h2h, basketball_dunk, basketball_3v3, court_carnival)
   - `Neuro_Arena`: tier B, level path, sublevel names, mode associations (brain_brawl, who_scene_it)

3. **`UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json`**
   Mirror of backend registry for UE project config path.

4. **`infra/ue5_config/DefaultGame.ini`**
   [EmergentPlayMap] section entries for court_carnival and who_scene_it.
   Format must follow UE5 DefaultGame.ini conventions (no existing template in workspace).

5. **`UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json`**
   Per-arena gameplay settings (scoreboard config, timer, prop activation flags for staging modes).
   No existing template; naming convention derived from `/Game/FEL/Config/` level path pattern.

### Files to Amend
- **`/backend/FEL_ModeManager.production.json`** — may need `venue_path`, `map_name`, and `sublevels` fields added to `court_carnival` and `who_scene_it` entries. Currently only stores `"status": "staging"`.

### Hard Constraints
- `court_carnival` and `who_scene_it` must remain `"status": "staging"` — do NOT promote to production
- `brain_brawl` is production and shares SL_NA_Shell with who_scene_it — do not break brain_brawl shell
- Venice_Beach_Court shell (SL_VBC_Shell) is shared by basketball_h2h, basketball_dunk, basketball_3v3, court_carnival — shell changes affect all four
- Cooked path convention `/Game/FEL/Venues/{Venue}/{Venue}` — no deviation, no alternate casing
- Staging modes require explicit fallback sublevels (SL_NA_Fallback, SL_VBC_Fallback) and TRG_Fallback_01 triggers
- iOS triangle budgets: court_carnival <= 375k, who_scene_it <= 300k visible triangles
- No translucent layer stacking > 3 deep in hero shots
- No decorative collision within 10m of any spawn

### Coupling Risks
- `market_browse` is non-game-module type, uses separate Module_Library venue path — do not conflate with staging modes
- `mario_party_fever` appears in env layout spec as VeniceBeach mode but absent from FEL_ModeManager — relationship to `court_carnival` is ambiguous
- Abacus blueprint (GitHub, not in workspace) is the stated architecture source of truth

---

## Spec/Layout Files Under Target Naming Conventions

### `fel_environment_layouts` naming
- `/assets/proposal/fel_environment_layouts_ue57_ios_plan/` — proposal directory
- `/assets/proposal/fel_environment_layouts_ue57_ios_plan/fel_environment_layouts_ue57_ios_plan.json` — metadata (status: ready, type: level_design_document)
- `/assets/fel_environment_layouts_ue57_ios_plan.md` — 540-line full spec

### `fel_mode_implementation_package` naming
- `/assets/proposal/fel_mode_implementation_package_ue57_ios/` — proposal directory
- `/assets/proposal/fel_mode_implementation_package_ue57_ios/fel_mode_implementation_package_ue57_ios.json` — metadata (status: ready, type: level_implementation_document, derived_from: fel_environment_layouts_ue57_ios_plan)
- `/assets/proposal/fel_mode_implementation_package_ue57_ios/.keep` — empty placeholder
- `/assets/fel_mode_implementation_package_ue57_ios.md` — 600-line full implementation sheet

---

## Spawn-Point and Coordinate Data

**Exists**: Named actor conventions and logical placement descriptions in spec MDs.
**Does not exist**: Any numeric world-space coordinates (X/Y/Z), UE transform data, or JSON coordinate blocks.

### VeniceBeach (court_carnival) — spawn actor inventory from spec
| Actor Name | Type | Placement Description |
|---|---|---|
| VeniceBeachCourt_CourtCarnival_SP_Player_01 | SP_Player | Social spawn, central court area |
| VeniceBeachCourt_CourtCarnival_SP_Player_02 | SP_Player | Alternate party spawn |
| VeniceBeachCourt_CourtCarnival_SP_AI_01..04 | SP_AI | Optional mini-event anchors x4 |

Inherited from shared basketball modes: baseline spawns (H2H), runway spawn (dunk), 3x team cluster spawns (3v3).

### NeuroArena (who_scene_it) — spawn actor inventory from spec
| Actor Name | Type | Placement Description |
|---|---|---|
| NeuroArena_WhoSceneIt_SP_Player_01 | SP_Player | Host-facing spawn |
| NeuroArena_WhoSceneIt_SP_Player_02 | SP_Player | Contestant-facing spawn |
| NeuroArena_WhoSceneIt_SP_AI_01 | SP_AI | Presenter anchor (optional) |

Inherited from brain_brawl: NeuroArena_BrainBrawl_SP_Player_01, SP_Player_02 (mirrored contestant spawns).

---

## Interactive Object Definitions

### VeniceBeach — court_carnival specific
| Object | Trigger Role | Notes |
|---|---|---|
| mini-event kiosk | TRG_Prompt_01 | Modular, removable via CourtCarnival_Staging sublevel |
| reward podium | TRG_Score_01 / reveal beat | Generic podium in fallback |
| social prompt beacon | TRG_Prompt_01 ambient | Guides at social spawn |
| reset beacon | SP_Reset anchor | Standard across all modes |

### VeniceBeach — shared with basketball modes
| Object | Role |
|---|---|
| ball pickup | Core gameplay start trigger |
| score hoop | TRG_Score_01 |
| tutorial hologram stand | TRG_Prompt_01 educational |
| sideline reset beacon | SP_Reset |

### VeniceBeach — court_carnival mode props (removable sublevel)
Party banners, podiums, modular kiosks, light strings — all in SL_VBC_CourtCarnival_Staging

### NeuroArena — who_scene_it specific
| Object | Trigger Role | Notes |
|---|---|---|
| reveal console | TRG_Start scene reveal | Scene-specific; fallback = flat card |
| answer podium | TRG_Score / answer lock | Shared structure with brain_brawl podiums |
| category screen | TRG_Prompt display | Totem variant in staging |
| reset beacon | SP_Reset anchor | Standard |

### NeuroArena — shared with brain_brawl
| Object | Role |
|---|---|
| answer terminal | TRG_Objective answer lock |
| countdown pillar | TRG_Audio countdown bed anchor |
| reveal screen | TRG_Score reveal confirmation |
| reset beacon | SP_Reset |

### NeuroArena — who_scene_it props (removable sublevel)
Preview curtains, scene frame panels, category totems — all in SL_NA_WhoSceneIt_Staging

---

## Risks / Unknowns

1. **Unreal project workspace is completely empty.** No .uproject, no Content/, no Config/ directory. The entire UE5 project structure must be created before any of the five absent files can live in their intended paths.

2. **`mario_party_fever` vs `court_carnival` name ambiguity.** Env layout spec uses mario_party_fever for the VeniceBeach party variant; FEL_ModeManager and impl package use court_carnival. May be same mode renamed, or two distinct modes. Needs clarification from Abacus blueprint before writing ArenaSettings.json or ue_mode_maps.json.

3. **FEL_ModeManager.production.json is incomplete.** Claims total_modes: 19 / production_modes: 12 but only names 15 modes. karate_endless and several others implied production but not explicitly keyed. Do not treat this file as the exhaustive registry.

4. **DefaultGame.ini [EmergentPlayMap] format is unknown.** No .ini template, schema, or example exists in workspace. Modifying agent must derive format from UE5 DefaultGame.ini conventions (or request a schema from the architecture blueprint).

5. **No canonical world-space coordinate system established.** ArenaSettings.json and VenueRegistry are both absent; no coordinate reference point exists. Spawn-point coordinates must be authored from scratch.

6. **`.keep` placeholder in impl package proposal dir** suggests this was scaffolded intentionally as a proposal stub with no concrete UE asset files produced from either spec doc yet.

7. **S3 CDN published copies** of both spec MDs exist. If local /assets/ copies diverge from CDN, S3 copy is likely the authoritative published version.
