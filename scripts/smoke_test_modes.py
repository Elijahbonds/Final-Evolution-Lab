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
sys.path.insert(0, str(REPO_ROOT / "backend"))

from registry_utils import launchable_mode_maps, load_ue_mode_maps, normalized_modes, production_count

PASS = 0
FAIL = 0
SKIP = 0

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

MODE_MANAGER_DATA = json.loads((REPO_ROOT / "backend" / "FEL_ModeManager.production.json").read_text())
VENUE_REGISTRY_DATA = json.loads((REPO_ROOT / "backend" / "FEL_VenueRegistry.production.json").read_text())
UE_MODE_MAPS = load_ue_mode_maps(REPO_ROOT / "backend")
NORMALIZED_MODES = normalized_modes(MODE_MANAGER_DATA, VENUE_REGISTRY_DATA, UE_MODE_MAPS)
MODES_BY_ID = {mode["mode_id"]: mode for mode in NORMALIZED_MODES}
RAW_REGISTRY = MODE_MANAGER_DATA["mode_manager"]["mode_registry"]
PRODUCTION_MODES = [mode["mode_id"] for mode in NORMALIZED_MODES if mode["status"] == "production"]
LAUNCHABLE_MODES = [mode["mode_id"] for mode in NORMALIZED_MODES if mode["launchable"]]
NON_GAME_MODULES = [mode["mode_id"] for mode in NORMALIZED_MODES if mode["status"] == "non-game-module"]
PREVIEW_MODES = [mode["mode_id"] for mode in NORMALIZED_MODES if mode["status"] == "preview"]


def swift_ids_for(mode: str) -> list[str]:
    if mode == "basketball_dunk":
        return ["basketball_dunk_3d", "basketball_dunk_irl"]
    return [mode]


def server_ids_for(mode: str) -> list[str]:
    runtime_id = MODES_BY_ID[mode].get("nexus_runtime_mode_id", mode)
    ids = [mode]
    if runtime_id != mode:
        ids.append(runtime_id)
    if mode == "basketball_dunk_3d":
        ids.append("basketball_dunk")
    return ids


