#!/usr/bin/env python3
"""
fel_conform.py — Blender 4.x, headless. Probe + conform any rigged asset to
the FEL canonical spec.

    blender --background --python fel_conform.py -- --input in.fbx --probe
    blender --background --python fel_conform.py -- --input in.fbx --output out.glb

THE ONE THING THIS SCRIPT EXISTS FOR
------------------------------------
FEL resolves bones by UNPREFIXED name at runtime (`Hips`, `LeftArm`, …).
Meshy/Mixamo/DeepMotion output is usually `mixamorig:`-prefixed. If a
prefixed rig reaches the game, every authored clip silently resolves nothing
and characters freeze at bind pose — the exact failure that took several
debugging cycles to diagnose once already. This script strips the prefix and
records that it did.

See AvatarSkeletonSpec.md. Nothing here is optional.

NOTE ON VERIFICATION: this script is written against the Blender 4.x Python
API but has NOT been executed in this environment (no Blender available).
Run `--probe` on a real asset first; it makes no changes, so it is safe to
use as the smoke test.
"""

import argparse
import json
import os
import re
import sys

try:
    import bpy
    import mathutils
except ImportError:  # pragma: no cover - allows linting outside Blender
    bpy = None
    mathutils = None

# `mixamorig:` was the only prefix this file ever stripped. The real FEL base
# mesh (male_athlete_base_model_fbx, downloaded fresh from the asset source
# and inspected directly) is prefixed `mixamorig10:` — Mixamo appends an
# incrementing suffix on every re-download through its auto-rigger, so the
# digit is not always absent and never always "1". A literal string compare
# against "mixamorig:" therefore MISSES this asset entirely: `probe()` would
# report zero prefixed bones and `conforms: True` on a rig where every single
# bone is unresolvable at runtime — a false negative from the one tool built
# to catch exactly this. Matched with a regex instead, once, and used
# everywhere below rather than repeating the literal four times.
MIXAMO_PREFIX = re.compile(r"^mixamorig\d*[:_]", re.IGNORECASE)


def strip_mixamo(name):
    """Unprefixed bone/vertex-group name, or the name unchanged if it never
    carried a Mixamo prefix in the first place."""
    return MIXAMO_PREFIX.sub("", name)


def is_mixamo_prefixed(name):
    return MIXAMO_PREFIX.match(name) is not None


REQUIRED_BONES = [
    "Hips", "Spine", "Spine1", "Spine2", "Neck", "Head",
    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
    "RightShoulder", "RightArm", "RightForeArm", "RightHand",
    "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
    "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
]

TRI_BUDGET = {"avatar": 25000, "part": 8000, "prop": 5000}


def log(msg):
    print("[FEL-CONFORM] %s" % msg)


# ── argument plumbing (Blender passes script args after `--`) ──────────────
def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output")
    p.add_argument("--probe", action="store_true", help="report only, change nothing")
    p.add_argument("--class", dest="asset_class", default="avatar",
                   choices=list(TRI_BUDGET.keys()))
    p.add_argument("--decimate", action="store_true",
                   help="decimate to the class triangle budget")
    p.add_argument("--strip-mesh", action="store_true",
                   help="animation-only export: drop all mesh data")
    p.add_argument("--json", help="write the report here")
    return p.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_any(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=True)
    elif ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".bvh":
        bpy.ops.import_anim.bvh(filepath=path, update_scene_fps=False)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    else:
        raise SystemExit("unsupported input: %s" % ext)


def find_armature():
    for obj in bpy.data.objects:
        if obj.type == "ARMATURE":
            return obj
    return None


def triangle_count():
    total = 0
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        mesh = obj.data
        mesh.calc_loop_triangles()
        total += len(mesh.loop_triangles)
    return total


def detect_bind_pose(arm):
    """T-pose vs A-pose: in a T-pose the hand sits near shoulder height and
    far out laterally; in an A-pose it hangs well below."""
    bones = arm.data.bones
    # Unprefixed first; then ANY Mixamo prefix, matched by name rather than a
    # second hardcoded literal that would have the same blind spot as the
    # first one.
    by_stripped = {strip_mixamo(b.name): b for b in bones}
    hand = bones.get("LeftHand") or by_stripped.get("LeftHand")
    shoulder = bones.get("LeftShoulder") or by_stripped.get("LeftShoulder")
    if not hand or not shoulder:
        return "unknown"
    drop = shoulder.head_local.z - hand.head_local.z
    spread = abs(hand.head_local.x - shoulder.head_local.x)
    if spread <= 0.0001:
        return "unknown"
    return "T-pose" if drop < spread * 0.4 else "A-pose"


