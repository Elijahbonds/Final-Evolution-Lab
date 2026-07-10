#!/usr/bin/env python3
"""
convert_fbx_to_gltf.py — Dance Mode mocap import helper (MANUAL steps only).

Most dance mocap ships as FBX (Mixamo, many capture services). The Dance Mode
timeline consumes glTF. This script does NOT bundle or automate a converter and
it NEVER logs into or scripts any external service — conversion tools require a
manual install and (for some sources) a manual, human-driven download. This
helper only:

  1. prints the exact manual steps for the recommended converters, and
  2. if a converter is already installed locally, offers to *open* it / run it
     on a file you already have on disk (open-tools-only; no login automation).

Usage:
  python3 scripts/convert_fbx_to_gltf.py --steps
  python3 scripts/convert_fbx_to_gltf.py --check
  python3 scripts/convert_fbx_to_gltf.py path/to/clip.fbx   # runs FBX2glTF IF installed
"""
import argparse
import shutil
import subprocess
import sys

STEPS = """\
Dance Mode — manual FBX -> glTF conversion
==========================================

Option A — FBX2glTF (Facebook/Khronos CLI, recommended for batch):
  1. Download the release binary for your OS from the FBX2glTF GitHub releases
     page and place it on your PATH as `FBX2glTF` (this is a one-time MANUAL
     download — this script will not fetch it for you).
  2. Convert:  FBX2glTF -i clip.fbx -o clip.gltf --khr-materials-unlit
  3. Move the result into assets/dance/samples/ (or your clip library).

Option B — Blender (GUI, best when you also need to inspect/retarget):
  1. Install Blender (manual).
  2. File > Import > FBX, then File > Export > glTF 2.0 (.gltf/.glb).
  3. Keep "Include > Animation" checked.

After conversion, build the retarget map to humanoid_v1:
  python3 scripts/dance_animation_map.py scaffold clip.gltf --source-rig mixamo \\
      -o clip.animation_map.json
  # edit the null bone entries, then:
  python3 scripts/dance_animation_map.py validate clip.animation_map.json

Mixamo clips: see assets/external/mixamo/README.md — Mixamo is MANUAL download
only (log in yourself in a browser). This tool never automates that login.
"""


def check() -> int:
    found = shutil.which("FBX2glTF") or shutil.which("fbx2gltf")
    blender = shutil.which("blender")
    print("FBX2glTF on PATH:", found or "not found")
    print("Blender on PATH: ", blender or "not found")
    if not found and not blender:
        print("\nNeither converter is installed. Run with --steps for manual install steps.")
        return 1
    return 0


def convert(fbx_path: str) -> int:
    exe = shutil.which("FBX2glTF") or shutil.which("fbx2gltf")
    if not exe:
        print("FBX2glTF is not installed — nothing to run. Manual steps:\n")
        print(STEPS)
        return 1
    out = fbx_path.rsplit(".", 1)[0] + ".gltf"
    print(f"Running locally-installed converter on {fbx_path} -> {out}")
    # Open/run a tool the user already installed; no network, no login.
    return subprocess.call([exe, "-i", fbx_path, "-o", out, "--khr-materials-unlit"])


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("fbx", nargs="?", help="FBX file to convert IF a converter is installed")
    p.add_argument("--steps", action="store_true", help="print manual install + convert steps")
    p.add_argument("--check", action="store_true", help="check for a locally installed converter")
    args = p.parse_args()

    if args.steps or (not args.fbx and not args.check):
        print(STEPS)
        return 0
    if args.check:
        return check()
    return convert(args.fbx)


if __name__ == "__main__":
    sys.exit(main())
