#!/usr/bin/env python3
"""
NEXUS texture atlas generator.

Packs a directory of PNG sprites into a single power-of-two atlas using a
shelf-packing algorithm, and writes a JSON manifest with normalized UV rects
that NEXUS material/sprite code can consume.

Usage:
    python3 scripts/assets/atlas_gen.py \
        --input assets/nexus/samples/sprites \
        --output assets/nexus/generated/atlas/fx_atlas \
        [--max-size 2048] [--padding 2]

Outputs:
    <output>.png          — packed atlas (RGBA)
    <output>.atlas.json   — {"size": [w,h], "sprites": {name: {x,y,w,h,u0,v0,u1,v1}}}

Requires: Pillow (see backend/requirements-ci.txt).
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


def shelf_pack(images: list, max_size: int, padding: int):
    """Simple shelf packer: sort by height desc, fill rows left to right."""
    images = sorted(images, key=lambda t: t[1].height, reverse=True)
    placements = {}
    x = y = shelf_h = max_x = 0
    for name, img in images:
        w, h = img.width + padding, img.height + padding
        if w > max_size:
            raise ValueError(f"Sprite '{name}' ({img.width}px) exceeds max atlas width {max_size}")
        if x + w > max_size:
            y += shelf_h
            x = 0
            shelf_h = 0
        placements[name] = (x, y, img)
        x += w
        max_x = max(max_x, x)
        shelf_h = max(shelf_h, h)
    total_h = y + shelf_h
    if total_h > max_size:
        raise ValueError(f"Sprites do not fit in {max_size}x{max_size} atlas (need height {total_h})")
    # Shrink to the tightest power-of-two extents (every placement still fits,
    # since wrapping only occurred at max_size and max_x bounds all sprites).
    return placements, next_pow2(max_x), next_pow2(total_h)


def main() -> int:
    parser = argparse.ArgumentParser(description="Pack PNG sprites into a texture atlas")
    parser.add_argument("--input", required=True, help="Directory of source PNGs")
    parser.add_argument("--output", required=True, help="Output path prefix (no extension)")
    parser.add_argument("--max-size", type=int, default=2048)
    parser.add_argument("--padding", type=int, default=2)
    args = parser.parse_args()

    src_dir = Path(args.input)
    pngs = sorted(src_dir.glob("*.png"))
    if not pngs:
        print(f"[atlas] no PNGs found in {src_dir}", file=sys.stderr)
        return 1

    images = [(p.stem, Image.open(p).convert("RGBA")) for p in pngs]
    placements, atlas_w, atlas_h = shelf_pack(images, args.max_size, args.padding)

    atlas = Image.new("RGBA", (atlas_w, atlas_h), (0, 0, 0, 0))
    sprites = {}
    for name, (x, y, img) in placements.items():
        atlas.paste(img, (x, y))
        sprites[name] = {
            "x": x, "y": y, "w": img.width, "h": img.height,
            "u0": round(x / atlas_w, 6), "v0": round(y / atlas_h, 6),
            "u1": round((x + img.width) / atlas_w, 6), "v1": round((y + img.height) / atlas_h, 6),
        }

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out.with_suffix(".png"))
    manifest = {"size": [atlas_w, atlas_h], "padding": args.padding, "sprites": sprites}
    out.with_suffix(".atlas.json").write_text(json.dumps(manifest, indent=2))
    print(f"[atlas] packed {len(sprites)} sprites -> {out}.png ({atlas_w}x{atlas_h})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
