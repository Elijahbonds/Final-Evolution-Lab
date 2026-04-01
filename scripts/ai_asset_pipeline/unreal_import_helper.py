#!/usr/bin/env python3
"""Generate Unreal Engine import scripts and update ExerciseCatalog.json
with paths to AI-generated assets.

This script:
  1. Reads the asset manifest
  2. Generates an Unreal Editor Python script to batch-import FBX/GLB files
  3. Updates ExerciseCatalog.json with correct animMontage / demonstratorMesh paths
  4. Generates a C++ asset registry header for compile-time asset references

Usage:
  python -m ai_asset_pipeline.unreal_import_helper --update-catalog
  python -m ai_asset_pipeline.unreal_import_helper --generate-import-script
"""
from __future__ import annotations

import argparse
import json
import logging
from pathlib import Path

from .config import PipelineConfig, ROOT_DIR, load_all_configs
from .asset_cache import AssetManifest

logger = logging.getLogger("unreal_import")

UE_GENERATED_CONTENT_PREFIX = "/Game/FEL/Generated"


def generate_editor_import_script(manifest: AssetManifest, pipeline_cfg: PipelineConfig) -> Path:
    """Create an Unreal Editor Python script that imports all generated assets."""
    lines = [
        '#!/usr/bin/env python3',
        '"""Auto-generated Unreal Editor Python script — imports AI-generated assets."""',
        'import unreal',
        '',
        'asset_tools = unreal.AssetToolsHelpers.get_asset_tools()',
        'import_tasks = []',
        '',
    ]

    for key in manifest.keys():
        entry = manifest.get(key)
        if not entry or entry.get("status") != "completed":
            continue
        for fp in entry.get("files", []):
            fp_path = Path(fp)
            if fp_path.suffix.lower() not in (".fbx", ".glb", ".obj"):
                continue
            # Determine UE destination
            service = entry.get("service", "unknown")
            ue_dest = f"{UE_GENERATED_CONTENT_PREFIX}/{service}/{key}"
            lines.append(f'# {key} — {service}')
            lines.append(f'task = unreal.AssetImportTask()')
            lines.append(f'task.filename = r"{fp}"')
            lines.append(f'task.destination_path = "{ue_dest}"')
            lines.append(f'task.replace_existing = True')
            lines.append(f'task.automated = True')
            lines.append(f'task.save = True')
            if fp_path.suffix.lower() == ".fbx":
                lines.append('# FBX-specific: import as animation if mocap, else static mesh')
                if "mocap" in key:
                    lines.append('fbx_opts = unreal.FbxImportUI()')
                    lines.append('fbx_opts.import_mesh = False')
                    lines.append('fbx_opts.import_animations = True')
                    lines.append('fbx_opts.import_as_skeletal = True')
                    lines.append('task.options = fbx_opts')
            lines.append('import_tasks.append(task)')
            lines.append('')

    lines.append('if import_tasks:')
    lines.append('    asset_tools.import_asset_tasks(import_tasks)')
    lines.append('    unreal.log(f"Imported {len(import_tasks)} AI-generated assets")')
    lines.append('else:')
    lines.append('    unreal.log("No assets to import")')

    script_path = ROOT_DIR / "UnrealStarter" / "BasketballGame" / "EditorPython" / "fel_import_ai_assets.py"
    script_path.parent.mkdir(parents=True, exist_ok=True)
    script_path.write_text("\n".join(lines), encoding="utf-8")
    logger.info("Generated UE import script: %s", script_path)
    return script_path


def update_exercise_catalog(manifest: AssetManifest, pipeline_cfg: PipelineConfig) -> Path:
    """Update ExerciseCatalog.json with AI-generated asset paths."""
    catalog_path = pipeline_cfg.exercise_catalog_path
    data = json.loads(catalog_path.read_text(encoding="utf-8"))

    updated_count = 0
    for cat in data.get("categories", []):
        for ex in cat.get("exercises", []):
            ex_id = ex.get("id", "")

            # Update animation montage path if mocap exists
            mocap_key = f"{ex_id}_mocap"
            if manifest.has(mocap_key):
                entry = manifest.get(mocap_key)
                fbx_files = [f for f in (entry or {}).get("files", []) if f.endswith(".fbx")]
                if fbx_files:
                    ue_path = f"{UE_GENERATED_CONTENT_PREFIX}/deepmotion/{mocap_key}/{Path(fbx_files[0]).stem}_Montage"
                    ex["animMontage"] = ue_path
                    updated_count += 1

            # Update prop mesh path if exists
            prop_key = f"{ex_id}_prop"
            if manifest.has(prop_key):
                entry = manifest.get(prop_key)
                mesh_files = [f for f in (entry or {}).get("files", []) if f.endswith((".glb", ".fbx"))]
                if mesh_files:
                    ue_path = f"{UE_GENERATED_CONTENT_PREFIX}/meshy/{prop_key}/{Path(mesh_files[0]).stem}"
                    ex["propMesh"] = ue_path

    catalog_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    logger.info("Updated %d exercises in catalog: %s", updated_count, catalog_path)
    return catalog_path


