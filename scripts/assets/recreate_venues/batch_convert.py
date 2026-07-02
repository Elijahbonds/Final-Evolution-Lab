#!/usr/bin/env python3
"""Recreate all venue assets for SceneKit.

Per venue: assimp FBX->glTF (recovers embedded PBR textures + slot mapping),
split the combined metallicRoughness map into channels, then the Swift
converter builds an indexed .scn from the existing desktop .nexusmesh.json
plus the recovered textures, and renders a preview PNG for eyeballing.
"""
import base64
import json
import subprocess
import sys
from pathlib import Path

from PIL import Image
import pymeshlab

TARGET_FACES = 45_000

def decimate_obj(obj_path, target=TARGET_FACES):
    """UV-preserving quadric decimation for heavy photogrammetry meshes."""
    ms = pymeshlab.MeshSet()
    ms.load_new_mesh(str(obj_path))
    faces = ms.current_mesh().face_number()
    if faces <= target:
        return obj_path, faces, faces
    # Photogrammetry OBJs carry duplicated per-corner vertices; the texture-
    # preserving decimator silently no-ops on them. Weld first.
    ms.meshing_remove_duplicate_vertices()
    ms.meshing_decimation_quadric_edge_collapse_with_texture(targetfacenum=target)
    out = obj_path.with_name(obj_path.stem + "_decimated.obj")
    ms.save_current_mesh(str(out))
    return out, faces, ms.current_mesh().face_number()

REPO = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("../fel")
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("./out")
SRC = REPO / "assets/nexus/source"
IMPORTED = REPO / "assets/nexus/imported"
CONVERTER = Path(__file__).parent / "convert_venue.swift"

def sh(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True)

def decode_textures(gltf_path: Path, workdir: Path):
    """Returns (albedo, metalrough, normal) paths (None where absent)."""
    g = json.loads(gltf_path.read_text())
    images = g.get("images", [])
    paths = []
    for i, im in enumerate(images):
        uri = im.get("uri", "")
        if not uri.startswith("data:"):
            paths.append(None)
            continue
        p = workdir / f"img{i}.png"
        p.write_bytes(base64.b64decode(uri.split(",", 1)[1]))
        paths.append(p)

    def tex_image(slot):
        idx = slot.get("index") if slot else None
        if idx is None:
            return None
        src = g["textures"][idx].get("source")
        return paths[src] if src is not None and src < len(paths) else None

    mats = g.get("materials", [])
    if not mats:
        return None, None, None
    m = mats[0]
    pbr = m.get("pbrMetallicRoughness", {})
    return (
        tex_image(pbr.get("baseColorTexture")),
        tex_image(pbr.get("metallicRoughnessTexture")),
        tex_image(m.get("normalTexture")),
    )

def split_mr(mr_path: Path, workdir: Path):
    """glTF combined map: G=roughness, B=metallic -> two grayscale PNGs."""
    img = Image.open(mr_path).convert("RGB")
    _, g, b = img.split()
    rough = workdir / "mr_roughness.png"
    metal = workdir / "mr_metalness.png"
    g.save(rough)
    b.save(metal)
    return rough, metal

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    fbx_files = sorted(SRC.glob("*.fbx"))
    if not fbx_files:
        sys.exit(f"no FBX under {SRC}")
    results = []
    for fbx in fbx_files:
        name = fbx.stem  # e.g. venice_beach_court_model_fbx
        mesh_json = IMPORTED / f"{name}.nexusmesh.json"
        if not mesh_json.exists():
            results.append((name, "SKIP: no imported nexusmesh"))
            continue
        work = OUT / name
        work.mkdir(parents=True, exist_ok=True)

        gltf = work / f"{name}.gltf"
        r = sh("assimp", "export", str(fbx), str(gltf))
        if r.returncode != 0 or not gltf.exists():
            results.append((name, f"FAIL: assimp export ({r.stderr.strip()[:80]})"))
            continue

        albedo, mr, normal = decode_textures(gltf, work)
        rough = None
        if mr is not None:
            rough, _ = split_mr(mr, work)

        # Geometry source: the indexed JSON when it kept UVs, else OBJ export
        # (ModelIO path) which preserves the FBX UVs the JSON dropped.
        geom_src = mesh_json
        first_vertex = json.loads(mesh_json.read_text())["vertices"][0]
        if "uv" not in first_vertex:
            obj = work / f"{name}.obj"
            r = sh("assimp", "export", str(fbx), str(obj))
            if r.returncode != 0 or not obj.exists():
                results.append((name, f"FAIL: assimp obj export ({r.stderr.strip()[:80]})"))
                continue
            try:
                obj, before, after = decimate_obj(obj)
                if after < before:
                    print(f"  {name}: decimated {before} -> {after} faces")
            except Exception as e:
                print(f"  {name}: decimation skipped ({e})")
            geom_src = obj

        scn = OUT / f"{name}.scn"
        preview = OUT / f"{name}_preview.png"
        r = sh("swift", str(CONVERTER), str(geom_src),
               str(albedo) if albedo else "-",
               str(rough) if rough else "-",
               str(normal) if normal else "-",
               str(scn), str(preview))
        ok = r.returncode == 0 and scn.exists()
        line = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else r.stderr.strip()[:120]
        results.append((name, ("OK " if ok else "FAIL ") + line))

    print("\n=== BATCH RESULTS ===")
    for name, status in results:
        print(f"{status.split(':')[0][:4]:5} {name}: {status}")
    fails = [r for r in results if not r[1].startswith("OK")]
    sys.exit(1 if fails else 0)

if __name__ == "__main__":
    main()
