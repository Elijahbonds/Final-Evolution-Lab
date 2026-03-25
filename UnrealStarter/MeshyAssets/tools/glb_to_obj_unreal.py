#!/usr/bin/env python3
"""
Convert a single-mesh glTF 2.0 binary (.glb) to OBJ + MTL + extracted images
for reliable import into Unreal Engine (5.2+; use when glTF/GLB import is unreliable).

Usage:
  python3 glb_to_obj_unreal.py input.glb [output_dir]

Coordinate fix: applies Y-up (glTF) -> Z-up (Unreal-friendly) by rotating -90° about X:
  (x, y, z) -> (x, z, -y)
Normals are transformed the same way and re-normalized.
"""
from __future__ import annotations

import json
import struct
import sys
from pathlib import Path


def read_glb(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    if len(data) < 12 or data[:4] != b"glTF":
        raise ValueError("Not a GLB file")
    version, total_len = struct.unpack_from("<II", data, 4)
    if version != 2:
        raise ValueError(f"Expected glTF 2.0, got version {version}")
    offset = 12
    json_chunk = None
    bin_chunk = None
    while offset < total_len:
        if offset + 8 > len(data):
            break
        chunk_len, chunk_type = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk_data = data[offset : offset + chunk_len]
        offset += chunk_len
        if chunk_len % 4:
            offset += (4 - (chunk_len % 4)) % 4
        if chunk_type == b"JSON":
            json_chunk = json.loads(chunk_data.decode("utf-8"))
        elif chunk_type == b"BIN\x00":
            bin_chunk = chunk_data
    if json_chunk is None or bin_chunk is None:
        raise ValueError("GLB missing JSON or BIN chunk")
    return json_chunk, bin_chunk


def elem_elem_size(component_type: int, components: int) -> int:
    sizes = {5126: 4, 5125: 4, 5123: 2, 5121: 1}
    return sizes[component_type] * components


def read_f32_vec3(buf: memoryview, count: int) -> list[tuple[float, float, float]]:
    out = []
    step = 12
    for i in range(count):
        o = i * step
        x, y, z = struct.unpack_from("<fff", buf, o)
        out.append((x, y, z))
    return out


def read_f32_vec2(buf: memoryview, count: int) -> list[tuple[float, float]]:
    out = []
    step = 8
    for i in range(count):
        o = i * step
        u, v = struct.unpack_from("<ff", buf, o)
        out.append((u, v))
    return out


def read_u32_indices(buf: memoryview, count: int) -> list[int]:
    out = []
    for i in range(count):
        (idx,) = struct.unpack_from("<I", buf, i * 4)
        out.append(idx)
    return out


def y_up_to_z_up(p: tuple[float, float, float]) -> tuple[float, float, float]:
    x, y, z = p
    return (x, z, -y)


def normalize(n: tuple[float, float, float]) -> tuple[float, float, float]:
    import math

    x, y, z = n
    l = math.sqrt(x * x + y * y + z * z)
    if l < 1e-20:
        return (0.0, 0.0, 1.0)
    return (x / l, y / l, z / l)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    src = Path(sys.argv[1]).resolve()
    if not src.is_file():
        print(f"Not found: {src}", file=sys.stderr)
        return 1
    out_dir = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else src.parent / f"{src.stem}_UE_OBJ"
    out_dir.mkdir(parents=True, exist_ok=True)
    tex_dir = out_dir / "textures"
    tex_dir.mkdir(exist_ok=True)

    gltf, bin_data = read_glb(src)
    meshes = gltf.get("meshes", [])
    if len(meshes) != 1 or len(meshes[0].get("primitives", [])) != 1:
        print(
            "Warning: expected exactly one mesh with one primitive; exporting first primitive only.",
            file=sys.stderr,
        )
    prim = meshes[0]["primitives"][0]
    attrs = prim["attributes"]
    idx_acc = prim.get("indices")
    if idx_acc is None:
        print("Mesh has no indices; not supported.", file=sys.stderr)
        return 1

    pos_acc = attrs["POSITION"]
    uv_acc = attrs.get("TEXCOORD_0")
    nrm_acc = attrs.get("NORMAL")

    # Raw buffer slices
    def slice_for_accessor(acc_idx: int) -> memoryview:
        acc = gltf["accessors"][acc_idx]
        bv = gltf["bufferViews"][acc["bufferView"]]
        off = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
        count = acc["count"]
        ctype = acc["componentType"]
        atype = acc["type"]
        comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[atype]
        es = elem_elem_size(ctype, comps)
        end = off + count * es
        return memoryview(bin_data)[off:end]

    positions = read_f32_vec3(slice_for_accessor(pos_acc), gltf["accessors"][pos_acc]["count"])
    indices = read_u32_indices(slice_for_accessor(idx_acc), gltf["accessors"][idx_acc]["count"])
    uvs = (
        read_f32_vec2(slice_for_accessor(uv_acc), gltf["accessors"][uv_acc]["count"])
        if uv_acc is not None
        else [(0.0, 0.0)] * len(positions)
    )
    normals = (
        read_f32_vec3(slice_for_accessor(nrm_acc), gltf["accessors"][nrm_acc]["count"])
        if nrm_acc is not None
        else [(0.0, 1.0, 0.0)] * len(positions)
    )

    # Y-up -> Z-up for Unreal
    positions = [y_up_to_z_up(p) for p in positions]
    normals = [normalize(y_up_to_z_up(n)) for n in normals]

    # Extract first material's base color image (if any)
    map_kd_rel = None
    mats = gltf.get("materials", [])
    if mats:
        pbr = mats[0].get("pbrMetallicRoughness", {})
        bct = pbr.get("baseColorTexture")
        if bct is not None:
            tex_idx = bct["index"]
            img_idx = gltf["textures"][tex_idx]["source"]
            img = gltf["images"][img_idx]
            bv_idx = img["bufferView"]
            bv = gltf["bufferViews"][bv_idx]
            start = bv.get("byteOffset", 0)
            end = start + bv["byteLength"]
            img_bytes = bytes(bin_data[start:end])
            mime = img.get("mimeType", "image/jpeg")
            ext = ".jpg" if "jpeg" in mime else ".png"
            img_name = f"basecolor{ext}"
            (tex_dir / img_name).write_bytes(img_bytes)
            map_kd_rel = f"textures/{img_name}"

    mtl_name = "Venice_mesh.mtl"
    mtl_path = out_dir / mtl_name
    obj_name = "Venice_mesh.obj"
    obj_path = out_dir / obj_name

    with mtl_path.open("w", encoding="utf-8") as mtl:
        mtl.write("newmtl Material_0\n")
        mtl.write("Ka 1 1 1\nKd 1 1 1\nKs 0 0 0\n")
        if map_kd_rel:
            mtl.write(f"map_Kd {map_kd_rel}\n")

    with obj_path.open("w", encoding="utf-8") as obj:
        obj.write(f"mtllib {mtl_name}\n")
        obj.write("o Mesh\n")
        for x, y, z in positions:
            obj.write(f"v {x:.6f} {y:.6f} {z:.6f}\n")
        for u, v in uvs:
            obj.write(f"vt {u:.6f} {v:.6f}\n")
        for x, y, z in normals:
            obj.write(f"vn {x:.6f} {y:.6f} {z:.6f}\n")
        obj.write("usemtl Material_0\n")
        for i in range(0, len(indices), 3):
            a, b, c = indices[i] + 1, indices[i + 1] + 1, indices[i + 2] + 1
            obj.write(f"f {a}/{a}/{a} {b}/{b}/{b} {c}/{c}/{c}\n")

    print(f"Wrote: {obj_path}")
    print(f"Wrote: {mtl_path}")
    if map_kd_rel:
        print(f"Texture: {out_dir / map_kd_rel}")
    print("\nUnreal: Import Venice_mesh.obj as Static Mesh; enable Nanite; add collision.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
