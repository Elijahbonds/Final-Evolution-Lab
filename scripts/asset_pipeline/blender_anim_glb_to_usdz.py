"""Headless Blender: convert a rigged+ANIMATED Meshy GLB to an animation-
PRESERVING USDZ for SceneKit, with the walk/run cycle locked IN PLACE.

Why a separate script from blender_to_usdz.py:
  The Meshy "basic_animations" walk/run GLBs are full skinned clips whose
  root (Hips) carries the cycle's translation. Converting them straight to
  USDZ can slide the character away from the origin (documented root-motion
  pitfall). For a looping in-place NPC/player cycle we must NEUTRALISE the
  horizontal (world X/Z) travel of the root while KEEPING the vertical bob
  and every joint rotation, and we must keep the SkelAnimation intact.

Approach (robust across the arbitrary Hips rest orientation):
  For every animated frame we read the Hips pose-bone WORLD position, and
  bake a compensating offset back into the Hips *location* fcurves so the
  Hips ends up horizontally locked to its frame-0 XY (world), vertical Z
  (height/bob) untouched. This works even though the Hips local axes are
  rotated relative to world (single-index stripping would not).

Also: strips the stray "Icosphere" helper mesh Meshy ships, optional
decimation to stay under the bundle size budget, and the same Z-up->Y-up
root correction + usd_export kwargs the project's blender_to_usdz.py uses.

Blender 4.4+/5.x note: Action.fcurves was removed; fcurves now live under
action.layers[].strips[].channelbag(slot). get_fcurves() handles both.

Usage:
  Blender --background --python blender_anim_glb_to_usdz.py -- \
      --input rig_X_walking.glb --output NPCXWalk.usdz \
      [--max-faces 90000] [--no-inplace] [--inspect]
"""

import argparse
import math
import sys
from pathlib import Path

import bpy
import mathutils


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    p = argparse.ArgumentParser()
    p.add_argument("--input", required=True)
    p.add_argument("--output")
    p.add_argument("--max-faces", type=int, default=0)
    p.add_argument("--no-inplace", action="store_true",
                   help="keep root translation (do NOT lock in place)")
    p.add_argument("--inspect", action="store_true")
    return p.parse_args(argv)


def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path: Path):
    bpy.ops.import_scene.gltf(filepath=str(path))


def get_fcurves(action):
    """Blender 4.4+/5.x slotted actions: gather every fcurve across layers."""
    if hasattr(action, "fcurves") and len(action.fcurves):
        return list(action.fcurves)
    fcs = []
    for layer in action.layers:
        for strip in layer.strips:
            for slot in action.slots:
                cb = strip.channelbag(slot)
                if cb:
                    fcs.extend(cb.fcurves)
    return fcs


def strip_helper_meshes():
    """Meshy ships a stray 'Icosphere' helper — never the visible character."""
    removed = []
    for obj in list(bpy.data.objects):
        if obj.type == "MESH" and obj.name.startswith("Icosphere"):
            removed.append(obj.name)
            bpy.data.objects.remove(obj, do_unlink=True)
    return removed


def find_action(armature):
    if armature.animation_data and armature.animation_data.action:
        return armature.animation_data.action
    return bpy.data.actions[0] if bpy.data.actions else None


