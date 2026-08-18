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
_DUPLICATE_JSON_KEYS = {}

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

def _strict_object_pairs(path):
    def hook(pairs):
        obj = {}
        seen = set()
        duplicates = []
        for key, value in pairs:
            if key in seen:
                duplicates.append(key)
            seen.add(key)
            obj[key] = value
        if duplicates:
            _DUPLICATE_JSON_KEYS.setdefault(str(path), []).extend(duplicates)
        return obj
    return hook

def load_json(path):
    _DUPLICATE_JSON_KEYS.pop(str(path), None)
    return json.loads(path.read_text(), object_pairs_hook=_strict_object_pairs(path))

# ═══════════════════════════════════════════════════════════════════════════════
# Production registry entries expected to pass all gates. `basketball_dunk` is the
# C++ runtime alias; iOS surfaces split `basketball_dunk_3d` / `basketball_dunk_irl`.
# ═══════════════════════════════════════════════════════════════════════════════
PRODUCTION_MODES = [
    "basketball_h2h", "basketball_dunk", "basketball_dunk_3d", "basketball_dunk_irl",
    "basketball_3v3",
    "karate_h2h", "karate_endless",
    "baseball", "football", "soccer", "golf",
    "tennis", "volleyball", "surfing",
    "gymnastics", "skateboarding", "snowboarding",
    "brain_brawl", "who_scene_it", "court_carnival",
]

NON_GAME_MODULES = ["market_browse"]
PREVIEW_MODES = ["movement_lab"]

