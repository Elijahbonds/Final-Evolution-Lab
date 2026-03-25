#!/usr/bin/env python3
"""
DeepMotion Animate 3D — video → FBX/BVH/GLB via official Python SDK.

Authentication (same as REST): HTTP Basic with Base64(clientId:clientSecret).
The SDK accepts client_id + client_secret; it performs token / requests for you.

Setup:
  pip install -r scripts/requirements-animate3d.txt
  export DEEPMOTION_CLIENT_ID=... DEEPMOTION_CLIENT_SECRET=...
  # or: set -a; source .env  (if you use python-dotenv, add it yourself)

Examples:
  python scripts/deepmotion_animate3d_pipeline.py balance
  python scripts/deepmotion_animate3d_pipeline.py single --video ./clip.mp4 --out ./out_fel
  python scripts/deepmotion_animate3d_pipeline.py multiperson --video ./clip.mp4 --out ./out_mp

Multi-person (experimental API): detection job first, then processing with per-person models.
See SDK examples: sync_multiperson_usage.py in the dm-animate3d-api repo.
"""
from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

# Local FEL helpers (smooth + physics + root-at-origin for retarget)
from deepmotion_process_params import build_fel_process_params


def _load_credentials() -> tuple[str, str, str]:
    cid = os.environ.get("DEEPMOTION_CLIENT_ID", "").strip()
    secret = os.environ.get("DEEPMOTION_CLIENT_SECRET", "").strip()
    base = os.environ.get("DEEPMOTION_API_SERVER_URL", "https://service.deepmotion.com").strip()
    if not cid or not secret:
        print(
            "Missing DEEPMOTION_CLIENT_ID or DEEPMOTION_CLIENT_SECRET.\n"
            "Set them in the environment (see scripts/deepmotion_animate3d.env.example).",
            file=sys.stderr,
        )
        sys.exit(2)
    return cid, secret, base


def _client():
    from dm.animate3d import Animate3DClient

    cid, secret, base = _load_credentials()
    return Animate3DClient(api_server_url=base, client_id=cid, client_secret=secret)


def cmd_balance() -> None:
    client = _client()
    bal = client.get_credit_balance()
    print(f"Credit balance: {bal}")


def cmd_single(args: argparse.Namespace) -> None:
    from dm.animate3d import Animate3DClient

    video = Path(args.video).resolve()
    if not video.is_file():
        print(f"Video not found: {video}", file=sys.stderr)
        sys.exit(1)
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    cid, secret, base = _load_credentials()
    client = Animate3DClient(api_server_url=base, client_id=cid, client_secret=secret)

    models = client.list_character_models()
    model_id = args.model_id or (models[0].id if models else None)
    if not model_id:
        print("No character models returned; set --model-id or upload a model in DeepMotion.", file=sys.stderr)
        sys.exit(1)

    formats = [x.strip() for x in args.formats.split(",") if x.strip()]
    params = build_fel_process_params(
        formats=formats,
        model_id=model_id,
        track_face=args.track_face,
        track_hand=args.track_hand,
    )

    def on_progress(data):
        if getattr(data, "position_in_queue", None):
            print(f"Queue position: {data.position_in_queue}")
        else:
            print(f"Progress: {getattr(data, 'progress_percent', '?')}%")

    def on_result(data):
        if data.result:
            print("Job completed.")
            client.download_job(data.rid, output_dir=str(out))
            print(f"Downloaded to {out}")
        elif data.error:
            print(f"Job failed: {data.error.message} ({data.error.code})", file=sys.stderr)

    print(f"Starting single-person job: {video} → model={model_id}")
    rid = client.start_new_job(
        str(video),
        params=params,
        result_callback=on_result,
        progress_callback=on_progress,
    )
    print(f"Done. RID: {rid}")


def cmd_multiperson(args: argparse.Namespace) -> None:
    """Run prepare_multi_person_job; then start_multi_person_job with --models (comma-separated model IDs)."""
    from dm.animate3d import Animate3DClient

    video = Path(args.video).resolve()
    if not video.is_file():
        print(f"Video not found: {video}", file=sys.stderr)
        sys.exit(1)
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    cid, secret, base = _load_credentials()
    client = Animate3DClient(api_server_url=base, client_id=cid, client_secret=secret)

    def on_progress(data):
        if getattr(data, "position_in_queue", None):
            print(f"Queue position: {data.position_in_queue}")
        else:
            print(f"Progress: {getattr(data, 'progress_percent', '?')}%")

    def on_result_detect(data):
        if data.result:
            print(f"Detection finished. RID: {data.rid}")
        elif data.error:
            print(f"Detection failed: {data.error.message} ({data.error.code})", file=sys.stderr)

    def on_result_process(data):
        if data.result:
            print("Processing completed.")
            client.download_job(data.rid, output_dir=str(out))
            print(f"Downloaded to {out}")
        elif data.error:
            print(f"Job failed: {data.error.message} ({data.error.code})", file=sys.stderr)

    print("Step 1: multi-person detection…")
    rid_detect = client.prepare_multi_person_job(
        str(video),
        result_callback=on_result_detect,
        progress_callback=on_progress,
    )
    print(f"Detection RID (return value): {rid_detect}")

    if not args.models:
        print(
            "\nRe-run with --models id1,id2,... (character model ID per detected person). "
            "See DeepMotion multi-person docs and SDK examples (sync_multiperson_usage.py).",
            file=sys.stderr,
        )
        sys.exit(0)

    model_ids = [m.strip() for m in args.models.split(",") if m.strip()]
    formats = [x.strip() for x in args.formats.split(",") if x.strip()]
    params = build_fel_process_params(
        formats=formats,
        model_id=None,
        track_face=args.track_face,
        track_hand=args.track_hand,
    )

    print("Step 2: multi-person animation…")
    rid_final = client.start_multi_person_job(
        rid_detect,
        models=model_ids,
        params=params,
        result_callback=on_result_process,
        progress_callback=on_progress,
    )
    print(f"Processing RID (return value): {rid_final}")


def main() -> None:
    p = argparse.ArgumentParser(description="DeepMotion Animate 3D pipeline (FBX/BVH export for FEL / Unreal).")
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("balance", help="Print API credit balance")

    s = sub.add_parser("single", help="Single-person video → mocap")
    s.add_argument("--video", required=True, help="Path to input video")
    s.add_argument("--out", required=True, help="Output directory for downloads")
    s.add_argument("--model-id", default="", help="Character model ID (default: first from API)")
    s.add_argument("--formats", default="fbx,bvh", help="Comma-separated: fbx,bvh,glb,mp4")
    s.add_argument("--track-face", type=int, default=1, choices=[0, 1])
    s.add_argument("--track-hand", type=int, default=1, choices=[0, 1])

    m = sub.add_parser("multiperson", help="Experimental multi-person pipeline")
    m.add_argument("--video", required=True)
    m.add_argument("--out", required=True)
    m.add_argument(
        "--models",
        default="",
        help="Comma-separated character model IDs (one per detected person, order matters)",
    )
    m.add_argument("--formats", default="fbx,bvh")
    m.add_argument("--track-face", type=int, default=1, choices=[0, 1])
    m.add_argument("--track-hand", type=int, default=1, choices=[0, 1])

    args = p.parse_args()
    if args.cmd == "balance":
        cmd_balance()
    elif args.cmd == "single":
        cmd_single(args)
    elif args.cmd == "multiperson":
        cmd_multiperson(args)


if __name__ == "__main__":
    main()
