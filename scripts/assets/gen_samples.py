#!/usr/bin/env python3
"""
Generate the deterministic sample assets used to exercise the asset pipeline
(atlas_gen, mipmap_gen, compress_textures, particle_sheet_gen) and the
validator. Pure-procedural so nothing binary needs an external art drop.

Usage:
    python3 scripts/assets/gen_samples.py --output assets/nexus/samples
"""
import argparse
import math
from pathlib import Path

from PIL import Image, ImageDraw


def sprite_ball(size: int = 48) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([2, 2, size - 2, size - 2], fill=(214, 120, 51, 255), outline=(60, 30, 10, 255), width=2)
    d.line([(size // 2, 2), (size // 2, size - 2)], fill=(60, 30, 10, 255), width=2)
    d.arc([-size // 2, 2, size // 2, size - 2], 270, 90, fill=(60, 30, 10, 255), width=2)
    d.arc([size // 2, 2, size + size // 2, size - 2], 90, 270, fill=(60, 30, 10, 255), width=2)
    return img


def sprite_star(size: int = 40) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = size / 2
    pts = []
    for i in range(10):
        r = size / 2 - 2 if i % 2 == 0 else size / 5
        a = math.pi / 2 + i * math.pi / 5
        pts.append((cx + r * math.cos(a), cy - r * math.sin(a)))
    d.polygon(pts, fill=(255, 214, 64, 255), outline=(160, 120, 10, 255))
    return img


def sprite_bolt(size: int = 56) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = size / 56.0
    pts = [(30, 4), (14, 32), (24, 32), (18, 52), (42, 24), (30, 24), (38, 4)]
    d.polygon([(x * s, y * s) for x, y in pts], fill=(120, 200, 255, 255), outline=(30, 80, 140, 255))
    return img


def texture_checker(size: int = 128, cells: int = 8) -> Image.Image:
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    step = size // cells
    for gy in range(cells):
        for gx in range(cells):
            c = (52, 52, 64, 255) if (gx + gy) % 2 == 0 else (200, 200, 214, 255)
            d.rectangle([gx * step, gy * step, (gx + 1) * step - 1, (gy + 1) * step - 1], fill=c)
    return img


def texture_court(size: int = 128) -> Image.Image:
    """Hardwood-ish stripes with a center line — stand-in court texture."""
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    for i in range(0, size, 16):
        tone = 168 + (i // 16 % 3) * 12
        d.rectangle([i, 0, i + 15, size], fill=(tone, int(tone * 0.62), int(tone * 0.35), 255))
    d.line([(0, size // 2), (size, size // 2)], fill=(240, 240, 240, 255), width=3)
    d.ellipse([size // 2 - 18, size // 2 - 18, size // 2 + 18, size // 2 + 18],
              outline=(240, 240, 240, 255), width=3)
    return img


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate deterministic sample assets")
    parser.add_argument("--output", default="assets/nexus/samples")
    args = parser.parse_args()

    root = Path(args.output)
    sprites = root / "sprites"
    textures = root / "textures"
    sprites.mkdir(parents=True, exist_ok=True)
    textures.mkdir(parents=True, exist_ok=True)

    sprite_ball().save(sprites / "spr_fx_ball.png")
    sprite_star().save(sprites / "spr_fx_star.png")
    sprite_bolt().save(sprites / "spr_fx_bolt.png")
    texture_checker().save(textures / "tex_env_checker_d.png")
    texture_court().save(textures / "tex_env_court_d.png")
    print(f"[samples] wrote 3 sprites + 2 textures under {root}")
    return 0


if __name__ == "__main__":
    main()
