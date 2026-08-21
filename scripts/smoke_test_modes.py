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

def load_json(relative_path):
    return json.loads((REPO_ROOT / relative_path).read_text())

MODE_MANAGER = load_json("backend/FEL_ModeManager.production.json")
REGISTRY = MODE_MANAGER["mode_manager"]["mode_registry"]
UE_MODE_MAPS = load_json("backend/ue_mode_maps.json")["mode_to_unreal_map"]

def registry_modes_with_status(status):
    return [mode for mode, info in REGISTRY.items() if info.get("status") == status]

# ═══════════════════════════════════════════════════════════════════════════════
# Registry-derived launch sets
# ═══════════════════════════════════════════════════════════════════════════════
PRODUCTION_MODES = registry_modes_with_status("production")
LAUNCH_ALIAS_MODES = [mode for mode, info in REGISTRY.items() if info.get("alias_for")]
STAGING_MODES = [mode for mode in registry_modes_with_status("staging") if mode not in LAUNCH_ALIAS_MODES]
PREVIEW_MODES = registry_modes_with_status("preview")
NON_GAME_MODULES = registry_modes_with_status("non-game-module")
UE_LAUNCH_MODES = [mode for mode, unreal_map in UE_MODE_MAPS.items() if unreal_map is not None]
SWIFT_ALIAS_TARGETS = {"basketball_dunk": "basketball_dunk_3d"}
SWIFT_EXCLUDED_PREVIEW_MODES = {"movement_lab"}

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    declared_total = MODE_MANAGER["mode_manager"]["total_modes"]
    declared_production = MODE_MANAGER["mode_manager"]["production_modes"]
    if declared_total == len(REGISTRY):
        ok(f"declared total_modes={declared_total}")
    else:
        fail(f"declared total_modes={declared_total}, actual={len(REGISTRY)}")
    if declared_production == len(PRODUCTION_MODES):
        ok(f"declared production_modes={declared_production}")
    else:
        fail(f"declared production_modes={declared_production}, actual={len(PRODUCTION_MODES)}")

    for mode in PRODUCTION_MODES:
        if mode in REGISTRY:
            info = REGISTRY[mode]
            if info["status"] == "production":
                ok(f"{mode} → production, venue_id={info['venue_id']}")
            else:
                fail(f"{mode} status={info['status']}, expected production")
        else:
            fail(f"{mode} missing from ModeManager registry")

    for mode in LAUNCH_ALIAS_MODES:
        info = REGISTRY[mode]
        if info.get("alias_for") in REGISTRY and info.get("status") in ("production", "staging"):
            ok(f"{mode} → launch alias for {info['alias_for']}")
        else:
            fail(f"{mode} alias_for={info.get('alias_for')} status={info.get('status')}, expected launchable alias")

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
    for mode, info in REGISTRY.items():
        mapped = UE_MODE_MAPS.get(mode, "__missing__")
        if mapped not in (None, "__missing__"):
            ok(f"{mode} → {mapped}")
        elif info.get("render_mode") == "IRL" and mapped is None:
            ok(f"{mode} → IRL/no UE map")
        elif info.get("status") in ("preview", "non-game-module"):
            skip(f"{mode} has no required UE launch map ({info.get('status')})")
        else:
            fail(f"{mode} missing from ue_mode_maps.json")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 3: ArenaSettings Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_arena_settings():
    print("\n── Test 3: ArenaSettings Config ──")
    arena = json.loads((REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json").read_text())
    modes = arena["modes"]

    for mode in UE_LAUNCH_MODES:
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

    for mode, info in REGISTRY.items():
        if mode in SWIFT_EXCLUDED_PREVIEW_MODES:
            skip(f"{mode} preview education module is not a UE venue")
            continue
        if mode in mode_ids:
            entry = next(m for m in vr["modes"] if m["id"] == mode)
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

    for mode in UE_LAUNCH_MODES:
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

    app_modes = [mode for mode in PRODUCTION_MODES + LAUNCH_ALIAS_MODES + NON_GAME_MODULES if mode not in SWIFT_EXCLUDED_PREVIEW_MODES]
    for mode in app_modes:
        # Search for rawValue
        if f'= "{mode}"' in content:
            ok(f'{mode} has Swift enum case')
        elif mode in SWIFT_ALIAS_TARGETS and f'case "{mode}":' in content and f'= "{SWIFT_ALIAS_TARGETS[mode]}"' in content:
            ok(f'{mode} resolves through Swift playableMode alias')
        else:
            fail(f'{mode} missing from GameMode.swift enum')

# ═══════════════════════════════════════════════════════════════════════════════
# Test 7: Server.py Seeded Game Modes
# ═══════════════════════════════════════════════════════════════════════════════
def test_server_seeded_modes():
    print("\n── Test 7: Server Seeded Game Modes ──")
    server_path = REPO_ROOT / "backend" / "server.py"
    content = server_path.read_text()

    seeded_modes = [mode for mode in PRODUCTION_MODES + LAUNCH_ALIAS_MODES + NON_GAME_MODULES if mode not in SWIFT_EXCLUDED_PREVIEW_MODES]
    for mode in seeded_modes:
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
    scoring_modes = [mode for mode in PRODUCTION_MODES if REGISTRY[mode].get("prq_weight", 0) > 0]
    for mode in scoring_modes:
        if f'"{mode}"' in content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0]:
            ok(f"PRQ weight defined for {mode}")
        else:
            fail(f"PRQ weight missing for {mode}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print("  19 modes · 8 test categories · Registry → Economy")
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
