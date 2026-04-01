#!/usr/bin/env python3
"""
fel_verify_assets_standalone.py
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Standalone filesystem verification of all FEL assets.
Adapted from EditorPython/fel_verify_assets.py to run without UE5.

Checks:
  1. All 49 AI-generated assets (definitions in FELGeneratedAssetPaths.h)
  2. All 26 Elijah Bonds animation definitions (FELElijahBondsAnimPaths.h)
  3. 130+ UE5 catalogue animation references (ue5_animation_mapping.json)
  4. Source video files and metadata
  5. Pipeline configuration files
  6. Directory structure integrity
"""

import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path

# Project root
ROOT = Path(__file__).resolve().parent.parent.parent
UNREAL_DIR = ROOT / "UnrealStarter" / "BasketballGame"
GEN_ASSETS = ROOT / "GeneratedAssets"
SCRIPTS_DIR = ROOT / "scripts"
SOURCE_VIDEOS = ROOT / "SourceVideos"

# ANSI colors
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"

def ok(msg): print(f"  {GREEN}✓{RESET} {msg}")
def fail(msg): print(f"  {RED}✗{RESET} {msg}")
def warn(msg): print(f"  {YELLOW}⚠{RESET} {msg}")
def header(msg): print(f"\n{BOLD}{CYAN}─── {msg} ───{RESET}")

report = {
    "timestamp": datetime.now().isoformat(),
    "checks": {},
    "summary": {"passed": 0, "failed": 0, "warnings": 0}
}

def check(category, name, condition, detail=""):
    if condition:
        ok(f"{name}" + (f" ({detail})" if detail else ""))
        report["checks"].setdefault(category, []).append({"name": name, "status": "PASS", "detail": detail})
        report["summary"]["passed"] += 1
        return True
    else:
        fail(f"{name}" + (f" ({detail})" if detail else ""))
        report["checks"].setdefault(category, []).append({"name": name, "status": "FAIL", "detail": detail})
        report["summary"]["failed"] += 1
        return False

def check_warn(category, name, condition, detail=""):
    if condition:
        ok(f"{name}" + (f" ({detail})" if detail else ""))
        report["checks"].setdefault(category, []).append({"name": name, "status": "PASS", "detail": detail})
        report["summary"]["passed"] += 1
        return True
    else:
        warn(f"{name}" + (f" ({detail})" if detail else ""))
        report["checks"].setdefault(category, []).append({"name": name, "status": "WARN", "detail": detail})
        report["summary"]["warnings"] += 1
        return False


# ── 1. AI-Generated Asset Definitions (49 expected) ──────────────────────────
def verify_ai_generated_assets():
    header("AI-Generated Asset Definitions (49 expected)")
    
    h_file = UNREAL_DIR / "Source" / "FinalEvolutionLab" / "FELGeneratedAssetPaths.h"
    check("ai_assets", "FELGeneratedAssetPaths.h exists", h_file.exists())
    
    if not h_file.exists():
        return 0
    
    content = h_file.read_text()
    
    # Parse all asset paths
    anim_paths = re.findall(r'ANIM_\w+\s*=\s*TEXT\("([^"]+)"\)', content)
    prop_paths = re.findall(r'PROP_\w+\s*=\s*TEXT\("([^"]+)"\)', content)
    env_paths = re.findall(r'ENV_\w+\s*=\s*TEXT\("([^"]+)"\)', content)
    
    total = len(anim_paths) + len(prop_paths) + len(env_paths)
    
    check("ai_assets", f"Animation definitions: {len(anim_paths)}/23", len(anim_paths) == 23)
    check("ai_assets", f"Prop definitions: {len(prop_paths)}/9", len(prop_paths) == 9)
    check("ai_assets", f"Environment definitions: {len(env_paths)}/12", len(env_paths) == 12)
    check("ai_assets", f"Total AI asset definitions: {total}/44", total >= 44,
          "Note: header has 44 unique definitions across 49 manifest entries")
    
    # Check C++ syntax validity
    check("ai_assets", "Header has #pragma once", "#pragma once" in content)
    check("ai_assets", "Header has namespace", "namespace FELGeneratedAssets" in content)
    
    return total


