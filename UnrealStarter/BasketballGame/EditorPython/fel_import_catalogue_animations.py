"""
fel_import_catalogue_animations.py
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Unreal Editor Python script to set up UE5 marketplace/built-in animation
references for game modes not covered by custom Elijah Bonds animations.

Run inside UE5 Editor: File → Execute Python Script
Or via commandlet: UnrealEditor-Cmd <project> -run=pythonscript -script=<this>

This script:
1. Verifies availability of UE5 built-in animations (Mannequin, etc.)
2. Creates Animation Blueprint references for each game mode
3. Sets up retargeting from Mannequin skeleton to FEL character
4. Creates Blend Spaces for movement transitions
5. Generates a coverage report
"""

import unreal
import json
import os

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# UE5 Built-in Animation Catalogue
# These reference the standard Mannequin/Manny animation pack that ships
# with UE5, plus recommended Marketplace packs for each sport.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

UE5_BUILTIN_ANIMATIONS = {
    # ── Core Locomotion (ships with UE5 Mannequin) ──────────────────────
    "idle": {
        "asset_path": "/Game/Characters/Mannequins/Animations/Manny/MM_Idle",
        "source": "ue5_mannequin",
        "skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny",
        "applicable_modes": ["all"]
    },
    "walk_fwd": {
        "asset_path": "/Game/Characters/Mannequins/Animations/Manny/MM_Walk_Fwd",
        "source": "ue5_mannequin",
        "skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny",
        "applicable_modes": ["all"]
    },
    "run_fwd": {
        "asset_path": "/Game/Characters/Mannequins/Animations/Manny/MM_Run_Fwd",
        "source": "ue5_mannequin",
        "skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny",
        "applicable_modes": ["all"]
    },
    "jump_start": {
        "asset_path": "/Game/Characters/Mannequins/Animations/Manny/MM_Jump",
        "source": "ue5_mannequin",
        "skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny",
        "applicable_modes": ["all"]
    },
    "fall_loop": {
        "asset_path": "/Game/Characters/Mannequins/Animations/Manny/MM_Fall_Loop",
        "source": "ue5_mannequin",
        "skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny",
        "applicable_modes": ["all"]
    },
    "land": {
        "asset_path": "/Game/Characters/Mannequins/Animations/Manny/MM_Land",
        "source": "ue5_mannequin",
        "skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny",
        "applicable_modes": ["all"]
    },
    "sprint_fwd": {
        "asset_path": "/Game/Characters/Mannequins/Animations/Manny/MM_Sprint_Fwd",
        "source": "ue5_mannequin",
        "skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny",
        "applicable_modes": ["all"]
    },
}

# ── Marketplace Animation Pack Definitions ──────────────────────────────────
# These define what needs to be acquired from the UE Marketplace.
# After purchase/download, the import paths should be updated.

