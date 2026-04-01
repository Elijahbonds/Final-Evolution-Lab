# Venice court + Luma scan — one playable environment

**“Compile”** here means **import** meshes and **compose** them in a **Persistent Level** (no special C++ required for the static geometry).

## 0. Audit — Venice Beach + Luma vs basketball modes (Unreal)

| Mode (`ArenaSettings.json`) | `unrealOpenLevelPackage` | Environment role |
|----------------------------|----------------------------|-------------------|
| `basketball_h2h` | `/Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach` | Same map: street 1v1 |
| `basketball_dunk` | same | Same map: dunk runway + hoops live in slice logic |
| `basketball_3v3` | same | Same map: wider spawn offsets / team starts in level or GM |

**Art stack (intended):** **Meshy `SM_VeniceCourt`** = authoritative floor, lines, and read as “Venice Beach court”. **Luma `SM_LumaCourt`** = photogrammetry shell / boardwalk context (~4 m footprint — often **scaled up**). Optional **extra Luma OBJ exports** (see §1b) = additional scanned geometry for **backdrop**, **LOD swap**, or **set dressing** — not a second travel target; keep **one** `VeniceBeach.umap` for all three modes unless you split packages in `ArenaSettings.json` later.

**Repo sources for Luma scans:**

| Source folder | Role |
|---------------|------|
| `UnrealStarter/LumaScan/` | Primary scan; `placement_hints.json` has bounds + suggested hoop anchors in OBJ space |
| `UnrealStarter/LumaExports/capture_03/` | High-detail textured mesh (closest to legacy LumaScan) |
| `UnrealStarter/LumaExports/capture_04/` | Smaller OBJ / fewer materials — good **mobile** or **distant** backdrop |
| `UnrealStarter/LumaExports/capture_05/` | More material slots than 04 — use for **hero** backdrop or alternate lighting pass |

**Per-mode layout notes (same level):**

- **H2H:** Single primary `PlayerStart` axis along court; Luma shell frames the Meshy court.
- **Dunk contest:** Long approach is **gameplay + props**; ensure runway strip on `SM_VeniceCourt` is clear of Luma meshes clipping through (raise shell or mask).
- **3v3:** Offset extra `PlayerStart` actors laterally per half; optional duplicate Luma block scaled as **far background** (non-colliding) to sell depth.

See `Content/FEL/Venues/VENUE_SETUP.txt` and `ArenaSettings.json` for travel and cook list.

## 1. Import

| Asset | Source in repo | Content path (suggested) | Rename to |
|--------|----------------|---------------------------|-----------|
| Luma scan | `UnrealStarter/LumaScan/mesh.obj` + `textures/` | `/Game/FEL/Environment/Luma/` | `SM_LumaCourt` |
| Venice court | `MeshyAssets/Venice_beach_UE5/Venice_mesh.obj` + `textures/` (or Meshy GLB) | `/Game/FEL/Environment/Venice/` | `SM_VeniceCourt` |

Use **Static Mesh**, **Nanite** if useful, **collision** on both (player must walk on Venice floor).

### 1b. Additional Luma textured-mesh exports (optional)

Import any of `UnrealStarter/LumaExports/capture_03|04|05/mesh.obj` (+ `mesh.mtl` + `textures/`) into e.g. **`/Game/FEL/Environment/LumaCaptures/`** and rename for clarity:

| After import (suggested name) | Typical use on VeniceBeach |
|------------------------------|----------------------------|
| `SM_LumaCapture03` | Full-detail environment block (match or replace primary shell) |
| `SM_LumaCapture04` | Lighter mesh — **iOS / perf** variant or mid-distance filler |
| `SM_LumaCapture05` | Alternate angle / lighting; **set dressing** behind fences |

Place as **child actors** under a folder `ENV_LumaBackdrops`, offset/rotate so they **do not intersect** the playable Venice floor. Turn **collision off** or **OverlapOnly** on pure backdrop meshes if they steal the walkable surface from `SM_VeniceCourt`.

## 2. Layout (recommended starting point)

1. Drag **`SM_LumaCourt`** into the level — this is the **world / backdrop** (scan footprint ~4 m; scale up if you want it to read as “environment shell”).
2. Drag **`SM_VeniceCourt`** in front of the playable area — **this is the actual court** (lines, hoop zones). **Scale and rotate** so:
   - Floor normal is **+Z** (Unreal up).
   - Venice mesh **sits on** or **clips slightly into** the Luma ground so there is no gap.
3. Add **PlayerStart** on the Venice floor, facing along the court.
4. Add **Directional Light** + **Sky Atmosphere** or **Sky Light** so the Meshy materials read clearly.

## 3. Tuning

- If Venice and Luma **units** differ, uniform **scale** one mesh (often Luma stays 1.0, Venice scaled to match real-world feel).
- For a **single cohesive look**, later you can **replace** Luma materials with a shared neutral ground material in the **Material Instances** Unreal generated on import.

## 4. Game mode

Set **GameMode Override** to **`FELBasketballGameMode`** so the **Elijah** pawn and **ball** spawn automatically (after C++ integration and successful build).

## 5. `fel_setup_level.py` (quick test map)

`UnrealStarter/EditorPython/fel_setup_level.py` spawns **one** Luma import path (`luma_environment`). After you import **`capture_04`** or **`capture_05`**, add optional `StaticMeshActor`s in the **same** test level or extend `ASSET_PATHS` with **Copy Reference** paths — do not assume filenames; Unreal renames on import.

---

*Final Evolution Lab — UnrealStarter.*
