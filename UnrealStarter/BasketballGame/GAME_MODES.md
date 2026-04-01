# FEL Arena — game modes (single source of truth)

This document is the **shared matrix** for design, QA, and automation: **15 sport / activity modes** plus **Sovereign Shop** (`market_browse`). Config rows add **Karate variants** (`karate`, `karate_h2h`, `karate_endless`) so JSON can express H2H vs endless without extra enums. Runtime wiring uses `active_mode` in **`readiness_snapshot.json`** and matching rows in **`Content/FEL/Config/ArenaSettings.json`**.

**Shell note:** Modes are Arena-style labs (shared verbs, readiness tuning, PRQ HUD). They are not a finished consumer SKU.

---

## Matrix (`active_mode` → venue → PRQ attribute)

| `active_mode` | Default venue (`.umap` package) | HUD PRQ attribute (`FELArenaBridge`) | Notes |
|---------------|-----------------------------------|--------------------------------------|--------|
| `basketball_h2h` | VeniceBeach | Court IQ | Street 1v1 |
| `basketball_dunk` | VeniceBeach | Hang Time | Dunk contest |
| `basketball_3v3` | VeniceBeach | Spacing IQ | Street 3v3 |
| `karate` | Dojo | Discipline | Legacy row; prefer `karate_h2h` / `karate_endless` for new snapshots |
| `karate_h2h` | Dojo | Strike Tempo | Timed / target score |
| `karate_endless` | Dojo | Endurance | No round cap |
| `baseball` | BaseballPark | Barrel Control | |
| `football` | Gridiron | Field Vision | |
| `soccer` | SoccerStadium | First Touch | |
| `golf` | Links | Tempo | |
| `tennis` | TennisCourt | Court Coverage | |
| `volleyball` | SandCourt | Read & React | |
| `gymnastics` | TrainingFloor | Body Line | |
| `brain_brawl` | NeuroArena | Cognitive Load | Academy / no ball |
| `surfing` | VeniceBeach | Line IQ | Coastal reuse until dedicated surf venue |
| `skateboarding` | Dojo | Edge Grip | Park line (Dojo reuse until dedicated skate venue) |
| `snowboarding` | TrainingFloor | Carve Control | Slope line (TrainingFloor reuse until alpine venue) |
| `market_browse` | Luma_Venice_Shop | Fit & Presence | Sovereign Shop (non-sport) |

**“16 modes” pitch:** **15** rows above from `basketball_h2h` through `snowboarding` (treat **Karate** as one product with three JSON ids), plus **`market_browse`** = **16 shipped slots**. Alternatively **15 sport + shop** without counting Karate variants twice.

---

## PRQ / economy (Unreal)

- **Attribute label** comes from **`FELArenaBridge::AttributeLabelForGameModeId`** (per `active_mode`, case-insensitive).
- **Displayed 0–1 attribute** uses **`AttributeDisplay01To100`** (mode-specific scale).
- **Shards** use **`ModeWeightForGameModeId`** in **`ComputeShardsEarned`** when economy is enabled.

Details and Swift parity notes: **`VISION_ALIGNMENT.md`** (repo root) and `FELArenaBridge.h`.

---

## Karate variants (H2H vs endless)

Merged enum is **`EFELArenaMode::Karate`**; **JSON row key** (`karate_h2h`, `karate_endless`, …) is stored on game state and passed into **`FELArenaRulesRegistry`** so rules differ without new enum values. See `FELBasketballGameMode` + `FELArenaRulesRegistry`.

---

## Release gate: maps must exist

**`Config/DefaultGame.ini`** → **`MapsToCook`** must list every venue package that **`ArenaSettings.json`** references, and each path must resolve to a **`.umap`** on disk. See **`Content/FEL/Venues/VENUE_SETUP.txt`** and run **`verify_fel_venue_maps.sh`** before packaging.

---

## Blueprint / native

Default game mode is native **`FELBasketballGameMode`** (`Config/DefaultEngine.ini`). Subclass in-editor if you extend C++ and need Blueprint overrides.

---

*Implemented under `UnrealStarter/BasketballGame/Source/FinalEvolutionLab/`; config: `Content/FEL/Config/ArenaSettings.json` (mirror: `ArenaSettings.json`).*
