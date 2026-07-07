"""Nexus motion pipeline (headless Blender): DeepMotion/SayMotion mocap -> engine clips.

Source-agnostic ingest (BVH or FBX), crop-range proposal, jitter smoothing,
floor/foot contact fixes, retarget onto the Meshy character rig, optional rim
normalization for dunks, USDZ export. Raw takes are never modified; every
output is versioned through assets/motion/registry.json.

Stages:
  analyze  — propose crop ranges for discrete moves; writes/updates proposals JSON.
             A HUMAN approves/adjusts crops before `process` — never skip that.
  process  — cut approved crops, smooth, retarget, fix contacts, export USDZ.

Usage:
  Blender --background --python mocap_pipeline.py -- analyze \
      --input take.bvh --proposals proposals.json
  Blender --background --python mocap_pipeline.py -- process \
      --input take.bvh --crop-id dunk_01 --start 120 --end 300 [--rim] \
      --target ElijahRig.glb --out clips/dunk_01.usdz [--rim-height 3.05]
"""

import argparse
import json
import math
import sys
from pathlib import Path

import bpy
import mathutils

# DeepMotion / Mixamo names -> Meshy rig names. Fingers intentionally dropped
# (Meshy rig has none). Spine chain is reversed on the Meshy side.
BONE_MAP = {
    "Hips": "Hips",
    "Spine": "Spine02",
    "Spine1": "Spine01",
    "Spine2": "Spine",
    "Neck": "neck",
    "Head": "Head",
    "LeftShoulder": "LeftShoulder",
    "LeftArm": "LeftArm",
    "LeftForeArm": "LeftForeArm",
    "LeftHand": "LeftHand",
    "RightShoulder": "RightShoulder",
    "RightArm": "RightArm",
    "RightForeArm": "RightForeArm",
    "RightHand": "RightHand",
    "LeftUpLeg": "LeftUpLeg",
    "LeftLeg": "LeftLeg",
    "LeftFoot": "LeftFoot",
    "LeftToeBase": "LeftToeBase",
    "RightUpLeg": "RightUpLeg",
    "RightLeg": "RightLeg",
    "RightFoot": "RightFoot",
    "RightToeBase": "RightToeBase",
}

KEY_BONES = ["Hips", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "Head"]

# Engine-standard character height baked into every exported clip (meters).
CHARACTER_HEIGHT_M = 1.85


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("stage", choices=["analyze", "process"])
    parser.add_argument("--input", required=True)
    parser.add_argument("--proposals")
    parser.add_argument("--crop-id")
    parser.add_argument("--start", type=int)
    parser.add_argument("--end", type=int)
    parser.add_argument("--rim", action="store_true")
    parser.add_argument("--rim-height", type=float, default=3.05)
    parser.add_argument("--target")
    parser.add_argument("--out")
    parser.add_argument("--smooth-window", type=int, default=5)
    parser.add_argument("--debug-render-dir", help="render start/mid/end frames before export")
    return parser.parse_args(argv)


def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_take(path: Path):
    """Source-agnostic mocap ingest: BVH (DeepMotion web export) or FBX
    (DeepMotion/SayMotion). Returns the imported armature object."""
    before = set(bpy.data.objects)
    ext = path.suffix.lower()
    if ext == ".bvh":
        bpy.ops.import_anim.bvh(filepath=str(path), update_scene_duration=True)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    else:
        raise SystemExit(f"unsupported mocap format: {ext}")
    new = [o for o in set(bpy.data.objects) - before if o.type == "ARMATURE"]
    if not new:
        raise SystemExit("no armature found in mocap file")
    return new[0]


def bone_world(armature, pose_bone_name):
    bone = armature.pose.bones.get(pose_bone_name)
    if bone is None:
        return None
    return armature.matrix_world @ bone.head


def sample_take(armature):
    """Sample key-bone world positions per frame. Vertical axis = Blender Z."""
    scene = bpy.context.scene
    start, end = scene.frame_start, scene.frame_end
    frames = []
    for frame in range(start, end + 1):
        scene.frame_set(frame)
        row = {}
        for name in KEY_BONES:
            pos = bone_world(armature, name)
            row[name] = (pos.x, pos.y, pos.z) if pos else None
        frames.append(row)
    return start, end, frames


