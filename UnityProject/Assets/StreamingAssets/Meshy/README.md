# Meshy GLB assets (Unity — **deprecated for new art**)

**Hybrid Phase C:** Canonical Meshy binaries live under `UnrealStarter/BasketballGame/Content/FEL/External/Meshy/` for UE5. This Unity `StreamingAssets` copy remains only for legacy `FELMeshyStreamingLoader` / UaaL workflows.

Place these **exact filenames** in this folder (copied from your Meshy export):

| File | Use |
|------|-----|
| `Meshy_AI_Stadium_Soccer_stad_0323202143_stylize.glb` | Soccer stadium environment |
| `Meshy_AI_Goal_Posts_Professi_0323202113_texture.glb` | Goal posts |
| `Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture.glb` | Soccer ball (rigidbody added at runtime) |
| `Meshy_AI_Tennis_Racket_Profe_0323202215_texture.glb` | Tennis racket |
| `Meshy_AI_Tennis_Ball_Bright__0323202210_texture.glb` | Tennis ball |

`FELMeshyStreamingLoader` loads them via **glTFast** (`com.atteneder.gltfast`) on play.

**Unity Editor:** Menu **FEL → Add Meshy Streaming Loader to Scene** if the bootstrap object is missing.

Adjust **scale / local positions** on the loader component if meshes import huge or offset.
