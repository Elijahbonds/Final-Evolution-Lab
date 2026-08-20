#!/usr/bin/env python3
"""
FEL Cooked Payload Validator
Validates that all required venue maps, ArenaSettings, and registry files
would be included in a cooked UE5 build. Runs pre-build as a CI gate.
"""
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ERRORS = []
WARNINGS = []

def err(msg): ERRORS.append(msg)
def warn(msg): WARNINGS.append(msg)

REQUIRED_VENUE_DIRS = [
    "BaseballPark", "Dojo", "Gridiron", "Links",
    "Luma_Venice_Shop", "NeuroArena", "SandCourt",
    "SoccerStadium", "TennisCourt", "TrainingFloor", "VeniceBeach",
]

STAGING_VENUE_DIRS = ["SkatePark", "MountainSlope"]

def validate_venue_content_dirs():
    """Check that venue content directories exist (or note them for asset pipeline)"""
    content_root = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Venues"
    if not content_root.exists():
        warn(f"Venue content root not found at {content_root} — expected for UE5 project structure")
        # This is expected in a repo without UE content checked in
        return

    for venue in REQUIRED_VENUE_DIRS:
        venue_dir = content_root / venue
        if not venue_dir.exists():
            err(f"Required venue directory missing: {venue}")

    for venue in STAGING_VENUE_DIRS:
        venue_dir = content_root / venue
        if not venue_dir.exists():
            warn(f"Staging venue directory missing: {venue}")

    print("  ✓ Venue content directories checked")

def validate_config_files_present():
    """Ensure all required config/registry files exist"""
    required_files = [
        ("backend/FEL_ModeManager.production.json", "Mode Manager"),
        ("backend/ue_mode_maps.json", "UE Mode Maps"),
        ("UnrealStarter/BasketballGame/Content/FEL/Config/ArenaSettings.json", "Arena Settings"),
        ("UnrealStarter/BasketballGame/Config/FEL_VenueRegistry.production.json", "Venue Registry"),
        ("infra/ue5_config/DefaultGame.ini", "Default Game INI"),
    ]
    for path, label in required_files:
        full = REPO_ROOT / path
        if not full.exists():
            err(f"Required config missing: {label} ({path})")
        else:
            # Validate JSON files parse correctly
            if path.endswith(".json"):
                try:
                    json.loads(full.read_text())
                except json.JSONDecodeError as e:
                    err(f"Invalid JSON in {label}: {e}")
    print("  ✓ Config file presence validated")

def validate_maps_to_cook_coverage():
    """Verify MapsToCook entries cover all production mode maps"""
    ini_path = REPO_ROOT / "infra" / "ue5_config" / "DefaultGame.ini"
    content = ini_path.read_text()

    import re
    maps_to_cook = set(re.findall(r'\+MapsToCook=\(FilePath="([^"]+)"\)', content))
    play_map = {}
    in_play_map = False
    for line in content.splitlines():
        stripped = line.strip()
        if stripped == "[FELPlayMap]":
            in_play_map = True
            continue
        if in_play_map and stripped.startswith("["):
            break
        if in_play_map and stripped and not stripped.startswith(";") and "=" in stripped:
            mode_id, cooked_path = stripped.split("=", 1)
            play_map[mode_id.strip()] = cooked_path.strip()

    mgr_path = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
    mgr = json.loads(mgr_path.read_text())
    registry = mgr.get("mode_manager", {}).get("mode_registry", {})

    for mode_id, info in registry.items():
        if info.get("status") != "production":
            continue
        if info.get("render_mode") == "IRL":
            continue
        map_path = info.get("map", "")
        cooked_path = play_map.get(mode_id, map_path)
        if cooked_path and cooked_path not in maps_to_cook:
            err(f"Production map not in MapsToCook: {mode_id} → {cooked_path}")

    print("  ✓ MapsToCook coverage validated")

def validate_binary_signatures():
    """Check expected binary signatures in ModeManager"""
    mgr_path = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
    mgr = json.loads(mgr_path.read_text())
    bridge = mgr.get("bridge_subsystem", {})
    sigs = bridge.get("expected_binary_signatures", [])

    required_sigs = [
        "FinalEvolutionLab-iOS-Shipping",
        "FinalEvolutionLab-Linux-Shipping",
    ]
    for sig in required_sigs:
        if sig not in sigs:
            err(f"Missing binary signature: {sig}")

    print("  ✓ Binary signatures validated")

def validate_prq_config():
    """Validate PRQ calculator configuration"""
    mgr_path = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
    mgr = json.loads(mgr_path.read_text())
    prq = mgr.get("prq_calculator", {})

    weights = prq.get("weights", {})
    total = sum(weights.values())
    if abs(total - 1.0) > 0.01:
        err(f"PRQ weights don't sum to 1.0: {total}")

    if prq.get("update_trigger") != "on_session_complete":
        warn(f"PRQ update_trigger is '{prq.get('update_trigger')}', expected 'on_session_complete'")

    print("  ✓ PRQ calculator config validated")


def main():
    print("═══ FEL Cooked Payload Validation ═══\n")
    validate_config_files_present()
    validate_venue_content_dirs()
    validate_maps_to_cook_coverage()
    validate_binary_signatures()
    validate_prq_config()

    print()
    if WARNINGS:
        print(f"⚠️  {len(WARNINGS)} warning(s):")
        for w in WARNINGS:
            print(f"   ⚠ {w}")
    if ERRORS:
        print(f"\n❌ {len(ERRORS)} error(s):")
        for e in ERRORS:
            print(f"   ✗ {e}")
        sys.exit(1)
    else:
        print("✅ All cooked payload validations passed")
        sys.exit(0)

if __name__ == "__main__":
    main()
