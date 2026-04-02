#!/usr/bin/env python3
"""
UE5 Editor Python Script: Import Creator Card Assets
====================================================
Run this script inside Unreal Editor to import all creator-related assets:
- 3D player models (GLB/FBX)
- Profile images, banners, card backgrounds
- Icons and badges
- Video assets

Execution: UE5 Editor > Tools > Execute Python Script > select this file
Or via commandlet: UE_CMD -run=pythonscript -script=EditorPython/fel_import_creator_assets.py
"""

try:
    import unreal
    IN_EDITOR = True
except ImportError:
    IN_EDITOR = False
    print("[INFO] Running outside UE5 Editor - generating import plan only.")

import os
import json
from pathlib import Path

# =====================================================================
# Asset Definitions
# =====================================================================

# 3D Models to import
CREATOR_MODELS = [
    {
        "creator": "amir_smith",
        "source": "GeneratedAssets/CreatorModels/amir_smith/amir_smith_model.glb",
        "dest": "/Game/FEL/CreatorModels/AmirSmith",
        "type": "skeletal_mesh",
        "skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny.SKM_Manny",
    },
    {
        "creator": "amir_smith",
        "source": "GeneratedAssets/CreatorModels/amir_smith/amir_smith_refined.glb",
        "dest": "/Game/FEL/CreatorModels/AmirSmith",
        "type": "skeletal_mesh",
        "skeleton": "/Game/Characters/Mannequins/Meshes/SKM_Manny.SKM_Manny",
    },
]

# Profile images
CREATOR_IMAGES = [
    # Elijah Bonds
    {"source": "GeneratedAssets/CreatorAssets/profiles/elijah_bonds_profile.png", "dest": "/Game/FEL/CreatorAssets/Profiles"},
    {"source": "GeneratedAssets/CreatorAssets/banners/elijah_bonds_banner.png", "dest": "/Game/FEL/CreatorAssets/Banners"},
    {"source": "GeneratedAssets/CreatorAssets/backgrounds/elijah_bonds_card_bg.png", "dest": "/Game/FEL/CreatorAssets/Backgrounds"},
    # Amir Smith
    {"source": "GeneratedAssets/CreatorAssets/profiles/amir_smith_profile.png", "dest": "/Game/FEL/CreatorAssets/Profiles"},
    {"source": "GeneratedAssets/CreatorAssets/banners/amir_smith_banner.png", "dest": "/Game/FEL/CreatorAssets/Banners"},
    {"source": "GeneratedAssets/CreatorAssets/backgrounds/amir_smith_card_bg.png", "dest": "/Game/FEL/CreatorAssets/Backgrounds"},
    # Eric Nash
    {"source": "GeneratedAssets/CreatorAssets/profiles/eric_nash_profile.png", "dest": "/Game/FEL/CreatorAssets/Profiles"},
    {"source": "GeneratedAssets/CreatorAssets/banners/eric_nash_banner.png", "dest": "/Game/FEL/CreatorAssets/Banners"},
    {"source": "GeneratedAssets/CreatorAssets/backgrounds/eric_nash_card_bg.png", "dest": "/Game/FEL/CreatorAssets/Backgrounds"},
]

# Magic Reveal Videos (Elijah Bonds)
MAGIC_REVEAL_VIDEOS = [
    {"source": "SourceVideos/MagicReveal/Venice_Beach_Court_magic_reveal.mp4", "dest": "/Game/FEL/Videos/MagicReveal"},
    {"source": "SourceVideos/MagicReveal/Venice_Ball_Shop_magic_reveal.mp4", "dest": "/Game/FEL/Videos/MagicReveal"},
    {"source": "SourceVideos/MagicReveal/Muscle_beach_gym_magic_reveal.mp4", "dest": "/Game/FEL/Videos/MagicReveal"},
    {"source": "SourceVideos/MagicReveal/Muscle_beach_stage_magic_reveal.mp4", "dest": "/Game/FEL/Videos/MagicReveal"},
    {"source": "SourceVideos/MagicReveal/Venice_beach_tennis_courts_magic_reveal.mp4", "dest": "/Game/FEL/Videos/MagicReveal"},
    {"source": "SourceVideos/MagicReveal/Venice_Beach_Black_Top_magic_reveal.mp4", "dest": "/Game/FEL/Videos/MagicReveal"},
    {"source": "SourceVideos/MagicReveal/Hoopbus_magic_reveal.mp4", "dest": "/Game/FEL/Videos/MagicReveal"},
]

# Icons
ICON_FILES = [
    "stat_vertical", "stat_shots", "stat_dunks", "stat_video", "stat_season",
    "stat_trophy", "stat_height", "stat_college", "stat_league", "stat_position",
    "stat_3d", "stat_moves", "stat_coaching", "stat_location", "stat_style",
    "stat_social", "badge_featured", "badge_coming_soon",
    "icon_instagram", "icon_twitter", "icon_tiktok",
]


