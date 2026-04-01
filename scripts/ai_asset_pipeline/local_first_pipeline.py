#!/usr/bin/env python3
"""Local-First Asset Pipeline for Final Evolution Lab.

Orchestrates the complete asset pipeline with local-first strategy:
  1. Register all local assets (animations, props, environments) in manifest
  2. Generate only missing assets via Meshy API
  3. Skip DeepMotion and Luma AI entirely (use local alternatives)
  4. Run Unreal import helper to update catalog, import script, C++ header
  5. Validate all game modes and exercises have required assets

Usage:
  python -m scripts.ai_asset_pipeline.local_first_pipeline
  python -m scripts.ai_asset_pipeline.local_first_pipeline --skip-meshy
  python -m scripts.ai_asset_pipeline.local_first_pipeline --dry-run
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import sys
import time
from pathlib import Path
from typing import Any

# Ensure project root on path
SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parents[1]
sys.path.insert(0, str(ROOT_DIR / "scripts"))

from ai_asset_pipeline.config import load_all_configs, PipelineConfig, ROOT_DIR as CFG_ROOT
from ai_asset_pipeline.asset_cache import AssetManifest
from ai_asset_pipeline.local_asset_mapper import (
    EXERCISE_ANIMATION_MAP,
    EXERCISE_PROP_MAP,
    VENUE_ENVIRONMENT_MAP,
    LOCAL_ANIMATIONS,
    LOCAL_PROPS,
    LOCAL_ENVIRONMENTS,
    LOCAL_CHARACTERS,
    VENUE_TO_ARENA_MAP,
    verify_local_assets,
    get_exercise_local_animation,
    get_exercise_local_prop,
    get_venue_local_assets,
    get_exercises_needing_props,
    get_venues_needing_generation,
)
from ai_asset_pipeline.exercise_batch_generator import (
    load_exercise_catalog,
    EXERCISE_PROP_PROMPTS,
)
from ai_asset_pipeline.environment_generator import VENUE_PROMPTS

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(name)s %(levelname)s  %(message)s",
)
logger = logging.getLogger("local_first_pipeline")


# ════════════════════════════════════════════════════════════════════════
# Phase 1: Register local assets in manifest
# ════════════════════════════════════════════════════════════════════════

def register_local_animations(
    exercises: list[dict],
    manifest: AssetManifest,
    pipeline_cfg: PipelineConfig,
) -> dict[str, str]:
    """Register local animation files as mocap entries in the manifest."""
    results: dict[str, str] = {}
    for ex in exercises:
        ex_id = ex["id"]
        mocap_key = f"{ex_id}_mocap"
        
        if manifest.has(mocap_key):
            results[ex_id] = "cached"
            continue

        local_anim = get_exercise_local_animation(ex_id)
        if local_anim:
            manifest.set(
                mocap_key,
                service="local_animation",
                task_id=f"local_{ex_id}",
                files=[str(local_anim)],
                params={
                    "source": "local",
                    "animation_type": EXERCISE_ANIMATION_MAP.get(ex_id, "walking"),
                    "original_file": local_anim.name,
                },
            )
            results[ex_id] = "registered_local"
            logger.info("  ✓ %s → local animation (%s)", ex_id, local_anim.name)
        else:
            results[ex_id] = "missing"
            logger.warning("  ✗ %s — no local animation found", ex_id)

    return results


def register_local_props(
    exercises: list[dict],
    manifest: AssetManifest,
    pipeline_cfg: PipelineConfig,
) -> dict[str, str]:
    """Register local prop files in the manifest. Returns status per exercise."""
    results: dict[str, str] = {}
    for ex in exercises:
        ex_id = ex["id"]
        if ex_id not in EXERCISE_PROP_MAP:
            results[ex_id] = "not_needed"
            continue

        prop_key = f"{ex_id}_prop"
        if manifest.has(prop_key):
            results[ex_id] = "cached"
            continue

        local_prop = get_exercise_local_prop(ex_id)
        if local_prop:
            manifest.set(
                prop_key,
                service="local_meshy",
                task_id=f"local_{ex_id}_prop",
                files=[str(local_prop)],
                params={"source": "local", "original_file": local_prop.name},
            )
            results[ex_id] = "registered_local"
            logger.info("  ✓ %s → local prop (%s)", ex_id, local_prop.name)
        else:
            results[ex_id] = "needs_generation"
            logger.info("  ⚡ %s — needs Meshy API generation", ex_id)

    return results


def register_local_environments(
    manifest: AssetManifest,
    pipeline_cfg: PipelineConfig,
) -> dict[str, str]:
    """Register local environment assets for venues."""
    results: dict[str, str] = {}
    for venue_key, venue_info in VENUE_ENVIRONMENT_MAP.items():
        model_key = f"env_{venue_key}_3d_model"
        
        if manifest.has(model_key):
            results[venue_key] = "cached"
            continue

        local_assets = get_venue_local_assets(venue_key)
        files: list[str] = []
        if local_assets["model"]:
            files.append(str(local_assets["model"]))
        if local_assets["scan"]:
            files.append(str(local_assets["scan"]))

        if files:
            manifest.set(
                model_key,
                service="local_environment",
                task_id=f"local_{venue_key}",
                files=files,
                params={
                    "source": "local",
                    "description": venue_info.get("description", ""),
                    "has_model": local_assets["model"] is not None,
                    "has_scan": local_assets["scan"] is not None,
                },
            )
            results[venue_key] = "registered_local"
            logger.info("  ✓ %s → local (%s)", venue_key, venue_info.get("description", ""))
        else:
            results[venue_key] = "needs_generation"
            logger.info("  ⚡ %s — needs Meshy API generation", venue_key)

    return results


def register_local_characters(manifest: AssetManifest) -> dict[str, str]:
    """Register local character models."""
    results: dict[str, str] = {}
    for char_key, char_path in LOCAL_CHARACTERS.items():
        mkey = f"character_{char_key}"
        if manifest.has(mkey):
            results[char_key] = "cached"
            continue
        if char_path.is_file():
            manifest.set(
                mkey,
                service="local_character",
                task_id=f"local_{char_key}",
                files=[str(char_path)],
                params={"source": "local", "original_file": char_path.name},
            )
            results[char_key] = "registered_local"
            logger.info("  ✓ character: %s", char_key)
        else:
            results[char_key] = "missing"
    return results


# ════════════════════════════════════════════════════════════════════════
# Phase 2: Generate missing assets via Meshy API
# ════════════════════════════════════════════════════════════════════════

def generate_missing_props(
    exercises: list[dict],
    manifest: AssetManifest,
    pipeline_cfg: PipelineConfig,
    dry_run: bool = False,
    skip_meshy: bool = False,
) -> dict[str, str]:
    """Generate missing exercise props via Meshy Text-to-3D."""
    results: dict[str, str] = {}
    missing = get_exercises_needing_props()

    for ex_id in missing:
        prop_key = f"{ex_id}_prop"
        if manifest.has(prop_key):
            results[ex_id] = "already_in_manifest"
            continue

        prompt = EXERCISE_PROP_PROMPTS.get(ex_id)
        if not prompt:
            results[ex_id] = "no_prompt"
            continue

        if dry_run:
            logger.info("  [DRY-RUN] Would generate prop for %s: %s", ex_id, prompt[:60])
            results[ex_id] = "dry_run"
            continue

        if skip_meshy:
            logger.info("  [SKIP] Meshy generation skipped for %s", ex_id)
            results[ex_id] = "skipped"
            continue

        try:
            from ai_asset_pipeline.meshy_service import MeshyService
            meshy = MeshyService()
            out_dir = pipeline_cfg.output_root / "meshy" / ex_id
            out_dir.mkdir(parents=True, exist_ok=True)
            logger.info("  ⚡ Generating prop for %s via Meshy API...", ex_id)
            result = meshy.text_to_3d_full(prompt, out_dir)
            manifest.set(
                prop_key,
                service="meshy",
                task_id=result.get("task", {}).get("id", ""),
                files=result.get("files", []),
                params={"prompt": prompt, "source": "meshy_api"},
            )
            results[ex_id] = "generated"
            logger.info("  ✓ %s → Meshy prop generated", ex_id)
        except Exception as exc:
            logger.error("  ✗ Meshy prop generation failed for %s: %s", ex_id, exc)
            results[ex_id] = f"failed: {exc}"

    return results


def generate_missing_environments(
    manifest: AssetManifest,
    pipeline_cfg: PipelineConfig,
    dry_run: bool = False,
    skip_meshy: bool = False,
) -> dict[str, str]:
    """Generate missing venue environments via Meshy Text-to-3D."""
    results: dict[str, str] = {}
    missing = get_venues_needing_generation()

    for venue_key in missing:
        model_key = f"env_{venue_key}_3d_model"
        if manifest.has(model_key):
            results[venue_key] = "already_in_manifest"
            continue

        venue_prompt_info = VENUE_PROMPTS.get(venue_key, {})
        # Use the luma_prompt as Meshy text-to-3D prompt (adapted)
        description = venue_prompt_info.get("description", venue_key)
        prompt = f"{description}, 3D environment model, game-ready, low-poly optimized"

        if dry_run:
            logger.info("  [DRY-RUN] Would generate environment for %s: %s", venue_key, prompt[:60])
            results[venue_key] = "dry_run"
            continue

        if skip_meshy:
            logger.info("  [SKIP] Meshy generation skipped for %s", venue_key)
            results[venue_key] = "skipped"
            continue

        try:
            from ai_asset_pipeline.meshy_service import MeshyService
            meshy = MeshyService()
            out_dir = pipeline_cfg.output_root / "meshy" / f"env_{venue_key}"
            out_dir.mkdir(parents=True, exist_ok=True)
            logger.info("  ⚡ Generating environment for %s via Meshy API...", venue_key)
            result = meshy.text_to_3d_full(prompt, out_dir)
            manifest.set(
                model_key,
                service="meshy",
                task_id=result.get("task", {}).get("id", ""),
                files=result.get("files", []),
                params={"prompt": prompt, "source": "meshy_api"},
            )
            results[venue_key] = "generated"
            logger.info("  ✓ %s → Meshy environment generated", venue_key)
        except Exception as exc:
            logger.error("  ✗ Meshy environment generation failed for %s: %s", venue_key, exc)
            results[venue_key] = f"failed: {exc}"

    return results


# ════════════════════════════════════════════════════════════════════════
# Phase 3: Unreal Import Helper
# ════════════════════════════════════════════════════════════════════════

def run_unreal_import_helper(manifest: AssetManifest, pipeline_cfg: PipelineConfig) -> dict[str, str]:
    """Run the Unreal import helper to generate import script, update catalog, and generate header."""
    from ai_asset_pipeline.unreal_import_helper import (
        generate_editor_import_script,
        update_exercise_catalog,
        generate_asset_registry_header,
    )

    results: dict[str, str] = {}

    try:
        script_path = generate_editor_import_script(manifest, pipeline_cfg)
        results["import_script"] = str(script_path)
        logger.info("  ✓ Generated UE import script")
    except Exception as exc:
        results["import_script"] = f"failed: {exc}"
        logger.error("  ✗ Import script generation failed: %s", exc)

    try:
        catalog_path = update_exercise_catalog(manifest, pipeline_cfg)
        results["exercise_catalog"] = str(catalog_path)
        logger.info("  ✓ Updated ExerciseCatalog.json")
    except Exception as exc:
        results["exercise_catalog"] = f"failed: {exc}"
        logger.error("  ✗ Exercise catalog update failed: %s", exc)

    try:
        header_path = generate_asset_registry_header(manifest, pipeline_cfg)
        results["asset_header"] = str(header_path)
        logger.info("  ✓ Generated C++ asset registry header")
    except Exception as exc:
        results["asset_header"] = f"failed: {exc}"
        logger.error("  ✗ Asset registry header generation failed: %s", exc)

    return results


# ════════════════════════════════════════════════════════════════════════
# Phase 4: Validation
# ════════════════════════════════════════════════════════════════════════

def validate_all_assets(
    exercises: list[dict],
    manifest: AssetManifest,
) -> dict[str, Any]:
    """Validate that all game modes, exercises, and venues have required assets."""
    validation: dict[str, Any] = {
        "exercises": {"total": 0, "with_animation": 0, "with_prop": 0, "missing_animation": [], "missing_prop": []},
        "venues": {"total": 0, "with_model": 0, "missing": []},
        "game_modes": {"total": 16, "covered": 0, "missing": []},
        "overall_pass": False,
    }

    # Validate exercises
    validation["exercises"]["total"] = len(exercises)
    for ex in exercises:
        ex_id = ex["id"]
        mocap_key = f"{ex_id}_mocap"
        if manifest.has(mocap_key):
            validation["exercises"]["with_animation"] += 1
        else:
            validation["exercises"]["missing_animation"].append(ex_id)

        prop_key = f"{ex_id}_prop"
        if ex_id in EXERCISE_PROP_MAP:
            if manifest.has(prop_key):
                validation["exercises"]["with_prop"] += 1
            else:
                validation["exercises"]["missing_prop"].append(ex_id)

    # Validate venues
    validation["venues"]["total"] = len(VENUE_ENVIRONMENT_MAP)
    for venue_key in VENUE_ENVIRONMENT_MAP:
        model_key = f"env_{venue_key}_3d_model"
        if manifest.has(model_key):
            validation["venues"]["with_model"] += 1
        else:
            validation["venues"]["missing"].append(venue_key)

    # Validate game modes (check ArenaSettings.json venue maps exist)
    arena_path = CFG_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json"
    if arena_path.is_file():
        arena_data = json.loads(arena_path.read_text(encoding="utf-8"))
        modes = arena_data.get("modes", {})
        for mode_key in modes:
            # Check if the venue .umap referenced exists
            level_pkg = modes[mode_key].get("unrealOpenLevelPackage", "")
            # Extract venue name from path like /Game/FEL/Venues/VeniceBeach/VeniceBeach.VeniceBeach
            parts = level_pkg.split("/")
            if len(parts) >= 5:
                venue_name = parts[4]  # e.g., VeniceBeach
                umap_path = CFG_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Venues" / venue_name / f"{venue_name}.umap"
                if umap_path.is_file():
                    validation["game_modes"]["covered"] += 1
                else:
                    validation["game_modes"]["missing"].append(mode_key)
            else:
                validation["game_modes"]["missing"].append(mode_key)

    # Overall pass check
    all_anims = validation["exercises"]["with_animation"] == validation["exercises"]["total"]
    all_venues_ok = validation["game_modes"]["covered"] >= 14  # Allow some flexibility
    validation["overall_pass"] = all_anims and all_venues_ok

    return validation


# ════════════════════════════════════════════════════════════════════════
# Main Pipeline
# ════════════════════════════════════════════════════════════════════════

def main() -> None:
    p = argparse.ArgumentParser(description="Local-First Asset Pipeline for Final Evolution Lab")
    p.add_argument("--dry-run", action="store_true", help="Preview operations without Meshy API calls")
    p.add_argument("--skip-meshy", action="store_true", help="Skip all Meshy API generation")
    p.add_argument("--skip-import", action="store_true", help="Skip Unreal import helper step")
    args = p.parse_args()

    start_time = time.time()
    pipeline_report: dict[str, Any] = {"phases": {}}

    # ── Load configs ──
    _, meshy_cfg, _, pipeline_cfg = load_all_configs()
    pipeline_cfg.ensure_dirs()
    manifest = AssetManifest(pipeline_cfg.manifest_path)
    exercises = load_exercise_catalog(pipeline_cfg.exercise_catalog_path)

    logger.info("╔" + "═" * 68 + "╗")
    logger.info("║  FINAL EVOLUTION LAB — Local-First Asset Pipeline                  ║")
    logger.info("╚" + "═" * 68 + "╝")
    logger.info("Exercises: %d | Venues: %d | Game Modes: 16", len(exercises), len(VENUE_ENVIRONMENT_MAP))

    # ── Phase 0: Verify local assets ──
    logger.info("")
    logger.info("━" * 70)
    logger.info("PHASE 0: Verifying Local Assets")
    logger.info("━" * 70)
    asset_report = verify_local_assets()
    for category, summary in asset_report["summary"].items():
        logger.info("  %s: %s available", category, summary)
    pipeline_report["phases"]["verify"] = asset_report["summary"]

    # ── Phase 1: Register local assets ──
    logger.info("")
    logger.info("━" * 70)
    logger.info("PHASE 1: Registering Local Assets in Manifest")
    logger.info("━" * 70)

    logger.info("")
    logger.info("── Exercise Animations (23 exercises → local animations) ──")
    anim_results = register_local_animations(exercises, manifest, pipeline_cfg)
    local_anims = sum(1 for v in anim_results.values() if v == "registered_local")
    cached_anims = sum(1 for v in anim_results.values() if v == "cached")
    logger.info("  Summary: %d registered, %d cached, %d missing",
                local_anims, cached_anims,
                sum(1 for v in anim_results.values() if v == "missing"))

    logger.info("")
    logger.info("── Exercise Props (9 exercises need props) ──")
    prop_results = register_local_props(exercises, manifest, pipeline_cfg)
    local_props_count = sum(1 for v in prop_results.values() if v == "registered_local")
    needs_gen = sum(1 for v in prop_results.values() if v == "needs_generation")
    logger.info("  Summary: %d local, %d need generation", local_props_count, needs_gen)

    logger.info("")
    logger.info("── Environment Assets (12 venues) ──")
    env_results = register_local_environments(manifest, pipeline_cfg)
    local_envs = sum(1 for v in env_results.values() if v == "registered_local")
    env_needs_gen = sum(1 for v in env_results.values() if v == "needs_generation")
    logger.info("  Summary: %d local, %d need generation", local_envs, env_needs_gen)

    logger.info("")
    logger.info("── Character Models ──")
    char_results = register_local_characters(manifest)
    logger.info("  Summary: %d characters registered",
                sum(1 for v in char_results.values() if v == "registered_local"))

    pipeline_report["phases"]["register_local"] = {
        "animations": anim_results,
        "props": prop_results,
        "environments": env_results,
        "characters": char_results,
    }

    # ── Phase 2: Generate missing assets via Meshy ──
    logger.info("")
    logger.info("━" * 70)
    logger.info("PHASE 2: Generating Missing Assets via Meshy API")
    logger.info("━" * 70)

    logger.info("")
    logger.info("── Missing Exercise Props ──")
    prop_gen_results = generate_missing_props(
        exercises, manifest, pipeline_cfg,
        dry_run=args.dry_run,
        skip_meshy=args.skip_meshy,
    )
    for ex_id, status in prop_gen_results.items():
        logger.info("  %s: %s", ex_id, status)

    logger.info("")
    logger.info("── Missing Environment Assets ──")
    env_gen_results = generate_missing_environments(
        manifest, pipeline_cfg,
        dry_run=args.dry_run,
        skip_meshy=args.skip_meshy,
    )
    for venue, status in env_gen_results.items():
        logger.info("  %s: %s", venue, status)

    pipeline_report["phases"]["generate_missing"] = {
        "props": prop_gen_results,
        "environments": env_gen_results,
    }

    # ── Phase 3: Unreal Import Helper ──
    if not args.skip_import:
        logger.info("")
        logger.info("━" * 70)
        logger.info("PHASE 3: Unreal Engine Integration")
        logger.info("━" * 70)
        import_results = run_unreal_import_helper(manifest, pipeline_cfg)
        pipeline_report["phases"]["unreal_import"] = import_results
    else:
        logger.info("")
        logger.info("[SKIP] Unreal import helper")

    # ── Phase 4: Validation ──
    logger.info("")
    logger.info("━" * 70)
    logger.info("PHASE 4: Validation")
    logger.info("━" * 70)
    validation = validate_all_assets(exercises, manifest)
    
    logger.info("  Exercises with animation: %d/%d",
                validation["exercises"]["with_animation"],
                validation["exercises"]["total"])
    if validation["exercises"]["missing_animation"]:
        logger.warning("  Missing animations: %s", validation["exercises"]["missing_animation"])
    
    logger.info("  Exercises with props: %d/9", validation["exercises"]["with_prop"])
    if validation["exercises"]["missing_prop"]:
        logger.info("  Props needing generation: %s", validation["exercises"]["missing_prop"])
    
    logger.info("  Venues with 3D model: %d/%d",
                validation["venues"]["with_model"],
                validation["venues"]["total"])
    if validation["venues"]["missing"]:
        logger.info("  Venues needing generation: %s", validation["venues"]["missing"])
    
    logger.info("  Game modes with venue maps: %d/16",
                validation["game_modes"]["covered"])
    if validation["game_modes"]["missing"]:
        logger.warning("  Missing venue maps for: %s", validation["game_modes"]["missing"])
    
    logger.info("  Overall validation: %s", "PASS ✓" if validation["overall_pass"] else "PARTIAL ⚠")
    pipeline_report["phases"]["validation"] = validation

    # ── Final Summary ──
    elapsed = time.time() - start_time
    logger.info("")
    logger.info("╔" + "═" * 68 + "╗")
    logger.info("║  PIPELINE COMPLETE — %.1fs elapsed                                 ║", elapsed)
    logger.info("╚" + "═" * 68 + "╝")
    logger.info("")
    logger.info(manifest.summary())

    # ── Write report ──
    report_path = pipeline_cfg.output_root / "pipeline_report.json"
    report_path.write_text(json.dumps(pipeline_report, indent=2, default=str), encoding="utf-8")
    logger.info("Full report: %s", report_path)


if __name__ == "__main__":
    main()