def generate_asset_registry_header(manifest: AssetManifest, pipeline_cfg: PipelineConfig) -> Path:
    """Generate C++ header with soft-reference paths for generated assets."""
    lines = [
        '// Auto-generated by ai_asset_pipeline/unreal_import_helper.py',
        '// DO NOT EDIT MANUALLY — re-run the import helper to update.',
        '#pragma once',
        '',
        '#include "CoreMinimal.h"',
        '',
        'namespace FELGeneratedAssets',
        '{',
    ]

    # Exercise mocap animations
    lines.append('    // === Exercise Motion Capture Animations ===')
    for key in sorted(manifest.keys()):
        if not key.endswith("_mocap"):
            continue
        entry = manifest.get(key)
        if not entry or entry.get("status") != "completed":
            continue
        ex_id = key.replace("_mocap", "")
        var_name = ex_id.upper()
        ue_path = f"{UE_GENERATED_CONTENT_PREFIX}/deepmotion/{key}"
        lines.append(f'    static const TCHAR* ANIM_{var_name} = TEXT("{ue_path}");')

    lines.append('')
    lines.append('    // === Exercise Props (Meshy 3D) ===')
    for key in sorted(manifest.keys()):
        if not key.endswith("_prop"):
            continue
        entry = manifest.get(key)
        if not entry or entry.get("status") != "completed":
            continue
        ex_id = key.replace("_prop", "")
        var_name = ex_id.upper()
        ue_path = f"{UE_GENERATED_CONTENT_PREFIX}/meshy/{key}"
        lines.append(f'    static const TCHAR* PROP_{var_name} = TEXT("{ue_path}");')

    lines.append('')
    lines.append('    // === Environment Assets (Luma + Meshy) ===')
    for key in sorted(manifest.keys()):
        if not key.startswith("env_") or not key.endswith("_3d_model"):
            continue
        entry = manifest.get(key)
        if not entry or entry.get("status") != "completed":
            continue
        venue = key.replace("env_", "").replace("_3d_model", "")
        var_name = venue.upper()
        ue_path = f"{UE_GENERATED_CONTENT_PREFIX}/meshy/{key}"
        lines.append(f'    static const TCHAR* ENV_{var_name} = TEXT("{ue_path}");')

    lines.append('}')
    lines.append('')

    header_path = (
        ROOT_DIR / "UnrealStarter" / "BasketballGame" / "Source" / "FinalEvolutionLab" / "FELGeneratedAssetPaths.h"
    )
    header_path.parent.mkdir(parents=True, exist_ok=True)
    header_path.write_text("\n".join(lines), encoding="utf-8")
    logger.info("Generated C++ asset registry header: %s", header_path)
    return header_path


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s  %(message)s")
    p = argparse.ArgumentParser(description="Unreal Engine import helper for AI-generated assets")
    p.add_argument("--update-catalog", action="store_true", help="Update ExerciseCatalog.json")
    p.add_argument("--generate-import-script", action="store_true", help="Generate UE Editor Python import script")
    p.add_argument("--generate-header", action="store_true", help="Generate C++ asset paths header")
    p.add_argument("--all", action="store_true", help="Run all steps")
    args = p.parse_args()

    _, _, _, pipeline_cfg = load_all_configs()
    manifest = AssetManifest(pipeline_cfg.manifest_path)

    if args.all or args.generate_import_script:
        generate_editor_import_script(manifest, pipeline_cfg)
    if args.all or args.update_catalog:
        update_exercise_catalog(manifest, pipeline_cfg)
    if args.all or args.generate_header:
        generate_asset_registry_header(manifest, pipeline_cfg)

    if not any([args.all, args.update_catalog, args.generate_import_script, args.generate_header]):
        p.print_help()


if __name__ == "__main__":
    main()
