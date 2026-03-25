# Unreal Editor Python — FEL level setup (UE 5.7 / MyProjec)

These scripts work with **Unreal Engine 5.7** and the **MyProjec** game module (same layout as **`../BasketballGame/`** templates). Older **5.2+** builds are generally compatible; enable the plugin the same way.

## Enable Python

1. **Edit → Plugins** → enable **Python Editor Script Plugin** → restart the editor.
2. **Edit → Project Settings → Plugins → Python** → enable **Developer Mode** if you want the console.

## Project layout

Typical paths on disk:

- **`.uproject`:** `~/Documents/Unreal Projects/MyProjec/MyProjec.uproject`
- **Python folder:** `MyProjec/Content/Python/` (create if missing)

`fel_quick_playtest_level.py` expects **compiled MyProjec C++** (e.g. `/Script/MyProjec.FELHoopScoreVolume`). See **`../BasketballGame/PACKAGE_AND_TEST.md`** § fast playtest map.

## One-time: copy assets into the project

Follow **`../FEL_UE52_LevelSetup.md`**: copy `LumaScan/` and `MeshyAssets/` into your project (or import directly from this repo path), then import so asset names match the constants in `fel_setup_level.py` (or edit the constants).

## Run the setup script

1. Copy `fel_setup_level.py` into your UE project, e.g. **`Content/Python/fel_setup_level.py`** (create the folder).
2. In Unreal: **Window → Developer Tools → Output Log** → dropdown **Python** (or use the Python console if exposed).
3. Execute:

```python
import sys
sys.path.append("/Users/YOU/Documents/Unreal Projects/MyProjec/Content/Python")
import fel_setup_level
fel_setup_level.run()
```

Or from **Tools → Execute Python Script** (if your build exposes it), pick `fel_setup_level.py`.

4. Save the level (**File → Save Current**).

The script spawns actors; it does not import FBX/OBJ/GLB (use Content Browser import first).
