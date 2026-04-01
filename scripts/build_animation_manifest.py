#!/usr/bin/env python3
"""
Build the comprehensive animation manifest for Final Evolution Lab.

Maps Elijah Bonds motion capture animations to game modes, identifies gaps,
and creates a complete animation mapping for all 16 game modes with both
custom animations and UE5 catalogue fallbacks.

Usage:
  python scripts/build_animation_manifest.py
  python scripts/build_animation_manifest.py --check-files   # Verify animation files exist
"""
from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT_DIR / "GeneratedAssets" / "Animations"
ELIJAHBONDS_DIR = OUTPUT_DIR / "ElijahBonds"
METADATA_FILE = ROOT_DIR / "SourceVideos" / "Instagram" / "video_metadata.json"
MANIFEST_FILE = OUTPUT_DIR / "animation_manifest.json"
UE5_MAPPING_FILE = OUTPUT_DIR / "ue5_animation_mapping.json"
PROCESSING_LOG = ELIJAHBONDS_DIR / "processing_log.json"

# ─── All 16 FEL Game Modes ──────────────────────────────────────────
GAME_MODES = [
    "basketball_5v5", "basketball_3v3", "slam_dunk_contest", "streetball",
    "soccer", "football", "track_and_field", "swimming",
    "tennis", "boxing", "martial_arts", "volleyball",
    "baseball", "gymnastics", "skateboarding", "wrestling",
]

# ─── Movement Categories & Game Mode Mapping ────────────────────────
MOVEMENT_CATEGORIES = {
    # Basketball-specific
    "dunking": {
        "movements": [
            "vertical_jump_dunk", "two_handed_reverse_dunk", "one_handed_alleyoop_dunk",
            "one_handed_front_dunk", "two_handed_front_dunk", "one_handed_reverse_dunk",
            "running_dunk", "one_handed_dunk", "slam_dunk", "windmill_dunk",
            "self_alleyoop", "reverse_dunk", "slam_dunk_one_handed", "slam_dunk_two_handed",
            "running_approach_dunk", "standing_dunk", "dunk_attempt", "dunk", "dunking",
            "one_handed_slam_dunk", "two_handed_dunk",
        ],
        "game_modes": ["basketball_5v5", "basketball_3v3", "slam_dunk_contest", "streetball"],
        "ue5_fallback": "UE5_Mannequin_Jump_Forward",
    },
    "ball_handling": {
        "movements": [
            "dribbling", "crossover_dribble", "behind_the_back_dribble",
            "lateral_shuffle_dribble", "ball_tricks_ground_bounce",
        ],
        "game_modes": ["basketball_5v5", "basketball_3v3", "streetball"],
        "ue5_fallback": "UE5_Mannequin_Jog_Fwd",
    },
    "shooting": {
        "movements": [
            "jump_shot", "mid_range_shot", "shooting", "layup",
        ],
        "game_modes": ["basketball_5v5", "basketball_3v3", "streetball"],
        "ue5_fallback": "UE5_Mannequin_Jump_Forward",
    },
    "passing": {
        "movements": [
            "passing", "behind_the_back_pass",
        ],
        "game_modes": ["basketball_5v5", "basketball_3v3", "streetball", "football", "soccer", "volleyball"],
        "ue5_fallback": "UE5_Mannequin_Throw",
    },
    "driving": {
        "movements": [
            "drive_to_basket", "aggressive_drive", "euro_step",
        ],
        "game_modes": ["basketball_5v5", "basketball_3v3", "streetball"],
        "ue5_fallback": "UE5_Mannequin_Sprint_Fwd",
    },
    "defense": {
        "movements": [
            "defensive_stance", "lateral_shuffle",
        ],
        "game_modes": ["basketball_5v5", "basketball_3v3", "streetball", "football", "soccer",
                        "tennis", "boxing", "martial_arts", "volleyball", "wrestling"],
        "ue5_fallback": "UE5_Mannequin_Idle_Ready",
    },
    "locomotion": {
        "movements": [
            "running", "sprinting", "running_approach", "running_to_basket",
            "quick_direction_change", "jumping", "explosive_jump", "explosive_vertical_jump",
        ],
        "game_modes": GAME_MODES,  # Universal
        "ue5_fallback": "UE5_Mannequin_Run_Fwd",
    },
    "celebration": {
        "movements": [
            "celebration_chest_bump",
        ],
        "game_modes": GAME_MODES,  # Universal
        "ue5_fallback": "UE5_Mannequin_Victory",
    },
    "acrobatic": {
        "movements": [
            "mid_air_body_rotation", "dribble_approach",
        ],
        "game_modes": ["slam_dunk_contest", "gymnastics", "skateboarding", "martial_arts"],
        "ue5_fallback": "UE5_Mannequin_Jump_Spin",
    },
}