def lock_root_in_place(armature, action):
    """Bake a per-frame compensating offset into the Hips location fcurves so
    the Hips is horizontally locked (world X/Y after gltf import = ground
    plane; Z = height) to its frame-0 position. Vertical bob + all joint
    rotations survive. Returns (drift_before, drift_after) in world units."""
    scene = bpy.context.scene
    hips = armature.pose.bones.get("Hips")
    if hips is None:
        return None

    fcs = get_fcurves(action)
    loc_fcurves = {
        i: fc for fc in fcs
        for i in (fc.array_index,)
        if fc.data_path == 'pose.bones["Hips"].location'
    }
    if len(loc_fcurves) < 3:
        return None

    keyed = {i: fc for i, fc in loc_fcurves.items()}
    if not all(i in keyed for i in range(3)):
        return None

    # Integer frames that actually carry Hips-location keys.
    key_frames = sorted({
        int(round(kp.co[0]))
        for fc in keyed.values()
        for kp in fc.keyframe_points
    })
    if not key_frames:
        return None
    f0 = key_frames[0]

    # Pass 1 — read the RAW (uncompensated) world Hips head at every keyed
    # frame and record the ORIGINAL keyframe values, before touching anything.
    #
    # The Hips pose-bone `.location` fcurve is authored in the bone's REST
    # basis (bone.matrix_local, in armature space), then the armature world
    # matrix maps to world. So world_delta = arm3x3 @ boneRest3x3 @ loc_delta,
    # hence loc_delta = inv(arm3x3 @ boneRest3x3) @ world_delta. Using only the
    # armature inverse (ignoring the bone rest rotation) does NOT cancel the
    # motion because the Hips rest basis is arbitrarily rotated.
    bone_rest_3x3 = hips.bone.matrix_local.to_3x3()
    arm_3x3 = armature.matrix_world.to_3x3()
    world_to_loc = (arm_3x3 @ bone_rest_3x3).inverted()
    ref = None
    raw_world = {}
    orig_vals = {i: {} for i in range(3)}
    xs0, ys0 = [], []
    for f in key_frames:
        scene.frame_set(f)
        w = armature.matrix_world @ hips.head
        raw_world[f] = w.copy()
        xs0.append(w.x)
        ys0.append(w.y)
        if ref is None:
            ref = w.copy()
        for i in range(3):
            for kp in keyed[i].keyframe_points:
                if abs(kp.co[0] - f) < 0.5:
                    orig_vals[i][f] = kp.co[1]
                    break
    drift_before = (round(max(xs0) - min(xs0), 4), round(max(ys0) - min(ys0), 4))

    # Pass 2 — for each keyed frame, subtract the RAW world horizontal error
    # (mapped into pose space) from the ORIGINAL keyframe value. Height (world
    # Z) is preserved. One shot, no feedback: exact by construction.
    for f in key_frames:
        w = raw_world[f]
        err_world = mathutils.Vector((w.x - ref.x, w.y - ref.y, 0.0))
        err_loc = world_to_loc @ err_world
        for i in range(3):
            fc = keyed[i]
            base = orig_vals[i].get(f)
            if base is None:
                continue
            new_val = base - err_loc[i]
            shift = new_val - base            # = -err_pose[i]
            for kp in fc.keyframe_points:
                if abs(kp.co[0] - f) < 0.5:
                    kp.co[1] = new_val
                    kp.handle_left[1] += shift   # move handles with the key
                    kp.handle_right[1] += shift  # (preserves tangent shape)
                    break
    for fc in keyed.values():
        fc.update()

    # Measure drift after (sample every frame in the range, not just keys).
    xs, ys = [], []
    for f in range(key_frames[0], key_frames[-1] + 1):
        scene.frame_set(f)
        w = armature.matrix_world @ hips.head
        xs.append(w.x)
        ys.append(w.y)
    drift_after = (round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4))
    return drift_before, drift_after


def decimate(max_faces: int):
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    total = sum(len(o.data.polygons) for o in meshes)
    if not max_faces or total <= max_faces:
        return total, total
    ratio = max_faces / total
    for obj in meshes:
        mod = obj.modifiers.new(name="nexus_decimate", type="DECIMATE")
        mod.ratio = ratio
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return total, sum(len(o.data.polygons) for o in meshes)


def convert_to_y_up():
    """Z-up -> Y-up: compose a -90 X rotation at each root (object level, not
    baked) so skinned animation data is untouched and it exports as a plain
    USD xformOp — identical to blender_to_usdz.py."""
    rot = mathutils.Matrix.Rotation(math.radians(-90.0), 4, "X")
    for obj in bpy.data.objects:
        if obj.parent is None:
            obj.matrix_world = rot @ obj.matrix_world


def export_usdz(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.usd_export(
        filepath=str(path),
        export_animation=True,
        export_uvmaps=True,
        export_normals=True,
        export_materials=True,
        selected_objects_only=False,
    )


def main():
    args = parse_args()
    src = Path(args.input).expanduser()
    if not src.exists():
        raise SystemExit(f"input not found: {src}")

    clean_scene()
    import_glb(src)

    armature = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    action = find_action(armature) if armature else None
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    print(f"[anim] imported {src.name}")
    print(f"[anim]   armature={armature.name if armature else None} "
          f"action={action.name if action else None} "
          f"meshes={[m.name for m in meshes]}")
    if action is None or armature is None:
        raise SystemExit(f"[anim] FATAL: no armature/action in {src.name}")

    removed = strip_helper_meshes()
    if removed:
        print(f"[anim]   stripped helper meshes: {removed}")

    if args.inspect:
        drift = None
        return

    if not args.no_inplace:
        drift = lock_root_in_place(armature, action)
        if drift is None:
            print("[anim]   WARN: could not lock root in place (no Hips loc fcurves)")
        else:
            print(f"[anim]   root lock: horizontal drift {drift[0]} -> {drift[1]} (world units)")

    if args.max_faces:
        before, after = decimate(args.max_faces)
        print(f"[anim]   decimate: {before} -> {after} faces (budget {args.max_faces})")

    # Reset to the first animated frame so the export's default pose is sane.
    bpy.context.scene.frame_set(int(round(action.frame_range[0])))
    convert_to_y_up()

    out = Path(args.output).expanduser() if args.output else src.with_suffix(".usdz")
    export_usdz(out)
    size_mb = out.stat().st_size / 1e6
    print(f"[anim] exported {out} ({size_mb:.1f} MB)")


main()
