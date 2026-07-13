"""Auto-rig a static Meshy character mesh with the standard FEL armature.

Meshy character exports (Eric Nash, body-type players) ship as unrigged
static meshes. This fits the Elijah Bonds donor armature to the mesh
(uniform height scale, feet aligned) and binds with automatic weights, so
the result can be driven by any clip via mocap_pipeline.py retarget.

Usage:
  Blender --background --python autorig_npc.py -- \
      --mesh NPC.fbx --donor ElijahRig.glb --out NPC_rigged.glb
"""

import argparse
import sys
from pathlib import Path

import bpy
import mathutils


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--mesh", required=True)
    parser.add_argument("--donor", required=True)
    parser.add_argument("--out", required=True)
    return parser.parse_args(argv)


def world_bbox(objects):
    deps = bpy.context.evaluated_depsgraph_get()
    lo = mathutils.Vector((1e9,) * 3)
    hi = mathutils.Vector((-1e9,) * 3)
    for obj in objects:
        if obj.type != "MESH":
            continue
        eval_obj = obj.evaluated_get(deps)
        for corner in eval_obj.bound_box:
            world = eval_obj.matrix_world @ mathutils.Vector(corner)
            lo = mathutils.Vector(map(min, lo, world))
            hi = mathutils.Vector(map(max, hi, world))
    return lo, hi


def main():
    args = parse_args()
    bpy.ops.wm.read_factory_settings(use_empty=True)

    # Donor armature (drop the donor's own mesh/extras).
    bpy.ops.import_scene.gltf(filepath=str(Path(args.donor).expanduser()))
    armature = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    if armature.animation_data:
        armature.animation_data.action = None
    for obj in list(bpy.data.objects):
        if obj.type != "ARMATURE":
            bpy.data.objects.remove(obj, do_unlink=True)

    # NPC mesh.
    before = set(bpy.data.objects)
    mesh_path = Path(args.mesh).expanduser()
    if mesh_path.suffix.lower() == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(mesh_path))
    else:
        bpy.ops.import_scene.gltf(filepath=str(mesh_path))
    npc_meshes = [o for o in set(bpy.data.objects) - before if o.type == "MESH"]
    if not npc_meshes:
        raise SystemExit("no mesh in NPC file")

    # Fit armature: uniform scale to NPC height, feet/floor aligned, centered.
    bpy.context.view_layer.update()
    mesh_lo, mesh_hi = world_bbox(npc_meshes)
    npc_height = mesh_hi.z - mesh_lo.z
    head_end = armature.data.bones.get("head_end") or armature.data.bones.get("Head")
    rig_top = (armature.matrix_world @ head_end.tail_local).z if head_end else 1.7
    if rig_top > 1e-4 and npc_height > 1e-4:
        k = npc_height / rig_top
        armature.scale = (k, k, k)
    armature.location = mathutils.Vector((
        (mesh_lo.x + mesh_hi.x) / 2,
        (mesh_lo.y + mesh_hi.y) / 2,
        mesh_lo.z,
    ))
    bpy.context.view_layer.update()

    # Bind with automatic weights (bone heat).
    bpy.ops.object.select_all(action="DESELECT")
    for mesh in npc_meshes:
        mesh.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")

    skinned = [m for m in npc_meshes if m.find_armature() is not None]
    print(f"[nexus] auto-rigged {mesh_path.name}: {len(skinned)}/{len(npc_meshes)} meshes bound, height {npc_height:.2f}")
    if not skinned:
        raise SystemExit("automatic weighting failed")

    out = Path(args.out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_animations=False)
    print(f"[nexus] rigged NPC -> {out} ({out.stat().st_size / 1e6:.1f} MB)")


main()
