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

def load_registry():
    mgr = json.loads((REPO_ROOT / "backend" / "FEL_ModeManager.production.json").read_text())
    return mgr["mode_manager"], mgr["mode_manager"]["mode_registry"]


def load_ue_mode_maps():
    return json.loads((REPO_ROOT / "backend" / "ue_mode_maps.json").read_text())["mode_to_unreal_map"]


MODE_MANAGER, REGISTRY = load_registry()
UE_MODE_MAPS = load_ue_mode_maps()

PRODUCTION_MODES = [mode for mode, info in REGISTRY.items() if info.get("status") == "production"]
STAGING_MODES = [mode for mode, info in REGISTRY.items() if info.get("status") == "staging"]
PREVIEW_MODES = [mode for mode, info in REGISTRY.items() if info.get("status") == "preview"]
NON_GAME_MODULES = [mode for mode, info in REGISTRY.items() if info.get("status") == "non-game-module"]
SCORING_MODES = [
    mode for mode, info in REGISTRY.items()
    if info.get("status") == "production" and float(info.get("prq_weight", 0.0)) > 0.0
]
SWIFT_RUNTIME_ALIASES = {
    "basketball_dunk": "basketball_dunk_3d",
}


def is_ue_mapped(mode):
    return mode in UE_MODE_MAPS and UE_MODE_MAPS[mode] is not None


def should_have_unreal_descriptor(mode):
    info = REGISTRY[mode]
    return is_ue_mapped(mode) and info.get("status") != "non-game-module"


def swift_has_mode(content, mode):
    if f'= "{mode}"' in content:
        return True
    alias = SWIFT_RUNTIME_ALIASES.get(mode)
    return bool(alias and f'= "{alias}"' in content and f'case "{mode}":' in content)

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    registry = REGISTRY

    for mode in PRODUCTION_MODES:
        info = registry[mode]
        ok(f"{mode} → production, venue_id={info.get('venue_id')}")

    for mode in STAGING_MODES:
        ok(f"{mode} → staging (expected)")

    for mode in PREVIEW_MODES:
        ok(f"{mode} → preview (expected)")

    for mode in NON_GAME_MODULES:
        ok(f"{mode} → non-game-module (expected)")

    declared_total = MODE_MANAGER.get("total_modes")
    declared_prod = MODE_MANAGER.get("production_modes")
    if declared_total == len(registry):
        ok(f"declared total_modes matches actual ({declared_total})")
    else:
        fail(f"total_modes declared={declared_total}, actual={len(registry)}")
    if declared_prod == len(PRODUCTION_MODES):
        ok(f"declared production_modes matches actual ({declared_prod})")
    else:
        fail(f"production_modes declared={declared_prod}, actual={len(PRODUCTION_MODES)}")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 2: UE Mode Maps Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_ue_mode_maps():
    print("\n── Test 2: UE Mode Maps ──")
    for mode, info in REGISTRY.items():
        if info.get("status") == "non-game-module":
            skip(f"{mode} → non-game module; UE map optional")
            continue
        if info.get("render_mode") == "IRL" or info.get("venue_id") is None:
            if mode in UE_MODE_MAPS and UE_MODE_MAPS[mode] is None:
                ok(f"{mode} → IRL/null UE map (expected)")
            else:
                fail(f"{mode} must be explicitly null in ue_mode_maps.json")
            continue
        if mode == "movement_lab":
            skip(f"{mode} → preview education module; no UE launch map required")
            continue
        if mode in UE_MODE_MAPS:
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

    for mode in REGISTRY:
        if not should_have_unreal_descriptor(mode):
            skip(f"{mode} → no ArenaSettings required")
            continue
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
        if mode == "movement_lab":
            skip(f"{mode} → preview education module; VenueRegistry row optional")
            continue
        if info.get("venue_id") is None and info.get("render_mode") != "IRL":
            skip(f"{mode} → no physical venue")
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

    for mode in REGISTRY:
        if not should_have_unreal_descriptor(mode):
            skip(f"{mode} → no FELPlayMap route required")
            continue
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

    for mode in REGISTRY:
        if mode == "movement_lab":
            skip(f"{mode} → preview education module; no Swift game enum required")
            continue
        if swift_has_mode(content, mode):
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

    for mode in REGISTRY:
        if mode == "movement_lab":
            skip(f"{mode} → preview education module; not in legacy game seed list")
            continue
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

    # Verify PRQ weights cover registry production modes that award PRQ.
    for mode in SCORING_MODES:
        if f'"{mode}"' in content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0]:
            ok(f"PRQ weight defined for {mode}")
        else:
            fail(f"PRQ weight missing for {mode}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print(f"  {len(REGISTRY)} registry entries · {len(PRODUCTION_MODES)} production · Registry → Economy")
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
