# Luma / textured-mesh exports (OBJ + MTL + textures)

Three captures from **`textured_mesh_obj 3.zip`**, **`4.zip`**, and **`5.zip`** (Downloads), extracted here for Unreal import.

| Folder | `mesh.obj` size | Materials (textures) | Notes |
|--------|-----------------|----------------------|--------|
| **`capture_03/`** | ~95 MB | 48 PNGs | Same layout as legacy **`../LumaScan/`** (high-detail scan). |
| **`capture_04/`** | ~70 MB | 21 PNGs | Lighter material count; smaller OBJ. |
| **`capture_05/`** | ~92 MB | 54 PNGs | More material slots than capture_04. |

Each folder is self-contained: **`mesh.obj`**, **`mesh.mtl`**, **`textures/*.png`**. Keep them together when copying into a UE project’s **`Content/`** tree.

## Import in Unreal (5.2+)

1. **Content Browser → Import** → choose that folder’s **`mesh.obj`** (or copy the whole folder under e.g. `Content/FEL/Environment/LumaCapture03/`).
2. **Static Mesh**, **Import Materials** / **Import Textures** on.
3. Open mesh → **Nanite** (if desired) + **collision** for gameplay.

See also **`../LumaScan/README_IMPORT.md`** for the same workflow on the original scan.

## Git / size

These folders are **large**. If you do not want them in git, add to `.gitignore`:

```gitignore
UnrealStarter/LumaExports/capture_*/
```

…and keep only this `README.md`, or use **Git LFS** for `*.obj` / `*.png`.

---

*Imported from `~/Downloads/textured_mesh_obj {3,4,5}.zip` on 2026-03-19.*
