#!/usr/bin/env python3
"""
Generate UE5 import scripts for both custom Elijah Bonds animations
and UE5 catalogue animations.

Creates:
  1. EditorPython import script for custom FBX/BVH animations
  2. Animation Blueprint setup references
  3. FEL animation system integration code
  4. Comprehensive coverage report

Usage:
  python scripts/generate_ue5_import_scripts.py
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent.parent
ANIMATIONS_DIR = ROOT_DIR / "GeneratedAssets" / "Animations"
MANIFEST_FILE = ANIMATIONS_DIR / "animation_manifest.json"
UE5_MAPPING_FILE = ANIMATIONS_DIR / "ue5_animation_mapping.json"
EDITOR_SCRIPT = ROOT_DIR / "UnrealStarter" / "BasketballGame" / "EditorPython" / "fel_import_elijahbonds_animations.py"
ANIM_HEADER = ROOT_DIR / "UnrealStarter" / "BasketballGame" / "Source" / "FinalEvolutionLab" / "FELElijahBondsAnimPaths.h"
COVERAGE_REPORT = ANIMATIONS_DIR / "animation_coverage_report.json"


def load_manifest() -> dict:
    with open(MANIFEST_FILE) as f:
        return json.load(f)


def load_ue5_mapping() -> dict:
    with open(UE5_MAPPING_FILE) as f:
        return json.load(f)


def generate_editor_import_script(manifest: dict) -> None:
    """Generate Unreal Editor Python script for importing Elijah Bonds animations."""
    EDITOR_SCRIPT.parent.mkdir(parents=True, exist_ok=True)

    # Group animations by source video
    by_video = {}
    for anim in manifest.get("custom_animations", []):
        video = Path(anim["source_video"]).stem
        if video not in by_video:
            by_video[video] = []
        by_video[video].append(anim)

    lines = [
        '#!/usr/bin/env python3',
        '"""',
        'Auto-generated Unreal Editor Python script for importing Elijah Bonds motion capture animations.',
        f'Generated: {datetime.now(timezone.utc).isoformat()}',
        '',
        'Run in Unreal Editor: Edit → Editor Preferences → Python → Execute Script',
        'Or: Window → Developer Tools → Output Log → Python console',
        '"""',
        'import unreal',
        '',
        'asset_tools = unreal.AssetToolsHelpers.get_asset_tools()',
        '',
        '# ─── Elijah Bonds Motion Capture Animations ───────────────────────',
        'ELIJAHBONDS_ANIMATIONS = [',
    ]

    eb_dir = ROOT_DIR / "GeneratedAssets" / "Animations" / "ElijahBonds"
    for video_stem, anims in sorted(by_video.items()):
        video_dir = eb_dir / video_stem
        fbx_files = list(video_dir.glob("*.fbx")) if video_dir.exists() else []
        bvh_files = list(video_dir.glob("*.bvh")) if video_dir.exists() else []

        for fbx in fbx_files:
            lines.append(f'    {{')
            lines.append(f'        "source_file": r"{fbx}",')
            lines.append(f'        "destination": "/Game/FEL/Animations/ElijahBonds/{video_stem}",')
            lines.append(f'        "video_source": "{video_stem}",')
            movements = [a["movement_type"] for a in anims]
            lines.append(f'        "movements": {movements},')
            lines.append(f'    }},')

        # Also add placeholder entries for pending animations
        if not fbx_files:
            lines.append(f'    # PENDING: {video_stem} (awaiting DeepMotion processing)')
            lines.append(f'    # {{')
            lines.append(f'    #     "source_file": r"{video_dir / (video_stem + ".fbx")}",')
            lines.append(f'    #     "destination": "/Game/FEL/Animations/ElijahBonds/{video_stem}",')
            lines.append(f'    # }},')

    lines.append(']')
    lines.append('')
    lines.append('# ─── UE5 Catalogue Animations (Marketplace / Mannequin) ─────────')
    lines.append('UE5_CATALOGUE_REFS = {')

    mapping = load_ue5_mapping()
    for anim_id, info in sorted(mapping.get("ue5_catalogue", {}).items()):
        lines.append(f'    "{anim_id}": "{info["asset"]}",')

    lines.append('}')
    lines.append('')
    lines.append('')
    lines.append('def import_elijahbonds_animations():')
    lines.append('    """Import all Elijah Bonds FBX animations into Unreal."""')
    lines.append('    tasks = []')
    lines.append('    for anim in ELIJAHBONDS_ANIMATIONS:')
    lines.append('        if isinstance(anim, dict) and "source_file" in anim:')
    lines.append('            import_path = anim["source_file"]')
    lines.append('            import unreal')
    lines.append('            import os')
    lines.append('            if not os.path.exists(import_path):')
    lines.append('                unreal.log_warning(f"Skipping {import_path} (file not found)")')
    lines.append('                continue')
    lines.append('            task = unreal.AssetImportTask()')
    lines.append('            task.set_editor_property("filename", import_path)')
    lines.append('            task.set_editor_property("destination_path", anim["destination"])')
    lines.append('            task.set_editor_property("automated", True)')
    lines.append('            task.set_editor_property("replace_existing", True)')
    lines.append('            task.set_editor_property("save", True)')
    lines.append('            # FBX import settings')
    lines.append('            fbx_options = unreal.FbxImportUI()')
    lines.append('            fbx_options.set_editor_property("import_as_skeletal", True)')
    lines.append('            fbx_options.set_editor_property("import_animations", True)')
    lines.append('            fbx_options.set_editor_property("import_mesh", False)')
    lines.append('            fbx_options.set_editor_property("create_physics_asset", False)')
    lines.append('            fbx_options.skeleton = unreal.load_asset("/Game/Characters/Mannequins/Meshes/SKM_Manny")')
    lines.append('            task.set_editor_property("options", fbx_options)')
    lines.append('            tasks.append(task)')
    lines.append('            unreal.log(f"Queued: {import_path} → {anim[\'destination\']}")')
    lines.append('    ')
    lines.append('    if tasks:')
    lines.append('        asset_tools.import_asset_tasks(tasks)')
    lines.append('        unreal.log(f"Imported {len(tasks)} Elijah Bonds animations")')
    lines.append('    else:')
    lines.append('        unreal.log_warning("No animation files found. Run DeepMotion processing first.")')
    lines.append('')
    lines.append('')
    lines.append('def verify_ue5_catalogue():')
    lines.append('    """Check which UE5 catalogue animations are available."""')
    lines.append('    available = 0')
    lines.append('    missing = []')
    lines.append('    for name, path in UE5_CATALOGUE_REFS.items():')
    lines.append('        asset = unreal.load_asset(path)')
    lines.append('        if asset:')
    lines.append('            available += 1')
    lines.append('        else:')
    lines.append('            missing.append(name)')
    lines.append('    unreal.log(f"UE5 Catalogue: {available}/{len(UE5_CATALOGUE_REFS)} available")')
    lines.append('    if missing:')
    lines.append('        unreal.log_warning(f"Missing: {missing}")')
    lines.append('    return missing')
    lines.append('')
    lines.append('')
    lines.append('if __name__ == "__main__":')
    lines.append('    import_elijahbonds_animations()')
    lines.append('    verify_ue5_catalogue()')
    lines.append('')

    with open(EDITOR_SCRIPT, "w") as f:
        f.write("\n".join(lines))
    print(f"✓ UE5 import script: {EDITOR_SCRIPT}")


