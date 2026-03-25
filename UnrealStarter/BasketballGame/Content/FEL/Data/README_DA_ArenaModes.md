# UFELArenaModeData — 12 Primary Data Assets

Unreal `.uasset` files are binary; they are **not** committed from this repo snippet. Create them once in the Editor so designers can tune sports **without C++**.

## Paths (match `FELArenaModeCatalog.cpp`)

| Asset name | `EFELArenaMode` |
|------------|------------------|
| `DA_ArenaMode_BasketballH2H` | BasketballHeadToHead |
| `DA_ArenaMode_BasketballDunk` | BasketballDunkContest |
| `DA_ArenaMode_Basketball3v3` | Basketball3v3 |
| `DA_ArenaMode_Karate` | Karate |
| `DA_ArenaMode_Baseball` | Baseball |
| `DA_ArenaMode_Football` | Football |
| `DA_ArenaMode_Soccer` | Soccer |
| `DA_ArenaMode_Golf` | Golf |
| `DA_ArenaMode_Tennis` | Tennis |
| `DA_ArenaMode_Volleyball` | Volleyball |
| `DA_ArenaMode_Gymnastics` | Gymnastics |
| `DA_ArenaMode_BrainBrawl` | BrainBrawl |

**Content folder:** `Content/FEL/Data/` (Unreal mount `/Game/FEL/Data/`).

## Creation steps (UE 5.2+)

1. **Content Browser → right-click → Miscellaneous → Data Asset.**
2. Pick class **`UFELArenaModeData`**.
3. Name the asset exactly as in the table (e.g. `DA_ArenaMode_BasketballH2H`).
4. Set **`ArenaMode`** to the matching enum value.
5. Copy **`ArenaRules`** from the C++ factory baseline: run PIE once with `GetMergedRules`, or duplicate from a template asset after first create.
6. Fill **`Hud`** (titles, **Perfect Form** checklist lines) and **`ArenaRules.SportNeuro`** demonstrator soft refs (`/Game/Models/Avatar/...`).

## Hotfix JSON

`Content/FEL/Config/ArenaSettings.json` still merges **on top** of each Data Asset via `FELArenaRulesRegistry::ApplyJsonOverridesToRules` (Swift / live tuning).

## Async load

`AFELBasketballGameMode` requests **`FELArenaModeCatalog::GetDefaultSoftPathForMode(active_mode)`** through `FStreamableManager` so only the active mode package and its referenced meshes/AnimBPs resolve for that session.
