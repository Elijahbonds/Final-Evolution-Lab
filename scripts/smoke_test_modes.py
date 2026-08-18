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

MODE_MANAGER_PATH = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
UE_MODE_MAPS_PATH = REPO_ROOT / "backend" / "ue_mode_maps.json"
ARENA_SETTINGS_PATH = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json"
VENUE_REGISTRY_PATH = REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Config" / "FEL_VenueRegistry.production.json"
FEL_PLAY_MAP_PATH = REPO_ROOT / "infra" / "ue5_config" / "DefaultGame.ini"
SWIFT_GAME_MODE_PATH = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
SERVER_PATH = REPO_ROOT / "backend" / "server.py"

# Intentional identity differences:
# - Swift/iOS exposes split dunk modes.
# - NEXUS C++ runtime and archived UE maps still use basketball_dunk for the 3D path.
# - IRL dunk and Movement Lab are not UE map launches.
RUNTIME_ALIASES = {"basketball_dunk_3d": "basketball_dunk"}
SWIFT_ALIAS_TARGETS = {"basketball_dunk": "basketball_dunk_3d"}
NO_UE_MAP_MODES = {"basketball_dunk_irl", "movement_lab"}
NON_GAME_MODULES = {"market_browse", "movement_lab"}


def load_mode_manager():
    return json.loads(MODE_MANAGER_PATH.read_text())


def mode_registry():
    return load_mode_manager()["mode_manager"]["mode_registry"]


def registry_modes(include_alias=True, include_non_game=False):
    modes = []
    for mode, info in mode_registry().items():
        if not include_alias and mode in SWIFT_ALIAS_TARGETS:
            continue
        if not include_non_game and info.get("status") in {"non-game-module", "preview"}:
            continue
        modes.append(mode)
    return modes


def app_facing_modes(include_non_game=False):
    return [
        mode
        for mode in registry_modes(include_alias=False, include_non_game=include_non_game)
        if mode != "movement_lab"
    ]


def runtime_mode(mode):
    return RUNTIME_ALIASES.get(mode, mode)


def swift_raw_value_present(content, mode):
    return f'= "{mode}"' in content


def swift_alias_present(content, mode):
    target = SWIFT_ALIAS_TARGETS.get(mode)
    if not target:
        return False
    return f'case "{mode}":' in content and f".{camelish_swift_case(target)}" in content


def camelish_swift_case(mode):
    return {
        "basketball_dunk_3d": "basketballDunkContest3D",
        "basketball_dunk_irl": "basketballDunkContestIRL",
    }.get(mode, mode)


def mode_weight_lookup_ids(mode):
    ids = {mode, runtime_mode(mode)}
    if mode in SWIFT_ALIAS_TARGETS:
        ids.add(SWIFT_ALIAS_TARGETS[mode])
    return ids

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    mgr = load_mode_manager()
    registry = mgr["mode_manager"]["mode_registry"]
    meta = mgr["mode_manager"]
    production_count = sum(1 for info in registry.values() if info.get("status") == "production")

    if meta.get("total_modes") == len(registry):
        ok(f"total_modes metadata matches registry ({len(registry)})")
    else:
        fail(f"total_modes={meta.get('total_modes')}, expected {len(registry)}")

    if meta.get("production_modes") == production_count:
        ok(f"production_modes metadata matches registry ({production_count})")
    else:
        fail(f"production_modes={meta.get('production_modes')}, expected {production_count}")

    allowed_statuses = {"production", "staging", "preview", "non-game-module"}
    for mode, info in registry.items():
        status = info.get("status")
        venue_id = info.get("venue_id")
        if status in allowed_statuses:
            ok(f"{mode} → {status}, venue_id={venue_id}")
        else:
            fail(f"{mode} has unsupported status={status}")
        if status == "production" and mode not in SWIFT_ALIAS_TARGETS and not venue_id:
            fail(f"{mode} production entry missing venue_id")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 2: UE Mode Maps Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_ue_mode_maps():
    print("\n── Test 2: UE Mode Maps ──")
    ue_maps = json.loads(UE_MODE_MAPS_PATH.read_text())
    mode_map = ue_maps["mode_to_unreal_map"]

    for mode in registry_modes(include_alias=True, include_non_game=True):
        if mode in mode_map:
            if mode in NO_UE_MAP_MODES:
                if mode_map[mode] is None:
                    ok(f"{mode} → no UE map (expected)")
                else:
                    fail(f"{mode} should not resolve to UE map {mode_map[mode]}")
            else:
                ok(f"{mode} → {mode_map[mode]}")
        else:
            if mode in NO_UE_MAP_MODES:
                ok(f"{mode} → no UE map required")
            else:
                fail(f"{mode} missing from ue_mode_maps.json")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 3: ArenaSettings Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_arena_settings():
    print("\n── Test 3: ArenaSettings Config ──")
    arena = json.loads(ARENA_SETTINGS_PATH.read_text())
    modes = arena["modes"]

    for mode in app_facing_modes(include_non_game=False):
        if mode in NO_UE_MAP_MODES:
            ok(f"{mode} → ArenaSettings not required")
            continue
        descriptor_id = runtime_mode(mode)
        if descriptor_id in modes:
            cfg = modes[descriptor_id]
            has_level = "unrealOpenLevelPackage" in cfg
            has_display = "modeDisplayName" in cfg
            if has_level and has_display:
                ok(f"{mode} → {cfg['modeDisplayName']}")
            else:
                fail(f"{mode} missing unrealOpenLevelPackage or modeDisplayName")
        else:
            fail(f"{mode} missing from ArenaSettings.json as {descriptor_id}")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 4: VenueRegistry Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_venue_registry():
    print("\n── Test 4: VenueRegistry Coverage ──")
    vr = json.loads(VENUE_REGISTRY_PATH.read_text())
    mode_entries = vr["modes"]
    venue_keys = {v["venueKey"] for v in vr["venues"]}

    for mode in app_facing_modes(include_non_game=True):
        candidates = [mode, runtime_mode(mode)]
        entry = next((m for m in mode_entries if m["id"] in candidates or m.get("nexusRuntimeModeId") in candidates), None)
        if entry:
            if entry["venueKey"] in venue_keys:
                ok(f"{mode} → venue={entry['venueKey']}")
            else:
                fail(f"{mode} references unknown venue: {entry['venueKey']}")
        else:
            fail(f"{mode} missing from VenueRegistry")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 5: DefaultGame.ini FELPlayMap