def generate_anim_paths_header(manifest: dict) -> None:
    """Generate C++ header with animation path constants."""
    ANIM_HEADER.parent.mkdir(parents=True, exist_ok=True)

    lines = [
        "// Auto-generated: Elijah Bonds motion capture animation paths for FEL",
        f"// Generated: {datetime.now(timezone.utc).isoformat()}",
        "// Source: @elijahbonds Instagram basketball videos → DeepMotion Animate 3D",
        "#pragma once",
        "",
        "namespace FELElijahBondsAnims",
        "{",
        "    // ─── Custom Motion Capture Animations ──────────────────────────",
    ]

    # Group by video
    by_video = {}
    for anim in manifest.get("custom_animations", []):
        video = Path(anim["source_video"]).stem
        if video not in by_video:
            by_video[video] = []
        by_video[video].append(anim)

    for video_stem, anims in sorted(by_video.items()):
        lines.append(f"")
        lines.append(f"    // Source: {video_stem}")
        for anim in anims:
            var_name = anim["animation_id"].upper().replace("-", "_")
            ue_path = anim["ue5_import_path"]
            lines.append(f'    static const TCHAR* {var_name} = TEXT("{ue_path}");')

    lines.append("")
    lines.append("    // ─── UE5 Catalogue Fallback Animations ──────────────────────")

    mapping = load_ue5_mapping()
    for anim_id, info in sorted(mapping.get("ue5_catalogue", {}).items()):
        var_name = f"UE5_{anim_id.upper()}"
        lines.append(f'    static const TCHAR* {var_name} = TEXT("{info["asset"]}");')

    lines.append("")
    lines.append("    // ─── Game Mode Animation Sets ────────────────────────────────")

    game_modes = [
        "basketball_5v5", "basketball_3v3", "slam_dunk_contest", "streetball",
        "soccer", "football", "track_and_field", "swimming",
        "tennis", "boxing", "martial_arts", "volleyball",
        "baseball", "gymnastics", "skateboarding", "wrestling",
    ]

    for mode in game_modes:
        var_name = f"MODE_{mode.upper()}"
        lines.append(f'    static const TCHAR* {var_name} = TEXT("{mode}");')

    lines.append("}")
    lines.append("")

    with open(ANIM_HEADER, "w") as f:
        f.write("\n".join(lines))
    print(f"✓ C++ animation paths header: {ANIM_HEADER}")


