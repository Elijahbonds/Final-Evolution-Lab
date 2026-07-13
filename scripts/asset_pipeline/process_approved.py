#!/usr/bin/env python3
"""Batch-process approved mocap crop proposals into engine-ready clips.

Reads assets/motion/proposals.json (crops approved 2026-07-06), drives
mocap_pipeline.py per crop through headless Blender, writes clips to the
output library, and maintains assets/motion/registry.json linking every
clip to its raw take, processing status, and consuming game mode.

Usage:
  python3 process_approved.py --target ElijahRig.glb --out-dir clips/
      [--takes NAME ...]        only these takes (substring match)
      [--types dunk_or_jump_reach kick ...]  only these move types
      [--limit N]               stop after N clips
      [--rim-auto]              pass --rim for rim_candidate crops
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path

BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
HERE = Path(__file__).resolve().parent
PIPELINE = HERE / "mocap_pipeline.py"
MOTION_DIR = HERE.parent.parent / "assets" / "motion"


def load_json(path, default):
    if Path(path).exists():
        return json.loads(Path(path).read_text())
    return default


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", required=True)
    parser.add_argument("--out-dir", required=True)
    parser.add_argument("--takes", nargs="*", default=None)
    parser.add_argument("--types", nargs="*", default=None)
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--rim-auto", action="store_true")
    parser.add_argument("--proposals", default=str(MOTION_DIR / "proposals.json"),
                        help="proposals JSON to process (e.g. proposals_cmu.json)")
    args = parser.parse_args()

    proposals = load_json(Path(args.proposals).expanduser(), [])
    registry_path = MOTION_DIR / "registry.json"
    registry = load_json(registry_path, {"clips": []})
    done_ids = {c["crop_id"] for c in registry["clips"] if c.get("status") == "processed"}

    out_dir = Path(args.out_dir).expanduser()
    out_dir.mkdir(parents=True, exist_ok=True)

    processed = 0
    for take in proposals:
        if args.takes and not any(t.lower() in take["take"].lower() for t in args.takes):
            continue
        for crop in take["proposals"]:
            if args.types and crop["type_guess"] not in args.types:
                continue
            if crop["crop_id"] in done_ids:
                continue
            if args.limit and processed >= args.limit:
                break

            out_file = out_dir / f"{crop['crop_id']}.usdz"
            cmd = [
                BLENDER, "--background", "--python", str(PIPELINE), "--",
                "process",
                "--input", take["path"],
                "--start", str(crop["start_frame"]),
                "--end", str(crop["end_frame"]),
                "--target", str(Path(args.target).expanduser()),
                "--out", str(out_file),
            ]
            if args.rim_auto and crop.get("rim_candidate"):
                cmd.append("--rim")

            print(f"[batch] {crop['crop_id']} ({crop['type_guess']}, "
                  f"{crop['start_frame']}-{crop['end_frame']})", flush=True)
            result = subprocess.run(cmd, capture_output=True, text=True)
            ok = out_file.exists() and "exported clip" in result.stdout
            registry["clips"] = [c for c in registry["clips"] if c["crop_id"] != crop["crop_id"]]
            registry["clips"].append({
                "crop_id": crop["crop_id"],
                "take": take["take"],
                "raw_path": take["path"],
                "type": crop["type_guess"],
                "rim_normalized": bool(args.rim_auto and crop.get("rim_candidate")),
                "clip_path": str(out_file),
                "status": "processed" if ok else "failed",
                "modes": (["basketball_dunk_3d"] if crop["type_guess"] == "dunk_or_jump_reach"
                          else ["karate_h2h", "karate_endless"] if crop["type_guess"] == "kick"
                          else []),
            })
            registry_path.write_text(json.dumps(registry, indent=2))
            print(f"[batch]   -> {'OK' if ok else 'FAILED'}", flush=True)
            processed += 1
        if args.limit and processed >= args.limit:
            break

    counts = {}
    for clip in registry["clips"]:
        counts[clip["status"]] = counts.get(clip["status"], 0) + 1
    print(f"[batch] done this run: {processed}; registry totals: {counts}", flush=True)


if __name__ == "__main__":
    main()
