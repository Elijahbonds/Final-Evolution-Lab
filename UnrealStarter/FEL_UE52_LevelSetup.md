# Unreal 5.2 — Import all FEL assets, Luma environment, hoops, Elijah Bonds

This repo does **not** ship a `.uproject`. Use your **Unreal Engine 5.2** project and either import from the paths below or copy folders into **`YourProject/Content/`** first so texture paths resolve.

**Short checklist (same as below):** **`IMPORT_CHECKLIST.md`**

---

## 1. Content folder layout (recommended)

Create in the Content Browser:

| Path | Purpose |
|------|--------|
| `/Game/FEL/Environment/Luma` | Luma scan (primary environment) |
| `/Game/FEL/Environment/Venice` | Optional Venice court (not the main env for this setup) |
| `/Game/FEL/Characters/ElijahBonds` | Test movement character |
| `/Game/FEL/Characters/Other` | Amir Smith, Eric Nash (optional) |
| `/Game/FEL/Props` | Basketball + future rim/backboard |

---

## 2. Import order (Luma first)

### A. Luma scene — **this is the environment**

1. Keep **`mesh.obj`**, **`mesh.mtl`**, and **`textures/`** in the **same folder** (from `UnrealStarter/LumaScan/`).
2. **Content Browser → Import** → `mesh.obj` into `/Game/FEL/Environment/Luma`.
3. Import options (UE 5.2): **Static Mesh**, **Import Materials** / **Import Textures** on, normals as needed.
4. Open the static mesh → enable **Nanite** if appropriate → **Collision** (Auto Convex or complex for tests).
5. Rename asset to something clear, e.g. **`SM_LumaCourt`** (match `fel_setup_level.py` or edit the script).

**Placement math:** see **`LumaScan/placement_hints.json`** (axis-aligned bounds from the OBJ). After import, **rotate the actor** so the ground reads as horizontal in your level; then fine-tune hoop props in the viewport.

### B. Elijah Bonds — **default movement test model**

1. Import **`MeshyAssets/Meshy_AI_Elijah_Bonds_biped/Meshy_AI_Elijah_Bonds_biped_Animation_Walking_withSkin.glb`** (primary for walk tests).
2. Also import **`…Animation_Running_withSkin.glb`** if you want a run variant.
3. If GLB fails in 5.2: Blender → import GLB → export **FBX** with armature → import FBX as Skeletal Mesh in UE.
4. Save skeletal mesh as e.g. **`SKM_ElijahBonds_Walking`** under `/Game/FEL/Characters/ElijahBonds/`.
5. Create an **Animation Blueprint** (or assign an **Animation Sequence**) on the mesh in the level — the Python spawner only places the actor.

### C. “Hoops” — what we have in repo

| Asset | Role |
|-------|------|
| **`Meshy_AI_HoopBus_Basketball_0319064117_texture.glb`** | Basketball prop only (no rim/backboard in repo) |

Import it as a **Static Mesh** → e.g. **`SM_HoopBusBasketball`** under `/Game/FEL/Props/`.

**Placement:** Opposite ends of the ~4 m Luma footprint (~±1.65 m from center on one axis). The included **`EditorPython/fel_setup_level.py`** spawns **two** instances as stand-ins for “under hoop” markers. When you add a real **rim + backboard** mesh, parent it to those actors or replace them.

The Venice Beach GLB/OBJ is a **full outdoor court** mesh — use it only if you switch environments; for your request (**Luma = environment**), Venice stays optional.

### D. Import the rest (optional)

- **`Meshy_AI_Amir_Smith_0319064218_texture.glb`**
- **`Meshy_AI_Eric_Nash_0319064148_texture.glb`**
- **`Meshy_AI_Venice_beach_basketba_0319064051_texture.glb`** or **`Venice_beach_UE5/Venice_mesh.obj`** (fallback if GLB fails)

---

## 3. Automated level spawn (Python)

After imports, paths in **`EditorPython/fel_setup_level.py`** must match your assets (use **Copy Reference** in Content Browser).

1. Enable **Python Editor Script Plugin** (see **`EditorPython/README.md`**).
2. Run `fel_setup_level.run()` — it spawns:
   - **`ENV_LumaCourt`** — Luma static mesh at origin  
   - **`PROP_Basketball_HoopEnd_A` / `_B`** — two basketball props at court ends  
   - **`CHAR_ElijahBonds_Test`** — Elijah skeletal mesh for movement tests  

3. **Save the level**, set **Game Mode** / default pawn if you are testing **PlayerController** + character.

---

## 4. Pawn / movement test (quick)

- Use **Third Person** template logic, or assign **`FELPlayerController`** (from this repo’s `UnrealStarter`) and a **pawn** that uses **Elijah**’s skeletal mesh.
- Ensure **collision** on Luma mesh so the character stands on the scan floor after you align rotation/scale.

---

## 5. Checklist

- [ ] Luma **`SM_LumaCourt`** imported with materials/textures  
- [ ] Level: Luma actor rotated so floor is horizontal  
- [ ] **`SKM_ElijahBonds_Walking`** + AnimBP or sequence  
- [ ] **`SM_HoopBusBasketball`** at two ends (script or hand-placed)  
- [ ] Optional: full hoop static mesh swapped in for basketball prop  

---

*Final Evolution Lab — UnrealStarter.*
