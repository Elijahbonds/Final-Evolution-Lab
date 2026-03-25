# Meshy AI assets – Unreal import

Assets in this folder (GLB with textures):

| File | Description |
|------|-------------|
| **Meshy_AI_Amir_Smith_0319064218_texture.glb** | Character – Amir Smith |
| **Meshy_AI_Eric_Nash_0319064148_texture.glb** | Character – Eric Nash |
| **Meshy_AI_HoopBus_Basketball_0319064117_texture.glb** | Prop – HoopBus basketball |
| **Meshy_AI_Venice_beach_basketba_0319064051_texture.glb** | Environment – Venice Beach basketball court |
| **Venice_beach_UE5/** | **Pre-converted OBJ + MTL + textures** (recommended on **UE 5.2+** if `.glb`/glTF import fails or is unstable) |
| **Meshy_AI_Elijah_Bonds_biped/** | Character – Elijah Bonds (biped, 2 GLBs with skin) |
| ↳ *Animation_Running_withSkin.glb* | Running animation + skinned mesh |
| ↳ *Animation_Walking_withSkin.glb* | Walking animation + skinned mesh |

---

## Importing GLB in Unreal Engine 5

Unreal’s built-in support for **glTF/GLB** varies by version. Prefer one of these:

### Option A – glTF Importer plugin (if available)

1. **Edit → Plugins** → search **“glTF”** or **“GLTF”** → enable **glTF Importer** (or **Interchange glTF**) → restart.
2. Drag each `.glb` from this folder into the Content Browser, or **File → Import** and select the GLB.
3. Use default import options; enable **Import Textures** / **Import Materials** if present.
4. For **Elijah_Bonds_biped**: import both Running and Walking GLBs; use the Skeleton from one and retarget or use the included animations on the same skeleton.

### Option B – Convert GLB → FBX in Blender, then import FBX

1. **Blender**: File → Import → glTF 2.0 (`.glb`). Open each GLB.
2. **File → Export → FBX** (embed textures or export to a folder; keep “Selected Objects” or export all).
3. In **Unreal**: Import the FBX (Materials/Textures on). For skinned characters, ensure **Skeleton** and **Import Mesh** are on; create/use a Physics Asset if needed.

### After import (characters)

- **Skeleton**: Assign to the same mannequin/skeleton for retargeting if you use UE mannequin animations, or use the Meshy skeleton as-is.
- **Materials**: GLB brings base color/PBR; fix up normals/roughness in the Material Editor if needed.
- **Collision**: Add capsule or simple collision to the character mesh for movement/physics.
- **Scale**: Check scale in the level; Meshy exports can be in different units (often 1 unit = 1 m).

### After import (Venice court + basketball prop)

- **Venice court**: Static mesh; enable **Nanite** if high poly; add collision (Auto Convex or custom).
- **Basketball**: Static or simple skeletal if needed; assign to a blueprint for gameplay.

---

## Venice Beach GLB won’t import (UE 5.2+)

The file **`Meshy_AI_Venice_beach_basketba_0319064051_texture.glb`** is a **valid** glTF 2.0 binary (~15 MB, one static mesh, ~123k vertices, PBR + embedded JPEG textures). If Unreal still refuses it, work through this list.

### 1) Use the glTF pipeline (not “wrong” asset type)

- Import as a **Static Mesh** (environment), not Skeletal.
- **Edit → Plugins**: enable **Interchange** and any **glTF** / **Interchange glTF** entries your **5.2** build lists (names vary by minor version). Restart the editor.
- In **Content Browser**: **Add / Import** → pick the `.glb` (or drag the file into a folder under your project’s **`Content/`** tree).

### 2) Read the real error

- **Window → Developer Tools → Output Log** (filter **LogInterchange** / **glTF** / **Error**).
- Copy the **exact** message; common patterns:
  - **Plugin disabled** → enable Interchange glTF and restart.
  - **Path / permissions** → copy the GLB into **`YourProject/Content/_Import/`** and import from there (avoid iCloud “online only” files).
  - **Crash** → often GPU/driver or a 5.x glTF bug; use the Blender → FBX workaround below.

### 3) Reliable workaround: Blender → FBX (or re-export GLB)

1. **Blender** (4.x): **File → Import → glTF 2.0** → open the Venice `.glb`.
2. **File → Export → FBX**  
   - Enable **Selected Objects** (select the mesh) or export all.  
   - **Apply Modifiers** on.  
   - **Mesh** type, **+Y Up** (Unreal is Z-up; Blender’s FBX preset usually handles this).
3. In Unreal: import the **FBX** as **Static Mesh**, materials/textures on.

Optional: re-export from Blender as **glTF Binary** with textures as **PNG** instead of JPEG (some glTF paths are pickier about JPEG).

### 4) OBJ fallback from Meshy

If you still have the Meshy web app: export the same scene as **OBJ + textures** (like the Luma workflow) and import **OBJ** into Unreal—OBJ import is very stable for large static environments.

---

## Paths (for import dialog)

- Characters/props:  
  `UnrealStarter/MeshyAssets/Meshy_AI_Amir_Smith_0319064218_texture.glb` (and the other three GLBs in `MeshyAssets/`).
- Elijah Bonds biped:  
  `UnrealStarter/MeshyAssets/Meshy_AI_Elijah_Bonds_biped/Meshy_AI_Elijah_Bonds_biped_Animation_Running_withSkin.glb`  
  `UnrealStarter/MeshyAssets/Meshy_AI_Elijah_Bonds_biped/Meshy_AI_Elijah_Bonds_biped_Animation_Walking_withSkin.glb`