def get_project_root():
    """Find the project root directory."""
    if IN_EDITOR:
        return Path(unreal.Paths.project_dir()).parent.parent
    # Fallback
    return Path(__file__).resolve().parent.parent.parent


def import_assets_in_editor():
    """Import all creator assets using the Unreal Editor API."""
    project_root = get_project_root()
    asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
    import_tasks = []

    print("\n" + "=" * 60)
    print("FEL Creator Asset Import")
    print("=" * 60)

    # Import 3D Models
    print("\n--- 3D Creator Models ---")
    for model in CREATOR_MODELS:
        source_path = str(project_root / model["source"])
        if not os.path.exists(source_path):
            print(f"  [SKIP] Not found: {source_path}")
            continue

        task = unreal.AssetImportTask()
        task.set_editor_property("automated", True)
        task.set_editor_property("filename", source_path)
        task.set_editor_property("destination_path", model["dest"])
        task.set_editor_property("replace_existing", True)
        task.set_editor_property("save", True)

        if model["type"] == "skeletal_mesh":
            options = unreal.FbxImportUI()
            options.set_editor_property("import_mesh", True)
            options.set_editor_property("import_as_skeletal", True)
            options.set_editor_property("import_animations", False)
            options.set_editor_property("import_materials", True)
            options.set_editor_property("import_textures", True)
            task.set_editor_property("options", options)

        import_tasks.append(task)
        print(f"  [QUEUE] {model['creator']}: {os.path.basename(source_path)} -> {model['dest']}")

    # Import Images
    print("\n--- Creator Images ---")
    for img in CREATOR_IMAGES:
        source_path = str(project_root / img["source"])
        if not os.path.exists(source_path):
            print(f"  [SKIP] Not found: {source_path}")
            continue

        task = unreal.AssetImportTask()
        task.set_editor_property("automated", True)
        task.set_editor_property("filename", source_path)
        task.set_editor_property("destination_path", img["dest"])
        task.set_editor_property("replace_existing", True)
        task.set_editor_property("save", True)
        import_tasks.append(task)
        print(f"  [QUEUE] {os.path.basename(source_path)} -> {img['dest']}")

    # Import Icons
    print("\n--- Icons ---")
    for icon_name in ICON_FILES:
        source_path = str(project_root / f"GeneratedAssets/CreatorAssets/icons/{icon_name}.png")
        if not os.path.exists(source_path):
            print(f"  [SKIP] Not found: {icon_name}.png")
            continue

        task = unreal.AssetImportTask()
        task.set_editor_property("automated", True)
        task.set_editor_property("filename", source_path)
        task.set_editor_property("destination_path", "/Game/FEL/CreatorAssets/Icons")
        task.set_editor_property("replace_existing", True)
        task.set_editor_property("save", True)
        import_tasks.append(task)

    # Execute all imports
    if import_tasks:
        print(f"\nExecuting {len(import_tasks)} import tasks...")
        asset_tools.import_asset_tasks(import_tasks)
        print(f"\n\u2705 Import complete: {len(import_tasks)} tasks processed")
    else:
        print("\n[WARNING] No assets found to import. Generate assets first.")


def generate_import_plan():
    """Generate import plan when running outside editor."""
    project_root = get_project_root()
    
    print("\n" + "=" * 60)
    print("FEL Creator Asset Import Plan")
    print("=" * 60)

    total = 0
    found = 0
    missing = 0

    all_assets = []
    for model in CREATOR_MODELS:
        all_assets.append({"source": model["source"], "dest": model["dest"], "type": "3D Model"})
    for img in CREATOR_IMAGES:
        all_assets.append({"source": img["source"], "dest": img["dest"], "type": "Image"})
    for icon_name in ICON_FILES:
        all_assets.append({
            "source": f"GeneratedAssets/CreatorAssets/icons/{icon_name}.png",
            "dest": "/Game/FEL/CreatorAssets/Icons",
            "type": "Icon"
        })

    for asset in all_assets:
        total += 1
        source_path = project_root / asset["source"]
        exists = source_path.exists()
        status = "\u2705" if exists else "\u274c"
        if exists:
            found += 1
        else:
            missing += 1
        print(f"  {status} [{asset['type']:<10}] {asset['source'][-50:]} -> {asset['dest']}")

    print(f"\nSummary: {found}/{total} found, {missing} missing")
    print("\nTo generate missing assets:")
    print("  python3 -m scripts.creator_pipeline.generate_creator_assets --all")
    print("  python3 -m scripts.creator_pipeline.meshy_creator_model --all")


if __name__ == "__main__":
    if IN_EDITOR:
        import_assets_in_editor()
    else:
        generate_import_plan()