# ─── UE5 Built-in Animation Catalogue (for gaps) ───────────────────
UE5_ANIMATION_CATALOGUE = {
    # Swimming
    "swimming_freestyle": {"asset": "/Game/Characters/Mannequins/Animations/Swim_Freestyle", "source": "UE5_Marketplace", "category": "swimming"},
    "swimming_backstroke": {"asset": "/Game/Characters/Mannequins/Animations/Swim_Backstroke", "source": "UE5_Marketplace", "category": "swimming"},
    "swimming_butterfly": {"asset": "/Game/Characters/Mannequins/Animations/Swim_Butterfly", "source": "UE5_Marketplace", "category": "swimming"},
    "swimming_dive": {"asset": "/Game/Characters/Mannequins/Animations/Swim_Dive", "source": "UE5_Marketplace", "category": "swimming"},
    "swimming_turn": {"asset": "/Game/Characters/Mannequins/Animations/Swim_Turn", "source": "UE5_Marketplace", "category": "swimming"},
    # Tennis
    "tennis_forehand": {"asset": "/Game/Characters/Mannequins/Animations/Tennis_Forehand", "source": "UE5_Marketplace", "category": "tennis"},
    "tennis_backhand": {"asset": "/Game/Characters/Mannequins/Animations/Tennis_Backhand", "source": "UE5_Marketplace", "category": "tennis"},
    "tennis_serve": {"asset": "/Game/Characters/Mannequins/Animations/Tennis_Serve", "source": "UE5_Marketplace", "category": "tennis"},
    "tennis_volley": {"asset": "/Game/Characters/Mannequins/Animations/Tennis_Volley", "source": "UE5_Marketplace", "category": "tennis"},
    # Boxing
    "boxing_jab": {"asset": "/Game/Characters/Mannequins/Animations/Boxing_Jab", "source": "UE5_Marketplace", "category": "boxing"},
    "boxing_cross": {"asset": "/Game/Characters/Mannequins/Animations/Boxing_Cross", "source": "UE5_Marketplace", "category": "boxing"},
    "boxing_hook": {"asset": "/Game/Characters/Mannequins/Animations/Boxing_Hook", "source": "UE5_Marketplace", "category": "boxing"},
    "boxing_uppercut": {"asset": "/Game/Characters/Mannequins/Animations/Boxing_Uppercut", "source": "UE5_Marketplace", "category": "boxing"},
    "boxing_block": {"asset": "/Game/Characters/Mannequins/Animations/Boxing_Block", "source": "UE5_Marketplace", "category": "boxing"},
    "boxing_dodge": {"asset": "/Game/Characters/Mannequins/Animations/Boxing_Dodge", "source": "UE5_Marketplace", "category": "boxing"},
    # Martial Arts
    "martial_arts_kick": {"asset": "/Game/Characters/Mannequins/Animations/MartialArts_Kick", "source": "UE5_Marketplace", "category": "martial_arts"},
    "martial_arts_punch": {"asset": "/Game/Characters/Mannequins/Animations/MartialArts_Punch", "source": "UE5_Marketplace", "category": "martial_arts"},
    "martial_arts_block": {"asset": "/Game/Characters/Mannequins/Animations/MartialArts_Block", "source": "UE5_Marketplace", "category": "martial_arts"},
    "martial_arts_kata": {"asset": "/Game/Characters/Mannequins/Animations/MartialArts_Kata", "source": "UE5_Marketplace", "category": "martial_arts"},
    # Football
    "football_throw": {"asset": "/Game/Characters/Mannequins/Animations/Football_Throw", "source": "UE5_Marketplace", "category": "football"},
    "football_catch": {"asset": "/Game/Characters/Mannequins/Animations/Football_Catch", "source": "UE5_Marketplace", "category": "football"},
    "football_tackle": {"asset": "/Game/Characters/Mannequins/Animations/Football_Tackle", "source": "UE5_Marketplace", "category": "football"},
    "football_hike": {"asset": "/Game/Characters/Mannequins/Animations/Football_Hike", "source": "UE5_Marketplace", "category": "football"},
    # Soccer
    "soccer_kick": {"asset": "/Game/Characters/Mannequins/Animations/Soccer_Kick", "source": "UE5_Marketplace", "category": "soccer"},
    "soccer_header": {"asset": "/Game/Characters/Mannequins/Animations/Soccer_Header", "source": "UE5_Marketplace", "category": "soccer"},
    "soccer_save": {"asset": "/Game/Characters/Mannequins/Animations/Soccer_GoalieSave", "source": "UE5_Marketplace", "category": "soccer"},
    "soccer_dribble": {"asset": "/Game/Characters/Mannequins/Animations/Soccer_Dribble", "source": "UE5_Marketplace", "category": "soccer"},
    # Volleyball
    "volleyball_serve": {"asset": "/Game/Characters/Mannequins/Animations/Volleyball_Serve", "source": "UE5_Marketplace", "category": "volleyball"},
    "volleyball_spike": {"asset": "/Game/Characters/Mannequins/Animations/Volleyball_Spike", "source": "UE5_Marketplace", "category": "volleyball"},
    "volleyball_set": {"asset": "/Game/Characters/Mannequins/Animations/Volleyball_Set", "source": "UE5_Marketplace", "category": "volleyball"},
    "volleyball_dig": {"asset": "/Game/Characters/Mannequins/Animations/Volleyball_Dig", "source": "UE5_Marketplace", "category": "volleyball"},
    # Baseball
    "baseball_pitch": {"asset": "/Game/Characters/Mannequins/Animations/Baseball_Pitch", "source": "UE5_Marketplace", "category": "baseball"},
    "baseball_bat_swing": {"asset": "/Game/Characters/Mannequins/Animations/Baseball_BatSwing", "source": "UE5_Marketplace", "category": "baseball"},
    "baseball_catch": {"asset": "/Game/Characters/Mannequins/Animations/Baseball_Catch", "source": "UE5_Marketplace", "category": "baseball"},
    "baseball_slide": {"asset": "/Game/Characters/Mannequins/Animations/Baseball_Slide", "source": "UE5_Marketplace", "category": "baseball"},
    # Track & Field
    "track_sprint_start": {"asset": "/Game/Characters/Mannequins/Animations/Track_SprintStart", "source": "UE5_Marketplace", "category": "track_and_field"},
    "track_hurdle": {"asset": "/Game/Characters/Mannequins/Animations/Track_Hurdle", "source": "UE5_Marketplace", "category": "track_and_field"},
    "track_high_jump": {"asset": "/Game/Characters/Mannequins/Animations/Track_HighJump", "source": "UE5_Marketplace", "category": "track_and_field"},
    "track_long_jump": {"asset": "/Game/Characters/Mannequins/Animations/Track_LongJump", "source": "UE5_Marketplace", "category": "track_and_field"},
    "track_javelin": {"asset": "/Game/Characters/Mannequins/Animations/Track_Javelin", "source": "UE5_Marketplace", "category": "track_and_field"},
    # Gymnastics
    "gymnastics_flip": {"asset": "/Game/Characters/Mannequins/Animations/Gymnastics_Flip", "source": "UE5_Marketplace", "category": "gymnastics"},
    "gymnastics_handstand": {"asset": "/Game/Characters/Mannequins/Animations/Gymnastics_Handstand", "source": "UE5_Marketplace", "category": "gymnastics"},
    "gymnastics_cartwheel": {"asset": "/Game/Characters/Mannequins/Animations/Gymnastics_Cartwheel", "source": "UE5_Marketplace", "category": "gymnastics"},
    "gymnastics_vault": {"asset": "/Game/Characters/Mannequins/Animations/Gymnastics_Vault", "source": "UE5_Marketplace", "category": "gymnastics"},
    # Skateboarding
    "skateboard_ollie": {"asset": "/Game/Characters/Mannequins/Animations/Skateboard_Ollie", "source": "UE5_Marketplace", "category": "skateboarding"},
    "skateboard_kickflip": {"asset": "/Game/Characters/Mannequins/Animations/Skateboard_Kickflip", "source": "UE5_Marketplace", "category": "skateboarding"},
    "skateboard_grind": {"asset": "/Game/Characters/Mannequins/Animations/Skateboard_Grind", "source": "UE5_Marketplace", "category": "skateboarding"},
    "skateboard_push": {"asset": "/Game/Characters/Mannequins/Animations/Skateboard_Push", "source": "UE5_Marketplace", "category": "skateboarding"},
    # Wrestling
    "wrestling_grapple": {"asset": "/Game/Characters/Mannequins/Animations/Wrestling_Grapple", "source": "UE5_Marketplace", "category": "wrestling"},
    "wrestling_takedown": {"asset": "/Game/Characters/Mannequins/Animations/Wrestling_Takedown", "source": "UE5_Marketplace", "category": "wrestling"},
    "wrestling_pin": {"asset": "/Game/Characters/Mannequins/Animations/Wrestling_Pin", "source": "UE5_Marketplace", "category": "wrestling"},
    "wrestling_escape": {"asset": "/Game/Characters/Mannequins/Animations/Wrestling_Escape", "source": "UE5_Marketplace", "category": "wrestling"},
    # Universal (from UE5 Mannequin)
    "idle": {"asset": "/Game/Characters/Mannequins/Animations/Manny/MM_Idle", "source": "UE5_Mannequin", "category": "universal"},
    "walk": {"asset": "/Game/Characters/Mannequins/Animations/Manny/MM_Walk_Fwd", "source": "UE5_Mannequin", "category": "universal"},
    "run": {"asset": "/Game/Characters/Mannequins/Animations/Manny/MM_Run_Fwd", "source": "UE5_Mannequin", "category": "universal"},
    "sprint": {"asset": "/Game/Characters/Mannequins/Animations/Manny/MM_Sprint_Fwd", "source": "UE5_Mannequin", "category": "universal"},
    "jump": {"asset": "/Game/Characters/Mannequins/Animations/Manny/MM_Jump", "source": "UE5_Mannequin", "category": "universal"},
    "land": {"asset": "/Game/Characters/Mannequins/Animations/Manny/MM_Land", "source": "UE5_Mannequin", "category": "universal"},
}


