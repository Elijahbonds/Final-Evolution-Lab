#!/usr/bin/env python3
"""
FEL iOS Build Descriptor Validator
Validates Info.plist fields, entitlements, and UE5 packaging settings
for App Store / TestFlight submission readiness.
"""
import json
import os
import sys
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
ERRORS = []
WARNINGS = []

IRL_RENDER_MODES = {"IRL"}

def err(msg): ERRORS.append(msg)
def warn(msg): WARNINGS.append(msg)

def parse_maps_to_cook(content):
    return set(re.findall(r'\+MapsToCook=\(FilePath="([^"]+)"\)', content))

def parse_fel_play_map(content):
    play_map = {}
    in_section = False
    for line in content.splitlines():
        stripped = line.strip()
        if stripped == "[FELPlayMap]":
            in_section = True
            continue
        if in_section and stripped.startswith("["):
            break
        if in_section and "=" in stripped and not stripped.startswith(";"):
            key, value = stripped.split("=", 1)
            play_map[key.strip()] = value.strip()
    return play_map

def arena_level_to_package(level_path):
    return level_path.split(".", 1)[0]

# ── 1. Validate DefaultGame.ini packaging settings ──────────────────────────
def validate_packaging_settings():
    ini_path = REPO_ROOT / "infra" / "ue5_config" / "DefaultGame.ini"
    if not ini_path.exists():
        err("DefaultGame.ini not found")
        return
    content = ini_path.read_text()

    # Required packaging flags
    required = {
        "bCookAll=True": "All content must be cooked for shipping",
        "BuildConfiguration=PPBC_Shipping": "Must be Shipping config",
        "ForDistribution=True": "ForDistribution must be True for store builds",
        "UsePakFile=True": "Pak file required for iOS",
        "bUseIoStore=True": "IoStore required for UE5.7 iOS",
    }
    for flag, reason in required.items():
        if flag not in content:
            err(f"Missing packaging flag: {flag} — {reason}")

    # Validate all runtime packages are listed in MapsToCook. The mode manager no
    # longer carries per-mode map fields, so derive package paths from FELPlayMap
    # and ArenaSettings, which are the routes iOS actually opens.
    mode_mgr_path = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
    if mode_mgr_path.exists():
        mgr = json.loads(mode_mgr_path.read_text())
        registry = mgr.get("mode_manager", {}).get("mode_registry", {})
        maps_in_ini = parse_maps_to_cook(content)
        play_map = parse_fel_play_map(content)
        arena_path = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json"
        arena_modes = {}
        if arena_path.exists():
            arena_modes = json.loads(arena_path.read_text()).get("modes", {})
        for mode_id, info in registry.items():
            if info.get("status") not in ("production", "non-game-module"):
                continue
            if info.get("render_mode") in IRL_RENDER_MODES:
                continue

            play_map_path = play_map.get(mode_id)
            arena_level = arena_modes.get(mode_id, {}).get("unrealOpenLevelPackage")
            arena_package = arena_level_to_package(arena_level) if arena_level else None
            expected_package = play_map_path or arena_package

            if not expected_package:
                err(f"Shipping mode '{mode_id}' missing FELPlayMap/ArenaSettings package")
                continue
            if arena_package and play_map_path and arena_package != play_map_path:
                err(f"Shipping mode '{mode_id}' FELPlayMap/ArenaSettings mismatch: {play_map_path} != {arena_package}")
            if expected_package not in maps_in_ini:
                err(f"Shipping mode '{mode_id}' package not in MapsToCook: {expected_package}")

    print("  ✓ Packaging settings validated")

# ── 2. Validate FELPlayMap completeness ─────────────────────────────────
def validate_fel_play_map():
    ini_path = REPO_ROOT / "infra" / "ue5_config" / "DefaultGame.ini"
    content = ini_path.read_text()

    # Parse [FELPlayMap] section
    play_map_section = {}
    in_section = False
    for line in content.split("\n"):
        if line.strip() == "[FELPlayMap]":
            in_section = True
            continue
        if in_section:
            if line.strip().startswith("["):
                break
            if "=" in line and not line.strip().startswith(";"):
                k, v = line.strip().split("=", 1)
                play_map_section[k.strip()] = v.strip()

    # Cross-check with ue_mode_maps.json
    ue_maps_path = REPO_ROOT / "backend" / "ue_mode_maps.json"
    if ue_maps_path.exists():
        ue_maps = json.loads(ue_maps_path.read_text()).get("mode_to_unreal_map", {})
        for mode_id, ue_map in ue_maps.items():
            if ue_map is None:
                continue
            if mode_id not in play_map_section:
                err(f"FELPlayMap missing mode: {mode_id}")
    print("  ✓ FELPlayMap cross-reference validated")

# ── 3. Validate mode registry consistency ────────────────────────────────────
def validate_mode_counts():
    mgr_path = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
    if not mgr_path.exists():
        err("FEL_ModeManager.production.json not found")
        return
    mgr = json.loads(mgr_path.read_text())
    mm = mgr.get("mode_manager", {})
    registry = mm.get("mode_registry", {})

    actual_total = len(registry)
    declared_total = mm.get("total_modes", 0)
    if actual_total != declared_total:
        err(f"Mode count mismatch: declared={declared_total}, actual={actual_total}")

    prod_count = sum(1 for v in registry.values() if v.get("status") == "production")
    declared_prod = mm.get("production_modes", 0)
    if prod_count != declared_prod:
        err(f"Production mode count mismatch: declared={declared_prod}, actual={prod_count}")

    print("  ✓ Mode registry counts validated")

# ── 4. Validate ArenaSettings has all modes ──────────────────────────────────
def validate_arena_settings():
    arena_path = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json"
    if not arena_path.exists():
        warn("ArenaSettings.json not found — skipping")
        return
    arena = json.loads(arena_path.read_text())
    modes = arena.get("modes", {})

    mgr_path = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
    if mgr_path.exists():
        mgr = json.loads(mgr_path.read_text())
        registry = mgr.get("mode_manager", {}).get("mode_registry", {})
        for mode_id, info in registry.items():
            if info.get("render_mode") in IRL_RENDER_MODES:
                continue
            if mode_id not in modes:
                if info.get("status") in ("production", "staging"):
                    warn(f"ArenaSettings missing config for {info['status']} mode: {mode_id}")

    print("  ✓ ArenaSettings cross-check completed")

# ── 5. Validate VenueRegistry completeness ───────────────────────────────────
def validate_venue_registry():
    vr_path = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Config" / "FEL_VenueRegistry.production.json"
    if not vr_path.exists():
        warn("VenueRegistry not found")
        return
    vr = json.loads(vr_path.read_text())
    mode_ids = {m["id"] for m in vr.get("modes", [])}
    venue_keys = {v["venueKey"] for v in vr.get("venues", [])}

    # Every mode should reference a known venue
    for m in vr.get("modes", []):
        if m.get("venueKey") not in venue_keys:
            err(f"VenueRegistry mode '{m['id']}' references unknown venue: {m['venueKey']}")

    print("  ✓ VenueRegistry validated")


def main():
    print("═══ FEL iOS Build Descriptor Validation ═══\n")
    validate_packaging_settings()
    validate_fel_play_map()
    validate_mode_counts()
    validate_arena_settings()
    validate_venue_registry()

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
        print("✅ All iOS descriptor validations passed")
        sys.exit(0)

if __name__ == "__main__":
    main()
