#!/usr/bin/env python3
"""
FEL Smoke Test Suite — 12 Production Mode Acceptance Tests
Tests each production mode's registration, configuration, and deep link routing.
Run against a live or mock FEL backend.
"""
import json
import sys
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PASS = 0
FAIL = 0
SKIP = 0

MODE_MANAGER = json.loads((REPO_ROOT / "backend" / "FEL_ModeManager.production.json").read_text())
REGISTRY = MODE_MANAGER["mode_manager"]["mode_registry"]
UE_MODE_MAPS = json.loads((REPO_ROOT / "backend" / "ue_mode_maps.json").read_text())["mode_to_unreal_map"]

RUNTIME_CONFIG_ALIASES = {
    "basketball_dunk_3d": "basketball_dunk",
}
VENUE_REGISTRY_ALIASES = {
    "basketball_dunk": "basketball_dunk_3d",
}
SWIFT_ENUM_ALIASES = {
    "basketball_dunk": "basketball_dunk_3d",
}
SERVER_SEED_ALIASES = {
    "basketball_dunk_3d": "basketball_dunk",
}

def modes_with_status(status):
    return [mode for mode, info in REGISTRY.items() if info.get("status") == status]

def is_non_ue_runtime_mode(mode):
    info = REGISTRY.get(mode, {})
    return (
        info.get("render_mode") == "IRL"
        or info.get("venue_id") is None
        or UE_MODE_MAPS.get(mode) is None
        or mode == "movement_lab"
    )

def candidate_ids(mode, aliases):
    alias = aliases.get(mode)
    return [mode] if alias is None or alias == mode else [mode, alias]

def ok(msg):
    global PASS
    PASS += 1
    print(f"  ✅ {msg}")

def fail(msg):
    global FAIL
    FAIL += 1
    print(f"  ❌ {msg}")

def skip(msg):
    global SKIP
    SKIP += 1
    print(f"  ⏭  {msg}")

