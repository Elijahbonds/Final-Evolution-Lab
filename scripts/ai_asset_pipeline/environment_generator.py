#!/usr/bin/env python3
"""Generate 3D environment assets for game venues using Luma AI + Meshy.

Pipeline:
  1. Luma AI → Generate high-quality reference image of the environment
  2. Meshy   → Convert reference image to 3D model (Image-to-3D)

Usage:
  python -m ai_asset_pipeline.environment_generator --all
  python -m ai_asset_pipeline.environment_generator --venue venice_basketball
  python -m ai_asset_pipeline.environment_generator --dry-run
"""
from __future__ import annotations

import argparse
import json
import logging
import sys
from pathlib import Path
from typing import Any

from .config import load_all_configs, PipelineConfig
from .asset_cache import AssetManifest

logger = logging.getLogger("env_generator")

# Venue environments to generate
VENUE_PROMPTS: dict[str, dict[str, str]] = {
    "venice_basketball": {
        "luma_prompt": "Venice Beach outdoor basketball court at golden hour, photorealistic, palm trees, ocean background, wide angle",
        "description": "Venice Beach basketball court environment",
    },
    "soccer_stadium": {
        "luma_prompt": "Professional soccer stadium interior, green pitch, filled stands, night game lights, photorealistic, wide angle",
        "description": "Professional soccer stadium",
    },
    "golf_course": {
        "luma_prompt": "Beautiful 18th hole golf course, manicured green, sand bunker, trees, blue sky, photorealistic, wide angle",
        "description": "Championship golf course",
    },
    "skatepark": {
        "luma_prompt": "Modern urban skatepark, concrete bowls, halfpipe, rails, graffiti walls, golden hour, photorealistic",
        "description": "Urban skatepark venue",
    },
    "tennis_court": {
        "luma_prompt": "Professional hard court tennis court, blue surface, stadium seating, photorealistic, wide angle",
        "description": "Professional tennis court",
    },
    "boxing_ring": {
        "luma_prompt": "Professional boxing ring in arena, red and blue corners, spotlights, crowd, photorealistic",
        "description": "Boxing ring arena",
    },
    "surf_beach": {
        "luma_prompt": "Tropical surf beach with perfect waves, blue water, white sand, palm trees, sunrise, photorealistic",
        "description": "Surf beach environment",
    },
    "gymnastics_arena": {
        "luma_prompt": "Olympic gymnastics arena, floor exercise mat, apparatus, judges table, spotlights, photorealistic",
        "description": "Olympic gymnastics arena",
    },
    "dojo": {
        "luma_prompt": "Traditional Japanese martial arts dojo, tatami mats, wooden walls, katana display, zen atmosphere",
        "description": "Traditional martial arts dojo",
    },
    "snowboard_mountain": {
        "luma_prompt": "Snowy mountain halfpipe, fresh powder, blue sky, pine trees, ski resort, photorealistic",
        "description": "Snowboard mountain course",
    },
    "training_gym": {
        "luma_prompt": "Modern high-tech training facility, weight racks, platforms, LED lighting, clean minimalist, photorealistic",
        "description": "High-tech training gym for Academy mode",
    },
    "marketplace": {
        "luma_prompt": "Futuristic digital marketplace, neon holographic displays, floating product cards, cyberpunk aesthetic",
        "description": "Digital marketplace environment",
    },
}


def generate_venue_assets(
    venue_key: str,
    venue_info: dict[str, str],
    pipeline_cfg: PipelineConfig,
    manifest: AssetManifest,
    dry_run: bool = False,
) -> dict[str, Any]:
    results: dict[str, Any] = {"venue": venue_key, "steps": []}

    # Step 1: Luma reference image
    img_key = f"env_{venue_key}_reference_image"
    image_file: str | None = None
    if not manifest.has(img_key):
        prompt = venue_info["luma_prompt"]
        if dry_run:
            logger.info("[DRY-RUN] Luma image: %s", prompt[:80])
            results["steps"].append({"step": "luma_image", "status": "dry_run"})
        else:
            try:
                from .luma_service import LumaAIService
                luma = LumaAIService()
                out_dir = pipeline_cfg.output_root / "luma" / f"env_{venue_key}"
                result = luma.generate_environment_reference(prompt, out_dir)
                files = result.get("files", [])
                manifest.set(img_key, service="luma",
                             task_id=result.get("generation", {}).get("id", ""),
                             files=files, params={"prompt": prompt})
                image_file = next((f for f in files if f.endswith((".png", ".jpg"))), None)
                results["steps"].append({"step": "luma_image", "status": "completed", "files": files})
            except Exception as exc:
                logger.error("Luma env image failed for %s: %s", venue_key, exc)
                results["steps"].append({"step": "luma_image", "status": "failed", "error": str(exc)})
    else:
        entry = manifest.get(img_key)
        image_file = next((f for f in (entry or {}).get("files", []) if f.endswith((".png", ".jpg"))), None)
        results["steps"].append({"step": "luma_image", "status": "cached"})

    # Step 2: Meshy Image-to-3D
    mesh_key = f"env_{venue_key}_3d_model"
    if not manifest.has(mesh_key) and image_file:
        if dry_run:
            logger.info("[DRY-RUN] Meshy Image-to-3D from: %s", image_file)
            results["steps"].append({"step": "meshy_image_to_3d", "status": "dry_run"})
        else:
            try:
                from .meshy_service import MeshyService
                meshy = MeshyService()
                out_dir = pipeline_cfg.output_root / "meshy" / f"env_{venue_key}"
                # Use file:// URL or upload — for now, if it's a URL from Luma, use directly
                result = meshy.image_to_3d_full(image_file, out_dir)
                manifest.set(mesh_key, service="meshy",
                             task_id=result.get("task", {}).get("id", ""),
                             files=result.get("files", []),
                             params={"source_image": image_file})
                results["steps"].append({"step": "meshy_image_to_3d", "status": "completed", "files": result["files"]})
            except Exception as exc:
                logger.error("Meshy env model failed for %s: %s", venue_key, exc)
                results["steps"].append({"step": "meshy_image_to_3d", "status": "failed", "error": str(exc)})
    else:
        status = "cached" if manifest.has(mesh_key) else "skipped_no_image"
        results["steps"].append({"step": "meshy_image_to_3d", "status": status})

    return results


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s  %(message)s")

    p = argparse.ArgumentParser(description="Generate 3D environment assets for game venues")
    p.add_argument("--all", action="store_true")
    p.add_argument("--venue", type=str)
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    _, _, _, pipeline_cfg = load_all_configs()
    pipeline_cfg.ensure_dirs()
    manifest = AssetManifest(pipeline_cfg.manifest_path)

    venues = VENUE_PROMPTS
    if args.venue:
        if args.venue not in venues:
            logger.error("Unknown venue: %s. Available: %s", args.venue, list(venues.keys()))
            sys.exit(1)
        venues = {args.venue: venues[args.venue]}
    elif not args.all:
        logger.error("Specify --all or --venue <key>")
        sys.exit(1)

    all_results = []
    for key, info in venues.items():
        logger.info("═" * 60)
        logger.info("Venue: %s — %s", key, info["description"])
        result = generate_venue_assets(key, info, pipeline_cfg, manifest, dry_run=args.dry_run)
        all_results.append(result)

    logger.info("═" * 60)
    logger.info(manifest.summary())
    print(json.dumps(all_results, indent=2))


if __name__ == "__main__":
    main()
