# UE 5.2 — FEL import checklist (copy/paste workflow)

**Product context:** These assets support the **Arena / Venice court** lab aligned with **`VISION_ALIGNMENT.md`** (same ecosystem as the iOS app — not a standalone art pack).

`fel_setup_level.py` expects the paths below. After each import, **rename** the asset in Content Browser if needed so the **object name** matches (F2 rename).

---

## 1. Luma environment

- Import **`UnrealStarter/LumaScan/mesh.obj`** into **`/Game/FEL/Environment/Luma/`** (keep **`mesh.mtl`** + **`textures/`** beside the OBJ).
- Rename static mesh → **`SM_LumaCourt`**.  
- **Reference:** `/Game/FEL/Environment/Luma/SM_LumaCourt`
- Bounds / hoop hints (OBJ space): **`UnrealStarter/LumaScan/placement_hints.json`**.

### 1b. Extra Luma scans (same Venice Beach venue — backdrop / LOD)

Repo includes **three** additional textured-mesh exports: **`UnrealStarter/LumaExports/capture_03/`**, **`capture_04/`**, **`capture_05/`** (each has `mesh.obj`, `mesh.mtl`, `textures/`). See **`UnrealStarter/LumaExports/README.md`** for size/material notes.

- Import each into **`/Game/FEL/Environment/LumaCaptures/`** (or subfolders per capture).
- Suggested renames: **`SM_LumaCapture03`**, **`SM_LumaCapture04`**, **`SM_LumaCapture05`**.
- Use on **`VeniceBeach`** as non-primary shells (offset from **`SM_VeniceCourt`**), or swap **`SM_LumaCourt`** for **`capture_04`** on low-end targets. Full workflow: **`BasketballGame/VENICE_LUMA_LEVEL.md`** §0 and §1b.

## 2. Elijah Bonds (movement test)

- Import **`Meshy_AI_Elijah_Bonds_biped_Animation_Walking_withSkin.glb`** into **`/Game/FEL/Characters/ElijahBonds/`** (or Blender → FBX if GLB fails).
- Rename skeletal mesh → **`SKM_ElijahBonds_Walking`**.  
- Add **AnimBP** or **Animation Sequence** on the actor after the Python spawn (script does not assign animation).
- **Reference:** `/Game/FEL/Characters/ElijahBonds/SKM_ElijahBonds_Walking`

## 3. HoopBus basketball (prop)

- Import **`Meshy_AI_HoopBus_Basketball_0319064117_texture.glb`** into **`/Game/FEL/Props/`**.
- Rename static mesh → **`SM_HoopBusBasketball`**.  
- **Reference:** `/Game/FEL/Props/SM_HoopBusBasketball`

## 4. Venice court (basketball floor — use with Luma)

- Import **`UnrealStarter/MeshyAssets/Venice_beach_UE5/Venice_mesh.obj`** (+ `textures/`) into **`/Game/FEL/Environment/Venice/`**.
- Rename static mesh → **`SM_VeniceCourt`**.
- Compose with **`SM_LumaCourt`** in-editor: see **`BasketballGame/VENICE_LUMA_LEVEL.md`**.

## 5. Optional GLBs

- Amir Smith, Eric Nash, extra Venice GLB → **`/Game/FEL/Characters/Other`** or **`/Game/FEL/Environment/Venice`**.

## 6. Level alignment

- Place **`SM_LumaCourt`** in the level (or run the script).
- **Rotate** the Luma actor until the **floor is horizontal** (Unreal **Z** up).
- If props float or sink, nudge **PROP_Basketball_*** / **CHAR_ElijahBonds_Test** in the viewport or edit **`HOOP_OFFSET_CM`** / **`CHARACTER_Z_ABOVE_FLOOR_CM`** in **`EditorPython/fel_setup_level.py`**.

## 7. Python spawn

1. **Edit → Plugins** → **Python Editor Script Plugin** → enable → restart.
2. Copy **`EditorPython/fel_setup_level.py`** to **`YourProject/Content/Python/`** (create folder).
3. If any name differs, either rename assets or edit **`ASSET_PATHS`** (or use **Copy Reference** on each asset and paste into the dict).
4. Run in Output Log (Python):

```python
import sys
sys.path.append("C:/YourProject/Content/Python")  # or macOS path
import importlib
import fel_setup_level
importlib.reload(fel_setup_level)
fel_setup_level.run()
```

5. **File → Save Current** on the level.

---

## Asset path summary (must match `ASSET_PATHS`)

| Asset | Full Unreal object path |
|--------|-------------------------|
| Luma | `/Game/FEL/Environment/Luma/SM_LumaCourt.SM_LumaCourt` |
| Venice court | `/Game/FEL/Environment/Venice/SM_VeniceCourt.SM_VeniceCourt` |
| Elijah | `/Game/FEL/Characters/ElijahBonds/SKM_ElijahBonds_Walking.SKM_ElijahBonds_Walking` |
| Basketball | `/Game/FEL/Props/SM_HoopBusBasketball.SM_HoopBusBasketball` |

If **Copy Reference** shows a different string, paste that into **`fel_setup_level.py`** instead.
