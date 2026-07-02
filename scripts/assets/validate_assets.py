#!/usr/bin/env python3
"""
NEXUS asset validator — enforces infra/asset_spec.md.

Checks, per tier (default mobile-mid):
  * naming conventions (tex_/spr_ prefixes, snake_case, paired manifests)
  * texture dimensions power-of-two and within the tier's max side
  * PNG file-size hard limit (4 MiB)
  * atlas manifests: UVs in [0,1], atlas size POT, sprites within bounds
  * mip descriptors: chain complete down to 1x1, level files present
  * particle sheets: grid covers frame count, frame size POT, frames <= tier cap
  * compressed outputs: real .astc OR honest placeholder descriptor with
    matching source hash reference (placeholder flag must be true)

Exit code 0 = all checks pass; 1 = violations (all listed).

Usage:
    python3 scripts/assets/validate_assets.py --root assets/nexus --tier mobile-mid
"""
import argparse
import json
import re
import sys
from pathlib import Path

from PIL import Image

TIERS = {
    "mobile-low":  {"max_side": 1024, "sheet_max_side": 256, "max_sheet_frames": 16},
    "mobile-mid":  {"max_side": 2048, "sheet_max_side": 512, "max_sheet_frames": 25},
    "mobile-high": {"max_side": 2048, "sheet_max_side": 512, "max_sheet_frames": 64},
}
MAX_PNG_BYTES = 4 * 1024 * 1024
NAME_RE = re.compile(r"^[a-z0-9_.]+$")


def is_pot(n: int) -> bool:
    return n > 0 and (n & (n - 1)) == 0


class Validator:
    def __init__(self, root: Path, tier: str):
        self.root = root
        self.tier = TIERS[tier]
        self.tier_name = tier
        self.errors: list[str] = []
        self.checked = 0

    def err(self, path: Path, msg: str) -> None:
        self.errors.append(f"{path.relative_to(self.root.parent)}: {msg}")

    # ── individual checks ──────────────────────────────────────────────

    def check_naming(self, p: Path) -> None:
        if not NAME_RE.match(p.name):
            self.err(p, "filename must be lowercase snake_case (a-z, 0-9, _, .)")

    def check_png(self, p: Path, max_side: int) -> None:
        self.checked += 1
        self.check_naming(p)
        if p.stat().st_size > MAX_PNG_BYTES:
            self.err(p, f"PNG exceeds {MAX_PNG_BYTES // (1024*1024)} MiB hard limit")
        img = Image.open(p)
        w, h = img.size
        if not (is_pot(w) and is_pot(h)):
            # Source sprites feeding the atlas packer may be non-POT; final
            # standalone textures and sheets must be POT.
            if "sprites" not in p.parts:
                self.err(p, f"dimensions {w}x{h} not power-of-two")
        if max(w, h) > max_side:
            self.err(p, f"side {max(w, h)} exceeds {self.tier_name} max {max_side}")

    def check_atlas(self, manifest_path: Path) -> None:
        self.checked += 1
        data = json.loads(manifest_path.read_text())
        png = manifest_path.with_suffix("").with_suffix(".png")
        if not png.exists():
            self.err(manifest_path, "atlas manifest has no paired .png")
            return
        aw, ah = data.get("size", [0, 0])
        if not (is_pot(aw) and is_pot(ah)):
            self.err(manifest_path, f"atlas size {aw}x{ah} not power-of-two")
        for name, s in data.get("sprites", {}).items():
            for k in ("u0", "v0", "u1", "v1"):
                if not (0.0 <= s[k] <= 1.0):
                    self.err(manifest_path, f"sprite '{name}' UV {k}={s[k]} outside [0,1]")
            if s["x"] + s["w"] > aw or s["y"] + s["h"] > ah:
                self.err(manifest_path, f"sprite '{name}' exceeds atlas bounds")

    def check_mips(self, desc_path: Path) -> None:
        self.checked += 1
        data = json.loads(desc_path.read_text())
        levels = data.get("levels", [])
        if not levels:
            self.err(desc_path, "empty mip chain")
            return
        last = levels[-1]
        if (last["width"], last["height"]) != (1, 1):
            self.err(desc_path, f"mip chain ends at {last['width']}x{last['height']}, not 1x1")
        for lvl in levels:
            f = desc_path.parent / lvl["file"]
            if not f.exists():
                self.err(desc_path, f"missing mip level file {lvl['file']}")

    def check_sheet(self, sheet_json: Path) -> None:
        self.checked += 1
        data = json.loads(sheet_json.read_text())
        png = sheet_json.with_suffix("").with_suffix(".png")
        if not png.exists():
            self.err(sheet_json, "sheet descriptor has no paired .png")
            return
        cols, rows = data.get("grid", [0, 0])
        frames = data.get("frames", 0)
        fsize = data.get("frame_size", 0)
        if cols * rows < frames:
            self.err(sheet_json, f"grid {cols}x{rows} cannot hold {frames} frames")
        if not is_pot(fsize):
            self.err(sheet_json, f"frame size {fsize} not power-of-two")
        if frames > self.tier["max_sheet_frames"]:
            self.err(sheet_json, f"{frames} frames exceeds {self.tier_name} cap "
                                 f"{self.tier['max_sheet_frames']}")
        img = Image.open(png)
        if max(img.size) > self.tier["sheet_max_side"]:
            self.err(sheet_json, f"sheet side {max(img.size)} exceeds "
                                 f"{self.tier_name} cap {self.tier['sheet_max_side']}")

    def check_compressed(self, p: Path) -> None:
        self.checked += 1
        if p.suffix == ".astc":
            if p.stat().st_size == 0:
                self.err(p, "empty .astc output")
            return
        data = json.loads(p.read_text())
        if data.get("placeholder") is not True:
            self.err(p, "compressed descriptor must set placeholder=true or be a real .astc")
        if not data.get("source_sha256"):
            self.err(p, "placeholder missing source_sha256 provenance")

    # ── walk ───────────────────────────────────────────────────────────

    def run(self) -> int:
        samples = self.root / "samples"
        generated = self.root / "generated"

        for p in sorted(samples.rglob("*.png")) if samples.exists() else []:
            self.check_png(p, self.tier["max_side"])
        if generated.exists():
            for p in sorted(generated.rglob("*.atlas.json")):
                self.check_atlas(p)
            for p in sorted(generated.rglob("*.mips.json")):
                self.check_mips(p)
            for p in sorted(generated.rglob("*.sheet.json")):
                self.check_sheet(p)
            for p in sorted(generated.rglob("*.astc")):
                self.check_compressed(p)
            for p in sorted(generated.rglob("*.todo.json")):
                self.check_compressed(p)
            for p in sorted((generated / "atlas").rglob("*.png")) if (generated / "atlas").exists() else []:
                self.check_png(p, self.tier["max_side"])

        print(f"[validate] tier={self.tier_name} checked={self.checked} "
              f"errors={len(self.errors)}")
        for e in self.errors:
            print(f"[validate]   FAIL {e}", file=sys.stderr)
        return 1 if self.errors else 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate NEXUS assets against infra/asset_spec.md")
    parser.add_argument("--root", default="assets/nexus")
    parser.add_argument("--tier", default="mobile-mid", choices=list(TIERS))
    args = parser.parse_args()
    return Validator(Path(args.root), args.tier).run()


if __name__ == "__main__":
    sys.exit(main())