def build_elijah_bonds_animations(metadata: dict) -> list[dict]:
    """Build the list of custom animations from Elijah Bonds videos."""
    animations = []

    for video in metadata["videos"]:
        filename = video["filename"]
        basename = Path(filename).stem
        anim_dir = ELIJAHBONDS_DIR / basename

        for movement in video.get("movements", []):
            # Determine which categories this movement belongs to
            categories = []
            target_game_modes = set()
            for cat_name, cat_info in MOVEMENT_CATEGORIES.items():
                if movement in cat_info["movements"]:
                    categories.append(cat_name)
                    target_game_modes.update(cat_info["game_modes"])

            if not categories:
                categories = ["uncategorized"]
                target_game_modes = set(video.get("suggested_game_modes", ["basketball_5v5"]))

            # Check if animation files exist
            fbx_path = anim_dir / f"{basename}.fbx"
            bvh_path = anim_dir / f"{basename}.bvh"
            has_fbx = fbx_path.exists()
            has_bvh = bvh_path.exists()

            animations.append({
                "animation_id": f"eb_{basename}_{movement}",
                "source": "elijah_bonds_mocap",
                "source_video": filename,
                "source_video_url": video.get("video_url", ""),
                "movement_type": movement,
                "movement_categories": categories,
                "target_game_modes": sorted(target_game_modes),
                "priority": video.get("deepmotion_priority", "medium"),
                "animation_files": {
                    "fbx": str(fbx_path) if has_fbx else str(fbx_path) + " (pending)",
                    "bvh": str(bvh_path) if has_bvh else str(bvh_path) + " (pending)",
                },
                "files_exist": has_fbx or has_bvh,
                "ue5_import_path": f"/Game/FEL/Animations/ElijahBonds/{basename}/{movement}",
                "description": video.get("description", ""),
                "duration_seconds": video.get("duration_seconds", 0),
                "motion_capture_notes": video.get("motion_capture_notes", ""),
            })

    return animations


