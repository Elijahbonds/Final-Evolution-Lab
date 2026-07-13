"""Headless Blender: convert Meshy/Seeles source assets (GLB/FBX) to USDZ for SceneKit.

Part of the Nexus asset pipeline. SceneKit cannot load GLB or FBX directly, so
bundled 3D assets are converted offline to USDZ (textures embedded, animations
baked). Blender 4.2+ exports .usdz natively.

Usage:
  Blender --background --python blender_to_usdz.py -- \
      --input /path/to/asset.glb --output /path/to/asset.usdz \
      [--max-faces 120000] [--scale 1.0] [--inspect]

  --inspect  print object/armature/animation/face stats and exit (no export)
  --max-faces  decimate meshes above this total face budget (venues)
  --scale      uniform scale applied to root objects before export
"""

import argparse
import math
import sys
from pathlib import Path

import bpy


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output")
    parser.add_argument("--max-faces", type=int, default=0)
    parser.add_argument("--scale", type=float, default=1.0)
    parser.add_argument("--inspect", action="store_true")
    return parser.parse_args(argv)


def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_asset(path: Path):
    ext = path.suffix.lower()
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    else:
        raise SystemExit(f"unsupported input format: {ext}")


def stats():
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    armatures = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    faces = sum(len(o.data.polygons) for o in meshes)
    actions = list(bpy.data.actions)
    skinned = [o.name for o in meshes if o.find_armature() is not None]
    frame_ranges = {a.name: tuple(int(f) for f in a.frame_range) for a in actions}
    return {
        "meshes": [o.name for o in meshes],
        "faces": faces,
        "armatures": [o.name for o in armatures],
        "bones": {a.name: len(a.data.bones) for a in armatures},
        "skinned_meshes": skinned,
        "actions": frame_ranges,
        "materials": [m.name for m in bpy.data.materials],
        "images": [(i.name, tuple(i.size)) for i in bpy.data.images if i.size[0]],
    }


def decimate(max_faces: int):
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    total = sum(len(o.data.polygons) for o in meshes)
    if total <= max_faces:
        return total, total
    ratio = max_faces / total
    for obj in meshes:
        mod = obj.modifiers.new(name="nexus_decimate", type="DECIMATE")
        mod.ratio = ratio
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return total, sum(len(o.data.polygons) for o in meshes)


def apply_scale(scale: float):
    if math.isclose(scale, 1.0):
        return
    for obj in bpy.data.objects:
        if obj.parent is None:
            obj.scale = (obj.scale[0] * scale, obj.scale[1] * scale, obj.scale[2] * scale)


def convert_to_y_up():
    """Blender scenes are Z-up; SceneKit expects Y-up. Compose a -90° X
    rotation at each root (object-level, NOT baked) so skinned animation
    data is untouched and the correction exports as a plain USD xformOp."""
    import mathutils
    rot = mathutils.Matrix.Rotation(math.radians(-90.0), 4, "X")
    for obj in bpy.data.objects:
        if obj.parent is None:
            obj.matrix_world = rot @ obj.matrix_world


def export_usdz(path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    # Minimal stable kwargs — the USD exporter's texture options vary across
    # Blender versions; textures embed automatically for .usdz targets.
    bpy.ops.wm.usd_export(
        filepath=str(path),
        export_animation=bool(bpy.data.actions),
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
    import_asset(src)

    info = stats()
    print(f"[nexus] imported {src.name}")
    for key, value in info.items():
        print(f"[nexus]   {key}: {value}")

    if args.inspect:
        return

    if args.max_faces:
        before, after = decimate(args.max_faces)
        print(f"[nexus] decimate: {before} -> {after} faces (budget {args.max_faces})")

    apply_scale(args.scale)

    # Animated characters: re-root so the FRAME-1 animated hips sit over the
    # origin with feet on the floor (SceneKit placement contract — same as
    # mocap_pipeline.py). Rest-pose joints are NOT reliable for this.
    if bpy.data.actions and "--no-reroot" not in sys.argv:
        armature = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
        if armature is not None:
            bpy.context.scene.frame_set(int(bpy.context.scene.frame_start))
            hips_bone = armature.pose.bones.get("Hips")
            feet = [armature.pose.bones.get(n) for n in ("LeftFoot", "RightFoot")]
            feet = [b for b in feet if b is not None]
            if hips_bone is not None and feet:
                hips_world = armature.matrix_world @ hips_bone.head
                foot_floor = min((armature.matrix_world @ b.head).z for b in feet)
                import mathutils as _mu
                offset = _mu.Vector((-hips_world.x, -hips_world.y, -foot_floor))
                for obj in bpy.data.objects:
                    if obj.parent is None:
                        obj.location = obj.location + offset
                print(f"[nexus] re-rooted animated clip by {tuple(round(v, 3) for v in offset)}")

    convert_to_y_up()

    out = Path(args.output).expanduser() if args.output else src.with_suffix(".usdz")
    export_usdz(out)
    size_mb = out.stat().st_size / 1e6
    print(f"[nexus] exported {out} ({size_mb:.1f} MB)")


main()
