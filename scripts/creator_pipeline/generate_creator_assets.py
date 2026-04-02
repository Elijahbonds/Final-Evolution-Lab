#!/usr/bin/env python3
"""
Creator Visual Asset Generator
==============================
Generates profile images, banners, card backgrounds, and icons
for the creator card system using Luma AI.

Usage:
    python3 -m scripts.creator_pipeline.generate_creator_assets --creator elijah_bonds
    python3 -m scripts.creator_pipeline.generate_creator_assets --all
    python3 -m scripts.creator_pipeline.generate_creator_assets --icons-only
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

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
ASSETS_DIR = PROJECT_ROOT / "GeneratedAssets" / "CreatorAssets"
MANIFEST_PATH = ASSETS_DIR / "creator_assets_manifest.json"


def get_luma_api_key():
    key = os.environ.get("LUMA_API_KEY", "")
    if not key:
        env_path = PROJECT_ROOT / ".env"
        if env_path.exists():
            for line in env_path.read_text().splitlines():
                if line.startswith("LUMA_API_KEY="):
                    key = line.split("=", 1)[1].strip().strip('"').strip("'")
                    break
    return key


def luma_generate_image(prompt, api_key, aspect_ratio="1:1", model="photon-1"):
    """Generate an image using Luma AI Photon."""
    url = "https://i.ytimg.com/vi/Ohl9KOXhO2s/hqdefault.jpg"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    data = json.dumps({
        "prompt": prompt,
        "aspect_ratio": aspect_ratio,
        "model": model,
    }).encode()
    req = urllib.request.Request(url, data=data, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read().decode())
    except Exception as e:
        print(f"  [ERROR] Luma API: {e}")
        return None


def poll_luma_task(task_id, api_key, max_wait=300):
    """Poll a Luma task until completion."""
    url = f"https://api.lumalabs.ai/dream-machine/v1/generations/{task_id}"
    headers = {"Authorization": f"Bearer {api_key}"}
    elapsed = 0
    interval = 5
    while elapsed < max_wait:
        time.sleep(interval)
        elapsed += interval
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                result = json.loads(resp.read().decode())
            state = result.get("state", "")
            if state == "completed":
                return result
            elif state == "failed":
                print(f"  [ERROR] Task failed: {result.get('failure_reason', 'unknown')}")
                return None
            print(f"  [{elapsed}s] State: {state}")
        except Exception:
            pass
    return None


def download_file(url, dest_path):
    dest_path = Path(dest_path)
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        urllib.request.urlretrieve(url, str(dest_path))
        print(f"  Downloaded: {dest_path.name} ({dest_path.stat().st_size:,} bytes)")
        return True
    except Exception as e:
        print(f"  [ERROR] Download failed: {e}")
        return False


def load_manifest():
    if MANIFEST_PATH.exists():
        return json.loads(MANIFEST_PATH.read_text())
    return {"version": "1.0", "assets": {}, "last_updated": ""}


def save_manifest(manifest):
    manifest["last_updated"] = datetime.now().isoformat()
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2))


# =====================================================================
# Asset Definitions
# =====================================================================

CREATOR_ASSET_PROMPTS = {
    "elijah_bonds": {
        "profile": {
            "prompt": "Professional sports portrait of a young athletic Black male basketball player, Venice Beach California vibes, golden hour lighting, basketball court background, confident expression, cinematic quality, 8K",
            "aspect_ratio": "1:1",
            "size": "512x512",
        },
        "banner": {
            "prompt": "Wide panoramic view of Venice Beach basketball courts at sunset, golden hour, palm trees, ocean in background, dynamic basketball action silhouette, cinematic sports photography, ultra-wide, 8K",
            "aspect_ratio": "16:9",
            "size": "1920x400",
        },
        "card_bg": {
            "prompt": "Abstract Venice Beach sunset gradient background, warm golden orange and purple tones, subtle basketball court texture overlay, premium card design, dark edges vignette",
            "aspect_ratio": "3:4",
            "size": "400x530",
        },
    },
    "amir_smith": {
        "profile": {
            "prompt": "Professional sports portrait of a tall athletic Black male basketball forward player, studio lighting, basketball in hand, determined expression, university basketball vibes, cinematic quality, 8K",
            "aspect_ratio": "1:1",
            "size": "512x512",
        },
        "banner": {
            "prompt": "Wide panoramic indoor basketball arena, dramatic stage lighting, modern basketball court, international basketball atmosphere, France basketball league vibes, ultra-wide, 8K",
            "aspect_ratio": "16:9",
            "size": "1920x400",
        },
        "card_bg": {
            "prompt": "Abstract holographic gradient background, blue and silver metallic tones, 3D wireframe basketball player silhouette, premium holographic card design, futuristic",
            "aspect_ratio": "3:4",
            "size": "400x530",
        },
    },
    "eric_nash": {
        "profile": {
            "prompt": "Professional sports portrait of a fit Black male basketball coach, Venice Beach setting, coaching attire, confident coaching pose, basketball court background, golden hour, cinematic quality, 8K",
            "aspect_ratio": "1:1",
            "size": "512x512",
        },
        "banner": {
            "prompt": "Wide panoramic view of Venice Beach boardwalk with basketball courts, morning light, coaching session atmosphere, community basketball vibes, ultra-wide, 8K",
            "aspect_ratio": "16:9",
            "size": "1920x400",
        },
        "card_bg": {
            "prompt": "Abstract basketball coaching diagram background, dark navy with chalk-style play markings, premium sports card design, elegant dark tones with gold accents",
            "aspect_ratio": "3:4",
            "size": "400x530",
        },
    },
}

ICON_PROMPTS = {
    "stat_vertical": "Simple flat icon of an upward arrow with basketball, white on transparent, minimal",
    "stat_shots": "Simple flat icon of a basketball going through hoop, white on transparent, minimal",
    "stat_dunks": "Simple flat icon of a basketball slam dunk silhouette, white on transparent, minimal",
    "stat_video": "Simple flat icon of a video play button, white on transparent, minimal",
    "stat_season": "Simple flat icon of a trophy, white on transparent, minimal",
    "stat_trophy": "Simple flat icon of a championship trophy, white on transparent, minimal",
    "stat_height": "Simple flat icon of a height measurement ruler, white on transparent, minimal",
    "stat_college": "Simple flat icon of a graduation cap, white on transparent, minimal",
    "stat_league": "Simple flat icon of a globe with basketball, white on transparent, minimal",
    "stat_position": "Simple flat icon of a basketball court position marker, white on transparent, minimal",
    "stat_3d": "Simple flat icon of a 3D cube wireframe, white on transparent, minimal",
    "stat_moves": "Simple flat icon of a basketball with motion lines, white on transparent, minimal",
    "stat_coaching": "Simple flat icon of a whistle, white on transparent, minimal",
    "stat_location": "Simple flat icon of a map pin, white on transparent, minimal",
    "stat_style": "Simple flat icon of a basketball with star, white on transparent, minimal",
    "stat_social": "Simple flat icon of a social media at symbol, white on transparent, minimal",
    "badge_featured": "Premium golden badge icon with star, 'FEATURED' text, game UI style, metallic",
    "badge_coming_soon": "Silver badge icon with question mark, 'COMING SOON' text, game UI style",
    "icon_instagram": "Instagram logo icon, white on transparent, clean",
    "icon_twitter": "X/Twitter logo icon, white on transparent, clean",
    "icon_tiktok": "TikTok logo icon, white on transparent, clean",
}


def generate_creator_visuals(creator_id, api_key, dry_run=False):
    """Generate all visual assets for a creator."""
    if creator_id not in CREATOR_ASSET_PROMPTS:
        print(f"[ERROR] Unknown creator: {creator_id}")
        return

    config = CREATOR_ASSET_PROMPTS[creator_id]
    manifest = load_manifest()

    for asset_type, asset_config in config.items():
        asset_key = f"{creator_id}_{asset_type}"
        output_dir = ASSETS_DIR / asset_type.replace("card_bg", "backgrounds").replace("profile", "profiles").replace("banner", "banners")
        output_path = output_dir / f"{creator_id}_{asset_type}.png"

        if output_path.exists() and asset_key in manifest.get("assets", {}):
            print(f"  [SKIP] {asset_key} already exists")
            continue

        print(f"\n  Generating {asset_type} for {creator_id}...")
        print(f"  Prompt: {asset_config['prompt'][:80]}...")

        if dry_run:
            print(f"  [DRY RUN] Would generate: {output_path}")
            continue

        # Generate via Luma
        result = luma_generate_image(
            asset_config["prompt"],
            api_key,
            aspect_ratio=asset_config["aspect_ratio"]
        )
        if not result:
            continue

        task_id = result.get("id", "")
        if not task_id:
            print(f"  [ERROR] No task ID returned")
            continue

        # Poll for result
        completed = poll_luma_task(task_id, api_key)
        if not completed:
            continue

        # Download
        assets = completed.get("assets", {})
        image_url = assets.get("image", "")
        if image_url and download_file(image_url, output_path):
            manifest.setdefault("assets", {})[asset_key] = {
                "path": str(output_path),
                "type": asset_type,
                "creator": creator_id,
                "generated_at": datetime.now().isoformat(),
                "ue5_path": f"/Game/FEL/CreatorAssets/{asset_type.title()}/{creator_id}_{asset_type}",
            }
            save_manifest(manifest)

    print(f"\n  ✅ Visuals generated for {creator_id}")


def generate_icons(api_key, dry_run=False):
    """Generate all shared icons."""
    manifest = load_manifest()
    icons_dir = ASSETS_DIR / "icons"
    icons_dir.mkdir(parents=True, exist_ok=True)

    for icon_key, prompt in ICON_PROMPTS.items():
        output_path = icons_dir / f"{icon_key}.png"
        if output_path.exists() and icon_key in manifest.get("assets", {}):
            print(f"  [SKIP] {icon_key} already exists")
            continue

        print(f"  Generating icon: {icon_key}...")
        if dry_run:
            print(f"  [DRY RUN] Would generate: {output_path}")
            continue

        result = luma_generate_image(prompt, api_key, aspect_ratio="1:1")
        if not result:
            continue

        task_id = result.get("id", "")
        if not task_id:
            continue

        completed = poll_luma_task(task_id, api_key)
        if not completed:
            continue

        assets = completed.get("assets", {})
        image_url = assets.get("image", "")
        if image_url and download_file(image_url, output_path):
            manifest.setdefault("assets", {})[icon_key] = {
                "path": str(output_path),
                "type": "icon",
                "generated_at": datetime.now().isoformat(),
                "ue5_path": f"/Game/FEL/CreatorAssets/Icons/{icon_key}",
            }
            save_manifest(manifest)


def main():
    parser = argparse.ArgumentParser(description="Creator Visual Asset Generator")
    parser.add_argument("--creator", type=str, help="Creator ID")
    parser.add_argument("--all", action="store_true", help="Generate for all creators")
    parser.add_argument("--icons-only", action="store_true", help="Generate icons only")
    parser.add_argument("--dry-run", action="store_true", help="Show plan without generating")
    args = parser.parse_args()

    api_key = get_luma_api_key()
    if not api_key:
        print("[WARNING] LUMA_API_KEY not set. Using placeholder assets.")
        # Create placeholder manifest entries
        manifest = load_manifest()
        for cid in CREATOR_ASSET_PROMPTS:
            for atype in ["profile", "banner", "card_bg"]:
                key = f"{cid}_{atype}"
                manifest.setdefault("assets", {})[key] = {
                    "path": f"placeholder_{key}.png",
                    "type": atype,
                    "creator": cid,
                    "status": "placeholder",
                    "ue5_path": f"/Game/FEL/CreatorAssets/{atype.title()}/{cid}_{atype}",
                }
        save_manifest(manifest)
        print("Created placeholder manifest. Set LUMA_API_KEY to generate real assets.")
        return

    print(f"Creator Visual Asset Generator")
    print(f"Output: {ASSETS_DIR}")

    if args.icons_only:
        generate_icons(api_key, dry_run=args.dry_run)
    elif args.all:
        for cid in CREATOR_ASSET_PROMPTS:
            generate_creator_visuals(cid, api_key, dry_run=args.dry_run)
        generate_icons(api_key, dry_run=args.dry_run)
    elif args.creator:
        generate_creator_visuals(args.creator, api_key, dry_run=args.dry_run)
    else:
        print("\nAvailable creators:")
        for cid in CREATOR_ASSET_PROMPTS:
            print(f"  {cid}")
        print("\nUsage: --creator <id> or --all")


if __name__ == "__main__":
    main()
