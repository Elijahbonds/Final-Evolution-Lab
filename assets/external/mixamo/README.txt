Mixamo manual download drop zone
================================
1. Log in at https://www.mixamo.com (free Adobe account).
2. Pick the character "X Bot" (or upload the FEL rig FBX).
3. For each clip in infra/assets_manifest.json animations lists
   (e.g. "Dunk", "Jab", "Roundhouse Kick", "Juke", "Spike"):
   Download -> Format: FBX Binary, Skin: Without Skin, 30 FPS, no keyframe reduction.
4. Place files here as <logical_name>.fbx (e.g. dunk.fbx).
5. Run: scripts/convert_assets.py convert --input assets/external/mixamo/dunk.fbx \
        --output assets/models/animations/dunk.glb
NOTE: Mixamo terms allow use in projects but NOT redistribution of raw
files — never commit the FBX; only converted, integrated scene assets.