# ── 2. Elijah Bonds Animation Definitions (26 movements) ─────────────────────
def verify_elijahbonds_animations():
    header("Elijah Bonds Animation Definitions (26 movements from 10 videos)")
    
    h_file = UNREAL_DIR / "Source" / "FinalEvolutionLab" / "FELElijahBondsAnimPaths.h"
    check("elijahbonds", "FELElijahBondsAnimPaths.h exists", h_file.exists())
    
    if not h_file.exists():
        return 0
    
    content = h_file.read_text()
    
    # Parse all animation paths
    anim_paths = re.findall(r'EB_\w+\s*=\s*TEXT\("([^"]+)"\)', content)
    
    # Count unique source videos
    source_videos = set()
    for match in re.finditer(r'// Source: (\S+)', content):
        source_videos.add(match.group(1))
    
    # Count UE5 catalogue references
    catalogue_refs = re.findall(r'UE5_\w+\s*=\s*TEXT\("([^"]+)"\)', content)
    
    # Count game mode definitions
    game_modes = re.findall(r'MODE_\w+\s*=\s*TEXT\("([^"]+)"\)', content)
    
    check("elijahbonds", f"Custom animation paths: {len(anim_paths)}", len(anim_paths) >= 26,
          f"{len(anim_paths)} Elijah Bonds movements defined")
    check("elijahbonds", f"Source videos referenced: {len(source_videos)}", len(source_videos) >= 10,
          "10+ source video sections in header")
    check_warn("elijahbonds", f"UE5 catalogue fallback refs: {len(catalogue_refs)}", len(catalogue_refs) > 0)
    check_warn("elijahbonds", f"Game mode constants: {len(game_modes)}", len(game_modes) >= 16)
    check("elijahbonds", "Header has namespace", "namespace FELElijahBondsAnims" in content)
    
    return len(anim_paths)


# ── 3. UE5 Animation Mapping (130+ references) ──────────────────────────────
def verify_ue5_animation_mapping():
    header("UE5 Animation Mapping (130+ references across 12 sport categories)")
    
    mapping_file = GEN_ASSETS / "Animations" / "ue5_animation_mapping.json"
    check("ue5_mapping", "ue5_animation_mapping.json exists", mapping_file.exists())
    
    if not mapping_file.exists():
        return 0
    
    data = json.loads(mapping_file.read_text())
    
    game_modes = data.get("game_modes", {})
    total_custom = 0
    total_catalogue = 0
    
    for mode_name, mode_data in game_modes.items():
        custom = len(mode_data.get("custom_animations", []))
        catalogue = len(mode_data.get("ue5_catalogue_animations", []))
        total_custom += custom
        total_catalogue += catalogue
    
    total_refs = total_custom + total_catalogue
    
    check("ue5_mapping", f"Game modes defined: {len(game_modes)}/16", len(game_modes) >= 16)
    check("ue5_mapping", f"Custom animation refs: {total_custom}", total_custom >= 50,
          f"Elijah Bonds movements mapped to game modes")
    check("ue5_mapping", f"UE5 catalogue animation refs: {total_catalogue}", total_catalogue > 0,
          f"Built-in/marketplace animations")
    check("ue5_mapping", f"Total animation references: {total_refs}", total_refs >= 130,
          f"Combined custom + catalogue across all modes")
    
    # Check coverage summary
    coverage = data.get("coverage_summary", {})
    if coverage:
        check("ue5_mapping", "Coverage summary present", True)
    
    return total_refs


# ── 4. Animation Manifest ────────────────────────────────────────────────────
def verify_animation_manifest():
    header("Animation Manifest & Coverage Report")
    
    manifest_file = GEN_ASSETS / "Animations" / "animation_manifest.json"
    check("manifest", "animation_manifest.json exists", manifest_file.exists())
    
    if manifest_file.exists():
        data = json.loads(manifest_file.read_text())
        custom_anims = data.get("custom_animations", [])
        check("manifest", f"Custom animations listed: {len(custom_anims)}", len(custom_anims) > 0)
        
        game_coverage = data.get("game_mode_coverage", {})
        check("manifest", f"Game mode coverage categories: {len(game_coverage)}", len(game_coverage) >= 3,
              "fully_covered / partially_covered / needs_catalogue")
    
    coverage_file = GEN_ASSETS / "Animations" / "animation_coverage_report.json"
    check("manifest", "animation_coverage_report.json exists", coverage_file.exists())
    
    pipeline_file = GEN_ASSETS / "pipeline_report.json"
    check("manifest", "pipeline_report.json exists", pipeline_file.exists())
    
    if pipeline_file.exists():
        data = json.loads(pipeline_file.read_text())
        validation = data.get("phases", {}).get("validation", {})
        overall = validation.get("overall_pass", False)
        check("manifest", "Pipeline validation passed", overall)
        
        exercises = validation.get("exercises", {})
        check("manifest", f"Exercises with animation: {exercises.get('with_animation', 0)}/23",
              exercises.get("with_animation", 0) == 23)
        check("manifest", f"Exercises with props: {exercises.get('with_prop', 0)}/9",
              exercises.get("with_prop", 0) == 9)
        
        venues = validation.get("venues", {})
        check("manifest", f"Venues with 3D model: {venues.get('with_model', 0)}/12",
              venues.get("with_model", 0) == 12)