# ═══════════════════════════════════════════════════════════════════════════════
def test_fel_play_map():
    print("\n── Test 5: FELPlayMap Deep Link Routing ──")
    content = FEL_PLAY_MAP_PATH.read_text()

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

    for mode in app_facing_modes(include_non_game=True):
        if mode in NO_UE_MAP_MODES:
            ok(f"{mode} → FELPlayMap not required")
            continue
        descriptor_id = runtime_mode(mode)
        if descriptor_id in play_map:
            path = play_map[descriptor_id]
            # Verify path uses /Venues/ convention
            if "/Venues/" in path:
                ok(f"{mode} → {path}")
            else:
                fail(f"{mode} deep link path doesn't use /Venues/ convention: {path}")
        else:
            fail(f"{mode} missing from FELPlayMap as {descriptor_id}")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 6: Swift GameMode Enum
# ═══════════════════════════════════════════════════════════════════════════════
def test_swift_enum():
    print("\n── Test 6: Swift GameMode Enum ──")
    content = SWIFT_GAME_MODE_PATH.read_text()

    for mode in app_facing_modes(include_non_game=True):
        if swift_raw_value_present(content, mode) or swift_alias_present(content, mode):
            ok(f'{mode} has Swift enum case')
        else:
            fail(f'{mode} missing from GameMode.swift enum')

# ═══════════════════════════════════════════════════════════════════════════════
# Test 7: Server.py Seeded Game Modes
# ═══════════════════════════════════════════════════════════════════════════════
def test_server_seeded_modes():
    print("\n── Test 7: Server Seeded Game Modes ──")
    content = SERVER_PATH.read_text()

    for mode in app_facing_modes(include_non_game=False):
        if mode == "basketball_dunk_irl":
            ok(f"{mode} is camera-native; backend seed not required")
            continue
        seeded_id = runtime_mode(mode)
        if f'"id":"{seeded_id}"' in content or f'"id": "{seeded_id}"' in content:
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
    content = SERVER_PATH.read_text()

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

    # Verify PRQ weights cover all production scoring modes and split dunk IDs.
    scoring_modes = [
        mode for mode in app_facing_modes(include_non_game=False)
        if mode_registry()[mode].get("prq_weight", 0.0) > 0.0
    ]
    weights_block = content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0]
    for mode in scoring_modes:
        if any(f'"{candidate}"' in weights_block for candidate in mode_weight_lookup_ids(mode)):
            ok(f"PRQ weight defined for {mode}")
        else:
            fail(f"PRQ weight missing for {mode}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print(f"  {len(app_facing_modes())} app-facing production modes · 8 test categories · Registry → Economy")
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
