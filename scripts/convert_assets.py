#!/usr/bin/env python3
"""FEL asset converter & validator.

- FBX/GLB/BVH -> glTF 2.0 (.glb) via headless Blender when available
  (falls back to printing the exact FBX2glTF/assimp commands otherwise)
- basic glTF validation (magic/json chunk parse; pygltflib if installed)
- --make-sprite: generates a radial-gradient particle sprite PNG so VFX
  never depend on an external download

Usage:
  scripts/convert_assets.py convert --input in.fbx --output out.glb
  scripts/convert_assets.py validate --input out.glb
  scripts/convert_assets.py make-sprite --output assets/placeholder/particle.png
"""
import argparse, json, shutil, struct, subprocess, sys, zlib
from pathlib import Path

BLENDER_CANDIDATES = [
    "/Applications/Blender.app/Contents/MacOS/Blender",
    shutil.which("blender") or "",
]

BLENDER_SNIPPET = """
import bpy, sys
src, dst = sys.argv[sys.argv.index('--')+1:][:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
ext = src.rsplit('.', 1)[-1].lower()
if ext == 'fbx':
    bpy.ops.import_scene.fbx(filepath=src)
elif ext == 'bvh':
    bpy.ops.import_anim.bvh(filepath=src, update_scene_duration=True)
elif ext in ('glb', 'gltf'):
    bpy.ops.import_scene.gltf(filepath=src)
else:
    raise SystemExit('unsupported: ' + ext)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB',
                          export_animations=True, export_force_sampling=True)
print('converted ->', dst)
"""

def blender():
    for c in BLENDER_CANDIDATES:
        if c and Path(c).exists():
            return c
    return None

def convert(args):
    b = blender()
    src, dst = Path(args.input), Path(args.output)
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not b:
        print("Blender not found. Manual alternatives:")
        print(f"  FBX2glTF --binary --input {src} --output {dst.with_suffix('')}")
        print(f"  assimp export {src} {dst}")
        sys.exit(3)
    snippet = dst.parent / "_fel_convert_snippet.py"
    snippet.write_text(BLENDER_SNIPPET)
    try:
        result = subprocess.run(
            [b, "--background", "--python", str(snippet), "--", str(src), str(dst)],
            capture_output=True, text=True, timeout=1800)
        ok = dst.exists() and "converted ->" in result.stdout
        print(result.stdout.splitlines()[-1] if result.stdout else result.stderr[-400:])
        sys.exit(0 if ok else 1)
    finally:
        snippet.unlink(missing_ok=True)

def validate(args):
    p = Path(args.input)
    data = p.read_bytes()
    try:
        import pygltflib  # type: ignore
        pygltflib.GLTF2().load(str(p))
        print(f"OK (pygltflib): {p}")
        return
    except ImportError:
        pass
    if p.suffix == ".glb":
        magic, version, length = struct.unpack_from("<4sII", data, 0)
        assert magic == b"glTF" and version == 2 and length == len(data), "bad GLB header"
        chunk_len, chunk_type = struct.unpack_from("<I4s", data, 12)
        assert chunk_type == b"JSON", "first chunk must be JSON"
        json.loads(data[20:20 + chunk_len])
    else:
        json.loads(data)
    print(f"OK (structural): {p}")

def make_sprite(args):
    size = 64
    rows = []
    center = (size - 1) / 2
    for y in range(size):
        row = b""
        for x in range(size):
            d = (((x - center) ** 2 + (y - center) ** 2) ** 0.5) / center
            a = max(0, min(255, int(255 * (1 - d) ** 2)))
            row += bytes((255, 255, 255, a))
        rows.append(b"\x00" + row)
    raw = b"".join(rows)
    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(raw))
           + chunk(b"IEND", b""))
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(png)
    print(f"sprite -> {out} ({len(png)} bytes)")

def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("convert"); c.add_argument("--input", required=True); c.add_argument("--output", required=True)
    v = sub.add_parser("validate"); v.add_argument("--input", required=True)
    m = sub.add_parser("make-sprite"); m.add_argument("--output", required=True)
    args = parser.parse_args()
    {"convert": convert, "validate": validate, "make-sprite": make_sprite}[args.cmd](args)

if __name__ == "__main__":
    main()
