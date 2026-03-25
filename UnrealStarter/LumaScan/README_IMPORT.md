# Luma scan – Unreal import

## About `.luma` project files

A **`.luma`** file is Luma’s **proprietary app/project format** (binary, not OBJ/GLB). **Unreal cannot import it directly**, and it **cannot be converted here** without Luma’s software—you must **open the project in the Luma app** and **export** a standard format.

**Export from Luma for Unreal (recommended):**

1. Open `yourfile.luma` in the **Luma** iOS/macOS/web app (wherever you created it).
2. Export **Textured mesh** as **OBJ** (with textures) or **FBX** if available.
3. Import the exported **OBJ/FBX** into Unreal as a **Static Mesh** (same steps as below).

If this repo’s **`LumaScan/`** folder came from the same capture as your `luma.luma`, you can skip re-export and use **`mesh.obj`** here.

**Additional captures:** **`../LumaExports/capture_03`**, **`capture_04`**, **`capture_05`** (from `textured_mesh_obj` zips) — see **`../LumaExports/README.md`**.

---

- **mesh.obj** – static mesh (~95 MB, high poly)
- **mesh.mtl** – material definitions (48 materials, diffuse only)
- **textures/** – 48 `map_Kd` (diffuse) PNGs

## Import in Unreal Engine 5

1. Open your Unreal project.
2. **File → Import to /Game/…** (or drag **mesh.obj** into the Content Browser).
3. Choose **mesh.obj** from this folder:  
   `UnrealStarter/LumaScan/mesh.obj`
4. In the OBJ import options:
   - **Import Type**: Static Mesh
   - **Normal Import Method**: Import Normals and Tangents (or Compute Normals if shading is wrong)
   - **Generate Lightmap UVs**: optional (e.g. for baked lighting)
   - **Import Materials**: On  
   - **Import Textures**: On  
   - **Material Import Method**: Create New Materials
5. Click **Import**. Textures are resolved from `textures/` next to the OBJ.
6. Open the new Static Mesh asset:
   - **Nanite**: enable (Nanite Settings → Enable Nanite).
   - **Collision**: Collision → Auto Convex Collision (or Use Complex as Simple for quick test).
7. Place the mesh in the level and adjust scale if the scan size is off.

## Materials

Unreal will create one material per OBJ material (48). Each uses the corresponding `mesh_materialXXXX_map_Kd.png` as Base Color (sRGB on). No normal/roughness in this export; you can add defaults in the material if needed.
