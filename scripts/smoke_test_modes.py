#!/usr/bin/env python3
"""
FEL Smoke Test Suite -- production mode acceptance tests.
Tests each NEXUS runtime mode's registration, configuration, and deep link routing.
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

# ═══════════════════════════════════════════════════════════════════════════════
# Production modes expected to pass all gates.
# Keep the runtime list aligned with app/gameplay/include/.../arena_mode_registry.h.
# ═══════════════════════════════════════════════════════════════════════════════
RUNTIME_PRODUCTION_MODES = [
    "basketball_h2h", "basketball_dunk", "basketball_3v3",
    "court_carnival",
    "karate_h2h", "karate_endless",
    "baseball", "football", "soccer", "golf",
    "tennis", "volleyball",
    "gymnastics", "surfing", "skateboarding", "snowboarding",
    "brain_brawl", "who_scene_it",
]

APP_PRODUCTION_MODES = ["basketball_dunk_3d", "basketball_dunk_irl"]
PRODUCTION_MODES = RUNTIME_PRODUCTION_MODES + APP_PRODUCTION_MODES
NON_GAME_MODULES = ["market_browse"]
PREVIEW_MODES = ["movement_lab"]

UE_NULL_MAP_MODES = {"basketball_dunk_irl"}
ARENA_SETTINGS_ALIASES = {"basketball_dunk_3d": "basketball_dunk"}
VENUE_REGISTRY_ALIASES = {"basketball_dunk": "basketball_dunk_3d"}
SWIFT_RUNTIME_ALIASES = {"basketball_dunk": "basketballDunkContest3D"}

UE_BACKED_MODES = [
    mode for mode in PRODUCTION_MODES + NON_GAME_MODULES
    if mode not in UE_NULL_MAP_MODES
]
SERVER_SEEDED_MODES = RUNTIME_PRODUCTION_MODES + NON_GAME_MODULES
ECONOMY_WEIGHT_MODES = RUNTIME_PRODUCTION_MODES

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    mgr = json.loads((REPO_ROOT / "backend" / "FEL_ModeManager.production.json").read_text())
    registry = mgr["mode_manager"]["mode_registry"]

    for mode in PRODUCTION_MODES:
        if mode in registry:
            info = registry[mode]
            if info["status"] == "production":
                ok(f"{mode} → production, venue_id={info['venue_id']}")
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
    ue_maps = json.loads((REPO_ROOT / "backend" / "ue_mode_maps.json").read_text())
    mode_map = ue_maps["mode_to_unreal_map"]

    for mode in UE_BACKED_MODES:
        if mode in mode_map and mode_map[mode] is not None:
            ok(f"{mode} → {mode_map[mode]}")
        else:
            fail(f"{mode} missing non-null map in ue_mode_maps.json")

    for mode in UE_NULL_MAP_MODES:
        if mode_map.get(mode) is None:
            ok(f"{mode} → IRL/null UE map (expected)")
        else:
            fail(f"{mode} should have null UE map")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 3: ArenaSettings Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_arena_settings():
    print("\n── Test 3: ArenaSettings Config ──")
    arena = json.loads((REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json").read_text())
    modes = arena["modes"]

    for mode in UE_BACKED_MODES:
        settings_mode = ARENA_SETTINGS_ALIASES.get(mode, mode)
        if settings_mode in modes:
            cfg = modes[settings_mode]
            has_level = "unrealOpenLevelPackage" in cfg
            has_display = "modeDisplayName" in cfg
            if has_level and has_display:
                alias_note = f" via {settings_mode}" if settings_mode != mode else ""
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

    for mode in PRODUCTION_MODES + NON_GAME_MODULES:
        venue_mode = VENUE_REGISTRY_ALIASES.get(mode, mode)
        if venue_mode in mode_ids:
            entry = next(m for m in vr["modes"] if m["id"] == venue_mode)
            if entry["venueKey"] in venue_keys:
                alias_note = f" via {venue_mode}" if venue_mode != mode else ""
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

    for mode in UE_BACKED_MODES:
        if mode in play_map:
            path = play_map[mode]
            # Verify path uses /Venues/ convention
            if "/Venues/" in path:
                ok(f"{mode} → {path}")
            else:
                fail(f"{mode} deep link path doesn't use /Venues/ convention: {path}")
        else:
            fail(f"{mode} missing from FELPlayMap")

    for mode in UE_NULL_MAP_MODES:
        if mode not in play_map:
            ok(f"{mode} → no FELPlayMap entry for IRL mode (expected)")
        else:
            fail(f"{mode} should not route to a UE FELPlayMap entry")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 6: Swift GameMode Enum
# ═══════════════════════════════════════════════════════════════════════════════
def test_swift_enum():
    print("\n── Test 6: Swift GameMode Enum ──")
    swift_path = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
    content = swift_path.read_text()

    for mode in PRODUCTION_MODES + NON_GAME_MODULES:
        if f'= "{mode}"' in content:
            ok(f'{mode} has Swift enum case')
        elif mode in SWIFT_RUNTIME_ALIASES and SWIFT_RUNTIME_ALIASES[mode] in content and f'case "{mode}"' in content:
            ok(f'{mode} maps to Swift {SWIFT_RUNTIME_ALIASES[mode]} runtime alias')
        else:
            fail(f'{mode} missing from GameMode.swift enum')

# ═══════════════════════════════════════════════════════════════════════════════
# Test 7: Server.py Seeded Game Modes
# ═══════════════════════════════════════════════════════════════════════════════
def test_server_seeded_modes():
    print("\n── Test 7: Server Seeded Game Modes ──")
    server_path = REPO_ROOT / "backend" / "server.py"
    content = server_path.read_text()

    for mode in SERVER_SEEDED_MODES:
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
    for mode in ECONOMY_WEIGHT_MODES:
        if f'"{mode}"' in content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0]:
            ok(f"PRQ weight defined for {mode}")
        else:
            fail(f"PRQ weight missing for {mode}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print("  18 runtime modes + split dunk app IDs · 8 test categories · Registry → Economy")
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