def build_game_mode_mapping(custom_animations: list[dict]) -> dict:
    """Build the comprehensive animation mapping for all 16 game modes."""
    mapping = {}

    for mode in GAME_MODES:
        mode_info = {
            "game_mode": mode,
            "custom_animations": [],
            "ue5_catalogue_animations": [],
            "coverage_summary": {},
        }

        # Find custom animations for this mode
        for anim in custom_animations:
            if mode in anim["target_game_modes"]:
                mode_info["custom_animations"].append({
                    "animation_id": anim["animation_id"],
                    "movement_type": anim["movement_type"],
                    "categories": anim["movement_categories"],
                    "fbx_path": anim["animation_files"]["fbx"],
                    "ue5_path": anim["ue5_import_path"],
                    "priority": anim["priority"],
                    "files_ready": anim["files_exist"],
                })

        # Find UE5 catalogue animations for this mode
        for anim_id, anim_info in UE5_ANIMATION_CATALOGUE.items():
            cat = anim_info.get("category", "")
            # Map category to game modes
            cat_to_modes = {
                "swimming": ["swimming"],
                "tennis": ["tennis"],
                "boxing": ["boxing"],
                "martial_arts": ["martial_arts"],
                "football": ["football"],
                "soccer": ["soccer"],
                "volleyball": ["volleyball"],
                "baseball": ["baseball"],
                "track_and_field": ["track_and_field"],
                "gymnastics": ["gymnastics"],
                "skateboarding": ["skateboarding"],
                "wrestling": ["wrestling"],
                "universal": GAME_MODES,
            }
            applicable_modes = cat_to_modes.get(cat, [])
            if mode in applicable_modes:
                mode_info["ue5_catalogue_animations"].append({
                    "animation_id": anim_id,
                    "asset_path": anim_info["asset"],
                    "source": anim_info["source"],
                    "category": cat,
                })

        # Calculate coverage
        custom_count = len(mode_info["custom_animations"])
        catalogue_count = len(mode_info["ue5_catalogue_animations"])
        total = custom_count + catalogue_count

        # Determine categories with custom animations
        custom_categories = set()
        for a in mode_info["custom_animations"]:
            custom_categories.update(a["categories"])

        mode_info["coverage_summary"] = {
            "custom_animation_count": custom_count,
            "ue5_catalogue_count": catalogue_count,
            "total_animations": total,
            "custom_categories": sorted(custom_categories),
            "has_custom_content": custom_count > 0,
            "needs_catalogue_fill": mode not in [
                "basketball_5v5", "basketball_3v3", "slam_dunk_contest", "streetball"
            ],
        }

        mapping[mode] = mode_info

    return mapping


