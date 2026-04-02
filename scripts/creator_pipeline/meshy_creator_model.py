#!/usr/bin/env python3
"""
Meshy Creator Model Pipeline
=============================
Downloads and prepares 3D player models from Meshy AI for creator profiles.
Specifically designed for Final Evolution Lab creator card system.

Usage:
    python3 -m scripts.creator_pipeline.meshy_creator_model --creator amir_smith
    python3 -m scripts.creator_pipeline.meshy_creator_model --generate-new --prompt "Athletic basketball forward"
    python3 -m scripts.creator_pipeline.meshy_creator_model --list-tasks
"""

import os
import sys
import json
import time
import argparse
import urllib.request
import urllib.error
from pathlib import Path
from datetime import datetime

# Project root
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
GENERATED_ASSETS = PROJECT_ROOT / "GeneratedAssets" / "CreatorModels"
MANIFEST_PATH = GENERATED_ASSETS / "creator_models_manifest.json"


def get_meshy_api_key():
    """Load Meshy API key from .env or environment."""
    key = os.environ.get("MESHY_API_KEY", "")
    if not key:
        env_path = PROJECT_ROOT / ".env"
        if env_path.exists():
            for line in env_path.read_text().splitlines():
                if line.startswith("MESHY_API_KEY="):
                    key = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break
    return key


def meshy_api_request(endpoint, method="GET", data=None, api_key=None):
    """Make a request to the Meshy API."""
    base_url = "https://api.meshy.ai/v2"
    url = f"{base_url}/{endpoint}"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    req_data = json.dumps(data).encode() if data else None
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ""
        print(f"  [ERROR] Meshy API {e.code}: {body[:200]}")
        return None
    except Exception as e:
        print(f"  [ERROR] Meshy API request failed: {e}")
        return None


def download_file(url, dest_path):
    """Download a file from URL to local path."""
    dest_path = Path(dest_path)
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        urllib.request.urlretrieve(url, str(dest_path))
        size = dest_path.stat().st_size
        print(f"  Downloaded: {dest_path.name} ({size:,} bytes)")
        return True
    except Exception as e:
        print(f"  [ERROR] Download failed: {e}")
        return False


def load_manifest():
    """Load or create the creator models manifest."""
    if MANIFEST_PATH.exists():
        return json.loads(MANIFEST_PATH.read_text())
    return {"version": "1.0", "models": {}, "last_updated": ""}


def save_manifest(manifest):
    """Save the manifest."""
    manifest["last_updated"] = datetime.now().isoformat()
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2))


# =====================================================================
# Creator Model Definitions
# =====================================================================

CREATOR_MODEL_PROMPTS = {
    "amir_smith": {
        "prompt": (
            "Ultra-detailed 3D model of a tall athletic African American basketball player, "
            "6 foot 7 inches, forward build with defined muscles, wearing a basketball jersey "
            "number 23 with shorts and high-top sneakers. Athletic stance ready to play. "
            "Clean topology, game-ready mesh, PBR textures."
        ),
        "art_style": "realistic",
        "negative_prompt": "low quality, blurry, deformed, cartoon",
        "topology": "quad",
        "target_polycount": 30000,
    },
    "elijah_bonds": {
        "prompt": (
            "Ultra-detailed 3D model of an athletic African American basketball player, "
            "6 foot 2 inches, guard build, explosive and lean, wearing Venice Beach style "
            "basketball outfit with headband. Dynamic dunking pose. "
            "Clean topology, game-ready mesh, PBR textures."
        ),
        "art_style": "realistic",
        "negative_prompt": "low quality, blurry, deformed, cartoon",
        "topology": "quad",
        "target_polycount": 30000,
    },
    "eric_nash": {
        "prompt": (
            "Ultra-detailed 3D model of an athletic basketball coach, "
            "6 foot tall, fit build, wearing coaching attire with basketball shoes. "
            "Confident coaching stance with whistle. "
            "Clean topology, game-ready mesh, PBR textures."
        ),
        "art_style": "realistic",
        "negative_prompt": "low quality, blurry, deformed, cartoon",
        "topology": "quad",
        "target_polycount": 30000,
    },
}