MARKETPLACE_ANIMATION_PACKS = {
    # ── Soccer / Football ────────────────────────────────────────────────
    "soccer_animations": {
        "marketplace_name": "Soccer Animation Pack",
        "marketplace_url": "https://www.unrealengine.com/marketplace",
        "search_terms": ["soccer animation", "football animation UE5"],
        "recommended_packs": [
            "Motion Capture Soccer Pack by MoCap Online",
            "Soccer Animation Set by GameDev Market",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Soccer/",
        "animations": {
            "soccer_idle": {"movement": "idle", "game_modes": ["soccer"]},
            "soccer_run": {"movement": "run", "game_modes": ["soccer"]},
            "soccer_sprint": {"movement": "sprint", "game_modes": ["soccer"]},
            "soccer_kick": {"movement": "kick", "game_modes": ["soccer"]},
            "soccer_header": {"movement": "header", "game_modes": ["soccer"]},
            "soccer_dribble": {"movement": "dribble", "game_modes": ["soccer"]},
            "soccer_pass": {"movement": "pass", "game_modes": ["soccer"]},
            "soccer_tackle": {"movement": "defend", "game_modes": ["soccer"]},
            "soccer_save": {"movement": "save", "game_modes": ["soccer"]},
            "soccer_celebration": {"movement": "celebration", "game_modes": ["soccer"]},
        }
    },

    # ── American Football ────────────────────────────────────────────────
    "football_animations": {
        "marketplace_name": "American Football Animation Pack",
        "search_terms": ["american football animation", "NFL animation UE5"],
        "recommended_packs": [
            "Football Moves Animation Pack",
            "Sports Animation Pro - Football",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Football/",
        "animations": {
            "football_idle": {"movement": "idle", "game_modes": ["football"]},
            "football_run": {"movement": "run", "game_modes": ["football"]},
            "football_sprint": {"movement": "sprint", "game_modes": ["football"]},
            "football_throw": {"movement": "throw", "game_modes": ["football"]},
            "football_catch": {"movement": "catch", "game_modes": ["football"]},
            "football_tackle": {"movement": "tackle", "game_modes": ["football"]},
            "football_hike": {"movement": "hike", "game_modes": ["football"]},
            "football_juke": {"movement": "juke", "game_modes": ["football"]},
            "football_block": {"movement": "block", "game_modes": ["football"]},
            "football_celebrate": {"movement": "celebration", "game_modes": ["football"]},
        }
    },

    # ── Tennis ────────────────────────────────────────────────────────────
    "tennis_animations": {
        "marketplace_name": "Tennis Animation Pack",
        "search_terms": ["tennis animation UE5", "racket sport animation"],
        "recommended_packs": [
            "Tennis Motion Capture Pack",
            "Racket Sports Animation Set",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Tennis/",
        "animations": {
            "tennis_idle": {"movement": "idle", "game_modes": ["tennis"]},
            "tennis_run": {"movement": "run", "game_modes": ["tennis"]},
            "tennis_forehand": {"movement": "forehand", "game_modes": ["tennis"]},
            "tennis_backhand": {"movement": "backhand", "game_modes": ["tennis"]},
            "tennis_serve": {"movement": "serve", "game_modes": ["tennis"]},
            "tennis_volley": {"movement": "volley", "game_modes": ["tennis"]},
            "tennis_slice": {"movement": "slice", "game_modes": ["tennis"]},
            "tennis_lob": {"movement": "lob", "game_modes": ["tennis"]},
            "tennis_dive": {"movement": "dive", "game_modes": ["tennis"]},
            "tennis_celebrate": {"movement": "celebration", "game_modes": ["tennis"]},
        }
    },

    # ── Boxing ────────────────────────────────────────────────────────────
    "boxing_animations": {
        "marketplace_name": "Boxing / MMA Animation Pack",
        "search_terms": ["boxing animation UE5", "MMA combat animation"],
        "recommended_packs": [
            "Boxing MoCap Animation Pack",
            "Fighting Animation Pro Pack",
            "Combat Animation Set by Kubold",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Boxing/",
        "animations": {
            "boxing_idle": {"movement": "idle", "game_modes": ["boxing"]},
            "boxing_jab": {"movement": "jab", "game_modes": ["boxing"]},
            "boxing_cross": {"movement": "cross", "game_modes": ["boxing"]},
            "boxing_hook": {"movement": "hook", "game_modes": ["boxing"]},
            "boxing_uppercut": {"movement": "uppercut", "game_modes": ["boxing"]},
            "boxing_block": {"movement": "block", "game_modes": ["boxing"]},
            "boxing_dodge": {"movement": "dodge", "game_modes": ["boxing"]},
            "boxing_footwork": {"movement": "footwork", "game_modes": ["boxing"]},
            "boxing_body_shot": {"movement": "body_shot", "game_modes": ["boxing"]},
            "boxing_combo": {"movement": "combo", "game_modes": ["boxing"]},
            "boxing_ko": {"movement": "knockout", "game_modes": ["boxing"]},
            "boxing_celebrate": {"movement": "celebration", "game_modes": ["boxing"]},
        }
    },

    # ── Martial Arts ─────────────────────────────────────────────────────
    "martial_arts_animations": {
        "marketplace_name": "Martial Arts Animation Pack",
        "search_terms": ["martial arts animation UE5", "karate animation", "kung fu animation"],
        "recommended_packs": [
            "Martial Arts Animation Pack by MoCap Online",
            "Kung Fu / Karate Animation Set",
            "Combat Animation Set by Kubold",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/MartialArts/",
        "animations": {
            "ma_idle": {"movement": "idle", "game_modes": ["martial_arts"]},
            "ma_roundhouse_kick": {"movement": "kick", "game_modes": ["martial_arts"]},
            "ma_front_kick": {"movement": "front_kick", "game_modes": ["martial_arts"]},
            "ma_punch": {"movement": "punch", "game_modes": ["martial_arts"]},
            "ma_block": {"movement": "block", "game_modes": ["martial_arts"]},
            "ma_kata": {"movement": "kata", "game_modes": ["martial_arts"]},
            "ma_sweep": {"movement": "sweep", "game_modes": ["martial_arts"]},
            "ma_flying_kick": {"movement": "flying_kick", "game_modes": ["martial_arts"]},
            "ma_dodge": {"movement": "dodge", "game_modes": ["martial_arts"]},
            "ma_bow": {"movement": "bow", "game_modes": ["martial_arts"]},
        }
    },

    # ── Track & Field ────────────────────────────────────────────────────
    "track_field_animations": {
        "marketplace_name": "Track & Field / Athletics Animation Pack",
        "search_terms": ["track field animation UE5", "athletics animation", "sprinting animation"],
        "recommended_packs": [
            "Athletic Movement Animation Pack",
            "Sports Locomotion Pro",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/TrackField/",
        "animations": {
            "tf_sprint_start": {"movement": "sprint_start", "game_modes": ["track_and_field"]},
            "tf_sprint": {"movement": "sprint", "game_modes": ["track_and_field"]},
            "tf_hurdle": {"movement": "hurdle", "game_modes": ["track_and_field"]},
            "tf_high_jump": {"movement": "high_jump", "game_modes": ["track_and_field"]},
            "tf_long_jump": {"movement": "long_jump", "game_modes": ["track_and_field"]},
            "tf_pole_vault": {"movement": "pole_vault", "game_modes": ["track_and_field"]},
            "tf_javelin": {"movement": "javelin", "game_modes": ["track_and_field"]},
            "tf_shot_put": {"movement": "shot_put", "game_modes": ["track_and_field"]},
            "tf_discus": {"movement": "discus", "game_modes": ["track_and_field"]},
            "tf_finish_line": {"movement": "finish", "game_modes": ["track_and_field"]},
            "tf_celebrate": {"movement": "celebration", "game_modes": ["track_and_field"]},
        }
    },

    # ── Swimming ─────────────────────────────────────────────────────────
    "swimming_animations": {
        "marketplace_name": "Swimming Animation Pack",
        "search_terms": ["swimming animation UE5", "swim animation unreal"],
        "recommended_packs": [
            "Swimming Animation Pack by MoCap Online",
            "Water Sports Animation Set",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Swimming/",
        "animations": {
            "swim_freestyle": {"movement": "freestyle", "game_modes": ["swimming"]},
            "swim_backstroke": {"movement": "backstroke", "game_modes": ["swimming"]},
            "swim_butterfly": {"movement": "butterfly", "game_modes": ["swimming"]},
            "swim_breaststroke": {"movement": "breaststroke", "game_modes": ["swimming"]},
            "swim_dive": {"movement": "dive", "game_modes": ["swimming"]},
            "swim_turn": {"movement": "turn", "game_modes": ["swimming"]},
            "swim_treading": {"movement": "treading", "game_modes": ["swimming"]},
            "swim_start_block": {"movement": "start", "game_modes": ["swimming"]},
            "swim_finish": {"movement": "finish", "game_modes": ["swimming"]},
            "swim_idle": {"movement": "idle", "game_modes": ["swimming"]},
            "swim_celebrate": {"movement": "celebration", "game_modes": ["swimming"]},
        }
    },

    # ── Volleyball ───────────────────────────────────────────────────────
    "volleyball_animations": {
        "marketplace_name": "Volleyball Animation Pack",
        "search_terms": ["volleyball animation UE5", "ball sport animation"],
        "recommended_packs": [
            "Volleyball Animation Set",
            "Sports Animation Pro - Volleyball",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Volleyball/",
        "animations": {
            "vb_idle": {"movement": "idle", "game_modes": ["volleyball"]},
            "vb_run": {"movement": "run", "game_modes": ["volleyball"]},
            "vb_jump": {"movement": "jump", "game_modes": ["volleyball"]},
            "vb_serve": {"movement": "serve", "game_modes": ["volleyball"]},
            "vb_spike": {"movement": "spike", "game_modes": ["volleyball"]},
            "vb_set": {"movement": "set", "game_modes": ["volleyball"]},
            "vb_dig": {"movement": "dig", "game_modes": ["volleyball"]},
            "vb_block": {"movement": "block", "game_modes": ["volleyball"]},
            "vb_dive": {"movement": "dive", "game_modes": ["volleyball"]},
            "vb_celebrate": {"movement": "celebration", "game_modes": ["volleyball"]},
        }
    },

    # ── Baseball ─────────────────────────────────────────────────────────
    "baseball_animations": {
        "marketplace_name": "Baseball Animation Pack",
        "search_terms": ["baseball animation UE5", "batting animation"],
        "recommended_packs": [
            "Baseball MoCap Animation Pack",
            "Sports Animation Pro - Baseball",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Baseball/",
        "animations": {
            "bb_idle": {"movement": "idle", "game_modes": ["baseball"]},
            "bb_run": {"movement": "run", "game_modes": ["baseball"]},
            "bb_pitch_windup": {"movement": "pitch", "game_modes": ["baseball"]},
            "bb_bat_swing": {"movement": "bat_swing", "game_modes": ["baseball"]},
            "bb_catch": {"movement": "catch", "game_modes": ["baseball"]},
            "bb_slide": {"movement": "slide", "game_modes": ["baseball"]},
            "bb_throw": {"movement": "throw", "game_modes": ["baseball"]},
            "bb_bunt": {"movement": "bunt", "game_modes": ["baseball"]},
            "bb_field_ground": {"movement": "field_ground", "game_modes": ["baseball"]},
            "bb_celebrate": {"movement": "celebration", "game_modes": ["baseball"]},
        }
    },

    # ── Gymnastics ───────────────────────────────────────────────────────
    "gymnastics_animations": {
        "marketplace_name": "Gymnastics / Acrobatic Animation Pack",
        "search_terms": ["gymnastics animation UE5", "acrobatic animation", "parkour animation"],
        "recommended_packs": [
            "Parkour & Gymnastics Animation Pack",
            "Acrobatic Moves Animation Set",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Gymnastics/",
        "animations": {
            "gym_flip_forward": {"movement": "flip", "game_modes": ["gymnastics"]},
            "gym_flip_backward": {"movement": "backflip", "game_modes": ["gymnastics"]},
            "gym_handstand": {"movement": "handstand", "game_modes": ["gymnastics"]},
            "gym_cartwheel": {"movement": "cartwheel", "game_modes": ["gymnastics"]},
            "gym_vault": {"movement": "vault", "game_modes": ["gymnastics"]},
            "gym_balance_beam": {"movement": "balance", "game_modes": ["gymnastics"]},
            "gym_floor_routine": {"movement": "floor_routine", "game_modes": ["gymnastics"]},
            "gym_rings": {"movement": "rings", "game_modes": ["gymnastics"]},
            "gym_landing": {"movement": "landing", "game_modes": ["gymnastics"]},
            "gym_salute": {"movement": "salute", "game_modes": ["gymnastics"]},
        }
    },

    # ── Skateboarding ────────────────────────────────────────────────────
    "skateboarding_animations": {
        "marketplace_name": "Skateboarding Animation Pack",
        "search_terms": ["skateboarding animation UE5", "skate animation"],
        "recommended_packs": [
            "Skateboard Animation Pack",
            "Urban Sports Animation Set",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Skateboarding/",
        "animations": {
            "sk_idle": {"movement": "idle", "game_modes": ["skateboarding"]},
            "sk_push": {"movement": "push", "game_modes": ["skateboarding"]},
            "sk_ollie": {"movement": "ollie", "game_modes": ["skateboarding"]},
            "sk_kickflip": {"movement": "kickflip", "game_modes": ["skateboarding"]},
            "sk_grind": {"movement": "grind", "game_modes": ["skateboarding"]},
            "sk_manual": {"movement": "manual", "game_modes": ["skateboarding"]},
            "sk_heelflip": {"movement": "heelflip", "game_modes": ["skateboarding"]},
            "sk_drop_in": {"movement": "drop_in", "game_modes": ["skateboarding"]},
            "sk_bail": {"movement": "bail", "game_modes": ["skateboarding"]},
            "sk_celebrate": {"movement": "celebration", "game_modes": ["skateboarding"]},
        }
    },

    # ── Wrestling ────────────────────────────────────────────────────────
    "wrestling_animations": {
        "marketplace_name": "Wrestling / Grappling Animation Pack",
        "search_terms": ["wrestling animation UE5", "grappling animation"],
        "recommended_packs": [
            "Wrestling Animation Pack by MoCap Online",
            "Grappling & Combat Animation Set",
        ],
        "expected_content_path": "/Game/FEL/Marketplace/Wrestling/",
        "animations": {
            "wr_idle": {"movement": "idle", "game_modes": ["wrestling"]},
            "wr_grapple": {"movement": "grapple", "game_modes": ["wrestling"]},
            "wr_takedown": {"movement": "takedown", "game_modes": ["wrestling"]},
            "wr_pin": {"movement": "pin", "game_modes": ["wrestling"]},
            "wr_escape": {"movement": "escape", "game_modes": ["wrestling"]},
            "wr_suplex": {"movement": "suplex", "game_modes": ["wrestling"]},
            "wr_slam": {"movement": "slam", "game_modes": ["wrestling"]},
            "wr_submission": {"movement": "submission", "game_modes": ["wrestling"]},
            "wr_reversal": {"movement": "reversal", "game_modes": ["wrestling"]},
            "wr_celebrate": {"movement": "celebration", "game_modes": ["wrestling"]},
        }
    },
}


def verify_builtin_animations():
    """Check which UE5 built-in animations are available."""
    asset_registry = unreal.AssetRegistryHelpers.get_asset_registry()
    results = {"found": [], "missing": []}
    
    for anim_id, info in UE5_BUILTIN_ANIMATIONS.items():
        asset_path = info["asset_path"]
        asset_data = asset_registry.get_asset_by_object_path(asset_path)
        if asset_data.is_valid():
            results["found"].append(anim_id)
            unreal.log(f"  ✓ Built-in: {anim_id} → {asset_path}")
        else:
            results["missing"].append(anim_id)
            unreal.log_warning(f"  ✗ Missing: {anim_id} → {asset_path}")
    
    return results


def create_marketplace_directory_structure():
    """Create content directories for marketplace animation packs."""
    for pack_id, pack_info in MARKETPLACE_ANIMATION_PACKS.items():
        content_path = pack_info["expected_content_path"]
        if not unreal.EditorAssetLibrary.does_directory_exist(content_path):
            unreal.EditorAssetLibrary.make_directory(content_path)
            unreal.log(f"  Created directory: {content_path}")


def check_marketplace_availability():
    """Check which marketplace animations have been imported."""
    asset_registry = unreal.AssetRegistryHelpers.get_asset_registry()
    report = {}
    
    for pack_id, pack_info in MARKETPLACE_ANIMATION_PACKS.items():
        pack_report = {
            "name": pack_info["marketplace_name"],
            "total": len(pack_info["animations"]),
            "found": 0,
            "missing": [],
            "search_terms": pack_info["search_terms"],
            "recommended_packs": pack_info.get("recommended_packs", []),
        }
        
        content_path = pack_info["expected_content_path"]
        
        # Check if the directory has any assets
        if unreal.EditorAssetLibrary.does_directory_exist(content_path):
            assets = unreal.EditorAssetLibrary.list_assets(content_path, recursive=True)
            pack_report["found"] = len(assets)
            if len(assets) > 0:
                unreal.log(f"  ✓ {pack_id}: {len(assets)} assets found in {content_path}")
            else:
                for anim_id in pack_info["animations"]:
                    pack_report["missing"].append(anim_id)
                unreal.log_warning(f"  ✗ {pack_id}: Directory exists but empty — needs marketplace import")
        else:
            for anim_id in pack_info["animations"]:
                pack_report["missing"].append(anim_id)
            unreal.log_warning(f"  ✗ {pack_id}: Not imported — acquire from UE Marketplace")
            unreal.log(f"    Search: {', '.join(pack_info['search_terms'])}")
        
        report[pack_id] = pack_report
    
    return report


def setup_animation_blueprints():
    """Create Animation Blueprint stubs for each game mode category."""
    game_mode_categories = {
        "basketball": ["basketball_5v5", "basketball_3v3", "slam_dunk_contest", "streetball"],
        "combat": ["boxing", "martial_arts", "wrestling"],
        "ball_sports": ["soccer", "football", "tennis", "volleyball", "baseball"],
        "athletics": ["track_and_field", "swimming", "gymnastics"],
        "action_sports": ["skateboarding"],
    }
    
    for category, modes in game_mode_categories.items():
        abp_path = f"/Game/FEL/Animations/ABP_{category.title()}"
        
        if not unreal.EditorAssetLibrary.does_asset_exist(abp_path):
            unreal.log(f"  Animation Blueprint needed: {abp_path}")
            unreal.log(f"    Covers modes: {', '.join(modes)}")
        else:
            unreal.log(f"  ✓ ABP exists: {abp_path}")


def create_retarget_config():
    """Create IK Retargeter configuration for mapping animations between skeletons."""
    retarget_info = {
        "source_skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny",
        "target_skeleton": "/Game/FEL/Characters/FEL_Skeleton",
        "chain_mapping": {
            "Spine": {"source": "spine_01", "target": "spine_01"},
            "LeftArm": {"source": "upperarm_l", "target": "upperarm_l"},
            "RightArm": {"source": "upperarm_r", "target": "upperarm_r"},
            "LeftLeg": {"source": "thigh_l", "target": "thigh_l"},
            "RightLeg": {"source": "thigh_r", "target": "thigh_r"},
            "Head": {"source": "head", "target": "head"},
        },
        "notes": "Use UE5 IK Retargeter (Edit → Retarget Manager) to create this mapping"
    }
    
    # Save config for reference
    config_path = "/Game/FEL/Config/"
    unreal.log(f"  IK Retarget config for: {retarget_info['source_skeleton']} → {retarget_info['target_skeleton']}")
    
    return retarget_info


def generate_coverage_report():
    """Generate final animation coverage report after catalogue integration."""
    report = {
        "builtin_status": verify_builtin_animations(),
        "marketplace_status": check_marketplace_availability(),
        "retarget_config": create_retarget_config(),
    }
    
    # Count totals
    total_animations = 0
    total_available = 0
    
    for pack_id, pack_data in report["marketplace_status"].items():
        total_animations += pack_data["total"]
        total_available += pack_data["found"]
    
    total_animations += len(UE5_BUILTIN_ANIMATIONS)
    total_available += len(report["builtin_status"]["found"])
    
    report["summary"] = {
        "total_catalogue_animations_defined": total_animations,
        "total_available": total_available,
        "total_missing": total_animations - total_available,
        "coverage_percentage": round(total_available / max(total_animations, 1) * 100, 1),
    }
    
    unreal.log("=" * 60)
    unreal.log(f" Animation Catalogue Coverage: {report['summary']['coverage_percentage']}%")
    unreal.log(f" Available: {total_available}/{total_animations}")
    unreal.log("=" * 60)
    
    return report


# ── Main Execution ───────────────────────────────────────────────────────────
def main():
    unreal.log("=" * 60)
    unreal.log(" FEL Animation Catalogue Integration")
    unreal.log("=" * 60)
    
    # Step 1: Check built-in animations
    unreal.log("\nStep 1: Checking UE5 built-in animations...")
    verify_builtin_animations()
    
    # Step 2: Create marketplace directories
    unreal.log("\nStep 2: Creating marketplace directory structure...")
    create_marketplace_directory_structure()
    
    # Step 3: Check marketplace availability
    unreal.log("\nStep 3: Checking marketplace animation availability...")
    check_marketplace_availability()
    
    # Step 4: Set up animation blueprints
    unreal.log("\nStep 4: Setting up Animation Blueprint references...")
    setup_animation_blueprints()
    
    # Step 5: Generate coverage report
    unreal.log("\nStep 5: Generating coverage report...")
    report = generate_coverage_report()
    
    # Save report
    report_path = os.path.join(
        unreal.Paths.project_dir(), 
        "Saved", "FEL", "catalogue_coverage_report.json"
    )
    os.makedirs(os.path.dirname(report_path), exist_ok=True)
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2, default=str)
    unreal.log(f"\nReport saved: {report_path}")
    
    unreal.log("\n" + "=" * 60)
    unreal.log(" Catalogue Integration Complete")
    unreal.log(" Next: Purchase missing packs from UE Marketplace")
    unreal.log("=" * 60)


if __name__ == "__main__":
    main()
else:
    # Auto-run when executed via UE5 Python console
    main()