def identify_gaps(game_mode_mapping: dict) -> dict:
    """Identify animation gaps that need to be filled."""
    gaps = {
        "fully_covered_by_custom": [],
        "partially_covered": [],
        "needs_full_catalogue": [],
        "gap_details": {},
    }

    for mode, info in game_mode_mapping.items():
        summary = info["coverage_summary"]
        if summary["custom_animation_count"] > 10:
            gaps["fully_covered_by_custom"].append(mode)
        elif summary["custom_animation_count"] > 0:
            gaps["partially_covered"].append(mode)
        else:
            gaps["needs_full_catalogue"].append(mode)

        # Identify specific missing animation types per mode
        mode_needs = {
            "basketball_5v5": ["idle", "run", "sprint", "jump", "dribble", "shoot", "dunk", "pass", "defend", "layup"],
            "basketball_3v3": ["idle", "run", "sprint", "jump", "dribble", "shoot", "dunk", "pass", "defend"],
            "slam_dunk_contest": ["run", "jump", "dunk_variations", "celebration", "acrobatic"],
            "streetball": ["idle", "run", "dribble", "shoot", "dunk", "pass", "tricks"],
            "soccer": ["idle", "run", "sprint", "kick", "header", "dribble", "pass", "defend", "save"],
            "football": ["idle", "run", "sprint", "throw", "catch", "tackle", "hike", "defend"],
            "track_and_field": ["sprint_start", "sprint", "hurdle", "high_jump", "long_jump", "javelin"],
            "swimming": ["freestyle", "backstroke", "butterfly", "dive", "turn"],
            "tennis": ["idle", "run", "forehand", "backhand", "serve", "volley", "defend"],
            "boxing": ["idle", "jab", "cross", "hook", "uppercut", "block", "dodge", "defend"],
            "martial_arts": ["idle", "kick", "punch", "block", "kata", "defend"],
            "volleyball": ["idle", "run", "jump", "serve", "spike", "set", "dig"],
            "baseball": ["idle", "run", "pitch", "bat_swing", "catch", "slide"],
            "gymnastics": ["flip", "handstand", "cartwheel", "vault", "acrobatic"],
            "skateboarding": ["ollie", "kickflip", "grind", "push"],
            "wrestling": ["idle", "grapple", "takedown", "pin", "escape", "defend"],
        }

        needed = mode_needs.get(mode, [])
        custom_movements = set()
        for a in info["custom_animations"]:
            custom_movements.add(a["movement_type"])
            custom_movements.update(a["categories"])

        missing = [n for n in needed if n not in custom_movements]
        gaps["gap_details"][mode] = {
            "needed_types": needed,
            "covered_by_custom": [n for n in needed if n in custom_movements],
            "missing_needs_catalogue": missing,
            "coverage_percentage": round((1 - len(missing) / max(len(needed), 1)) * 100, 1),
        }

    return gaps