STAGING_MODES = []
RUNTIME_PRODUCTION_MODES = [
    mode for mode in PRODUCTION_MODES
    if mode not in ("basketball_dunk_3d", "basketball_dunk_irl")
]
SWIFT_PRODUCTION_MODES = [
    mode for mode in PRODUCTION_MODES if mode != "basketball_dunk"
]

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    mgr_path = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
    mgr = load_json(mgr_path)
    manager = mgr["mode_manager"]
    registry = mgr["mode_manager"]["mode_registry"]

    declared_total = manager.get("total_modes")
    declared_production = manager.get("production_modes")
    actual_total = len(registry)
    actual_production = sum(1 for info in registry.values() if info.get("status") == "production")
    if declared_total == actual_total:
        ok(f"declared total_modes={declared_total} matches registry")
    else:
        fail(f"declared total_modes={declared_total}, actual={actual_total}")
    if declared_production == actual_production == len(PRODUCTION_MODES):
        ok(f"declared production_modes={declared_production} matches canonical production set")
    else:
        fail(
            f"production count drift: declared={declared_production}, "
            f"actual={actual_production}, expected={len(PRODUCTION_MODES)}"
        )

    for mode in PRODUCTION_MODES:
        if mode in registry:
            info = registry[mode]
            if info["status"] == "production":
                ok(f"{mode} → production, venue_id={info['venue_id']}")
            else:
                fail(f"{mode} status={info['status']}, expected production")
        else:
            fail(f"{mode} missing from ModeManager registry")

    for mode in STAGING_MODES:
        if mode in registry and registry[mode]["status"] == "staging":
            ok(f"{mode} → staging (expected)")
        elif mode in registry:
            fail(f"{mode} status={registry[mode]['status']}, expected staging")
        else:
            fail(f"{mode} missing from registry")

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

    duplicates = _DUPLICATE_JSON_KEYS.get(str(mgr_path))
    if duplicates:
        fail(f"Duplicate keys in {mgr_path}: {duplicates}")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 2: UE Mode Maps Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_ue_mode_maps():
    print("\n── Test 2: UE Mode Maps ──")
    ue_path = REPO_ROOT / "backend" / "ue_mode_maps.json"
    ue_maps = load_json(ue_path)
    mode_map = ue_maps["mode_to_unreal_map"]

    all_modes = PRODUCTION_MODES + NON_GAME_MODULES
    for mode in all_modes:
        if mode in mode_map:
            if mode == "basketball_dunk_irl" and mode_map[mode] is None:
                ok(f"{mode} → no UE map (IRL mode)")
            elif mode_map[mode]:
                ok(f"{mode} → {mode_map[mode]}")
            else:
                fail(f"{mode} has an empty UE map")
        else:
            fail(f"{mode} missing from ue_mode_maps.json")

    duplicates = _DUPLICATE_JSON_KEYS.get(str(ue_path))
    if duplicates:
        fail(f"Duplicate keys in {ue_path}: {duplicates}")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 3: ArenaSettings Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_arena_settings():
    print("\n── Test 3: ArenaSettings Config ──")
    arena_path = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json"
    arena = load_json(arena_path)
    modes = arena["modes"]

    all_modes = [mode for mode in PRODUCTION_MODES + NON_GAME_MODULES if mode != "basketball_dunk_irl"]
    for mode in all_modes:
        arena_mode = "basketball_dunk" if mode == "basketball_dunk_3d" else mode
        if arena_mode in modes:
            cfg = modes[arena_mode]
        else:
            fail(f"{mode} missing from ArenaSettings.json")
            continue
        has_level = "unrealOpenLevelPackage" in cfg
        has_display = "modeDisplayName" in cfg
        if has_level and has_display:
            ok(f"{mode} → {cfg['modeDisplayName']}")
        else:
            fail(f"{mode} missing unrealOpenLevelPackage or modeDisplayName")

    duplicates = _DUPLICATE_JSON_KEYS.get(str(arena_path))
    if duplicates:
        fail(f"Duplicate keys in {arena_path}: {duplicates}")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 4: VenueRegistry Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_venue_registry():
    print("\n── Test 4: VenueRegistry Coverage ──")
    vr_path = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Config" / "FEL_VenueRegistry.production.json"
    vr = load_json(vr_path)
    mode_ids = {m["id"] for m in vr["modes"]}
    venue_keys = {v["venueKey"] for v in vr["venues"]}

    all_modes = [mode for mode in PRODUCTION_MODES + NON_GAME_MODULES if mode != "basketball_dunk_irl"]
    for mode in all_modes:
        if mode in mode_ids:
            entry = next(m for m in vr["modes"] if m["id"] == mode)
            if entry["venueKey"] in venue_keys:
                ok(f"{mode} → venue={entry['venueKey']}")
            else:
                fail(f"{mode} references unknown venue: {entry['venueKey']}")
        else:
            fail(f"{mode} missing from VenueRegistry")

    duplicates = _DUPLICATE_JSON_KEYS.get(str(vr_path))
    if duplicates:
        fail(f"Duplicate keys in {vr_path}: {duplicates}")

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

    all_modes = [mode for mode in PRODUCTION_MODES + NON_GAME_MODULES if mode != "basketball_dunk_irl"]
    for mode in all_modes:
        if mode in play_map:
            path = play_map[mode]
            # Verify path uses /Venues/ convention
            if "/Venues/" in path:
                ok(f"{mode} → {path}")
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

    all_modes = SWIFT_PRODUCTION_MODES + NON_GAME_MODULES
    for mode in all_modes:
        # Search for rawValue
        if f'= "{mode}"' in content:
            ok(f'{mode} has Swift enum case')
        else:
            fail(f'{mode} missing from GameMode.swift enum')

# ═══════════════════════════════════════════════════════════════════════════════
# Test 7: Server.py Seeded Game Modes
# ═══════════════════════════════════════════════════════════════════════════════
def test_server_seeded_modes():
    print("\n── Test 7: Server Seeded Game Modes ──")
    server_path = REPO_ROOT / "backend" / "server.py"
    content = server_path.read_text()

    all_modes = RUNTIME_PRODUCTION_MODES + NON_GAME_MODULES
    for mode in all_modes:
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
    scoring_modes = RUNTIME_PRODUCTION_MODES  # server economy scores runtime ids, not split iOS aliases
    for mode in scoring_modes:
        if f'"{mode}"' in content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0]:
            ok(f"PRQ weight defined for {mode}")
        else:
            fail(f"PRQ weight missing for {mode}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print(f"  {len(PRODUCTION_MODES)} production registry entries · 8 test categories · Registry → Economy")
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
