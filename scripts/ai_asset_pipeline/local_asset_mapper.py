#!/usr/bin/env python3
"""Local Asset Mapper — discovers and maps local assets in UnrealStarter/
to exercises, venues, and game modes.

This module scans the local asset directories and creates mappings that
allow the pipeline to use existing assets instead of calling external APIs.
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

from .config import ROOT_DIR

logger = logging.getLogger("local_asset_mapper")

# ── Base paths ──────────────────────────────────────────────────────────
UNREAL_STARTER = ROOT_DIR / "UnrealStarter"
MESHY_ASSETS = UNREAL_STARTER / "MeshyAssets"
FEL_EXTERNAL_MESHY = UNREAL_STARTER / "BasketballGame" / "Content" / "FEL" / "External" / "Meshy"
LUMA_SCAN = UNREAL_STARTER / "LumaScan"
LUMA_EXPORTS = UNREAL_STARTER / "LumaExports"
VENUE_MAPS = UNREAL_STARTER / "BasketballGame" / "Content" / "FEL" / "Venues"

# ── Animation Assets ────────────────────────────────────────────────────
# Elijah Bonds biped has Running and Walking animations with skinned mesh.
# These serve as the base motion-capture-equivalent for all exercises.
LOCAL_ANIMATIONS = {
    "running": MESHY_ASSETS / "Meshy_AI_Elijah_Bonds_biped" / "Meshy_AI_Elijah_Bonds_biped_Animation_Running_withSkin.glb",
    "walking": MESHY_ASSETS / "Meshy_AI_Elijah_Bonds_biped" / "Meshy_AI_Elijah_Bonds_biped_Animation_Walking_withSkin.glb",
}

# ── Character Models ────────────────────────────────────────────────────
LOCAL_CHARACTERS = {
    "elijah_bonds_running": LOCAL_ANIMATIONS["running"],
    "elijah_bonds_walking": LOCAL_ANIMATIONS["walking"],
    "amir_smith": MESHY_ASSETS / "Meshy_AI_Amir_Smith_0319064218_texture.glb",
    "eric_nash": MESHY_ASSETS / "Meshy_AI_Eric_Nash_0319064148_texture.glb",
    "hoopbus": MESHY_ASSETS / "Meshy_AI_HoopBus_Basketball_0319064117_texture.glb",
}

# ── Prop Assets (Meshy GLBs) ───────────────────────────────────────────
LOCAL_PROPS = {
    "tennis_ball": FEL_EXTERNAL_MESHY / "Meshy_AI_Tennis_Ball_Bright__0323202210_texture.glb",
    "soccer_ball": FEL_EXTERNAL_MESHY / "Meshy_AI_Soccer_Ball_FIFA_st_0323202119_texture.glb",
    "tennis_racket": FEL_EXTERNAL_MESHY / "Meshy_AI_Tennis_Racket_Profe_0323202215_texture.glb",
    "goal_posts": FEL_EXTERNAL_MESHY / "Meshy_AI_Goal_Posts_Professi_0323202113_texture.glb",
    "soccer_stadium": FEL_EXTERNAL_MESHY / "Meshy_AI_Stadium_Soccer_stad_0323202143_stylize.glb",
}

# ── Environment Assets ─────────────────────────────────────────────────
LOCAL_ENVIRONMENTS = {
    "venice_beach_glb": MESHY_ASSETS / "Meshy_AI_Venice_beach_basketba_0319064051_texture.glb",
    "venice_beach_obj": MESHY_ASSETS / "Venice_beach_UE5" / "Venice_mesh.obj",
    "luma_venice_primary": LUMA_SCAN / "mesh.obj",
    "luma_capture_03": LUMA_EXPORTS / "capture_03" / "mesh.obj",
    "luma_capture_04": LUMA_EXPORTS / "capture_04" / "mesh.obj",
    "luma_capture_05": LUMA_EXPORTS / "capture_05" / "mesh.obj",
    "soccer_stadium_glb": FEL_EXTERNAL_MESHY / "Meshy_AI_Stadium_Soccer_stad_0323202143_stylize.glb",
}

# ── Exercise → Animation Mapping ───────────────────────────────────────
# Maps each exercise_id to the best-fit local animation.
# High-energy / running exercises → Running animation
# Slow / mobility / recovery exercises → Walking animation
EXERCISE_ANIMATION_MAP: dict[str, str] = {
    # Warm-Up — mostly dynamic/running-type motions
    "dynamic_lunge_walk": "walking",
    "arm_circles_progressive": "walking",
    "high_knees": "running",
    "lateral_shuffle": "running",
    # Strength — mixed intensity
    "squat_form": "walking",
    "box_jump": "running",
    "pushup_explosive": "running",
    "deadlift_hip_hinge": "walking",
    # Mobility — slow/controlled
    "hip_90_90": "walking",
    "thoracic_rotation": "walking",
    "ankle_dorsiflexion": "walking",
    "shoulder_dislocate": "walking",
    # Sport-Specific — dynamic
    "dunk_approach": "running",
    "golf_swing_drill": "walking",
    "kick_form": "running",
    "serve_motion": "running",
    "karate_kata_basic": "running",
    "surf_popup": "running",
    "balance_board": "walking",
    "tumbling_roundoff": "running",
    # Recovery — slow
    "foam_roll_it_band": "walking",
    "pigeon_stretch": "walking",
    "breathing_box": "walking",
}

# ── Exercise → Local Prop Mapping ──────────────────────────────────────
# Maps exercise_id to a local prop asset key (if available).
# Only 9 exercises need props; we have local assets for some.
EXERCISE_PROP_MAP: dict[str, str | None] = {
    "serve_motion": "tennis_racket",     # Tennis racket GLB available
    "kick_form": "soccer_ball",           # Soccer ball GLB available
    "squat_form": None,                   # Barbell — needs generation
    "deadlift_hip_hinge": None,           # Barbell — needs generation
    "box_jump": None,                     # Plyo box — needs generation
    "balance_board": None,                # Balance board — needs generation
    "foam_roll_it_band": None,            # Foam roller — needs generation
    "shoulder_dislocate": None,           # Resistance band — needs generation
    "golf_swing_drill": None,             # Golf club — needs generation
}

# ── Venue → Local Environment Mapping ──────────────────────────────────
# Maps venue_key (from environment_generator.py) to local asset(s).
# Venues with None need Meshy API generation.
VENUE_ENVIRONMENT_MAP: dict[str, dict[str, Any]] = {
    "venice_basketball": {
        "local_3d_model": "venice_beach_glb",
        "local_scan": "luma_venice_primary",
        "has_local": True,
        "description": "Venice Beach basketball — Meshy GLB + Luma photogrammetry scan",
    },
    "soccer_stadium": {
        "local_3d_model": "soccer_stadium_glb",
        "local_scan": None,
        "has_local": True,
        "description": "Soccer stadium — Meshy GLB model available",
    },
    "golf_course": {
        "local_3d_model": None,
        "local_scan": None,
        "has_local": False,
        "description": "Golf course — needs Meshy generation",
    },
    "skatepark": {
        "local_3d_model": None,
        "local_scan": None,
        "has_local": False,
        "description": "Skatepark — needs Meshy generation",
    },
    "tennis_court": {
        "local_3d_model": None,
        "local_scan": None,
        "has_local": False,
        "description": "Tennis court — needs Meshy generation",
    },
    "boxing_ring": {
        "local_3d_model": None,
        "local_scan": None,
        "has_local": False,
        "description": "Boxing ring (Dojo/Karate) — needs Meshy generation",
    },
    "surf_beach": {
        "local_3d_model": "venice_beach_glb",  # Reuse Venice Beach for surf
        "local_scan": "luma_capture_04",
        "has_local": True,
        "description": "Surf beach — reusing Venice Beach assets",
    },
    "gymnastics_arena": {
        "local_3d_model": None,
        "local_scan": None,
        "has_local": False,
        "description": "Gymnastics arena — needs Meshy generation",
    },
    "dojo": {
        "local_3d_model": None,
        "local_scan": None,
        "has_local": False,
        "description": "Traditional dojo — needs Meshy generation",
    },
    "snowboard_mountain": {
        "local_3d_model": None,
        "local_scan": None,
        "has_local": False,
        "description": "Snowboard mountain — needs Meshy generation",
    },
    "training_gym": {
        "local_3d_model": None,
        "local_scan": None,
        "has_local": False,
        "description": "Training gym — needs Meshy generation",
    },
    "marketplace": {
        "local_3d_model": None,
        "local_scan": "luma_capture_05",  # Luma scan for shop environment
        "has_local": True,
        "description": "Marketplace — using Luma capture_05 scan",
    },
}

# ── Venue Key → ArenaSettings Game Mode Mapping ────────────────────────
# Maps environment_generator venue_key to ArenaSettings.json venue names
VENUE_TO_ARENA_MAP: dict[str, list[str]] = {
    "venice_basketball": ["basketball_h2h", "basketball_dunk", "basketball_3v3", "surfing"],
    "soccer_stadium": ["soccer"],
    "golf_course": ["golf"],
    "skatepark": ["skateboarding"],
    "tennis_court": ["tennis"],
    "boxing_ring": ["karate", "karate_h2h", "karate_endless"],
    "surf_beach": ["surfing"],
    "gymnastics_arena": ["gymnastics", "snowboarding"],
    "dojo": ["karate", "karate_h2h", "karate_endless", "skateboarding"],
    "snowboard_mountain": ["snowboarding"],
    "training_gym": ["gymnastics", "snowboarding"],
    "marketplace": ["market_browse"],
}


def verify_local_assets() -> dict[str, Any]:
    """Verify which local assets exist on disk and return a report."""
    report: dict[str, Any] = {
        "animations": {},
        "props": {},
        "environments": {},
        "characters": {},
        "summary": {},
    }

    # Check animations
    for key, path in LOCAL_ANIMATIONS.items():
        exists = path.is_file()
        report["animations"][key] = {"path": str(path), "exists": exists}

    # Check props
    for key, path in LOCAL_PROPS.items():
        exists = path.is_file()
        report["props"][key] = {"path": str(path), "exists": exists}

    # Check environments
    for key, path in LOCAL_ENVIRONMENTS.items():
        exists = path.is_file()
        report["environments"][key] = {"path": str(path), "exists": exists}

    # Check characters
    for key, path in LOCAL_CHARACTERS.items():
        exists = path.is_file()
        report["characters"][key] = {"path": str(path), "exists": exists}

    # Summary
    anim_ok = sum(1 for v in report["animations"].values() if v["exists"])
    prop_ok = sum(1 for v in report["props"].values() if v["exists"])
    env_ok = sum(1 for v in report["environments"].values() if v["exists"])
    char_ok = sum(1 for v in report["characters"].values() if v["exists"])

    report["summary"] = {
        "animations": f"{anim_ok}/{len(LOCAL_ANIMATIONS)}",
        "props": f"{prop_ok}/{len(LOCAL_PROPS)}",
        "environments": f"{env_ok}/{len(LOCAL_ENVIRONMENTS)}",
        "characters": f"{char_ok}/{len(LOCAL_CHARACTERS)}",
    }
    return report


def get_exercise_local_animation(exercise_id: str) -> Path | None:
    """Get the local animation file for an exercise, or None if unavailable."""
    anim_key = EXERCISE_ANIMATION_MAP.get(exercise_id)
    if not anim_key:
        return None
    path = LOCAL_ANIMATIONS.get(anim_key)
    if path and path.is_file():
        return path
    return None


def get_exercise_local_prop(exercise_id: str) -> Path | None:
    """Get the local prop file for an exercise, or None."""
    prop_key = EXERCISE_PROP_MAP.get(exercise_id)
    if not prop_key:
        return None
    path = LOCAL_PROPS.get(prop_key)
    if path and path.is_file():
        return path
    return None


def get_venue_local_assets(venue_key: str) -> dict[str, Path | None]:
    """Get local asset paths for a venue."""
    info = VENUE_ENVIRONMENT_MAP.get(venue_key, {})
    result: dict[str, Path | None] = {"model": None, "scan": None}

    model_key = info.get("local_3d_model")
    if model_key:
        path = LOCAL_ENVIRONMENTS.get(model_key)
        if path and path.is_file():
            result["model"] = path

    scan_key = info.get("local_scan")
    if scan_key:
        path = LOCAL_ENVIRONMENTS.get(scan_key)
        if path and path.is_file():
            result["scan"] = path

    return result


def get_exercises_needing_props() -> list[str]:
    """Return exercise IDs that need props but don't have local ones."""
    missing = []
    for ex_id, prop_key in EXERCISE_PROP_MAP.items():
        if prop_key is None:  # No local asset mapped
            missing.append(ex_id)
    return missing


def get_venues_needing_generation() -> list[str]:
    """Return venue keys that need 3D model generation."""
    return [
        key for key, info in VENUE_ENVIRONMENT_MAP.items()
        if not info.get("has_local", False)
    ]