def build_manifest():
    """Build the complete animation manifest."""
    # Load metadata
    with open(METADATA_FILE) as f:
        metadata = json.load(f)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ELIJAHBONDS_DIR.mkdir(parents=True, exist_ok=True)

    # Build custom animations list
    custom_animations = build_elijah_bonds_animations(metadata)

    # Build game mode mapping
    game_mode_mapping = build_game_mode_mapping(custom_animations)

    # Identify gaps
    gaps = identify_gaps(game_mode_mapping)

    # Check processing log
    processing_status = "not_started"
    processed_count = 0
    if PROCESSING_LOG.exists():
        with open(PROCESSING_LOG) as f:
            log = json.load(f)
            processed_count = log.get("total_success", 0)
            if processed_count > 0:
                processing_status = "partial" if processed_count < 10 else "complete"

    # Build the manifest
    manifest = {
        "manifest_version": "2.0",
        "created": datetime.now(timezone.utc).isoformat(),
        "project": "Final Evolution Lab",
        "source_athlete": {
            "name": "Elijah Bonds",
            "instagram": "@elijahbonds",
            "profile": metadata.get("profile_description", ""),
        },
        "processing_status": {
            "deepmotion_status": processing_status,
            "videos_total": len(metadata.get("videos", [])),
            "videos_processed": processed_count,
            "animations_ready": sum(1 for a in custom_animations if a["files_exist"]),
            "animations_pending": sum(1 for a in custom_animations if not a["files_exist"]),
        },
        "statistics": {
            "total_custom_animations": len(custom_animations),
            "total_unique_movements": len(set(a["movement_type"] for a in custom_animations)),
            "total_ue5_catalogue_animations": len(UE5_ANIMATION_CATALOGUE),
            "game_modes_with_custom": len(gaps["fully_covered_by_custom"]) + len(gaps["partially_covered"]),
            "game_modes_catalogue_only": len(gaps["needs_full_catalogue"]),
        },
        "custom_animations": custom_animations,
        "game_mode_coverage": {
            "fully_covered_by_custom": gaps["fully_covered_by_custom"],
            "partially_covered": gaps["partially_covered"],
            "needs_full_catalogue": gaps["needs_full_catalogue"],
        },
        "gap_analysis": gaps["gap_details"],
    }

    # Save manifest
    with open(MANIFEST_FILE, "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"✓ Animation manifest saved: {MANIFEST_FILE}")

    # Save UE5 mapping
    ue5_mapping = {
        "mapping_version": "2.0",
        "created": datetime.now(timezone.utc).isoformat(),
        "game_modes": game_mode_mapping,
        "ue5_catalogue": UE5_ANIMATION_CATALOGUE,
        "import_instructions": {
            "custom_animations": {
                "source": "DeepMotion Animate 3D → FBX/BVH",
                "import_path": "/Game/FEL/Animations/ElijahBonds/",
                "steps": [
                    "Run DeepMotion processing: python scripts/process_elijahbonds_animations.py",
                    "Import FBX files into UE5: Content Browser → Import",
                    "Or use automated import: python UnrealStarter/BasketballGame/EditorPython/fel_import_ai_assets.py",
                    "Create Animation Montages from imported sequences",
                    "Set up Animation Blueprint references",
                ],
            },
            "ue5_catalogue": {
                "source": "UE5 Marketplace / Mannequin Pack",
                "notes": [
                    "Download required animation packs from UE5 Marketplace",
                    "Sport-specific packs may require purchase",
                    "Universal animations (idle, walk, run, jump) come with UE5 Mannequin",
                    "Retarget animations using IK Retargeter if skeleton differs",
                ],
            },
        },
    }

    with open(UE5_MAPPING_FILE, "w") as f:
        json.dump(ue5_mapping, f, indent=2)
    print(f"✓ UE5 animation mapping saved: {UE5_MAPPING_FILE}")

    # Print summary
    print("\n" + "=" * 70)
    print("ANIMATION MANIFEST SUMMARY")
    print("=" * 70)
    print(f"\n📊 Custom Animations (Elijah Bonds): {len(custom_animations)}")
    print(f"   Unique movements: {manifest['statistics']['total_unique_movements']}")
    print(f"   Files ready: {manifest['processing_status']['animations_ready']}")
    print(f"   Files pending (need DeepMotion): {manifest['processing_status']['animations_pending']}")

    print(f"\n🎮 Game Mode Coverage (16 total):")
    print(f"   ✅ Fully covered by custom: {gaps['fully_covered_by_custom']}")
    print(f"   🔶 Partially covered: {gaps['partially_covered']}")
    print(f"   📦 Needs UE5 catalogue: {gaps['needs_full_catalogue']}")

    print(f"\n📈 Coverage by Game Mode:")
    for mode, details in gaps["gap_details"].items():
        pct = details["coverage_percentage"]
        bar = "█" * int(pct / 5) + "░" * (20 - int(pct / 5))
        print(f"   {mode:25s} {bar} {pct:5.1f}%")

    print(f"\n📦 UE5 Catalogue Animations: {len(UE5_ANIMATION_CATALOGUE)}")
    print("=" * 70)

    return manifest


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-files", action="store_true")
    args = parser.parse_args()

    manifest = build_manifest()

    if args.check_files:
        print("\n🔍 Checking animation files...")
        for anim in manifest["custom_animations"]:
            fbx = anim["animation_files"]["fbx"]
            status = "✓" if anim["files_exist"] else "✗ (pending DeepMotion processing)"
            print(f"   {status} {anim['animation_id']}")
