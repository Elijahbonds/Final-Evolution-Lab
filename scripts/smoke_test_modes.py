#!/usr/bin/env python3
"""
FEL Smoke Test Suite

Registry-driven acceptance checks for mode registration, UE/NEXUS launch
metadata, Swift surfacing, and backend economy coverage.
"""
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
PASS = 0
FAIL = 0
SKIP = 0


class DuplicateKeyError(ValueError):
    pass


def load_json(path: Path):
    def reject_duplicates(pairs):
        obj = {}
        for key, value in pairs:
            if key in obj:
                raise DuplicateKeyError(f"Duplicate JSON key '{key}' in {path.relative_to(REPO_ROOT)}")
            obj[key] = value
        return obj

    return json.loads(path.read_text(), object_pairs_hook=reject_duplicates)


MODE_MANAGER = load_json(REPO_ROOT / "backend" / "FEL_ModeManager.production.json")
REGISTRY = MODE_MANAGER["mode_manager"]["mode_registry"]
UE_MODE_MAPS = load_json(REPO_ROOT / "backend" / "ue_mode_maps.json")["mode_to_unreal_map"]


def ok(msg):
    global PASS
    PASS += 1
    print(f"  OK {msg}")


def fail(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")


def skip(msg):
    global SKIP
    SKIP += 1
    print(f"  SKIP {msg}")


def modes_with_status(status):
    return [mode_id for mode_id, info in REGISTRY.items() if info.get("status") == status]


def is_legacy_alias(mode_id):
    note = REGISTRY.get(mode_id, {}).get("note", "")
    return "Legacy alias" in note


def is_preview_education_module(mode_id):
    info = REGISTRY.get(mode_id, {})
    return info.get("education_source") is not None


def is_ue_backed(mode_id):
    info = REGISTRY.get(mode_id, {})
    if info.get("render_mode") == "IRL":
        return False
    return mode_id in UE_MODE_MAPS and UE_MODE_MAPS.get(mode_id) is not None


def registry_modes_for_ios():
    return [
        mode_id for mode_id in REGISTRY
        if not is_legacy_alias(mode_id) and not is_preview_education_module(mode_id)
    ]


def registry_modes_for_venue_registry():
    return [
        mode_id for mode_id in REGISTRY
        if not is_legacy_alias(mode_id) and not is_preview_education_module(mode_id)
    ]


def registry_modes_for_seeded_backend():
    return [mode_id for mode_id in REGISTRY if not is_preview_education_module(mode_id)]


def parse_fel_play_map():
    content = (REPO_ROOT / "infra" / "ue5_config" / "DefaultGame.ini").read_text()
    play_map = {}
    in_section = False
    for line in content.splitlines():
        stripped = line.strip()
        if stripped == "[FELPlayMap]":
            in_section = True
            continue
        if in_section and stripped.startswith("["):
            break
        if in_section and "=" in stripped and not stripped.startswith(";"):
            key, value = stripped.split("=", 1)
            play_map[key.strip()] = value.strip()
    return play_map


def extract_python_dict_block(content, name):
    match = re.search(rf"{name}\s*=\s*\{{(?P<body>.*?)\n\}}", content, re.S)
    return match.group("body") if match else ""


def test_mode_manager_registry():
    print("\n-- Test 1: ModeManager Registry --")
    mode_manager = MODE_MANAGER["mode_manager"]
    actual_total = len(REGISTRY)
    declared_total = mode_manager.get("total_modes")
    if actual_total == declared_total:
        ok(f"declared total_modes={declared_total}")
    else:
        fail(f"total_modes declared={declared_total}, actual={actual_total}")

    production = modes_with_status("production")
    declared_production = mode_manager.get("production_modes")
    if len(production) == declared_production:
        ok(f"declared production_modes={declared_production}")
    else:
        fail(f"production_modes declared={declared_production}, actual={len(production)}")

    for mode_id, info in REGISTRY.items():
        status = info.get("status")
        if status in {"production", "staging", "preview", "non-game-module"}:
            ok(f"{mode_id} -> {status}")
        else:
            fail(f"{mode_id} has unsupported status={status!r}")


def test_ue_mode_maps():
    print("\n-- Test 2: UE Mode Maps --")
    for mode_id in REGISTRY:
        if is_preview_education_module(mode_id):
            skip(f"{mode_id} is preview education overlay, not UE launch routed")
            continue
        if mode_id not in UE_MODE_MAPS:
            fail(f"{mode_id} missing from ue_mode_maps.json")
            continue
        if UE_MODE_MAPS[mode_id] is None:
            if REGISTRY[mode_id].get("render_mode") == "IRL":
                ok(f"{mode_id} intentionally has null UE map")
            else:
                fail(f"{mode_id} has null UE map without IRL render_mode")
        else:
            ok(f"{mode_id} -> {UE_MODE_MAPS[mode_id]}")


def test_arena_settings():
    print("\n-- Test 3: ArenaSettings Config --")
    arena = load_json(
        REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json"
    )
    modes = arena["modes"]
    for mode_id in REGISTRY:
        if not is_ue_backed(mode_id):
            skip(f"{mode_id} does not require ArenaSettings")
            continue
        if mode_id not in modes:
            fail(f"{mode_id} missing from ArenaSettings.json")
            continue
        cfg = modes[mode_id]
        if "unrealOpenLevelPackage" in cfg and "modeDisplayName" in cfg:
            ok(f"{mode_id} -> {cfg['modeDisplayName']}")
        else:
            fail(f"{mode_id} missing unrealOpenLevelPackage or modeDisplayName")


def test_venue_registry():
    print("\n-- Test 4: VenueRegistry Coverage --")
    vr = load_json(REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Config" / "FEL_VenueRegistry.production.json")
    mode_ids = {m["id"] for m in vr["modes"]}
    venue_keys = {v["venueKey"] for v in vr["venues"]}
    for mode_id in registry_modes_for_venue_registry():
        if mode_id not in mode_ids:
            fail(f"{mode_id} missing from VenueRegistry")
            continue
        entry = next(m for m in vr["modes"] if m["id"] == mode_id)
        if entry["venueKey"] in venue_keys:
            ok(f"{mode_id} -> venue={entry['venueKey']}")
        else:
            fail(f"{mode_id} references unknown venue: {entry['venueKey']}")


def test_fel_play_map():
    print("\n-- Test 5: FELPlayMap Deep Link Routing --")
    play_map = parse_fel_play_map()
    for mode_id in REGISTRY:
        if not is_ue_backed(mode_id):
            skip(f"{mode_id} does not require FELPlayMap")
            continue
        if mode_id not in play_map:
            fail(f"{mode_id} missing from FELPlayMap")
            continue
        path = play_map[mode_id]
        if "/Venues/" in path:
            ok(f"{mode_id} -> {path}")
        else:
            fail(f"{mode_id} deep link path does not use /Venues/: {path}")


def test_swift_enum():
    print("\n-- Test 6: Swift GameMode Enum --")
    content = (REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift").read_text()
    for mode_id in registry_modes_for_ios():
        if f'= "{mode_id}"' in content:
            ok(f"{mode_id} has Swift enum case")
        else:
            fail(f"{mode_id} missing from GameMode.swift enum")


def test_server_seeded_modes():
    print("\n-- Test 7: Backend Seeded Game Modes --")
    server_content = (REPO_ROOT / "backend" / "server.py").read_text()
    router_content = (REPO_ROOT / "backend" / "routers" / "games.py").read_text()
    for mode_id in registry_modes_for_seeded_backend():
        needle_compact = f'"id":"{mode_id}"'
        needle_spaced = f'"id": "{mode_id}"'
        if needle_compact in server_content or needle_spaced in server_content:
            ok(f"{mode_id} in server.py seeded modes")
        else:
            fail(f"{mode_id} missing from server.py seeded modes")
        if needle_compact in router_content or needle_spaced in router_content:
            ok(f"{mode_id} in routers/games.py seeded modes")
        else:
            fail(f"{mode_id} missing from routers/games.py seeded modes")


def test_economy_integration():
    print("\n-- Test 8: Economy Integration --")
    server_content = (REPO_ROOT / "backend" / "server.py").read_text()
    router_content = (REPO_ROOT / "backend" / "routers" / "games.py").read_text()
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
        if pattern in server_content and pattern in router_content:
            ok(f"{label} present")
        else:
            fail(f"{label} missing from server.py or routers/games.py")

    server_weights = extract_python_dict_block(server_content, "PRQ_MODE_WEIGHTS")
    router_weights = extract_python_dict_block(router_content, "PRQ_MODE_WEIGHTS")
    weighted_modes = [
        mode_id for mode_id, info in REGISTRY.items()
        if info.get("status") == "production" and float(info.get("prq_weight", 0.0)) > 0.0
    ]
    for mode_id in weighted_modes:
        if f'"{mode_id}"' in server_weights:
            ok(f"server.py PRQ weight defined for {mode_id}")
        else:
            fail(f"server.py PRQ weight missing for {mode_id}")
        if f'"{mode_id}"' in router_weights:
            ok(f"routers/games.py PRQ weight defined for {mode_id}")
        else:
            fail(f"routers/games.py PRQ weight missing for {mode_id}")


def main():
    print("=" * 59)
    print("  FEL Production Smoke Test Suite")
    print(f"  {len(REGISTRY)} registry entries - 8 test categories")
    print("=" * 59)

    try:
        test_mode_manager_registry()
        test_ue_mode_maps()
        test_arena_settings()
        test_venue_registry()
        test_fel_play_map()
        test_swift_enum()
        test_server_seeded_modes()
        test_economy_integration()
    except DuplicateKeyError as exc:
        fail(str(exc))

    total = PASS + FAIL + SKIP
    print(f"\n{'=' * 60}")
    print(f"  Results: {PASS} passed - {FAIL} failed - {SKIP} skipped - {total} total")
    print(f"{'=' * 60}")

    if FAIL > 0:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
