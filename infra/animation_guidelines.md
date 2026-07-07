# Animation Retargeting & Blending Guidelines (FEL / Nexus)

Authoritative pipeline: `scripts/asset_pipeline/mocap_pipeline.py` on
`feature/phase2-input-design-tokens` (rest-offset matrix retarget, baked
per frame). This document encodes the rules it enforces and the failure
modes discovered while shipping the first retargeted clips.

## Skeleton
- Target: FEL Meshy-convention rig, 24 bones (`infra/skeleton_map_fel.json`).
- Sources: DeepMotion/Mixamo/CMU (Mixamo-convention names; strip
  `mixamorig:` prefixes) or Meshy-convention (identity map; marker bone
  `Spine02`).

## Retarget algorithm (do NOT use naive world-rotation copy)
Per bone: `offset = src_rest_world⁻¹ @ tgt_rest_world`, then per frame
`tgt_world = src_world @ offset`, parents before children; Hips also
copies world translation with source pre-scaled to target hip height.
Naive COPY_ROTATION constraints crumple the mesh whenever rest poses
differ (DeepMotion rest vs Meshy A-pose) — verified failure.

## Units & scale (hardest-won lessons)
1. Bake absolute scale into DATA (`transform_apply` + rescale hips
   location F-curves) — object-level scale does NOT survive Blender→USD→
   SceneKit skeleton binding.
2. Never trust skinned-mesh bounding boxes at runtime; normalize from
   skeleton JOINT positions (Hips/Head/feet import as real nodes).
3. Never `clone()` skinned nodes in SceneKit — the skinner stays bound to
   the original skeleton and the clone renders nowhere.
4. Meshy preset animation GLBs must be BAKED through the retarget path,
   not format-converted directly: their root-motion curves are in mixed
   units and render characters meters off their node origin.

## Re-rooting
Every exported clip: ANIMATED frame-1 hips over origin (x,z), feet at
floor (y=0). Rest-pose joints are NOT a valid re-root reference
(animated hips ≠ rest hips — client-side rest-joint re-rooting broke
correct clips; owner of re-rooting is the exporter, exactly once).

## Root motion policy
- CARRIES root motion: run/sprint/approach, jump, dunk, cartwheel/vault,
  ko_fall/bail, board ride/carve.
- IN PLACE (root motion stripped, gameplay moves the entity): idle,
  dribble, strikes (jab/hook/kick), blocks, celebrate, serve/swing.
- Dunks additionally rim-normalize: scale airborne hips-Y so peak hand
  height hits the fixed 3.05 m virtual rim (`--rim`).

## Blend windows (starting values, tune on device)
- locomotion <-> locomotion: 150 ms cross-fade
- idle -> strike: 80 ms; strike -> idle: 120 ms
- approach -> launch (dunk): 120 ms window, input-buffered 4 frames
- hit_react interrupts anything: 50 ms; ko_fall: no blend (hard cut)
- Layering: strikes/upper-body may layer over locomotion lower-body once
  the runtime supports masks; until then strikes are full-body one-shots
  (current implementation: one-shot node swap, see GameSceneHostView
  playKarateStrike / setDunkClipActive).

## IK hooks (deferred until runtime support)
- Foot placement: plant when foot joint speed < 0.15 m/s and height
  < 0.08 m; current pipeline only floor-clamps penetration.
- Hand-on-ball: attach ball to RightHand socket during dribble/dunk
  windows (see animation_map source hints).

## Clip hygiene
- 30 fps export, no keyframe reduction on source download.
- Smoothing: 5-frame moving average on mocap curves (DeepMotion jitter).
- Lengths: strikes 0.8–1.5 s; celebrate 2–3 s; loops seamless
  (first/last pose match within 2°/bone).

## Validation
`scripts/convert_assets.py validate --input clip.glb` (structure) and
render-check via the snapshot harness (`/tmp/fel_snapshots`) before
bundling. Every clip must appear in `infra/ASSET_CHECKSUMS.json`.
