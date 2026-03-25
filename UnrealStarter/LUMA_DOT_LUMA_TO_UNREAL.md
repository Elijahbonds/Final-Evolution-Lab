# Converting `*.luma` → Unreal Engine

## Can `.luma` be converted automatically?

**No.** Files like `luma.luma` use Luma’s **private project format** (binary, starts with `LUMA` magic). They are **not** meshes or textures until you **export** them from **Luma’s official app**.

There is no supported public spec to turn `.luma` into OBJ/FBX/GLB outside Luma’s export flow.

## What to do instead (works in UE 5.2+)

1. **Open the `.luma` project** in the Luma app (mobile or web, same account as the capture).
2. **Export** a standard asset:
   - **OBJ + textures** — most reliable for large static scans in Unreal.
   - **FBX** — also fine if Luma offers it.
   - **GLB** — works if **Interchange glTF** imports cleanly in your project; if not, use OBJ/FBX or Blender as a passthrough.
3. In **Unreal**: **Content Browser → Import** → choose the exported **OBJ** or **FBX** as **Static Mesh**.
4. Enable **Nanite** on the mesh if it’s high poly; add **collision** (Auto Convex or custom).

## Already in this repo

If your scan is the one that was exported as **`textured_mesh_obj.zip`**, the Unreal-ready files are here:

- `UnrealStarter/LumaScan/mesh.obj`
- `UnrealStarter/LumaScan/mesh.mtl`
- `UnrealStarter/LumaScan/textures/*.png`

See **`LumaScan/README_IMPORT.md`** for step-by-step Unreal import.

## Summary

| Format        | Unreal import |
|---------------|----------------|
| `.luma`       | ❌ Not importable — export from Luma first |
| `.obj` + MTL + textures | ✅ Static mesh (recommended for scans) |
| `.fbx`        | ✅ Static mesh |
| `.glb`        | ✅ Often works (Interchange glTF); use OBJ if it fails |

## 3-step checklist (drop folder)

Follow **`LumaExportForUE/README.md`** — export OBJ from Luma → place `mesh.obj` + `textures/` in that folder (or UE `Content/`) → import as Static Mesh in UE.
