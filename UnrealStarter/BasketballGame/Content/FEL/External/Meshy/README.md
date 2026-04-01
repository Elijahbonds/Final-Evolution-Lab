# Meshy GLB staging (Unreal — canonical hybrid path)

**Source of truth:** GLBs in this folder are copied from `UnityProject/Assets/StreamingAssets/Meshy/` for **Unreal Engine 5** import (FBX/glTF pipeline per project settings).  
**Unity:** The duplicate `UnityProject/.../Meshy/` path is **deprecated** for new work — keep Unity-only scripts in sync only if you still ship UaaL; otherwise edit Unreal content here.

## Basketball / Venice (primary FEL props)

| File | Unreal import target | Notes |
|------|----------------------|--------|
| `Meshy_AI_HoopBus_Basketball_0319064117_texture.glb` | `/Game/FEL/Props/` → **`SM_HoopBusBasketball`** (or keep default name — `FELBasketballActor` resolves both) | `IMPORT_CHECKLIST.md` |
| `Meshy_AI_Elijah_Bonds_biped_Animation_Walking_withSkin.glb` | `/Game/FEL/Characters/ElijahBonds/` → **`SKM_ElijahBonds_Walking`** | Movement test character |
| `Meshy_AI_Elijah_Bonds_biped_Animation_Running_withSkin.glb` | Same folder (optional run variant) | Used by iOS SceneKit hero if present |
| Venice / Luma | `UnrealStarter/MeshyAssets/Venice_beach_UE5/`, `UnrealStarter/LumaScan/` | See `VENICE_LUMA_LEVEL.md` |
| Extra Luma scans (OBJ) | `UnrealStarter/LumaExports/capture_03/`, `capture_04/`, `capture_05/` | Optional backdrops / mobile LOD on same `VeniceBeach` map — import to `/Game/FEL/Environment/LumaCaptures/` |

**iOS SceneKit:** Copy the same `.glb` filenames into `ios/FinalEvolutionLab/Meshy/` (see that folder’s `README.md`).

## Soccer / tennis (stadium props)

| File | Use |
|------|-----|
| `Meshy_AI_Stadium_Soccer_stad_0323202143_stylize.glb` | Soccer stadium environment |
| `Meshy_AI_Goal_Posts_Professi_0323202113_texture.glb` | Goal posts |
| `Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture.glb` | Soccer ball |
| `Meshy_AI_Tennis_Racket_Profe_0323202215_texture.glb` | Tennis racket |
| `Meshy_AI_Tennis_Ball_Bright__0323202210_texture.glb` | Tennis ball |

**Import:** Drag into `/Game/FEL/Environment/Soccer/` (recommended) or `/Game/FEL/StreamingAssets/Meshy/` in the Unreal Editor. Static mesh names usually match the GLB file name; `AFELSoccerStadiumPresentation` and `AFELBasketballActor::ApplyArenaBallVisual` load those paths at runtime. Stadium shell: merge into `/Game/FEL/Venues/SoccerStadium/SoccerStadium` after running `EditorPython/fel_quick_soccer_stadium_level.py`.

**Crowd SFX:** Add a looping Sound Cue at `/Game/FEL/Audio/Ambience/SC_Crowd_Stadium_Loop` (or assign `CrowdAmbienceSound` on a `FELSoccerStadiumPresentation` placed in the level).