def probe(arm):
    names = [b.name for b in arm.data.bones] if arm else []
    prefixed = [n for n in names if is_mixamo_prefixed(n)]
    stripped = {strip_mixamo(n) for n in names}
    missing = [b for b in REQUIRED_BONES if b not in stripped]
    scene = bpy.context.scene
    return {
        "boneCount": len(names),
        "prefixedBones": len(prefixed),
        "missingRequired": missing,
        "bindPose": detect_bind_pose(arm) if arm else "unknown",
        "unitScale": scene.unit_settings.scale_length,
        "fps": scene.render.fps,
        "frameRange": [scene.frame_start, scene.frame_end],
        "triangles": triangle_count(),
        "meshObjects": sum(1 for o in bpy.data.objects if o.type == "MESH"),
        "conforms": (not missing) and (not prefixed),
    }


def strip_prefix(arm, fixes):
    renamed = 0
    for bone in arm.data.bones:
        if is_mixamo_prefixed(bone.name):
            new = strip_mixamo(bone.name)
            fixes.append({"category": "skeleton", "what": "strip mixamorig prefix",
                          "before": bone.name, "after": new, "confidence": "certain"})
            bone.name = new
            renamed += 1
    # vertex groups must follow the bone names or skinning breaks
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for vg in obj.vertex_groups:
            if is_mixamo_prefixed(vg.name):
                vg.name = strip_mixamo(vg.name)
    if renamed:
        log("stripped mixamorig prefix from %d bones (+ vertex groups)" % renamed)
    return renamed


def conform_transform(fixes):
    scene = bpy.context.scene
    if abs(scene.unit_settings.scale_length - 1.0) > 1e-6:
        fixes.append({"category": "transform", "what": "unit scale -> meters",
                      "before": scene.unit_settings.scale_length, "after": 1.0,
                      "confidence": "certain"})
        scene.unit_settings.scale_length = 1.0
    scene.unit_settings.system = "METRIC"


def decimate_to(budget, fixes):
    current = triangle_count()
    if current <= budget:
        return
    ratio = budget / float(current)
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        mod = obj.modifiers.new(name="FELDecimate", type="DECIMATE")
        mod.ratio = ratio
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    fixes.append({"category": "geometry", "what": "decimate to budget",
                  "before": current, "after": triangle_count(),
                  "confidence": "heuristic"})
    log("decimated %d -> %d tris" % (current, triangle_count()))


def strip_meshes(fixes):
    removed = 0
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
            removed += 1
    if removed:
        fixes.append({"category": "geometry", "what": "strip mesh (animation-only export)",
                      "before": removed, "after": 0, "confidence": "certain"})
        log("stripped %d mesh object(s) for animation-only export" % removed)


def export_glb(path):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_animations=True,
        export_skins=True,
    )
    log("wrote %s (%.1f KB)" % (path, os.path.getsize(path) / 1024.0))


def main():
    if bpy is None:
        raise SystemExit("run this inside Blender: blender --background --python fel_conform.py -- ...")
    args = parse_args()
    clear_scene()
    import_any(args.input)

    arm = find_armature()
    report = probe(arm)
    log("PROBE: %s" % json.dumps(report, indent=2))

    if args.probe:
        if args.json:
            with open(args.json, "w") as fh:
                json.dump({"probe": report, "fixes": []}, fh, indent=2)
        # exit non-zero on a non-conformant rig so CI can gate on it
        raise SystemExit(0 if report["conforms"] else 1)

    if not arm:
        raise SystemExit("no armature found — nothing to conform")

    fixes = []
    strip_prefix(arm, fixes)
    conform_transform(fixes)
    if args.decimate:
        decimate_to(TRI_BUDGET[args.asset_class], fixes)
    if args.strip_mesh:
        strip_meshes(fixes)

    after = probe(arm)
    if after["missingRequired"]:
        log("REJECT: still missing required bones after conform: %s"
            % ", ".join(after["missingRequired"]))
        raise SystemExit(1)

    out = args.output or os.path.splitext(args.input)[0] + ".fel.glb"
    export_glb(out)

    ledger = {
        "sourceFile": args.input, "output": out,
        "probeBefore": report, "probeAfter": after,
        "fixes": fixes,
    }
    ledger_path = out + ".import.json"
    with open(ledger_path, "w") as fh:
        json.dump(ledger, fh, indent=2)
    log("fix ledger -> %s" % ledger_path)
    if args.json:
        with open(args.json, "w") as fh:
            json.dump(ledger, fh, indent=2)


if __name__ == "__main__":
    main()
