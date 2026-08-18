#!/usr/bin/env python3
"""
FEL Smoke Test Suite — production mode acceptance tests.
Checks C++ runtime aliases, Swift split-mode ids, registry config, and economy
coverage without requiring UE maps for intentional IRL/null-map modes.
"""
import json
import sys
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
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

# ═══════════════════════════════════════════════════════════════════════════════
# Production C++ runtime modes expected to pass all gates.
# ═══════════════════════════════════════════════════════════════════════════════
RUNTIME_PRODUCTION_MODES = [
    "basketball_h2h", "basketball_dunk", "basketball_3v3",
    "karate_h2h", "karate_endless",
    "baseball", "football", "soccer", "golf",
    "tennis", "volleyball", "surfing",
    "gymnastics", "skateboarding", "snowboarding",
    "brain_brawl", "who_scene_it", "court_carnival",
]

SWIFT_PRODUCTION_MODES = [
    "basketball_h2h", "basketball_dunk_irl", "basketball_dunk_3d", "basketball_3v3",
    "karate_h2h", "karate_endless",
    "baseball", "football", "soccer", "golf", "tennis", "volleyball",
    "gymnastics", "surfing", "skateboarding", "snowboarding",
    "brain_brawl", "who_scene_it", "court_carnival",
]

BACKEND_PRODUCTION_ENTRIES = sorted(set(RUNTIME_PRODUCTION_MODES + SWIFT_PRODUCTION_MODES))
UE_MAPPED_MODES = sorted(set(RUNTIME_PRODUCTION_MODES + ["basketball_dunk_3d", "market_browse"]))
ARENA_SETTINGS_MODES = UE_MAPPED_MODES
FEL_PLAY_MAP_MODES = UE_MAPPED_MODES
NON_GAME_MODULES = ["market_browse"]
PREVIEW_MODULES = ["movement_lab"]

def load_json_no_duplicate_keys(path):
    duplicate_keys = []

    def hook(pairs):
        seen = set()
        out = {}
        for key, value in pairs:
            if key in seen:
                duplicate_keys.append(key)
            seen.add(key)
            out[key] = value
        return out

    data = json.loads(path.read_text(), object_pairs_hook=hook)
    return data, duplicate_keys

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    mgr = json.loads((REPO_ROOT / "backend" / "FEL_ModeManager.production.json").read_text())
    registry = mgr["mode_manager"]["mode_registry"]

    declared_total = mgr["mode_manager"].get("total_modes")
    declared_production = mgr["mode_manager"].get("production_modes")
    actual_production = sum(1 for info in registry.values() if info["status"] == "production")

    if declared_total == len(registry):
        ok(f"total_modes metadata matches registry ({declared_total})")
    else:
        fail(f"total_modes metadata={declared_total}, actual={len(registry)}")

    if declared_production == actual_production == len(BACKEND_PRODUCTION_ENTRIES):
        ok(f"production_modes metadata matches production registry ({declared_production})")
    else:
        fail(
            f"production_modes metadata={declared_production}, actual={actual_production}, "
            f"expected={len(BACKEND_PRODUCTION_ENTRIES)}"
        )

    for mode in BACKEND_PRODUCTION_ENTRIES:
        if mode in registry:
            info = registry[mode]
            if info["status"] == "production":
                ok(f"{mode} → production, venue_id={info['venue_id']}")
            else:
                fail(f"{mode} status={info['status']}, expected production")
        else:
            fail(f"{mode} missing from ModeManager registry")

    for mode in PREVIEW_MODULES:
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
    ue_maps = json.loads((REPO_ROOT / "backend" / "ue_mode_maps.json").read_text())
    mode_map = ue_maps["mode_to_unreal_map"]

    all_modes = sorted(set(UE_MAPPED_MODES + ["basketball_dunk_irl"]))
    for mode in all_modes:
        if mode in mode_map:
            if mode_map[mode] is None:
                ok(f"{mode} → IRL/null UE map (expected)")
            else:
                ok(f"{mode} → {mode_map[mode]}")
        else:
            fail(f"{mode} missing from ue_mode_maps.json")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 3: ArenaSettings Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_arena_settings():
    print("\n── Test 3: ArenaSettings Config ──")
    arena_path = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json"
    arena, duplicate_keys = load_json_no_duplicate_keys(arena_path)
    if duplicate_keys:
        fail(f"ArenaSettings has duplicate mode keys: {sorted(set(duplicate_keys))}")
    else:
        ok("ArenaSettings has no duplicate JSON keys")
    modes = arena["modes"]

    for mode in ARENA_SETTINGS_MODES:
        if mode in modes:
            cfg = modes[mode]
            has_level = "unrealOpenLevelPackage" in cfg
            has_display = "modeDisplayName" in cfg
            if has_level and has_display:
                ok(f"{mode} → {cfg['modeDisplayName']}")
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

    registry_modes = SWIFT_PRODUCTION_MODES + NON_GAME_MODULES
    for mode in registry_modes:
        if mode in mode_ids:
            entry = next(m for m in vr["modes"] if m["id"] == mode)
            if entry["venueKey"] in venue_keys:
                ok(f"{mode} → venue={entry['venueKey']}")
            else:
                fail(f"{mode} references unknown venue: {entry['venueKey']}")
        else:
            fail(f"{mode} missing from VenueRegistry")

    dunk_3d = next((m for m in vr["modes"] if m["id"] == "basketball_dunk_3d"), None)
    if dunk_3d and dunk_3d.get("nexusRuntimeModeId") == "basketball_dunk":
        ok("basketball_dunk runtime alias resolves through basketball_dunk_3d venue entry")
    else:
        fail("basketball_dunk runtime alias missing from basketball_dunk_3d venue entry")

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

    for mode in FEL_PLAY_MAP_MODES:
        if mode in play_map:
            path = play_map[mode]
            # Verify path uses /Venues/ convention
            if "/Venues/" in path:
                ok(f"{mode} → {path}")
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

    swift_modes = SWIFT_PRODUCTION_MODES + NON_GAME_MODULES
    for mode in swift_modes:
        # Search for rawValue
        if f'= "{mode}"' in content:
            ok(f'{mode} has Swift enum case')
        else:
            fail(f'{mode} missing from GameMode.swift enum')

    if 'case "basketball_dunk":' in content and "basketballDunkContest3D" in content:
        ok("basketball_dunk runtime alias resolves to Swift basketball_dunk_3d")
    else:
        fail("basketball_dunk runtime alias missing from Swift playableMode(forRegistryId:)")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 7: Server.py Seeded Game Modes
# ═══════════════════════════════════════════════════════════════════════════════
def test_server_seeded_modes():
    print("\n── Test 7: Server Seeded Game Modes ──")
    server_path = REPO_ROOT / "backend" / "server.py"
    content = server_path.read_text()

    for mode in RUNTIME_PRODUCTION_MODES:
        if f'"id":"{mode}"' in content or f'"id": "{mode}"' in content:
            ok(f"{mode} in server seeded modes")
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

    # Verify PRQ weights cover all scoring modes
    scoring_modes = RUNTIME_PRODUCTION_MODES
    for mode in scoring_modes:
        if f'"{mode}"' in content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0]:
            ok(f"PRQ weight defined for {mode}")
        else:
            fail(f"PRQ weight missing for {mode}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print("  18 runtime modes · 19 Swift production ids · Registry → Economy")
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
