# Mixamo dance clips — MANUAL download only

Mixamo (Adobe) animations are free to use but are **not** redistributable in
this repo and **must be downloaded by a human through a browser login**. No part
of this project automates, scripts, or stores Mixamo credentials — do not add
any login automation here.

## Steps (do these yourself)

1. Open https://www.mixamo.com in a browser and sign in with your own Adobe ID.
2. Search a dance animation (e.g. "Hip Hop Dancing", "Breakdance").
3. Choose **Download** with:
   - Format: **FBX Binary (.fbx)**
   - Skeleton: **Without Skin** (animation only) unless you need the mesh
   - Frames per Second: 30, Keyframe Reduction: none
4. Save the `.fbx` into this folder (`assets/external/mixamo/`).
   These files are git-ignored — keep them local, do not commit Mixamo assets.
5. Convert to glTF (manual converter, see the script's `--steps`):
   ```
   python3 scripts/convert_fbx_to_gltf.py --steps
   ```
6. Build + validate the retarget map to `humanoid_v1`:
   ```
   python3 scripts/dance_animation_map.py scaffold your_clip.gltf --source-rig mixamo \
       -o your_clip.animation_map.json
   python3 scripts/dance_animation_map.py validate your_clip.animation_map.json
   ```
7. Drop the resulting `.gltf` into your clip library; it now shows up as a
   choreography clip source (source: `mocap`).

## Why nothing here is automated

Mixamo's terms require an interactive, authenticated session. Automating that
login would violate both the ToS and this project's hard rules. The bundled
`assets/dance/samples/*.gltf` clips are tiny **CC0 placeholders** so the demo
runs with zero manual steps; Mixamo/DeepMotion/Meshy clips are the real-content
upgrade path and slot into the exact same timeline entries.