# ═══════════════════════════════════════════════════════════════════════════════
# Production modes expected to pass all gates
# ═══════════════════════════════════════════════════════════════════════════════
PRODUCTION_MODES = modes_with_status("production")
NON_GAME_MODULES = modes_with_status("non-game-module")
STAGING_MODES = modes_with_status("staging")
PREVIEW_MODES = modes_with_status("preview")
REGISTRY_GAME_MODES = PRODUCTION_MODES + STAGING_MODES + PREVIEW_MODES
UE_CONFIGURED_MODES = [mode for mode in REGISTRY_GAME_MODES if not is_non_ue_runtime_mode(mode)]

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    declared_total = MODE_MANAGER["mode_manager"]["total_modes"]
    declared_production = MODE_MANAGER["mode_manager"]["production_modes"]
    actual_total = len(REGISTRY)
    actual_production = len(PRODUCTION_MODES)
    if declared_total == actual_total:
        ok(f"declared total_modes={declared_total}")
    else:
        fail(f"declared total_modes={declared_total}, actual={actual_total}")
    if declared_production == actual_production:
        ok(f"declared production_modes={declared_production}")
    else:
        fail(f"declared production_modes={declared_production}, actual={actual_production}")

    for mode in PRODUCTION_MODES:
        if mode in REGISTRY:
            info = REGISTRY[mode]
            if info["status"] == "production":
                ok(f"{mode} → production, venue_id={info['venue_id']}")
            else:
                fail(f"{mode} status={info['status']}, expected production")
        else:
            fail(f"{mode} missing from ModeManager registry")

    for mode in STAGING_MODES:
        if mode in REGISTRY and REGISTRY[mode]["status"] == "staging":
            ok(f"{mode} → staging (expected)")
        elif mode in REGISTRY:
            fail(f"{mode} status={REGISTRY[mode]['status']}, expected staging")
        else:
            fail(f"{mode} missing from registry")

    for mode in PREVIEW_MODES:
        if mode in REGISTRY and REGISTRY[mode]["status"] == "preview":
            ok(f"{mode} → preview (expected)")
        else:
            fail(f"{mode} missing or wrong status in registry")

    for mode in NON_GAME_MODULES:
        if mode in REGISTRY and REGISTRY[mode]["status"] == "non-game-module":
            ok(f"{mode} → non-game-module (expected)")
        elif mode in REGISTRY:
            fail(f"{mode} status={REGISTRY[mode]['status']}, expected non-game-module")
        else:
            fail(f"{mode} missing from registry")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 2: UE Mode Maps Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_ue_mode_maps():
    print("\n── Test 2: UE Mode Maps ──")
    for mode in REGISTRY_GAME_MODES + NON_GAME_MODULES:
        if mode in UE_MODE_MAPS:
            if UE_MODE_MAPS[mode] is None:
                ok(f"{mode} → no UE map (intentional non-UE mode)")
            else:
                ok(f"{mode} → {UE_MODE_MAPS[mode]}")
        else:
            fail(f"{mode} missing from ue_mode_maps.json")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 3: ArenaSettings Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_arena_settings():
    print("\n── Test 3: ArenaSettings Config ──")
    arena = json.loads((REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json").read_text())
    modes = arena["modes"]

    for mode in UE_CONFIGURED_MODES:
        found = next((candidate for candidate in candidate_ids(mode, RUNTIME_CONFIG_ALIASES) if candidate in modes), None)
        if found:
            cfg = modes[found]
            has_level = "unrealOpenLevelPackage" in cfg
            has_display = "modeDisplayName" in cfg
            if has_level and has_display:
                alias_note = f" via {found}" if found != mode else ""
                ok(f"{mode}{alias_note} → {cfg['modeDisplayName']}")
            else:
                fail(f"{mode} missing unrealOpenLevelPackage or modeDisplayName")
        else:
            fail(f"{mode} missing from ArenaSettings.json")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 4: VenueRegistry Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_venue_registry():
    print("\n── Test 4: VenueRegistry Coverage ──")
    vr = json.loads((REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Config" / "FEL_VenueRegistry.production.json").read_text())
    mode_ids = {m["id"] for m in vr["modes"]}
    venue_keys = {v["venueKey"] for v in vr["venues"]}

    for mode in UE_CONFIGURED_MODES:
        found = next((candidate for candidate in candidate_ids(mode, VENUE_REGISTRY_ALIASES) if candidate in mode_ids), None)
        if found:
            entry = next(m for m in vr["modes"] if m["id"] == found)
            if entry["venueKey"] in venue_keys:
                alias_note = f" via {found}" if found != mode else ""
                ok(f"{mode}{alias_note} → venue={entry['venueKey']}")
            else:
                fail(f"{mode} references unknown venue: {entry['venueKey']}")
        else:
            fail(f"{mode} missing from VenueRegistry")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 5: DefaultGame.ini FELPlayMap
# ═══════════════════════════════════════════════════════════════════════════════
def test_fel_play_map():
    print("\n── Test 5: FELPlayMap Deep Link Routing ──")
    content = (REPO_ROOT / "infra" / "ue5_config" / "DefaultGame.ini").read_text()

    play_map = {}
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
                play_map[k.strip()] = v.strip()

    for mode in UE_CONFIGURED_MODES:
        found = next((candidate for candidate in candidate_ids(mode, RUNTIME_CONFIG_ALIASES) if candidate in play_map), None)
        if found:
            path = play_map[found]
            # Verify path uses /Venues/ convention
            if "/Venues/" in path:
                alias_note = f" via {found}" if found != mode else ""
                ok(f"{mode}{alias_note} → {path}")
            else:
                fail(f"{mode} deep link path doesn't use /Venues/ convention: {path}")
        else:
            fail(f"{mode} missing from FELPlayMap")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 6: Swift GameMode Enum
# ═══════════════════════════════════════════════════════════════════════════════
def test_swift_enum():
    print("\n── Test 6: Swift GameMode Enum ──")
    swift_path = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
    content = swift_path.read_text()

    for mode in PRODUCTION_MODES:
        # Search for rawValue
        found = next((candidate for candidate in candidate_ids(mode, SWIFT_ENUM_ALIASES) if f'= "{candidate}"' in content), None)
        if found:
            alias_note = f" via {found}" if found != mode else ""
            ok(f'{mode}{alias_note} has Swift enum case')
        else:
            fail(f'{mode} missing from GameMode.swift enum')

# ═══════════════════════════════════════════════════════════════════════════════
# Test 7: Server.py Seeded Game Modes
# ═══════════════════════════════════════════════════════════════════════════════
def test_server_seeded_modes():
    print("\n── Test 7: Server Seeded Game Modes ──")
    server_path = REPO_ROOT / "backend" / "server.py"
    content = server_path.read_text()

    for mode in UE_CONFIGURED_MODES:
        found = next((candidate for candidate in candidate_ids(mode, SERVER_SEED_ALIASES) if f'"id":"{candidate}"' in content or f'"id": "{candidate}"' in content), None)
        if found:
            alias_note = f" via {found}" if found != mode else ""
            ok(f"{mode}{alias_note} in server seeded modes")
        else:
            fail(f"{mode} missing from server.py seeded modes")

    # Verify all mario_party references have been scrubbed
    if 'mario_party' in content:
        fail("mario_party still referenced in server.py — scrub incomplete")
    else:
        ok("No mario_party references in server.py")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 8: Economy Integration
# ═══════════════════════════════════════════════════════════════════════════════
def test_economy_integration():
    print("\n── Test 8: Economy Integration ──")
    server_path = REPO_ROOT / "backend" / "server.py"
    content = server_path.read_text()

    checks = [
        ("PRQ_MODE_WEIGHTS", "PRQ mode weights dict"),
        ("_compute_prq_delta", "PRQ delta calculator"),
        ("_compute_shard_reward", "Shard reward calculator"),
        ("XP_CAP_PER_SESSION", "XP cap constant"),
        ("shard_ledger", "Shard ledger recording"),
        ("prq_delta", "PRQ delta in session receipt"),
        ("shards_earned", "Shards in session receipt"),
    ]
    for pattern, label in checks:
        if pattern in content:
            ok(f"{label} present")
        else:
            fail(f"{label} missing")

    # Verify PRQ weights cover all scoring map-backed modes.
    scoring_modes = [
        mode for mode in PRODUCTION_MODES
        if REGISTRY.get(mode, {}).get("prq_weight", 0) > 0 and not is_non_ue_runtime_mode(mode)
    ]
    for mode in scoring_modes:
        found = next((candidate for candidate in candidate_ids(mode, SERVER_SEED_ALIASES) if f'"{candidate}"' in content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0]), None)
        if found:
            alias_note = f" via {found}" if found != mode else ""
            ok(f"PRQ weight defined for {mode}{alias_note}")
        else:
            fail(f"PRQ weight missing for {mode}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print(f"  {len(PRODUCTION_MODES)} production entries · {len(UE_CONFIGURED_MODES)} map-backed modes · 8 categories")
    print("═══════════════════════════════════════════════════════════")

    test_mode_manager_registry()
    test_ue_mode_maps()
    test_arena_settings()
    test_venue_registry()
    test_fel_play_map()
    test_swift_enum()
    test_server_seeded_modes()
    test_economy_integration()

    total = PASS + FAIL + SKIP
    print(f"\n{'═'*60}")
    print(f"  Results: {PASS} passed · {FAIL} failed · {SKIP} skipped · {total} total")
    print(f"{'═'*60}")

    if FAIL > 0:
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
