#!/usr/bin/env python3
"""
NEXUS compressed-texture output stage (ASTC / ETC2).

For each input PNG:
  * If the `astcenc` CLI (ARM astc-encoder) is on PATH, emits a real
    `<name>.astc` compressed texture at the requested block size.
  * Otherwise emits `<name>.astc.todo.json` / `<name>.etc2.todo.json`
    PLACEHOLDER descriptors that record the intended target format, block
    size, and source hash — no fake binary data is ever written. The iOS
    runtime keeps consuming PNG until real encoders run in the asset bake.

Usage:
    python3 scripts/assets/compress_textures.py \
        --input assets/nexus/samples/textures \
        --output assets/nexus/generated/compressed \
        [--astc-block 6x6]

Install a real encoder with: `brew install astcenc` (macOS).
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    h.update(p.read_bytes())
    return h.hexdigest()


def compress_astc(src: Path, out_dir: Path, block: str, encoder: str) -> Path:
    dst = out_dir / f"{src.stem}.astc"
    subprocess.run(
        [encoder, "-cl", str(src), str(dst), block, "-medium"],
        check=True, capture_output=True,
    )
    return dst


def write_placeholder(src: Path, out_dir: Path, fmt: str, detail: dict) -> Path:
    dst = out_dir / f"{src.stem}.{fmt}.todo.json"
    payload = {
        "placeholder": True,
        "note": f"No {fmt.upper()} encoder available at generation time; "
                "runtime falls back to PNG. Re-run with an encoder installed.",
        "source": src.name,
        "source_sha256": sha256_file(src),
        "target_format": fmt,
        **detail,
    }
    dst.write_text(json.dumps(payload, indent=2))
    return dst


def main() -> int:
    parser = argparse.ArgumentParser(description="Compress PNGs to ASTC/ETC2 (or placeholders)")
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--astc-block", default="6x6", help="ASTC block size (e.g. 4x4, 6x6, 8x8)")
    args = parser.parse_args()

    src_dir = Path(args.input)
    pngs = sorted(src_dir.glob("*.png"))
    if not pngs:
        print(f"[compress] no PNGs found in {src_dir}", file=sys.stderr)
        return 1

    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)

    astc_encoder = shutil.which("astcenc") or shutil.which("astcenc-avx2")
    for p in pngs:
        if astc_encoder:
            dst = compress_astc(p, out_dir, args.astc_block, astc_encoder)
            print(f"[compress] {p.name} -> {dst.name} (astcenc {args.astc_block})")
        else:
            dst = write_placeholder(p, out_dir, "astc", {"block_size": args.astc_block})
            print(f"[compress] {p.name} -> {dst.name} (PLACEHOLDER — astcenc not installed)")
        # ETC2: no commonly-preinstalled CLI encoder; always a descriptor for now.
        etc2 = write_placeholder(p, out_dir, "etc2", {"profile": "RGBA8"})
        print(f"[compress] {p.name} -> {etc2.name} (PLACEHOLDER — ETC2 encode deferred)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