def generate_coverage_report(manifest: dict) -> None:
    """Generate comprehensive coverage report."""
    mapping = load_ue5_mapping()

    report = {
        "report_version": "1.0",
        "generated": datetime.now(timezone.utc).isoformat(),
        "summary": {
            "total_game_modes": 16,
            "custom_animations_total": manifest["statistics"]["total_custom_animations"],
            "unique_movements_captured": manifest["statistics"]["total_unique_movements"],
            "ue5_catalogue_total": manifest["statistics"]["total_ue5_catalogue_animations"],
            "deepmotion_processing_status": manifest["processing_status"]["deepmotion_status"],
        },
        "elijah_bonds_coverage": {
            "movements_covered": sorted(set(
                a["movement_type"] for a in manifest.get("custom_animations", [])
            )),
            "movement_categories": {},
        },
        "per_game_mode": {},
        "action_items": [],
    }

    # Movement categories
    categories = {}
    for anim in manifest.get("custom_animations", []):
        for cat in anim["movement_categories"]:
            if cat not in categories:
                categories[cat] = []
            if anim["movement_type"] not in categories[cat]:
                categories[cat].append(anim["movement_type"])
    report["elijah_bonds_coverage"]["movement_categories"] = categories

    # Per game mode analysis
    for mode, details in manifest.get("gap_analysis", {}).items():
        mode_data = mapping.get("game_modes", {}).get(mode, {})
        custom_count = mode_data.get("coverage_summary", {}).get("custom_animation_count", 0)
        catalogue_count = mode_data.get("coverage_summary", {}).get("ue5_catalogue_count", 0)

        report["per_game_mode"][mode] = {
            "custom_animations": custom_count,
            "catalogue_animations": catalogue_count,
            "coverage_percentage": details["coverage_percentage"],
            "missing_needs_catalogue": details["missing_needs_catalogue"],
            "animation_source": "custom" if custom_count > 5 else ("mixed" if custom_count > 0 else "catalogue"),
        }

    # Action items
    if manifest["processing_status"]["deepmotion_status"] == "not_started":
        report["action_items"].append({
            "priority": "critical",
            "action": "Configure DeepMotion API credentials and process videos",
            "details": "Set DEEPMOTION_CLIENT_ID and DEEPMOTION_CLIENT_SECRET in .env, then run: python scripts/process_elijahbonds_animations.py",
        })

    report["action_items"].extend([
        {
            "priority": "high",
            "action": "Import processed FBX animations into UE5",
            "details": "Run fel_import_elijahbonds_animations.py in Unreal Editor after DeepMotion processing",
        },
        {
            "priority": "high",
            "action": "Acquire UE5 Marketplace animation packs for non-basketball sports",
            "details": "Swimming, tennis, boxing, martial arts, football, soccer, etc. need sport-specific packs",
        },
        {
            "priority": "medium",
            "action": "Create Animation Montages for each imported animation",
            "details": "Set up montages with proper sections, blend in/out, and notify events",
        },
        {
            "priority": "medium",
            "action": "Set up IK Retargeting for animations from different skeletons",
            "details": "Use UE5 IK Retargeter to map DeepMotion skeleton to FEL character skeleton",
        },
        {
            "priority": "low",
            "action": "Create transition animations between movement states",
            "details": "Blend spaces and state machines for smooth animation transitions",
        },
    ])

    with open(COVERAGE_REPORT, "w") as f:
        json.dump(report, f, indent=2)
    print(f"✓ Coverage report: {COVERAGE_REPORT}")


def main():
    manifest = load_manifest()

    generate_editor_import_script(manifest)
    generate_anim_paths_header(manifest)
    generate_coverage_report(manifest)

    print("\n✅ All UE5 integration files generated successfully!")
    print("\nNext steps:")
    print("  1. Configure DeepMotion credentials in .env")
    print("  2. Run: python scripts/process_elijahbonds_animations.py")
    print("  3. Open Unreal Editor and run the import script")
    print("  4. Acquire UE5 Marketplace packs for remaining sports")


if __name__ == "__main__":
    main()
