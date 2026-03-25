# Venice Beach – Unreal-friendly OBJ (from Meshy GLB)

Converted from `../Meshy_AI_Venice_beach_basketba_0319064051_texture.glb` for reliable import into **Unreal Engine 5.2+** (especially when direct GLB import is flaky).

## Contents

- **`Venice_mesh.obj`** – static mesh (Y-up glTF → Z-up friendly rotation applied)
- **`Venice_mesh.mtl`** – material with diffuse map
- **`textures/basecolor.jpg`** – embedded base color from the GLB

## Import in Unreal

1. Copy this folder into your UE project under **`Content/`** (optional but recommended), or import from this path.
2. **Content Browser → Import** → select **`Venice_mesh.obj`**.
3. Import as **Static Mesh**; enable **Import Materials** and **Import Textures**.
4. Open the mesh → enable **Nanite** → add **collision** (Auto Convex or custom).

If the mesh needs a small rotation tweak in the level, adjust the actor transform once (coordinate conversion is standard glTF Y-up → UE Z-up).

## Regenerate from GLB

From repo root:

```bash
python3 UnrealStarter/MeshyAssets/tools/glb_to_obj_unreal.py \
  UnrealStarter/MeshyAssets/Meshy_AI_Venice_beach_basketba_0319064051_texture.glb \
  UnrealStarter/MeshyAssets/Venice_beach_UE5
```