# ── 5. Source Videos & Metadata ──────────────────────────────────────────────
def verify_source_videos():
    header("Source Videos & Metadata (@elijahbonds)")
    
    meta_file = SOURCE_VIDEOS / "Instagram" / "video_metadata.json"
    check("videos", "video_metadata.json exists", meta_file.exists())
    
    video_dir = SOURCE_VIDEOS / "Instagram" / "basketball"
    check("videos", "basketball/ video directory exists", video_dir.exists())
    
    if video_dir.exists():
        videos = list(video_dir.glob("*.mp4"))
        check("videos", f"Video files: {len(videos)}/10", len(videos) >= 10,
              ", ".join(v.name for v in videos[:5]) + ("..." if len(videos) > 5 else ""))
    
    if meta_file.exists():
        data = json.loads(meta_file.read_text())
        videos_meta = data.get("videos", [])
        check("videos", f"Video metadata entries: {len(videos_meta)}/10", len(videos_meta) >= 10)
        
        total_movements = sum(len(v.get("movements", [])) for v in videos_meta)
        check("videos", f"Total movements defined: {total_movements}", total_movements >= 26,
              f"across {len(videos_meta)} videos")


# ── 6. UE5 Editor Python Scripts ─────────────────────────────────────────────
def verify_editor_scripts():
    header("UE5 Editor Python Scripts")
    
    editor_dir = UNREAL_DIR / "EditorPython"
    scripts = [
        ("fel_import_ai_assets.py", "49 AI-generated assets importer"),
        ("fel_import_elijahbonds_animations.py", "Elijah Bonds animation importer"),
        ("fel_import_catalogue_animations.py", "UE5 catalogue animation setup"),
        ("fel_verify_assets.py", "Asset verification (UE5 Editor version)"),
    ]
    
    for filename, desc in scripts:
        path = editor_dir / filename
        check("editor_scripts", f"{filename}", path.exists(), desc)


# ── 7. C++ Source Files ──────────────────────────────────────────────────────
def verify_cpp_source():
    header("C++ Source Integration Files")
    
    src_dir = UNREAL_DIR / "Source" / "FinalEvolutionLab"
    files = [
        ("FELGeneratedAssetPaths.h", "49 AI asset compile-time paths"),
        ("FELElijahBondsAnimPaths.h", "Elijah Bonds animation paths"),
        ("UFELAIAssetManagerSubsystem.h", "Runtime asset manager header"),
        ("UFELAIAssetManagerSubsystem.cpp", "Runtime asset manager implementation"),
    ]
    
    for filename, desc in files:
        path = src_dir / filename
        check("cpp_source", f"{filename}", path.exists(), desc)


# ── 8. UE5 Setup Scripts ────────────────────────────────────────────────────
def verify_setup_scripts():
    header("UE5 Setup & Deployment Scripts")
    
    setup_dir = SCRIPTS_DIR / "ue5_setup"
    scripts = [
        "install_ue5_linux.sh",
        "import_all_assets.sh",
        "cook_fel_linux_server.sh",
        "cook_fel_ios.sh",
        "prepare_ios_build.sh",
        "fel_complete_pipeline.sh",
    ]
    
    for s in scripts:
        path = setup_dir / s
        is_exec = path.exists() and os.access(str(path), os.X_OK)
        check("setup_scripts", f"{s}", path.exists(),
              "executable" if is_exec else "exists but not executable" if path.exists() else "MISSING")


# ── 9. Exercise Catalog ──────────────────────────────────────────────────────
def verify_exercise_catalog():
    header("Exercise Catalog (UE5 Content)")
    
    catalog_file = UNREAL_DIR / "Content" / "FEL" / "Config" / "ExerciseCatalog.json"
    check("catalog", "ExerciseCatalog.json exists", catalog_file.exists())
    
    if catalog_file.exists():
        data = json.loads(catalog_file.read_text())
        categories = data.get("categories", data.get("exercises", []))
        if isinstance(categories, dict):
            cat_count = len(categories)
            total = sum(len(v) if isinstance(v, list) else 1 for v in categories.values())
        elif isinstance(categories, list):
            cat_count = len(categories)
            total = cat_count
        else:
            cat_count = 0
            total = 0
        check("catalog", f"Exercise categories: {cat_count}", cat_count >= 5,
              f"with {total} total exercises/entries across categories")


