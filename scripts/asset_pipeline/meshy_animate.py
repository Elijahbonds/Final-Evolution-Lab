#!/usr/bin/env python3
"""Meshy Rigging + Animation API client for the FEL motion pipeline.

Rigs a humanoid character (GLB) through Meshy, then applies preset
animation actions from the Meshy animation library. Outputs land in
assets/motion/external/meshy/ as GLB + USDZ (Meshy emits USDZ natively).

Reads MESHY_API_KEY from scripts/asset_pipeline/.env (gitignored).

Usage:
  python3 meshy_animate.py rig --model character.glb [--height 1.85]
  python3 meshy_animate.py animate --rig-task-id <id> --actions 195 207 215
  python3 meshy_animate.py status --task-id <id> [--kind rigging|animations]

Credits are consumed per task (rigging: 5). Failed tasks refund.
"""

import argparse
import base64
import json
import sys
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT_DIR = HERE.parent.parent / "assets" / "motion" / "external" / "meshy"
BASE = "https://api.meshy.ai/openapi/v1"


def api_key():
    env = HERE / ".env"
    for line in env.read_text().splitlines():
        if line.startswith("MESHY_API_KEY="):
            key = line.split("=", 1)[1].strip()
            if key:
                return key
    raise SystemExit("MESHY_API_KEY missing from scripts/asset_pipeline/.env")


def request(method, path, body=None):
    req = urllib.request.Request(
        f"{BASE}{path}",
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={
            "Authorization": f"Bearer {api_key()}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as err:
        detail = err.read().decode()[:500]
        raise SystemExit(f"Meshy API {err.code} on {method} {path}: {detail}")


def poll(kind, task_id, interval=10, timeout=1800):
    started = time.time()
    while time.time() - started < timeout:
        task = request("GET", f"/{kind}/{task_id}")
        status = task.get("status")
        progress = task.get("progress", "?")
        print(f"[meshy] {kind}/{task_id}: {status} ({progress}%)", flush=True)
        if status in ("SUCCEEDED", "FAILED", "CANCELED"):
            return task
        time.sleep(interval)
    raise SystemExit(f"timed out waiting for {kind}/{task_id}")


def download(url, dest: Path):
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url)
    with urllib.request.urlopen(req, timeout=300) as resp:
        dest.write_bytes(resp.read())
    print(f"[meshy] saved {dest} ({dest.stat().st_size / 1e6:.1f} MB)", flush=True)


def save_result_urls(task, prefix):
    saved = []
    result = task.get("result", task)
    def walk(obj, label=""):
        if isinstance(obj, dict):
            for key, value in obj.items():
                walk(value, f"{label}_{key}" if label else key)
        elif isinstance(obj, str) and obj.startswith("http"):
            ext = obj.split("?")[0].rsplit(".", 1)[-1].lower()
            if ext in ("glb", "fbx", "usdz"):
                dest = OUT_DIR / f"{prefix}_{label}.{ext}"
                download(obj, dest)
                saved.append(str(dest))
    walk(result)
    return saved


def cmd_rig(args):
    model_path = Path(args.model).expanduser()
    data = base64.b64encode(model_path.read_bytes()).decode()
    print(f"[meshy] uploading {model_path.name} ({model_path.stat().st_size / 1e6:.1f} MB) as data URI", flush=True)
    created = request("POST", "/rigging", {
        "model_url": f"data:model/gltf-binary;base64,{data}",
        "height_meters": args.height,
    })
    task_id = created.get("result") or created.get("id")
    print(f"[meshy] rigging task: {task_id}", flush=True)
    task = poll("rigging", task_id)
    if task.get("status") != "SUCCEEDED":
        raise SystemExit(f"rigging failed: {json.dumps(task)[:400]}")
    saved = save_result_urls(task, f"rig_{model_path.stem[:24]}")
    print(f"[meshy] RIG_TASK_ID={task_id} files={len(saved)} credits={task.get('consumed_credits')}", flush=True)


def cmd_animate(args):
    for action_id in args.actions:
        created = request("POST", "/animations", {
            "rig_task_id": args.rig_task_id,
            "action_id": int(action_id),
        })
        task_id = created.get("result") or created.get("id")
        print(f"[meshy] animation task {task_id} (action {action_id})", flush=True)
        task = poll("animations", task_id)
        if task.get("status") != "SUCCEEDED":
            print(f"[meshy] action {action_id} FAILED: {json.dumps(task)[:300]}", flush=True)
            continue
        saved = save_result_urls(task, f"anim_{action_id}")
        print(f"[meshy] action {action_id}: {len(saved)} files, credits={task.get('consumed_credits')}", flush=True)


def cmd_status(args):
    task = request("GET", f"/{args.kind}/{args.task_id}")
    print(json.dumps(task, indent=2)[:2000])


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="cmd", required=True)
    rig = sub.add_parser("rig")
    rig.add_argument("--model", required=True)
    rig.add_argument("--height", type=float, default=1.85)
    anim = sub.add_parser("animate")
    anim.add_argument("--rig-task-id", required=True)
    anim.add_argument("--actions", nargs="+", required=True)
    status = sub.add_parser("status")
    status.add_argument("--task-id", required=True)
    status.add_argument("--kind", default="animations")
    args = parser.parse_args()
    {"rig": cmd_rig, "animate": cmd_animate, "status": cmd_status}[args.cmd](args)


if __name__ == "__main__":
    main()