def generate_creator_model(creator_id, api_key, dry_run=False):
    """Generate a 3D model for a creator using Meshy Text-to-3D."""
    if creator_id not in CREATOR_MODEL_PROMPTS:
        print(f"[ERROR] Unknown creator: {creator_id}")
        print(f"  Available: {', '.join(CREATOR_MODEL_PROMPTS.keys())}")
        return None

    config = CREATOR_MODEL_PROMPTS[creator_id]
    output_dir = GENERATED_ASSETS / creator_id
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest = load_manifest()

    # Check if already generated
    if creator_id in manifest.get("models", {}):
        existing = manifest["models"][creator_id]
        glb_path = output_dir / f"{creator_id}_model.glb"
        if glb_path.exists():
            print(f"[SKIP] Model already exists for {creator_id}")
            print(f"  GLB: {glb_path}")
            return existing

    print(f"\n{'='*60}")
    print(f"Generating 3D model for: {creator_id}")
    print(f"{'='*60}")
    print(f"  Prompt: {config['prompt'][:100]}...")

    if dry_run:
        print("  [DRY RUN] Skipping API call")
        return None

    # Step 1: Create Text-to-3D Preview
    print("\n  Step 1: Creating Text-to-3D preview...")
    preview_data = {
        "mode": "preview",
        "prompt": config["prompt"],
        "art_style": config["art_style"],
        "negative_prompt": config["negative_prompt"],
    }
    result = meshy_api_request("text-to-3d", method="POST", data=preview_data, api_key=api_key)
    if not result or "result" not in result:
        print("  [ERROR] Failed to create preview task")
        return None

    task_id = result["result"]
    print(f"  Preview task ID: {task_id}")

    # Step 2: Poll for completion
    print("  Polling for preview completion...")
    max_wait = 600  # 10 minutes
    poll_interval = 10
    elapsed = 0
    preview_result = None

    while elapsed < max_wait:
        time.sleep(poll_interval)
        elapsed += poll_interval
        status = meshy_api_request(f"text-to-3d/{task_id}", api_key=api_key)
        if not status:
            continue

        state = status.get("status", "")
        progress = status.get("progress", 0)
        print(f"  [{elapsed}s] Status: {state} | Progress: {progress}%")

        if state == "SUCCEEDED":
            preview_result = status
            break
        elif state in ("FAILED", "EXPIRED"):
            print(f"  [ERROR] Task {state}")
            return None

    if not preview_result:
        print("  [ERROR] Preview timed out")
        return None

    # Step 3: Download preview assets
    print("\n  Step 3: Downloading preview assets...")
    model_urls = preview_result.get("model_urls", {})
    thumbnail_url = preview_result.get("thumbnail_url", "")

    downloaded_files = {}

    for fmt in ["glb", "fbx", "obj"]:
        url = model_urls.get(fmt, "")
        if url:
            dest = output_dir / f"{creator_id}_model.{fmt}"
            if download_file(url, dest):
                downloaded_files[fmt] = str(dest)

    if thumbnail_url:
        thumb_dest = output_dir / f"{creator_id}_thumbnail.png"
        if download_file(thumbnail_url, thumb_dest):
            downloaded_files["thumbnail"] = str(thumb_dest)

    # Step 4: Try to refine (if preview succeeded)
    print("\n  Step 4: Requesting refined model...")
    refine_data = {
        "mode": "refine",
        "preview_task_id": task_id,
    }
    refine_result = meshy_api_request("text-to-3d", method="POST", data=refine_data, api_key=api_key)
    
    if refine_result and "result" in refine_result:
        refine_id = refine_result["result"]
        print(f"  Refine task ID: {refine_id}")

        # Poll for refine completion
        elapsed = 0
        while elapsed < max_wait:
            time.sleep(poll_interval)
            elapsed += poll_interval
            status = meshy_api_request(f"text-to-3d/{refine_id}", api_key=api_key)
            if not status:
                continue

            state = status.get("status", "")
            progress = status.get("progress", 0)
            print(f"  [{elapsed}s] Refine: {state} | Progress: {progress}%")

            if state == "SUCCEEDED":
                # Download refined model
                refined_urls = status.get("model_urls", {})
                for fmt in ["glb", "fbx", "obj"]:
                    url = refined_urls.get(fmt, "")
                    if url:
                        dest = output_dir / f"{creator_id}_refined.{fmt}"
                        if download_file(url, dest):
                            downloaded_files[f"refined_{fmt}"] = str(dest)
                break
            elif state in ("FAILED", "EXPIRED"):
                print(f"  Refine {state} - using preview model")
                break

    # Step 5: Update manifest
    model_entry = {
        "creator_id": creator_id,
        "preview_task_id": task_id,
        "files": downloaded_files,
        "prompt": config["prompt"],
        "generated_at": datetime.now().isoformat(),
        "status": "ready",
        "ue5_import_path": f"/Game/FEL/CreatorModels/{creator_id.title().replace('_', '')}/SK_{creator_id.title().replace('_', '')}",
    }

    manifest["models"][creator_id] = model_entry
    save_manifest(manifest)

    print(f"\n  ✅ Model generated for {creator_id}")
    print(f"  Files: {len(downloaded_files)}")
    return model_entry


def list_tasks(api_key):
    """List recent Meshy text-to-3d tasks."""
    result = meshy_api_request("text-to-3d?limit=10&sortBy=-created_at", api_key=api_key)
    if not result:
        print("Failed to list tasks")
        return

    tasks = result if isinstance(result, list) else result.get("results", [])
    print(f"\nRecent Meshy Tasks ({len(tasks)}):")
    for t in tasks:
        print(f"  {t.get('id', '?')} | {t.get('status', '?')} | {t.get('prompt', '?')[:60]}")


def main():
    parser = argparse.ArgumentParser(description="Meshy Creator Model Pipeline")
    parser.add_argument("--creator", type=str, help="Creator ID to generate model for")
    parser.add_argument("--all", action="store_true", help="Generate models for all creators")
    parser.add_argument("--list-tasks", action="store_true", help="List recent Meshy tasks")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done")
    parser.add_argument("--generate-new", action="store_true", help="Force generate even if exists")
    parser.add_argument("--prompt", type=str, help="Custom prompt for new generation")
    args = parser.parse_args()

    api_key = get_meshy_api_key()
    if not api_key:
        print("[ERROR] MESHY_API_KEY not set. Check .env or environment.")
        sys.exit(1)

    print(f"Meshy Creator Model Pipeline")
    print(f"API Key: {api_key[:8]}...{api_key[-4:]}")
    print(f"Output: {GENERATED_ASSETS}")

    if args.list_tasks:
        list_tasks(api_key)
        return

    if args.all:
        for cid in CREATOR_MODEL_PROMPTS:
            generate_creator_model(cid, api_key, dry_run=args.dry_run)
    elif args.creator:
        generate_creator_model(args.creator, api_key, dry_run=args.dry_run)
    else:
        print("\nAvailable creators:")
        for cid, cfg in CREATOR_MODEL_PROMPTS.items():
            print(f"  {cid}: {cfg['prompt'][:80]}...")
        print("\nUsage: --creator <id> or --all")


if __name__ == "__main__":
    main()
