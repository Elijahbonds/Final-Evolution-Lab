#!/usr/bin/env python3
"""
FEL Smoke Test Suite — Production Mode Acceptance Tests
Tests each registered mode's configuration, routing, and app/backend exposure.
Run against a live or mock FEL backend.
"""
import json
import sys
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

MODE_MANAGER = json.loads((REPO_ROOT / "backend" / "FEL_ModeManager.production.json").read_text())
MODE_REGISTRY = MODE_MANAGER["mode_manager"]["mode_registry"]
UE_MODE_MAP = json.loads((REPO_ROOT / "backend" / "ue_mode_maps.json").read_text())["mode_to_unreal_map"]


def is_runtime_alias(mode_id):
    info = MODE_REGISTRY.get(mode_id, {})
    note = str(info.get("note", "")).lower()
    return (
        "legacy alias" in note
        or any(other.get("nexus_runtime_mode_id") == mode_id for other in MODE_REGISTRY.values())
    )


def is_education_module(mode_id, info):
    text = f"{info.get('description', '')} {info.get('note', '')}".lower()
    return mode_id == "movement_lab" or "not a game module" in text


def is_non_game_module(mode_id):
    info = MODE_REGISTRY[mode_id]
    return info.get("status") == "non-game-module" or is_education_module(mode_id, info)


def requires_unreal_package(mode_id):
    info = MODE_REGISTRY[mode_id]
    if is_non_game_module(mode_id):
        return False
    if info.get("render_mode") == "IRL":
        return False
    if mode_id in UE_MODE_MAP and UE_MODE_MAP[mode_id] is None:
        return False
    return True


PRODUCTION_MODES = [
    mode_id for mode_id, info in MODE_REGISTRY.items()
    if info.get("status") == "production" and not is_non_game_module(mode_id)
]
STAGING_MODES = [
    mode_id for mode_id, info in MODE_REGISTRY.items()
    if info.get("status") == "staging" and not is_non_game_module(mode_id)
]
PREVIEW_MODES = [
    mode_id for mode_id, info in MODE_REGISTRY.items()
    if info.get("status") == "preview" and not is_non_game_module(mode_id)
]
NON_GAME_MODULES = [
    mode_id for mode_id, info in MODE_REGISTRY.items()
    if info.get("status") == "non-game-module"
]
EDUCATION_MODULES = [
    mode_id for mode_id, info in MODE_REGISTRY.items()
    if info.get("status") == "preview" and is_education_module(mode_id, info)
]
VALIDATED_GAME_MODES = PRODUCTION_MODES + STAGING_MODES + PREVIEW_MODES
USER_FACING_APP_MODES = [
    mode_id for mode_id in VALIDATED_GAME_MODES + NON_GAME_MODULES
    if not is_runtime_alias(mode_id)
]

# ═══════════════════════════════════════════════════════════════════════════════
# Test 1: Mode Manager Registry Completeness
# ═══════════════════════════════════════════════════════════════════════════════
def test_mode_manager_registry():
    print("\n── Test 1: ModeManager Registry ──")
    mm = MODE_MANAGER["mode_manager"]
    registry = MODE_REGISTRY

    actual_total = len(registry)
    declared_total = mm.get("total_modes")
    if declared_total == actual_total:
        ok(f"declared total_modes={declared_total}")
    else:
        fail(f"total_modes mismatch: declared={declared_total}, actual={actual_total}")

    actual_prod = sum(1 for info in registry.values() if info.get("status") == "production")
    declared_prod = mm.get("production_modes")
    if declared_prod == actual_prod:
        ok(f"declared production_modes={declared_prod}")
    else:
        fail(f"production_modes mismatch: declared={declared_prod}, actual={actual_prod}")

    for mode in PRODUCTION_MODES:
        if mode in registry:
            info = registry[mode]
            if info["status"] == "production":
                ok(f"{mode} → production, venue_id={info.get('venue_id')}")
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

    for mode in EDUCATION_MODULES:
        if mode in registry and registry[mode]["status"] == "preview":
            ok(f"{mode} → preview education module (expected)")
        else:
            fail(f"{mode} missing or wrong education-module status")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 2: UE Mode Maps Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_ue_mode_maps():
    print("\n── Test 2: UE Mode Maps ──")
    mode_map = UE_MODE_MAP

    for mode in VALIDATED_GAME_MODES + NON_GAME_MODULES:
        if mode in mode_map:
            if mode_map[mode] is None:
                if requires_unreal_package(mode):
                    fail(f"{mode} has null UE map but requires a package route")
                else:
                    ok(f"{mode} → null UE map (expected)")
            else:
                ok(f"{mode} → {mode_map[mode]}")
        else:
            if is_non_game_module(mode):
                ok(f"{mode} → no UE map required")
            else:
                fail(f"{mode} missing from ue_mode_maps.json")

# ═══════════════════════════════════════════════════════════════════════════════
# Test 3: ArenaSettings Coverage
# ═══════════════════════════════════════════════════════════════════════════════
def test_arena_settings():
    print("\n── Test 3: ArenaSettings Config ──")
    arena = json.loads((REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json").read_text())
    modes = arena["modes"]

    for mode in VALIDATED_GAME_MODES:
        if not requires_unreal_package(mode):
            ok(f"{mode} → no ArenaSettings required")
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

    for mode in VALIDATED_GAME_MODES:
        if is_runtime_alias(mode):
            ok(f"{mode} → runtime alias covered by split/user-facing mode")
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

    for mode in VALIDATED_GAME_MODES:
        if not requires_unreal_package(mode):
            ok(f"{mode} → no FELPlayMap required")
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

    for mode in USER_FACING_APP_MODES:
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

    for mode in USER_FACING_APP_MODES:
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

    # Verify PRQ weights cover all production gameplay/runtime modes.
    scoring_modes = PRODUCTION_MODES
    for mode in scoring_modes:
        if f'"{mode}"' in content.split("PRQ_MODE_WEIGHTS")[1].split("}")[0]:
            ok(f"PRQ weight defined for {mode}")
        else:
            fail(f"PRQ weight missing for {mode}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Production Smoke Test Suite")
    print(
        f"  {len(MODE_REGISTRY)} registry entries · "
        f"{len(PRODUCTION_MODES)} production gameplay modes · "
        "8 test categories · Registry → Economy"
    )
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
