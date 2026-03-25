# Meshy GLB staging (Unreal — canonical hybrid path)

**Source of truth:** GLBs in this folder are copied from `UnityProject/Assets/StreamingAssets/Meshy/` for **Unreal Engine 5** import (FBX/glTF pipeline per project settings).  
**Unity:** The duplicate `UnityProject/.../Meshy/` path is **deprecated** for new work — keep Unity-only scripts in sync only if you still ship UaaL; otherwise edit Unreal content here.

| File | Use |
|------|-----|
| `Meshy_AI_Stadium_Soccer_stad_0323202143_stylize.glb` | Soccer stadium environment |
| `Meshy_AI_Goal_Posts_Professi_0323202113_texture.glb` | Goal posts |
| `Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture.glb` | Soccer ball |
| `Meshy_AI_Tennis_Racket_Profe_0323202215_texture.glb` | Tennis racket |
| `Meshy_AI_Tennis_Ball_Bright__0323202210_texture.glb` | Tennis ball |

**Import:** Drag into `/Game/FEL/...` in the Unreal Editor or use Editor Python batch import; align with `fel_luma_venue_texture_presave.py` platform stamps for materials.
