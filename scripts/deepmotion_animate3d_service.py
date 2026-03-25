#!/usr/bin/env python3
"""
Background-friendly job runner: poll a JSON queue file and run single / multiperson jobs.

No credentials in repo — set DEEPMOTION_CLIENT_ID / DEEPMOTION_CLIENT_SECRET in the environment.

Example queue file (array of jobs):
[
  {"type": "single", "video": "/path/in.mp4", "out": "/path/out", "model_id": ""},
  {"type": "multiperson", "video": "/path/g.mp4", "out": "/path/out2", "models": "id1,id2"}
]

Run:
  python scripts/deepmotion_animate3d_service.py --queue /tmp/fel_dm_jobs.json --poll 5

When the queue is empty, the process sleeps. Another process can append jobs to the file.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def run_pipeline(args: list[str]) -> int:
    cmd = [sys.executable, str(ROOT / "scripts" / "deepmotion_animate3d_pipeline.py"), *args]
    env = os.environ.copy()
    return subprocess.call(cmd, cwd=str(ROOT), env=env)


def process_one(job: dict) -> None:
    jt = job.get("type", "single")
    video = job.get("video")
    out = job.get("out")
    if not video or not out:
        print("skip job (missing video/out)", job, file=sys.stderr)
        return
    if jt == "single":
        extra = []
        if job.get("model_id"):
            extra.extend(["--model-id", str(job["model_id"])])
        if job.get("formats"):
            extra.extend(["--formats", str(job["formats"])])
        run_pipeline(["single", "--video", str(video), "--out", str(out), *extra])
    elif jt == "multiperson":
        extra = []
        if job.get("models"):
            extra.extend(["--models", str(job["models"])])
        if job.get("formats"):
            extra.extend(["--formats", str(job["formats"])])
        run_pipeline(["multiperson", "--video", str(video), "--out", str(out), *extra])
    else:
        print("unknown job type", jt, file=sys.stderr)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--queue", required=True, type=Path, help="JSON file: list of job objects")
    ap.add_argument("--poll", type=float, default=4.0, help="Seconds between queue checks")
    args = ap.parse_args()

    if not os.environ.get("DEEPMOTION_CLIENT_ID") or not os.environ.get("DEEPMOTION_CLIENT_SECRET"):
        print("Set DEEPMOTION_CLIENT_ID and DEEPMOTION_CLIENT_SECRET", file=sys.stderr)
        sys.exit(2)

    while True:
        if not args.queue.is_file():
            time.sleep(args.poll)
            continue
        try:
            raw = args.queue.read_text(encoding="utf-8")
            jobs = json.loads(raw) if raw.strip() else []
        except json.JSONDecodeError:
            time.sleep(args.poll)
            continue
        if not jobs:
            time.sleep(args.poll)
            continue
        job = jobs[0]
        rest = jobs[1:]
        try:
            process_one(job)
        finally:
            args.queue.write_text(json.dumps(rest, indent=2), encoding="utf-8")
        time.sleep(0.5)


if __name__ == "__main__":
    main()
