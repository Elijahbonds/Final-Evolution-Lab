# Asset Attribution — Nexus Dance Mode

All assets bundled with the Dance Mode branch are either original to this repo
or CC0 (public domain). No copyrighted or login-gated content is committed.

## Bundled sample animation clips (`assets/dance/samples/*.gltf`)

| File | Clip | License | Source |
|---|---|---|---|
| `two_step.gltf` | Two-Step | CC0 | Original FEL placeholder |
| `idle_sway.gltf` | Idle Sway | CC0 | Original FEL placeholder |
| `spin.gltf` | Spin | CC0 | Original FEL placeholder |
| `wave.gltf` | Wave | CC0 | Original FEL placeholder |
| `jump.gltf` | Jump | CC0 | Original FEL placeholder |
| `freeze_pose.gltf` | Freeze Pose | CC0 | Original FEL placeholder |

These are **tiny schema placeholders**, not rendered animations — each is a
minimal glTF stub carrying clip metadata (id, name, duration, target skeleton)
so the choreography timeline and playback have something to reference. Real
motion data replaces the file contents in place; the timeline entries are
unchanged.

## Real-content upgrade paths (NOT committed — manual, user-supplied)

- **Mixamo (Adobe):** free-to-use dance FBX, MANUAL browser download only. See
  `assets/external/mixamo/README.md`. Git-ignored; never committed.
- **Quaternius:** CC0 character/animation packs — safe to bundle if kept tiny
  (<5MB) and listed here when added.
- **DeepMotion / Meshy:** AI-generated mocap; user account required. Export
  glTF, retarget to `humanoid_v1` via `scripts/dance_animation_map.py`.

## Tooling (documents manual steps; no login automation)

- `scripts/convert_fbx_to_gltf.py` — prints manual FBX→glTF steps; runs a
  locally installed converter only if present. No network, no credentials.
- `scripts/dance_animation_map.py` — scaffolds/validates the retarget map from a
  source rig to `humanoid_v1`. Pure local JSON.