# ── 10. iOS Configuration ────────────────────────────────────────────────────
def verify_ios_config():
    header("iOS App Configuration")
    
    ios_dir = ROOT / "ios" / "FinalEvolutionLab"
    config = ios_dir / "Config.swift"
    ps_service = ios_dir / "Services" / "PixelStreamingService.swift"
    
    check("ios", "Config.swift exists", config.exists())
    check("ios", "PixelStreamingService.swift exists", ps_service.exists())
    
    if config.exists():
        content = config.read_text()
        check("ios", "Production streaming URL configured",
              "stream.finalevolutiongroup.com" in content)
        check("ios", "Bundle ID set", "com.finalevolutiongroup.lab" in content)


# ── 11. Streaming Infrastructure ─────────────────────────────────────────────
def verify_streaming():
    header("Streaming Infrastructure")
    
    sig_dir = ROOT / "streaming" / "signalling"
    fe_dir = ROOT / "streaming" / "frontend"
    
    check("streaming", "Signalling server.js", (sig_dir / "server.js").exists())
    check("streaming", "Signalling package.json", (sig_dir / "package.json").exists())
    check("streaming", "Frontend package.json", (fe_dir / "package.json").exists())
    check_warn("streaming", "Frontend dist/ built", (fe_dir / "dist").exists())


# ── 12. Directory Structure ──────────────────────────────────────────────────
def verify_directory_structure():
    header("Directory Structure Integrity")
    
    dirs = [
        "GeneratedAssets",
        "GeneratedAssets/Animations",
        "SourceVideos/Instagram/basketball",
        "UnrealStarter/BasketballGame/EditorPython",
        "UnrealStarter/BasketballGame/Source/FinalEvolutionLab",
        "UnrealStarter/BasketballGame/Content/FEL/Config",
        "scripts/ue5_setup",
        "scripts/ai_asset_pipeline",
        "streaming/signalling",
        "streaming/frontend",
        "ios/FinalEvolutionLab/Services",
    ]
    
    for d in dirs:
        path = ROOT / d
        check("structure", d, path.exists())


# ═══════════════════════════════════════════════════════════════════════════════
def main():
    print(f"\n{BOLD}{'═' * 70}{RESET}")
    print(f"{BOLD} FEL Asset Verification Report — Standalone Filesystem Check{RESET}")
    print(f"{BOLD} Project: {ROOT}{RESET}")
    print(f"{BOLD} Generated: {datetime.now().isoformat()}{RESET}")
    print(f"{BOLD}{'═' * 70}{RESET}")
    
    ai_count = verify_ai_generated_assets()
    eb_count = verify_elijahbonds_animations()
    ue5_count = verify_ue5_animation_mapping()
    verify_animation_manifest()
    verify_source_videos()
    verify_editor_scripts()
    verify_cpp_source()
    verify_setup_scripts()
    verify_exercise_catalog()
    verify_ios_config()
    verify_streaming()
    verify_directory_structure()
    
    # Summary
    p = report["summary"]["passed"]
    f = report["summary"]["failed"]
    w = report["summary"]["warnings"]
    total = p + f + w
    
    print(f"\n{BOLD}{'═' * 70}{RESET}")
    print(f"{BOLD} VERIFICATION SUMMARY{RESET}")
    print(f"  {GREEN}Passed:   {p}/{total}{RESET}")
    print(f"  {RED}Failed:   {f}/{total}{RESET}")
    print(f"  {YELLOW}Warnings: {w}/{total}{RESET}")
    print()
    print(f"  AI Asset Definitions:        {ai_count} paths in C++ header")
    print(f"  Elijah Bonds Animations:     {eb_count} custom movement paths")
    print(f"  UE5 Animation References:    {ue5_count} total (custom + catalogue)")
    print()
    
    if f == 0:
        print(f"  {GREEN}{BOLD}STATUS: ✓ ALL CHECKS PASSED{RESET}")
    else:
        print(f"  {RED}{BOLD}STATUS: ✗ {f} CHECKS FAILED{RESET}")
    
    print(f"{BOLD}{'═' * 70}{RESET}")
    
    # Save report
    report_path = ROOT / "logs" / "asset_verification_report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    
    report["asset_counts"] = {
        "ai_definitions": ai_count,
        "elijahbonds_animations": eb_count,
        "ue5_animation_refs": ue5_count,
    }
    
    with open(report_path, "w") as f_out:
        json.dump(report, f_out, indent=2)
    print(f"\n  Report saved: {report_path}")
    
    return 0 if report["summary"]["failed"] == 0 else 1

if __name__ == "__main__":
    sys.exit(main())
