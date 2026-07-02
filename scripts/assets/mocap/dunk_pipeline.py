#!/usr/bin/env python3
"""Automated dunk-animation pipeline: AI video → mocap → game assets.

Stages (each pluggable; the pipeline runs with whatever is available):

  1. VIDEO   AI generation via Runway (RUNWAY_API_KEY) — or drop your own
             clips (AI-generated elsewhere, or filmed dunks) into
             work/videos/<style>_<n>.mp4 and the stage is skipped.
  2. MOCAP   local MediaPipe (default, no account) via
             video_to_nexus_animation.py — or DeepMotion
             (DEEPMOTION_CLIENT_ID/SECRET) producing BVH, converted by
             bvh_to_nexus_animation.py.
  3. BLEND   state transitions via blend_transitions.py.
  4. INSTALL copy .nexusanim.json into assets/nexus/animations/ (bundled
             by the Xcode phase, loaded by NexusAnimationLibrary,
             validated by AnimationLibraryTests).

Usage:
  python3 dunk_pipeline.py --repo ../../.. --work ./work [--styles tomahawk reverse]
"""
import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

STYLES = {
    # style id → video-generation prompt (used when a video API key is set)
    "tomahawk": "athlete performs a tomahawk dunk on an outdoor Venice Beach basketball court, single person, full body always in frame, side view, consistent lighting, 4 seconds",
    "reverse": "athlete performs a reverse dunk, single person, full body in frame, side view, outdoor court, 4 seconds",
    "windmill": "athlete performs a windmill dunk, single person, full body in frame, side view, outdoor court, 4 seconds",
    "alley_oop": "athlete catches an alley-oop pass and dunks, single person, full body in frame, side view, 4 seconds",
    "euro_step": "athlete performs a euro step layup drive, single person, full body in frame, side view, 4 seconds",
    "failed_rim": "athlete attempts a dunk and misses off the rim, stumbles on landing and recovers, single person, full body in frame, 4 seconds",
}

HERE = Path(__file__).parent


def sh(*cmd):
    print("  $", " ".join(str(c) for c in cmd))
    return subprocess.run([str(c) for c in cmd], capture_output=True, text=True)


def stage_video(work: Path, styles, variations):
    videos = work / "videos"
    videos.mkdir(parents=True, exist_ok=True)
    wanted = [(s, n) for s in styles for n in range(1, variations + 1)]
    missing = [(s, n) for s, n in wanted
               if not (videos / f"{s}_{n}.mp4").exists()]
    if not missing:
        print(f"[video] all {len(wanted)} clips present")
        return
    if os.environ.get("RUNWAY_API_KEY"):
        # Runway gen-3 text-to-video; polling kept minimal on purpose —
        # curate outputs before mocap, AI video physics can be off.
        import time
        import urllib.request
        for style, n in missing:
            body = json.dumps({
                "model": "gen3a_turbo",
                "promptText": STYLES[style],
                "duration": 5, "ratio": "768:1280",
            }).encode()
            req = urllib.request.Request(
                "https://api.runwayml.com/v1/text_to_video", data=body,
                headers={"Authorization": f"Bearer {os.environ['RUNWAY_API_KEY']}",
                         "Content-Type": "application/json",
                         "X-Runway-Version": "2024-11-06"})
            task = json.load(urllib.request.urlopen(req))
            print(f"[video] runway task {task.get('id')} for {style}_{n} — poll+download")
            # Poll task, then download task['output'][0] to videos/<style>_<n>.mp4
            # (left as the documented step: outputs should be human-curated anyway)
    else:
        print(f"[video] {len(missing)} clips missing and RUNWAY_API_KEY unset.")
        print("        Drop MP4s at work/videos/<style>_<n>.mp4 — AI-generated")
        print("        (Runway/Pika/Veo) or filmed dunks both work:")
        for s, n in missing[:8]:
            print(f"          videos/{s}_{n}.mp4   prompt: {STYLES[s][:60]}…")


def stage_mocap(work: Path, out: Path):
    videos = sorted((work / "videos").glob("*.mp4"))
    out.mkdir(parents=True, exist_ok=True)
    if not videos:
        print("[mocap] no videos to process (stage 1 outputs land in work/videos)")
        return 0
    done = 0
    for v in videos:
        aid = f"mocap_{v.stem}"
        target = out / f"{aid}.nexusanim.json"
        if target.exists():
            done += 1
            continue
        if os.environ.get("DEEPMOTION_CLIENT_ID"):
            print(f"[mocap] DeepMotion path for {v.name}: upload → poll → BVH →")
            print(f"        python3 {HERE}/bvh_to_nexus_animation.py <out.bvh> {target} --id {aid}")
            continue
        r = sh(sys.executable, HERE / "video_to_nexus_animation.py", v, target,
               "--id", aid, "--title", v.stem.replace("_", " ").title(),
               "--category", "dunk", "--creator", "dunk_pipeline")
        print("   ", (r.stdout or r.stderr).strip().splitlines()[-1])
        if target.exists():
            done += 1
    return done


def stage_blend(library: Path):
    r = sh(sys.executable, HERE / "blend_transitions.py", library)
    for line in r.stdout.strip().splitlines():
        print("   ", line)


def stage_install(out: Path, repo: Path):
    lib = repo / "assets/nexus/animations"
    lib.mkdir(parents=True, exist_ok=True)
    n = 0
    for f in out.glob("*.nexusanim.json"):
        shutil.copy2(f, lib / f.name)
        n += 1
    print(f"[install] {n} assets → {lib}")
    print("[install] verify: xcodebuild test -only-testing:FinalEvolutionLabTests/AnimationLibraryTests")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo", default=str(HERE / "../../.."))
    ap.add_argument("--work", default=str(HERE / "work"))
    ap.add_argument("--styles", nargs="*", default=list(STYLES))
    ap.add_argument("--variations", type=int, default=3)
    args = ap.parse_args()
    repo, work = Path(args.repo).resolve(), Path(args.work).resolve()
    out = work / "assets"

    print("== dunk pipeline ==")
    stage_video(work, args.styles, args.variations)
    made = stage_mocap(work, out)
    print(f"[mocap] {made} assets ready")
    if made:
        stage_blend(out)
        stage_install(out, repo)
    else:
        print("[done] nothing to install yet — add videos or API keys and rerun.")


if __name__ == "__main__":
    main()