def ue_aliases_for(mode: str) -> list[str]:
    if mode == "basketball_dunk_3d":
        return ["basketball_dunk"]
    return []

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    registry = RAW_REGISTRY
    declared_total = MODE_MANAGER_DATA["mode_manager"]["total_modes"]
    declared_production = MODE_MANAGER_DATA["mode_manager"]["production_modes"]
    if declared_total == len(registry):
        ok(f"declared total_modes matches registry ({declared_total})")
    else:
        fail(f"declared total_modes={declared_total}, actual={len(registry)}")
    actual_production = production_count(NORMALIZED_MODES)
    if declared_production == actual_production:
        ok(f"declared production_modes matches registry ({declared_production})")
    else:
        fail(f"declared production_modes={declared_production}, actual={actual_production}")

    for mode in PRODUCTION_MODES:
        if mode in registry:
            info = registry[mode]
            if info["status"] == "production":
                ok(f"{mode} → production, venue_id={info.get('venue_id')}")
            else:
                fail(f"{mode} status={info['status']}, expected production")
        else:
            fail(f"{mode} missing from ModeManager registry")

    for mode in PREVIEW_MODES:
        if mode in registry and registry[mode]["status"] == "preview":
            ok(f"{mode} → preview (expected)")
        else:
            fail(f"{mode} missing or wrong status in registry")

    for mode in NON_GAME_MODULES:
        if mode in registry and registry[mode]["status"] == "non-game-module":
            ok(f"{mode} → non-game-module (expected)")
        elif mode in registry:
            fail(f"{mode} status={registry[mode]['status']}, expected non-game-module")
        else:
            fail(f"{mode} missing from registry")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 2: UE Mode Maps Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_ue_mode_maps():
    print("\n── Test 2: UE Mode Maps ──")
    mode_map = launchable_mode_maps(MODE_MANAGER_DATA, VENUE_REGISTRY_DATA, UE_MODE_MAPS)

    for mode in LAUNCHABLE_MODES:
        if mode in mode_map:
            ok(f"{mode} → {mode_map[mode]}")
        else:
            fail(f"{mode} missing from launchable mode maps")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 3: ArenaSettings Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_arena_settings():
    print("\n── Test 3: ArenaSettings Config ──")
    arena = json.loads((REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json").read_text())
    modes = arena["modes"]

    for mode in LAUNCHABLE_MODES:
        arena_mode = mode if mode in modes else next((alias for alias in ue_aliases_for(mode) if alias in modes), None)
        if arena_mode:
            cfg = modes[arena_mode]
            has_level = "unrealOpenLevelPackage" in cfg
            has_display = "modeDisplayName" in cfg
            if has_level and has_display:
                alias_note = f" via {arena_mode}" if arena_mode != mode else ""
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

    for mode in LAUNCHABLE_MODES:
        if mode in mode_ids:
            entry = next(m for m in vr["modes"] if m["id"] == mode)
            if entry["venueKey"] in venue_keys:
                ok(f"{mode} → venue={entry['venueKey']}")
            else:
                fail(f"{mode} references unknown venue: {entry['venueKey']}")
        elif MODES_BY_ID[mode].get("map"):
            ok(f"{mode} → normalized venue={MODES_BY_ID[mode]['map']}")
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

    for mode in LAUNCHABLE_MODES:
        play_mode = mode if mode in play_map else next((alias for alias in ue_aliases_for(mode) if alias in play_map), None)
        if play_mode:
            path = play_map[play_mode]
            # Verify path uses /Venues/ convention
            if "/Venues/" in path:
                alias_note = f" via {play_mode}" if play_mode != mode else ""
                ok(f"{mode}{alias_note} → {path}")
            else:
                fail(f"{mode} deep link path doesn't use /Venues/ convention: {path}")
        else:
            if mode in ("market_browse",):
                # market_browse has its own path format
                if mode in play_map:
                    ok(f"{mode} → {play_map[mode]}")
                else:
                    fail(f"{mode} missing from FELPlayMap")
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
        expected_ids = swift_ids_for(mode)
        if any(f'= "{swift_id}"' in content for swift_id in expected_ids):
            ok(f'{mode} has Swift enum coverage')
        else:
            fail(f"{mode} missing from GameMode.swift enum (expected one of {expected_ids})")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 7: Server.py Seeded Game Modes
# ═══════════════════════════════════════════════════════════════════════════════
def test_server_seeded_modes():
    print("\n── Test 7: Server Seeded Game Modes ──")
    server_path = REPO_ROOT / "backend" / "server.py"
    content = server_path.read_text()

    for mode in LAUNCHABLE_MODES:
        candidate_ids = server_ids_for(mode)
        if any(f'"id":"{candidate}"' in content or f'"id": "{candidate}"' in content for candidate in candidate_ids):
            ok(f"{mode} in server seeded modes")
        else:
            fail(f"{mode} missing from server.py seeded modes (checked {candidate_ids})")

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

    # Verify PRQ weights cover all scoring modes
    scoring_modes = [
        mode
        for mode in PRODUCTION_MODES
        if RAW_REGISTRY[mode].get("scoring_enabled", True) and mode not in ("basketball_dunk_irl",)
    ]
    for mode in scoring_modes:
        candidate_ids = server_ids_for(mode)
        if any(f'"{candidate}"' in content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0] for candidate in candidate_ids):
            ok(f"PRQ weight defined for {mode}")
        else:
            fail(f"PRQ weight missing for {mode} (checked {candidate_ids})")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print(f"  {len(PRODUCTION_MODES)} production entries · {len(LAUNCHABLE_MODES)} launchable · Registry → Economy")
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
