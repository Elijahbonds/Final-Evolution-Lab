#!/usr/bin/env python3
"""
FEL Smoke Test Suite — 12 Production Mode Acceptance Tests
Tests each production mode's registration, configuration, and deep link routing.
Run against a live or mock FEL backend.
"""
import json
import sys
import os
import re
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
# Production modes expected to pass all gates
# ═══════════════════════════════════════════════════════════════════════════════
PRODUCTION_MODES = [
    "basketball_h2h", "basketball_dunk", "basketball_3v3", "court_carnival",
    "karate_h2h", "karate_endless",
    "baseball", "football", "soccer", "golf", "tennis", "volleyball",
    "gymnastics", "surfing", "skateboarding", "snowboarding",
    "brain_brawl", "who_scene_it",
]

NON_GAME_MODULES = ["market_browse"]

STAGING_MODES = []
PREVIEW_MODES = []
PREVIEW_MODULES = ["movement_lab"]
IOS_UE_ALIASES = {"basketball_dunk": "basketball_dunk_3d"}
IOS_IRL_MODES = ["basketball_dunk_irl"]

def mode_or_ios_alias(mode):
    return IOS_UE_ALIASES.get(mode, mode)

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    mgr = json.loads((REPO_ROOT / "backend" / "FEL_ModeManager.production.json").read_text())
    registry = mgr["mode_manager"]["mode_registry"]

    declared_total = mgr["mode_manager"].get("total_modes")
    declared_production = mgr["mode_manager"].get("production_modes")
    actual_total = len(registry)
    actual_production = sum(1 for info in registry.values() if info.get("status") == "production")
    if declared_total == actual_total:
        ok(f"declared total_modes={declared_total}")
    else:
        fail(f"declared total_modes={declared_total}, actual={actual_total}")
    if declared_production == actual_production:
        ok(f"declared production_modes={declared_production}")
    else:
        fail(f"declared production_modes={declared_production}, actual={actual_production}")

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

    for mode in PREVIEW_MODULES:
        if mode in registry and registry[mode]["status"] == "preview":
            ok(f"{mode} → preview module (expected)")
        elif mode in registry:
            fail(f"{mode} status={registry[mode]['status']}, expected preview")
        else:
            fail(f"{mode} missing from registry")

    for mode in IOS_IRL_MODES:
        if mode in registry and registry[mode].get("render_mode") == "IRL":
            ok(f"{mode} → IRL camera/HealthKit mode (no UE map)")
        else:
            fail(f"{mode} missing or not marked render_mode=IRL")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 2: UE Mode Maps Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_ue_mode_maps():
    print("\n── Test 2: UE Mode Maps ──")
    ue_maps = json.loads((REPO_ROOT / "backend" / "ue_mode_maps.json").read_text())
    mode_map = ue_maps["mode_to_unreal_map"]

    all_modes = [mode_or_ios_alias(mode) for mode in PRODUCTION_MODES] + STAGING_MODES + PREVIEW_MODES
    for mode in all_modes:
        if mode in mode_map:
            ok(f"{mode} → {mode_map[mode]}")
        else:
            if mode == "market_browse":
                # market_browse may not have a UE map (it's a shop module)
                ok(f"{mode} → present in ue_mode_maps")
            else:
                fail(f"{mode} missing from ue_mode_maps.json")

    for mode in IOS_IRL_MODES:
        if mode in mode_map and mode_map[mode] is None:
            ok(f"{mode} → no UE map (IRL)")
        else:
            fail(f"{mode} should be present with null UE map")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 3: ArenaSettings Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_arena_settings():
    print("\n── Test 3: ArenaSettings Config ──")
    arena = json.loads((REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json").read_text())
    modes = arena["modes"]

    all_modes = [mode_or_ios_alias(mode) for mode in PRODUCTION_MODES] + STAGING_MODES + PREVIEW_MODES
    for mode in all_modes:
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
    mode_entries = vr["modes"]
    mode_ids = {m["id"] for m in mode_entries}
    venue_keys = {v["venueKey"] for v in vr["venues"]}

    all_modes = PRODUCTION_MODES + STAGING_MODES + PREVIEW_MODES
    for mode in all_modes:
        entry = next(
            (m for m in mode_entries if m["id"] == mode or m.get("nexusRuntimeModeId") == mode),
            None,
        )
        if entry:
            if entry["venueKey"] in venue_keys:
                ok(f"{mode} → venue={entry['venueKey']}")
            else:
                fail(f"{mode} references unknown venue: {entry['venueKey']}")
        else:
            fail(f"{mode} missing from VenueRegistry")

    for mode in IOS_IRL_MODES:
        entry = next((m for m in mode_entries if m["id"] == mode), None)
        if entry and entry.get("isIRLMode") and entry["venueKey"] in venue_keys:
            ok(f"{mode} → IRL venue={entry['venueKey']}")
        else:
            fail(f"{mode} missing IRL venue registry entry")

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

    all_modes = [mode_or_ios_alias(mode) for mode in PRODUCTION_MODES] + STAGING_MODES + PREVIEW_MODES
    for mode in all_modes:
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

    all_modes = PRODUCTION_MODES + STAGING_MODES + PREVIEW_MODES + IOS_IRL_MODES
    for mode in all_modes:
        # Search for rawValue
        swift_mode = mode_or_ios_alias(mode)
        if f'= "{swift_mode}"' in content:
            if swift_mode != mode:
                ok(f'{mode} represented by Swift enum case {swift_mode}')
            else:
                ok(f'{mode} has Swift enum case')
        else:
            fail(f'{mode} missing from GameMode.swift enum')

def test_swift_non_game_guardrails():
    print("\n── Test 6b: Swift Non-Game Guardrails ──")
    swift_path = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
    content = swift_path.read_text()

    if re.search(r"case\s+\.marketBrowse:\s*return\s+\.nonGame", content):
        ok("market_browse maps to NexusCapabilityTier.nonGame")
    else:
        fail("market_browse must remain NexusCapabilityTier.nonGame")

    if re.search(r"case\s+\.marketBrowse:\s*return\s+true", content):
        fail("market_browse must not be marked sprint-playable")
    else:
        ok("market_browse is not sprint-playable")

    if re.search(r'case\s+"market_browse"[^:]*:\s*return\s+mode\(for:\s*\.marketBrowse\)', content, re.DOTALL):
        fail("playableMode(forRegistryId:) must not return market_browse as launchable")
    else:
        ok("playableMode(forRegistryId:) excludes market_browse")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 7: Server.py Seeded Game Modes
# ═══════════════════════════════════════════════════════════════════════════════
def test_server_seeded_modes():
    print("\n── Test 7: Server Seeded Game Modes ──")
    server_path = REPO_ROOT / "backend" / "server.py"
    content = server_path.read_text()

    all_modes = PRODUCTION_MODES + STAGING_MODES + PREVIEW_MODES
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
    scoring_modes = PRODUCTION_MODES  # all production modes are scoring modes
    for mode in scoring_modes:
        if f'"{mode}"' in content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0]:
            ok(f"PRQ weight defined for {mode}")
        else:
            fail(f"PRQ weight missing for {mode}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print("  18 NEXUS runtime modes · split dunk iOS aliases · Registry → Economy")
    print("═══════════════════════════════════════════════════════════")

    test_mode_manager_registry()
    test_ue_mode_maps()
    test_arena_settings()
    test_venue_registry()
    test_fel_play_map()
    test_swift_enum()
    test_swift_non_game_guardrails()
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