def moving_average(values, window):
    if window <= 1:
        return list(values)
    half = window // 2
    out = []
    for i in range(len(values)):
        lo, hi = max(0, i - half), min(len(values), i + half + 1)
        out.append(sum(values[lo:hi]) / (hi - lo))
    return out


def analyze(args):
    src = Path(args.input).expanduser()
    clean_scene()
    armature = import_take(src)
    fps = bpy.context.scene.render.fps
    start, end, frames = sample_take(armature)
    n = len(frames)
    if n < 10:
        raise SystemExit("take too short to analyze")

    # Unit scale: median hips height ~= 0.95m for a standing adult.
    hips_z = [f["Hips"][2] for f in frames if f["Hips"]]
    hips_z_sorted = sorted(hips_z)
    median_hips = hips_z_sorted[len(hips_z_sorted) // 2]
    scale = 0.95 / max(median_hips, 1e-6)
    floor = min(min(f[k][2] for k in ("LeftFoot", "RightFoot") if f[k]) for f in frames)

    # Motion energy: per-frame displacement of hands+feet (scaled to meters).
    energy = [0.0]
    for i in range(1, n):
        e = 0.0
        for k in ("LeftHand", "RightHand", "LeftFoot", "RightFoot"):
            a, b = frames[i - 1][k], frames[i][k]
            if a and b:
                e += math.dist(a, b) * scale
        energy.append(e)
    energy = moving_average(energy, max(3, fps // 6))
    threshold = max(0.012, sorted(energy)[n // 2] * 1.2)

    # Active windows: energy above threshold, merged across short gaps.
    windows = []
    active = None
    gap = 0
    max_gap = int(fps * 0.4)
    for i, e in enumerate(energy):
        if e > threshold:
            if active is None:
                active = [i, i]
            active[1] = i
            gap = 0
        elif active is not None:
            gap += 1
            if gap > max_gap:
                windows.append(tuple(active))
                active, gap = None, 0
    if active is not None:
        windows.append(tuple(active))
    windows = [w for w in windows if (w[1] - w[0]) / fps >= 0.4]

    # Classify each window.
    proposals = []
    for index, (w0, w1) in enumerate(windows):
        seg = frames[w0:w1 + 1]
        peak_hand = max(
            max((f[k][2] for k in ("LeftHand", "RightHand") if f[k]), default=0)
            for f in seg
        )
        peak_hips = max(f["Hips"][2] for f in seg if f["Hips"])
        head_z = max(f["Head"][2] for f in seg if f["Head"]) if seg[0].get("Head") else peak_hips * 1.4
        peak_foot = max(
            max((f[k][2] for k in ("LeftFoot", "RightFoot") if f[k]), default=0)
            for f in seg
        )
        airborne = (peak_hips - median_hips) * scale > 0.18
        hand_above_head = peak_hand > head_z * 0.98
        high_kick = (peak_foot - floor) * scale > 0.75

        if airborne and hand_above_head:
            move = "dunk_or_jump_reach"
        elif high_kick:
            move = "kick"
        elif airborne:
            move = "jump"
        else:
            move = "ground_move"

        lead = int(fps * 0.25)
        proposals.append({
            "crop_id": f"{src.stem[:24]}_{index:02d}",
            "start_frame": max(start, start + w0 - lead),
            "end_frame": min(end, start + w1 + lead),
            "duration_s": round((w1 - w0) / fps, 2),
            "type_guess": move,
            "jump_height_m": round(max(0.0, (peak_hips - median_hips) * scale), 2),
            "peak_hand_m": round((peak_hand - floor) * scale, 2),
            "rim_candidate": bool(airborne and hand_above_head),
            "status": "proposed",
        })

    record = {
        "take": src.name,
        "source": "deepmotion" if "customModel" in src.name else "unknown",
        "path": str(src),
        "fps": fps,
        "frames": n,
        "duration_s": round(n / fps, 1),
        "unit_scale_to_m": round(scale, 5),
        "proposals": proposals,
    }

    out_path = Path(args.proposals).expanduser() if args.proposals else src.with_suffix(".proposals.json")
    existing = []
    if out_path.exists():
        existing = json.loads(out_path.read_text())
        existing = [t for t in existing if t.get("take") != record["take"]]
    existing.append(record)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(existing, indent=2))
    print(f"[nexus] {src.name}: {len(proposals)} crop(s) proposed -> {out_path}")


def action_fcurves(action):
    """FCurve access across Blender versions — 5.x uses layered/slotted
    actions (`layers[].strips[].channelbags[].fcurves`); 4.x has `.fcurves`."""
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    curves = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                curves.extend(bag.fcurves)
    return curves


def smooth_action(armature, start, end, window):
    """Moving-average smoothing of all pose curves inside the crop window —
    knocks down DeepMotion per-frame jitter without flattening the motion."""
    action = armature.animation_data.action if armature.animation_data else None
    if action is None or window <= 1:
        return
    for fcurve in action_fcurves(action):
        points = [kp for kp in fcurve.keyframe_points if start <= kp.co.x <= end]
        if len(points) < window:
            continue
        values = [kp.co.y for kp in points]
        smoothed = moving_average(values, window)
        for kp, v in zip(points, smoothed):
            kp.co.y = v
        fcurve.update()


def retarget(source, target, start, end):
    """Rest-offset matrix retarget, baked per frame.

    World-space rotation copy alone crumples the mesh when the two rigs'
    rest poses differ (DeepMotion BVH rest vs Meshy A-pose). For each bone we
    precompute the rest delta `offset = src_rest_world⁻¹ @ tgt_rest_world`
    and apply `tgt_world = src_world @ offset` every frame, parents before
    children. Hips also copies world translation (source pre-scaled to the
    target's hip height)."""
    scene = bpy.context.scene

    # Scale source so hip heights match the target character.
    scene.frame_set(start)
    src_hips = bone_world(source, "Hips")
    tgt_hips = bone_world(target, "Hips")
    if src_hips and tgt_hips and src_hips.z > 1e-6:
        k = tgt_hips.z / src_hips.z
        source.scale = (source.scale[0] * k, source.scale[1] * k, source.scale[2] * k)
        bpy.context.view_layer.update()

    def rest_world_rot(obj, bone_name):
        bone = obj.data.bones.get(bone_name)
        if bone is None:
            return None
        return (obj.matrix_world @ bone.matrix_local).to_3x3().normalized()

    offsets = {}
    for src_name, tgt_name in BONE_MAP.items():
        src_rest = rest_world_rot(source, src_name)
        tgt_rest = rest_world_rot(target, tgt_name)
        if src_rest and tgt_rest:
            offsets[tgt_name] = (src_name, src_rest.inverted() @ tgt_rest)

    for pose_bone in target.pose.bones:
        pose_bone.rotation_mode = "QUATERNION"

    # Parents before children — a child's pose matrix depends on its parent.
    order = [pb.name for pb in sorted(target.pose.bones, key=lambda p: len(p.parent_recursive))
             if pb.name in offsets]
    inv_tgt_world = target.matrix_world.inverted()

    for frame in range(start, end + 1):
        scene.frame_set(frame)
        for tgt_name in order:
            src_name, offset = offsets[tgt_name]
            src_pb = source.pose.bones.get(src_name)
            tgt_pb = target.pose.bones.get(tgt_name)
            src_world = source.matrix_world @ src_pb.matrix
            desired = (src_world.to_3x3().normalized() @ offset).to_4x4()
            if tgt_name == "Hips":
                desired.translation = src_world.to_translation()
            else:
                desired.translation = (target.matrix_world @ tgt_pb.matrix).to_translation()
            tgt_pb.matrix = inv_tgt_world @ desired
            bpy.context.view_layer.update()
            tgt_pb.keyframe_insert("rotation_quaternion", frame=frame)
            if tgt_name == "Hips":
                tgt_pb.keyframe_insert("location", frame=frame)


def fix_floor_contacts(target, start, end):
    """v1 contact pass: no foot may sink under the floor — lift hips per-frame
    by the deepest penetration. (Full IK foot-lock is a later upgrade.)"""
    scene = bpy.context.scene
    hips = target.pose.bones.get("Hips")
    if hips is None:
        return
    corrections = {}
    for frame in range(start, end + 1):
        scene.frame_set(frame)
        depths = []
        for name in ("LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"):
            pos = bone_world(target, name)
            if pos is not None:
                depths.append(pos.z)
        if depths and min(depths) < 0:
            corrections[frame] = -min(depths)
    for frame, lift in corrections.items():
        scene.frame_set(frame)
        # v1 approximation: hips-local Z tracks world Z closely for this rig family.
        hips.location.z += lift / max(target.scale[2], 1e-6)
        hips.keyframe_insert("location", frame=frame)


def normalize_rim_contact(target, start, end, rim_height):
    """Dunk clips: scale airborne root motion so the peak hand height lands at
    the fixed virtual rim height — every dunk clip contacts the same hoop."""
    scene = bpy.context.scene
    peak, peak_frame, ground = 0.0, start, None
    for frame in range(start, end + 1):
        scene.frame_set(frame)
        for name in ("LeftHand", "RightHand"):
            pos = bone_world(target, name)
            if pos and pos.z > peak:
                peak, peak_frame = pos.z, frame
        hips = bone_world(target, "Hips")
        if hips is not None:
            ground = hips.z if ground is None else min(ground, hips.z)
    if peak <= (ground or 0) + 0.1:
        print("[nexus] rim: no clear apex; skipped")
        return
    k = (rim_height - (ground or 0)) / (peak - (ground or 0))
    print(f"[nexus] rim: apex {peak:.2f}m @f{peak_frame} -> scale {k:.3f} to rim {rim_height}m")
    hips = target.pose.bones.get("Hips")
    action = target.animation_data.action
    for fcurve in action_fcurves(action):
        if fcurve.data_path == 'pose.bones["Hips"].location' and fcurve.array_index == 2:
            for kp in fcurve.keyframe_points:
                if start <= kp.co.x <= end:
                    kp.co.y *= k
            fcurve.update()


def export_clip(target, start, end, out_path: Path):
    """Export via GLB first, then GLB -> USDZ in a fresh scene. This is the
    proven conversion route (identical to blender_to_usdz.py, which produced
    the in-game character USDZs); Blender's GLB exporter is the most robust
    serializer of baked skinned animation."""
    scene = bpy.context.scene
    scene.frame_start = start
    scene.frame_end = end
    out_path.parent.mkdir(parents=True, exist_ok=True)
    glb_path = out_path.with_suffix(".glb")
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        export_animations=True,
        export_frame_range=True,
        export_force_sampling=True,
        export_apply=False,
    )
    print(f"[nexus] baked GLB {glb_path} ({glb_path.stat().st_size / 1e6:.1f} MB)")

    # Fresh scene: GLB -> absolute height -> Y-up -> USDZ.
    clean_scene()
    bpy.ops.import_scene.gltf(filepath=str(glb_path))

    # Bake absolute character height into the clip. SceneKit bounding boxes
    # lie for skinned meshes, so the app loads clips UN-normalized and trusts
    # these units (meters).
    armature = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
    if armature is not None:
        bpy.context.scene.frame_set(start)
        tops, feet = [], []
        for name in ("Head", "head_end"):
            pos = bone_world(armature, name)
            if pos:
                tops.append(pos.z)
        for name in ("LeftFoot", "RightFoot"):
            pos = bone_world(armature, name)
            if pos:
                feet.append(pos.z)
        if tops and feet:
            height = max(tops) - min(feet)
            if height > 1e-4:
                k = CHARACTER_HEIGHT_M / height
                # Object-level scale does NOT survive into SceneKit's skeleton
                # binding — bake it into the data: apply scale on armature +
                # meshes, then rescale the root-motion (hips location) curves.
                for obj in bpy.data.objects:
                    if obj.parent is None:
                        obj.scale = (obj.scale[0] * k, obj.scale[1] * k, obj.scale[2] * k)
                bpy.ops.object.select_all(action="DESELECT")
                for obj in bpy.data.objects:
                    if obj.type in ("ARMATURE", "MESH"):
                        obj.select_set(True)
                bpy.context.view_layer.objects.active = armature
                bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
                if armature.animation_data and armature.animation_data.action:
                    for fcurve in action_fcurves(armature.animation_data.action):
                        if fcurve.data_path.endswith('].location'):
                            for kp in fcurve.keyframe_points:
                                kp.co.y *= k
                            fcurve.update()
                print(f"[nexus] clip height {height:.2f} -> baked scale x{k:.4f} to {CHARACTER_HEIGHT_M}m")

    # Re-root: the character's hips start over the origin with feet on the
    # floor, so game code can place clips by node position alone.
    if armature is not None:
        bpy.context.scene.frame_set(start)
        hips = bone_world(armature, "Hips")
        feet = [bone_world(armature, n) for n in ("LeftFoot", "RightFoot")]
        feet = [f for f in feet if f]
        if hips is not None and feet:
            offset = mathutils.Vector((-hips.x, -hips.y, -min(f.z for f in feet)))
            for obj in bpy.data.objects:
                if obj.parent is None:
                    obj.location = obj.location + offset
            print(f"[nexus] re-rooted by {tuple(round(v, 2) for v in offset)}")

    rot = mathutils.Matrix.Rotation(math.radians(-90.0), 4, "X")
    for obj in bpy.data.objects:
        if obj.parent is None:
            obj.matrix_world = rot @ obj.matrix_world
    bpy.ops.wm.usd_export(
        filepath=str(out_path),
        export_animation=True,
        export_uvmaps=True,
        export_normals=True,
        export_materials=True,
        selected_objects_only=False,
    )
    print(f"[nexus] exported clip {out_path} ({out_path.stat().st_size / 1e6:.1f} MB)")


def process(args):
    if args.start is None or args.end is None or not args.target or not args.out:
        raise SystemExit("process needs --start --end --target --out")
    src = Path(args.input).expanduser()
    clean_scene()

    # Target character (Meshy rig + skinned mesh).
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(Path(args.target).expanduser()))
    target = next(o for o in set(bpy.data.objects) - before if o.type == "ARMATURE")
    if target.animation_data:
        target.animation_data.action = None  # drop the shipped walk/run loop

    # Keep only skinned meshes (drops stray props like the Meshy Icosphere),
    # and decimate to the mobile face budget.
    for obj in [o for o in set(bpy.data.objects) - before if o.type == "MESH"]:
        if obj.find_armature() is None:
            bpy.data.objects.remove(obj, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == target]
    total = sum(len(o.data.polygons) for o in meshes)
    budget = 60000
    if total > budget:
        ratio = budget / total
        for obj in meshes:
            mod = obj.modifiers.new("nexus_decimate", "DECIMATE")
            mod.ratio = ratio
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
        print(f"[nexus] target decimated {total} -> {budget} faces")

    source = import_take(src)
    smooth_action(source, args.start, args.end, args.smooth_window)
    retarget(source, target, args.start, args.end)

    # Remove the source rig before contact/rim passes and export.
    for obj in list(bpy.data.objects):
        if obj == source or (obj.parent == source):
            bpy.data.objects.remove(obj, do_unlink=True)

    fix_floor_contacts(target, args.start, args.end)
    if args.rim:
        normalize_rim_contact(target, args.start, args.end, args.rim_height)

    if args.debug_render_dir:
        debug_render(target, args.start, args.end, Path(args.debug_render_dir).expanduser())

    export_clip(target, args.start, args.end, Path(args.out).expanduser())


def debug_render(target, start, end, outdir):
    """Workbench-render start/mid/end frames of the retargeted rig in-session,
    isolating retarget errors from USD-export errors."""
    scene = bpy.context.scene
    cam = bpy.data.objects.new("dbg_cam", bpy.data.cameras.new("dbg_cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    sun = bpy.data.objects.new("dbg_sun", bpy.data.lights.new("dbg_sun", "SUN"))
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    outdir.mkdir(parents=True, exist_ok=True)
    for frame in (start, (start + end) // 2, end):
        scene.frame_set(frame)
        hips = bone_world(target, "Hips") or mathutils.Vector((0, 0, 1))
        span = max(1.0, hips.z * 2.2)
        cam.location = (hips.x, hips.y - span * 2.2, hips.z + span * 0.3)
        direction = mathutils.Vector((hips.x, hips.y, hips.z)) - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(outdir / f"dbg_{frame:04d}.png")
        bpy.ops.render.render(write_still=True)
        print(f"[nexus] debug render f{frame} hips_z={hips.z:.2f}")


def main():
    args = parse_args()
    if args.stage == "analyze":
        analyze(args)
    else:
        process(args)


main()
