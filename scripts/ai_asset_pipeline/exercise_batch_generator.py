#!/usr/bin/env python3
"""Batch-generate the 23 exercise animations using the AI asset pipeline.

Pipeline per exercise:
  1. Luma AI  → Generate reference video of the exercise (text-to-video)
  2. DeepMotion → Process reference video → FBX/BVH motion capture data
  3. (Optional) Meshy → Generate 3D prop if exercise needs equipment

The script reads ExerciseCatalog.json, iterates exercises, and orchestrates
the three services. Results are cached in the asset manifest.

Usage:
  python -m ai_asset_pipeline.exercise_batch_generator --all
  python -m ai_asset_pipeline.exercise_batch_generator --exercise squat_form
  python -m ai_asset_pipeline.exercise_batch_generator --category strength
  python -m ai_asset_pipeline.exercise_batch_generator --dry-run
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

logger = logging.getLogger("exercise_batch")

# Exercise ID → text prompt for Luma AI video generation
EXERCISE_VIDEO_PROMPTS: dict[str, str] = {
    "dynamic_lunge_walk": "Athletic person performing walking lunges in a gym, side view, full body visible, clean background, smooth motion",
    "arm_circles_progressive": "Athletic person doing progressive arm circles, front view, full body, clean gym background",
    "high_knees": "Athletic person performing high knees running in place, side view, full body, gym setting",
    "lateral_shuffle": "Athletic person doing lateral shuffle drill, front view, full body, basketball court",
    "squat_form": "Athletic person performing perfect barbell squat form, side view, full body, clean gym background",
    "box_jump": "Athletic person performing explosive box jumps, side view, full body, gym with plyo box",
    "pushup_explosive": "Athletic person doing explosive clap pushups, side view, full body, gym floor",
    "deadlift_hip_hinge": "Athletic person performing deadlift hip hinge with barbell, side view, full body, gym",
    "hip_90_90": "Athletic person doing 90-90 hip mobility stretch on floor, front view, gym setting",
    "thoracic_rotation": "Athletic person performing thoracic spine rotation stretch, front view, seated on floor",
    "ankle_dorsiflexion": "Athletic person doing ankle dorsiflexion stretch against wall, side view, gym",
    "shoulder_dislocate": "Athletic person performing shoulder dislocate with resistance band, front view, gym",
    "dunk_approach": "Basketball player practicing dunk approach run and jump, side view, basketball court",
    "golf_swing_drill": "Golfer performing a full golf swing drill, side view, driving range background",
    "kick_form": "Soccer player practicing kick form and follow-through, side view, soccer field",
    "serve_motion": "Tennis player performing serve motion, side view, tennis court background",
    "karate_kata_basic": "Martial artist performing basic karate kata sequence, front view, dojo",
    "surf_popup": "Surfer practicing popup technique from lying to standing, side view, beach gym",
    "balance_board": "Athletic person doing balance board exercises, front view, gym setting",
    "tumbling_roundoff": "Gymnast performing roundoff tumbling pass, side view, gymnastics floor",
    "foam_roll_it_band": "Athletic person foam rolling IT band, side view, gym floor mat",
    "pigeon_stretch": "Athletic person performing pigeon stretch yoga pose, side view, yoga studio",
    "breathing_box": "Person performing box breathing meditation, front view, seated, calm studio",
}

# Exercises that need 3D props generated via Meshy
EXERCISE_PROP_PROMPTS: dict[str, str] = {
    "squat_form": "Standard Olympic barbell with weight plates, photorealistic",
    "deadlift_hip_hinge": "Deadlift barbell with bumper plates on floor, photorealistic",
    "box_jump": "Plyometric jump box, 24 inch, wooden, gym equipment",
    "balance_board": "Round wooden balance board with roller, gym equipment",
    "foam_roll_it_band": "High-density foam roller, cylindrical, gym equipment",
    "shoulder_dislocate": "Resistance band, exercise equipment, stretched",
    "golf_swing_drill": "Golf club iron, photorealistic, studio lighting",
    "serve_motion": "Tennis racket, professional, photorealistic",
    "kick_form": "Soccer ball, professional match ball, photorealistic",
}


def load_exercise_catalog(catalog_path: Path) -> list[dict]:
    """Load exercises from ExerciseCatalog.json."""
    data = json.loads(catalog_path.read_text(encoding="utf-8"))
    exercises = []
    for cat in data.get("categories", []):
        cat_id = cat.get("id", "")
        for ex in cat.get("exercises", []):
            ex["category_id"] = cat_id
            exercises.append(ex)
    return exercises


def generate_exercise_assets(
    exercise: dict,
    pipeline_cfg: PipelineConfig,
    manifest: AssetManifest,
    dry_run: bool = False,
    skip_video: bool = False,
    skip_mocap: bool = False,
    skip_props: bool = False,
) -> dict[str, Any]:
    """Generate all assets for a single exercise."""
    ex_id = exercise["id"]
    ex_name = exercise.get("name", ex_id)
    results: dict[str, Any] = {"exercise_id": ex_id, "steps": []}

    # --- Step 1: Luma AI reference video ---
    video_key = f"{ex_id}_reference_video"
    if not skip_video and not manifest.has(video_key):
        prompt = EXERCISE_VIDEO_PROMPTS.get(ex_id, f"Athletic person performing {ex_name}, full body, gym setting")
        if dry_run:
            logger.info("[DRY-RUN] Would generate Luma video: %s", prompt[:80])
            results["steps"].append({"step": "luma_video", "status": "dry_run", "prompt": prompt})
        else:
            try:
                from .luma_service import LumaAIService
                luma = LumaAIService()
                out_dir = pipeline_cfg.output_root / "luma" / ex_id
                result = luma.generate_exercise_reference_video(prompt, out_dir)
                manifest.set(
                    video_key,
                    service="luma",
                    task_id=result.get("generation", {}).get("id", ""),
                    files=result.get("files", []),
                    params={"prompt": prompt},
                )
                results["steps"].append({"step": "luma_video", "status": "completed", "files": result["files"]})
            except Exception as exc:
                logger.error("Luma video generation failed for %s: %s", ex_id, exc)
                results["steps"].append({"step": "luma_video", "status": "failed", "error": str(exc)})
    else:
        results["steps"].append({"step": "luma_video", "status": "cached" if manifest.has(video_key) else "skipped"})

    # --- Step 2: DeepMotion motion capture ---
    mocap_key = f"{ex_id}_mocap"
    if not skip_mocap and not manifest.has(mocap_key):
        video_entry = manifest.get(video_key)
        video_files = video_entry.get("files", []) if video_entry else []
        video_file = next((f for f in video_files if f.endswith(".mp4")), None)
        if video_file and Path(video_file).is_file():
            if dry_run:
                logger.info("[DRY-RUN] Would run DeepMotion on: %s", video_file)
                results["steps"].append({"step": "deepmotion_mocap", "status": "dry_run"})
            else:
                try:
                    from .deepmotion_service import DeepMotionService
                    dm = DeepMotionService()
                    out_dir = pipeline_cfg.output_root / "deepmotion" / ex_id
                    result = dm.process_video(video_file, out_dir)
                    manifest.set(
                        mocap_key,
                        service="deepmotion",
                        files=result.get("files", []),
                        params={"video": video_file},
                    )
                    results["steps"].append({"step": "deepmotion_mocap", "status": "completed", "files": result["files"]})
                except Exception as exc:
                    logger.error("DeepMotion failed for %s: %s", ex_id, exc)
                    results["steps"].append({"step": "deepmotion_mocap", "status": "failed", "error": str(exc)})
        else:
            logger.warning("No reference video for %s — skipping mocap", ex_id)
            results["steps"].append({"step": "deepmotion_mocap", "status": "skipped_no_video"})
    else:
        results["steps"].append({"step": "deepmotion_mocap", "status": "cached" if manifest.has(mocap_key) else "skipped"})

    # --- Step 3: Meshy 3D prop (if needed) ---
    prop_key = f"{ex_id}_prop"
    if not skip_props and ex_id in EXERCISE_PROP_PROMPTS and not manifest.has(prop_key):
        prompt = EXERCISE_PROP_PROMPTS[ex_id]
        if dry_run:
            logger.info("[DRY-RUN] Would generate Meshy prop: %s", prompt[:80])
            results["steps"].append({"step": "meshy_prop", "status": "dry_run", "prompt": prompt})
        else:
            try:
                from .meshy_service import MeshyService
                meshy = MeshyService()
                out_dir = pipeline_cfg.output_root / "meshy" / ex_id
                result = meshy.text_to_3d_full(prompt, out_dir)
                manifest.set(
                    prop_key,
                    service="meshy",
                    task_id=result.get("task", {}).get("id", ""),
                    files=result.get("files", []),
                    params={"prompt": prompt},
                )
                results["steps"].append({"step": "meshy_prop", "status": "completed", "files": result["files"]})
            except Exception as exc:
                logger.error("Meshy prop generation failed for %s: %s", ex_id, exc)
                results["steps"].append({"step": "meshy_prop", "status": "failed", "error": str(exc)})
    else:
        status = "cached" if manifest.has(prop_key) else ("not_needed" if ex_id not in EXERCISE_PROP_PROMPTS else "skipped")
        results["steps"].append({"step": "meshy_prop", "status": status})

    return results


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s  %(message)s")

    p = argparse.ArgumentParser(description="Batch-generate exercise animations via AI asset pipeline")
    p.add_argument("--all", action="store_true", help="Process all 23 exercises")
    p.add_argument("--exercise", type=str, help="Process a single exercise by ID")
    p.add_argument("--category", type=str, help="Process all exercises in a category")
    p.add_argument("--dry-run", action="store_true", help="Show what would be generated without running")
    p.add_argument("--skip-video", action="store_true", help="Skip Luma video generation")
    p.add_argument("--skip-mocap", action="store_true", help="Skip DeepMotion mocap")
    p.add_argument("--skip-props", action="store_true", help="Skip Meshy prop generation")
    args = p.parse_args()

    _, _, _, pipeline_cfg = load_all_configs()
    pipeline_cfg.ensure_dirs()
    manifest = AssetManifest(pipeline_cfg.manifest_path)

    exercises = load_exercise_catalog(pipeline_cfg.exercise_catalog_path)
    if not exercises:
        logger.error("No exercises found in catalog.")
        sys.exit(1)

    # Filter
    if args.exercise:
        exercises = [e for e in exercises if e["id"] == args.exercise]
    elif args.category:
        exercises = [e for e in exercises if e.get("category_id") == args.category]
    elif not args.all:
        logger.error("Specify --all, --exercise <id>, or --category <id>")
        sys.exit(1)

    logger.info("Processing %d exercises (dry_run=%s)", len(exercises), args.dry_run)
    all_results = []
    for ex in exercises:
        logger.info("═" * 60)
        logger.info("Exercise: %s (%s)", ex["id"], ex.get("name", ""))
        result = generate_exercise_assets(
            ex, pipeline_cfg, manifest,
            dry_run=args.dry_run,
            skip_video=args.skip_video,
            skip_mocap=args.skip_mocap,
            skip_props=args.skip_props,
        )
        all_results.append(result)

    # Summary
    logger.info("═" * 60)
    logger.info(manifest.summary())
    print(json.dumps(all_results, indent=2))


if __name__ == "__main__":
    main()
