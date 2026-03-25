# Prepare a Luma capture for Unreal (3 steps)

**`*.luma` files cannot be converted on disk** — they are Luma’s app project format. You must **export** from Luma, then import into Unreal.

## Step 1 — Export from Luma

1. Open your project **`luma.luma`** in the **Luma** app (iOS / web / desktop — wherever you use Luma).
2. Choose **Export** / **Download** and pick **textured mesh** as:
   - **OBJ** + textures (best for UE static scans), **or**
   - **FBX** if OBJ isn’t offered.

You should get something like: `mesh.obj`, `mesh.mtl`, and a **`textures/`** folder (or a single `.zip`).

## Step 2 — Put files here (or in your UE `Content/` folder)

1. If you got a **`.zip`**, unzip it.
2. Copy the whole folder into **this directory** (`LumaExportForUE/`) **or** directly into your Unreal project’s **`Content/`** tree (e.g. `Content/Scans/LumaCourt/`).

Keep **`mesh.obj`**, **`mesh.mtl`**, and **`textures/`** in the **same folder** so material paths resolve.

## Step 3 — Import in Unreal Engine 5.2+

1. **Content Browser** → **Import** → select **`mesh.obj`**.
2. **Import Type**: **Static Mesh**  
   **Import Materials** / **Import Textures**: **On**  
   **Normal Import Method**: **Import Normals and Tangents** (try **Compute Normals** if shading is wrong).
3. Open the new Static Mesh → enable **Nanite** → **Collision** → **Auto Convex** (or **Use Complex as Simple** for quick tests).

---

## Already exported in this repo?

If this capture is the same as **`textured_mesh_obj.zip`**, you don’t need Step 1 again — use:

`UnrealStarter/LumaScan/mesh.obj`  
See **`../LumaScan/README_IMPORT.md`**.

---

## Summary

| File        | Unreal |
|------------|--------|
| `luma.luma` | ❌ Not importable — export in Luma first |
| `mesh.obj` + `mesh.mtl` + `textures/` | ✅ Static mesh |
