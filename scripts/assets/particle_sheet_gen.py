#!/usr/bin/env python3
"""
GPU-particle sprite sheet generator.

Procedurally renders flipbook sprite sheets for the NEXUS GPU particle path
(soft radial puffs, sparks, and ring shockwaves) so VFX work never depends on
external art drops. Each sheet is a grid of frames animated by the particle
shader via frame index.

Usage:
    python3 scripts/assets/particle_sheet_gen.py \
        --output assets/nexus/generated/particles \
        [--frames 16] [--frame-size 64]

Outputs per template:
    <output>/<name>_sheet.png        — frames laid out in a square-ish grid
    <output>/<name>_sheet.sheet.json — frame count/size/grid + per-frame UVs
"""
import argparse
import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw


def render_puff(size: int, t: float) -> Image.Image:
    """Soft radial smoke puff: expands and fades over t in [0,1]."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx = cy = size / 2
    radius = (0.15 + 0.75 * t) * size / 2
    alpha_peak = int(255 * (1.0 - t) ** 1.5)
    px = img.load()
    for yy in range(size):
        for xx in range(size):
            d = math.hypot(xx - cx, yy - cy) / max(radius, 1e-5)
            if d < 1.0:
                a = int(alpha_peak * (1.0 - d) ** 2)
                px[xx, yy] = (235, 235, 245, a)
    return img


def render_spark(size: int, t: float) -> Image.Image:
    """Star spark: bright cross flare that shrinks and fades."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = cy = size / 2
    length = (1.0 - 0.8 * t) * size / 2
    alpha = int(255 * (1.0 - t))
    for angle in (0, 45, 90, 135):
        rad = math.radians(angle)
        dx, dy = math.cos(rad) * length, math.sin(rad) * length
        w = max(1, int(size * 0.04 * (1.0 - t)))
        draw.line([(cx - dx, cy - dy), (cx + dx, cy + dy)],
                  fill=(255, 230, 160, alpha), width=w)
    core = max(2, int(size * 0.08 * (1.0 - t)))
    draw.ellipse([cx - core, cy - core, cx + core, cy + core],
                 fill=(255, 255, 255, alpha))
    return img


def render_ring(size: int, t: float) -> Image.Image:
    """Shockwave ring: expands outward with thinning edge."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    cx = cy = size / 2
    radius = (0.1 + 0.85 * t) * size / 2
    alpha = int(220 * (1.0 - t))
    width = max(1, int(size * 0.08 * (1.0 - t) + 1))
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                 outline=(140, 200, 255, alpha), width=width)
    return img


TEMPLATES = {"puff": render_puff, "spark": render_spark, "ring": render_ring}


def build_sheet(name: str, renderer, frames: int, frame_size: int, out_dir: Path) -> None:
    cols = math.ceil(math.sqrt(frames))
    rows = math.ceil(frames / cols)
    sheet = Image.new("RGBA", (cols * frame_size, rows * frame_size), (0, 0, 0, 0))
    uvs = []
    for i in range(frames):
        t = i / max(frames - 1, 1)
        frame = renderer(frame_size, t)
        x, y = (i % cols) * frame_size, (i // cols) * frame_size
        sheet.paste(frame, (x, y))
        uvs.append({
            "frame": i,
            "u0": round(x / sheet.width, 6), "v0": round(y / sheet.height, 6),
            "u1": round((x + frame_size) / sheet.width, 6),
            "v1": round((y + frame_size) / sheet.height, 6),
        })
    base = out_dir / f"{name}_sheet"
    sheet.save(base.with_suffix(".png"))
    base.with_suffix(".sheet.json").write_text(json.dumps({
        "name": name, "frames": frames, "frame_size": frame_size,
        "grid": [cols, rows], "size": [sheet.width, sheet.height], "uv": uvs,
    }, indent=2))
    print(f"[particles] {name}: {frames} frames @ {frame_size}px -> {base}.png")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate GPU particle sprite sheets")
    parser.add_argument("--output", required=True)
    parser.add_argument("--frames", type=int, default=16)
    parser.add_argument("--frame-size", type=int, default=64)
    parser.add_argument("--templates", nargs="*", default=list(TEMPLATES))
    args = parser.parse_args()

    out_dir = Path(args.output)
    out_dir.mkdir(parents=True, exist_ok=True)
    for name in args.templates:
        if name not in TEMPLATES:
            print(f"[particles] unknown template '{name}' (have: {list(TEMPLATES)})", file=sys.stderr)
            return 1
        build_sheet(name, TEMPLATES[name], args.frames, args.frame_size, out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
