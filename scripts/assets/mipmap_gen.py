#!/usr/bin/env python3
"""
NEXUS mipmap chain generator.

Generates a full mip chain for each input texture down to 1x1 using
high-quality Lanczos downsampling, and writes a JSON descriptor per texture.
Mip level 0 is re-emitted so the chain is self-contained.

Non-power-of-two inputs are first resized up to the next power of two
(flagged in the descriptor) because GPU block-compressed formats require
POT dimensions on the mobile tiers.

Usage:
    python3 scripts/assets/mipmap_gen.py \
        --input assets/nexus/samples/textures \
        --output assets/nexus/generated/mips

Outputs per texture `foo.png`:
    <output>/foo/mip0.png ... mipN.png
    <output>/foo/foo.mips.json
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image


def next_pow2(n: int) -> int:
    p = 1
    while p < n:
        p *= 2
    return p


def generate_chain(src: Path, out_root: Path) -> dict:
    img = Image.open(src).convert("RGBA")
    orig_size = (img.width, img.height)
    pot = (next_pow2(img.width), next_pow2(img.height))
    resized = pot != orig_size
    if resized:
        img = img.resize(pot, Image.LANCZOS)

    tex_dir = out_root / src.stem
    tex_dir.mkdir(parents=True, exist_ok=True)

    levels = []
    level = 0
    current = img
    while True:
        path = tex_dir / f"mip{level}.png"
        current.save(path)
        levels.append({"level": level, "width": current.width, "height": current.height,
                       "file": path.name})
        if current.width == 1 and current.height == 1:
            break
        current = current.resize(
            (max(1, current.width // 2), max(1, current.height // 2)), Image.LANCZOS
        )
        level += 1

    descriptor = {
        "source": src.name,
        "original_size": list(orig_size),
        "pot_resized": resized,
        "levels": levels,
    }
    (tex_dir / f"{src.stem}.mips.json").write_text(json.dumps(descriptor, indent=2))
    return descriptor


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate mipmap chains for PNG textures")
    parser.add_argument("--input", required=True, help="Directory of source PNGs")
    parser.add_argument("--output", required=True, help="Output root directory")
    args = parser.parse_args()

    src_dir = Path(args.input)
    pngs = sorted(src_dir.glob("*.png"))
    if not pngs:
        print(f"[mips] no PNGs found in {src_dir}", file=sys.stderr)
        return 1

    out_root = Path(args.output)
    for p in pngs:
        d = generate_chain(p, out_root)
        print(f"[mips] {p.name}: {len(d['levels'])} levels"
              f"{' (POT-resized)' if d['pot_resized'] else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
