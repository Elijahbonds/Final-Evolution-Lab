#!/usr/bin/env python3
"""
dance_animation_map.py — Retarget-mapping tool for the Dance Mode mocap seam.

A glTF/FBX dance clip authored against some source rig (Mixamo, DeepMotion,
Meshy, a custom capture) must be *retargeted* to the FEL standard skeleton
`humanoid_v1` before the choreography timeline / playback can drive it. This
tool produces and validates the `animation_map` JSON that records which source
bone drives which target (`humanoid_v1`) bone.

It does NOT perform the retarget bake itself (that is a DCC / engine step) and
it does NOT log into or automate any external tool — it only reads local files
and writes/validates JSON.

Usage:
  # Emit a starter map (identity + common Mixamo aliases) for a clip:
  python3 scripts/dance_animation_map.py scaffold assets/dance/samples/two_step.gltf \\
      --source-rig mixamo -o assets/dance/two_step.animation_map.json

  # Validate a hand-edited map covers every humanoid_v1 bone:
  python3 scripts/dance_animation_map.py validate assets/dance/two_step.animation_map.json
"""
import argparse
import json
import os
import sys

# FEL standard target skeleton. Keep in sync with backend `skeleton="humanoid_v1"`.
HUMANOID_V1_BONES = [
    "Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
    "RightShoulder", "RightArm", "RightForeArm", "RightHand",
    "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
    "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
]

# Known source-rig naming conventions -> humanoid_v1. Extend as new sources land.
SOURCE_ALIASES = {
    "mixamo": {  # Mixamo prefixes bones with "mixamorig:"
        b: f"mixamorig:{b}" for b in HUMANOID_V1_BONES
    },
    "deepmotion": {  # DeepMotion tends to use lower-snake bone names
        "Hips": "pelvis", "Spine": "spine_01", "Spine1": "spine_02",
        "Spine2": "spine_03", "Neck": "neck", "Head": "head",
        "LeftArm": "upperarm_l", "LeftForeArm": "lowerarm_l", "LeftHand": "hand_l",
        "RightArm": "upperarm_r", "RightForeArm": "lowerarm_r", "RightHand": "hand_r",
        "LeftUpLeg": "thigh_l", "LeftLeg": "calf_l", "LeftFoot": "foot_l",
        "RightUpLeg": "thigh_r", "RightLeg": "calf_r", "RightFoot": "foot_r",
    },
    "identity": {b: b for b in HUMANOID_V1_BONES},
}


def scaffold(clip_path: str, source_rig: str) -> dict:
    aliases = SOURCE_ALIASES.get(source_rig, SOURCE_ALIASES["identity"])
    clip_meta = {}
    if clip_path.endswith(".gltf") and os.path.exists(clip_path):
        try:
            with open(clip_path) as f:
                doc = json.load(f)
            clip_meta = doc.get("extras", {}).get("clip", {})
        except Exception:
            pass
    return {
        "version": "1.0",
        "target_skeleton": "humanoid_v1",
        "source_rig": source_rig,
        "clip": clip_meta or {"id": os.path.splitext(os.path.basename(clip_path))[0]},
        "source_clip": os.path.basename(clip_path),
        # target_bone -> source_bone. null means "unmapped, fill me in".
        "bone_map": {b: aliases.get(b) for b in HUMANOID_V1_BONES},
        "notes": "Retarget bake happens in a DCC/engine step; this file only records the mapping.",
    }


def validate(map_path: str) -> int:
    with open(map_path) as f:
        m = json.load(f)
    errs = []
    if m.get("target_skeleton") != "humanoid_v1":
        errs.append(f"target_skeleton must be 'humanoid_v1', got {m.get('target_skeleton')!r}")
    bone_map = m.get("bone_map", {})
    missing = [b for b in HUMANOID_V1_BONES if not bone_map.get(b)]
    extra = [b for b in bone_map if b not in HUMANOID_V1_BONES]
    if missing:
        errs.append(f"{len(missing)} unmapped target bone(s): {', '.join(missing)}")
    if extra:
        errs.append(f"unknown target bone(s) not in humanoid_v1: {', '.join(extra)}")
    if errs:
        print("INVALID animation_map:")
        for e in errs:
            print("  -", e)
        return 1
    print(f"OK: animation_map maps all {len(HUMANOID_V1_BONES)} humanoid_v1 bones "
          f"(source_rig={m.get('source_rig')}).")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    ps = sub.add_parser("scaffold", help="emit a starter animation_map for a clip")
    ps.add_argument("clip", help="path to source .gltf/.fbx clip")
    ps.add_argument("--source-rig", default="identity", choices=sorted(SOURCE_ALIASES))
    ps.add_argument("-o", "--out", help="write JSON here (default: stdout)")

    pv = sub.add_parser("validate", help="check a map covers all humanoid_v1 bones")
    pv.add_argument("map", help="path to an animation_map JSON")

    args = p.parse_args()
    if args.cmd == "scaffold":
        doc = scaffold(args.clip, args.source_rig)
        out = json.dumps(doc, indent=2)
        if args.out:
            with open(args.out, "w") as f:
                f.write(out + "\n")
            print(f"wrote {args.out}")
        else:
            print(out)
        return 0
    if args.cmd == "validate":
        return validate(args.map)
    return 2


if __name__ == "__main__":
    sys.exit(main())
