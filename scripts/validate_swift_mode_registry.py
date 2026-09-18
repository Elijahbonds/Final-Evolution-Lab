#!/usr/bin/env python3
"""Validate Swift game-mode registry alignment with NEXUS C++ and backend JSON."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_MODE_SWIFT = REPO_ROOT / "FinalEvolutionLab/Models/GameMode.swift"
CONTENT_VIEW_SWIFT = REPO_ROOT / "FinalEvolutionLab/ContentView.swift"
GAMEPLAY_VIEW_SWIFT = REPO_ROOT / "FinalEvolutionLab/Views/GamePlayView.swift"
RECEIPT_COORDINATOR_SWIFT = REPO_ROOT / "FinalEvolutionLab/Services/GameplaySessionReceiptCoordinator.swift"
ECONOMY_AUTHORITY_SWIFT = REPO_ROOT / "FinalEvolutionLab/Services/NexusEconomyAuthority.swift"
ARENA_REGISTRY_HEADER = REPO_ROOT / "app/gameplay/include/nexus/gameplay/arena_mode_registry.h"
BACKEND_MODE_MANAGER = REPO_ROOT / "backend/FEL_ModeManager.production.json"

SWIFT_RUNTIME_ALIASES = {
    "basketball_dunk": "basketball_dunk_3d",
    "venice_pickup": "basketball_h2h",
    "module_library": "market_browse",
    "vault_shop": "market_browse",
}


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def duplicate_values(values: list[str]) -> list[str]:
    seen: set[str] = set()
    duplicates: set[str] = set()
    for value in values:
        if value in seen:
            duplicates.add(value)
        seen.add(value)
    return sorted(duplicates)


def swift_case_ids() -> dict[str, str]:
    text = GAME_MODE_SWIFT.read_text()
    return dict(re.findall(r"case\s+([A-Za-z0-9_]+)\s*=\s*\"([a-z0-9_]+)\"", text))


def swift_string_list(name: str) -> list[str]:
    text = GAME_MODE_SWIFT.read_text()
    match = re.search(rf"static let {name}:\s*\[[^\]]+\]\s*=\s*\[(?P<body>.*?)\]", text, re.S)
    if match is None:
        fail(f"could not find Swift {name}")
    return re.findall(r'"([a-z0-9_]+)"', match.group("body"))


def swift_case_list(name: str, cases: dict[str, str]) -> list[str]:
    text = GAME_MODE_SWIFT.read_text()
    match = re.search(rf"static let {name}:\s*\[[^\]]+\]\s*=\s*\[(?P<body>.*?)\]", text, re.S)
    if match is None:
        fail(f"could not find Swift {name}")
    values: list[str] = []
    for case_name in re.findall(r"\.([A-Za-z0-9_]+)", match.group("body")):
        if case_name not in cases:
            fail(f"Swift {name} references unknown GameModeId case .{case_name}")
        values.append(cases[case_name])
    return values


def cpp_production_modes() -> list[str]:
    text = ARENA_REGISTRY_HEADER.read_text()
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(?P<body>.*?)\};", text, re.S)
    if match is None:
        fail("could not find C++ kProductionModeIds")
    return re.findall(r'"([a-z0-9_]+)"', match.group("body"))


def backend_registry() -> dict[str, dict[str, object]]:
    payload = json.loads(BACKEND_MODE_MANAGER.read_text())
    return payload["mode_manager"]["mode_registry"]


def backend_expected_swift_production_ids(registry: dict[str, dict[str, object]]) -> set[str]:
    expected: set[str] = set()
    for mode_id, info in registry.items():
        if info.get("status") != "production":
            continue
        expected.add(SWIFT_RUNTIME_ALIASES.get(mode_id, mode_id))
    return expected


def backend_runtime_production_ids(registry: dict[str, dict[str, object]]) -> set[str]:
    expected: set[str] = set()
    for mode_id, info in registry.items():
        if info.get("status") != "production":
            continue
        if info.get("render_mode") == "IRL":
            continue
        runtime_id = str(info.get("nexus_runtime_mode_id", mode_id))
        expected.add(runtime_id)
    return expected


def backend_expected_arena_ids(registry: dict[str, dict[str, object]]) -> set[str]:
    expected: set[str] = set()
    for mode_id, info in registry.items():
        status = info.get("status")
        if status not in {"production", "non-game-module"}:
            continue
        expected.add(SWIFT_RUNTIME_ALIASES.get(mode_id, mode_id))
    return expected


def assert_source_patterns() -> None:
    game_mode = GAME_MODE_SWIFT.read_text()
    content_view = CONTENT_VIEW_SWIFT.read_text()
    gameplay_view = GAMEPLAY_VIEW_SWIFT.read_text()
    receipt_coordinator = RECEIPT_COORDINATOR_SWIFT.read_text()
    economy_authority = ECONOMY_AUTHORITY_SWIFT.read_text()

    for alias, swift_id in SWIFT_RUNTIME_ALIASES.items():
        if alias in {"module_library", "vault_shop"}:
            continue
        if f'case "{alias}"' not in game_mode:
            fail(f"GameModeRegistry.modeId(forRegistryId:) missing alias case for {alias}")
        if swift_id not in game_mode:
            fail(f"Swift registry missing alias target {swift_id}")

    if not re.search(r"case\s+\.brainBrawl:\s*return\s+\.prod", game_mode):
        fail("brain_brawl must be .prod in Swift to match backend/C++ production registries")

    if "GameModeRegistry.modeId(forRegistryId: modeStr)" not in receipt_coordinator:
        fail("receipt parser must resolve C++/backend aliases through GameModeRegistry.modeId")

    if "GameModeRegistry.playableMode(forRegistryId: modeId)" not in content_view:
        fail("agent launch must resolve aliases through GameModeRegistry.playableMode")

    if "playerScore: nexusSessionPlayerScore" not in gameplay_view:
        fail("GamePlayView onDisappear must pass the current player score into NEXUS stop")
    if "NexusEconomyAuthority.allowsLocalEconomyGrant" not in gameplay_view:
        fail("GamePlayView finalize must use NexusEconomyAuthority before mutating economy")

    for case_name in [
        "basketballDunkContestIRL",
        "basketballDunkContest3D",
        "basketballHeadToHead",
        "venicePickup",
        "karateEndless",
        "courtCarnival",
    ]:
        if f".{case_name}" not in economy_authority:
            fail(f"NexusEconomyAuthority must cover P0/P1 mode .{case_name}")


def main() -> int:
    cases = swift_case_ids()
    swift_production = swift_string_list("productionModeIds")
    swift_arena = swift_case_list("arenaRegistryModeIds", cases)
    cpp_production = cpp_production_modes()
    registry = backend_registry()

    if duplicates := duplicate_values(swift_production):
        fail(f"duplicate Swift production ids: {duplicates}")
    if duplicates := duplicate_values(swift_arena):
        fail(f"duplicate Swift arena ids: {duplicates}")

    expected_swift_production = backend_expected_swift_production_ids(registry)
    if set(swift_production) != expected_swift_production:
        fail(
            "Swift productionModeIds drifted from backend production registry\n"
            f"  swift_only={sorted(set(swift_production) - expected_swift_production)}\n"
            f"  backend_only={sorted(expected_swift_production - set(swift_production))}"
        )

    expected_arena = backend_expected_arena_ids(registry)
    if set(swift_arena) != expected_arena:
        fail(
            "Swift arenaRegistryModeIds drifted from backend arena registry\n"
            f"  swift_only={sorted(set(swift_arena) - expected_arena)}\n"
            f"  backend_only={sorted(expected_arena - set(swift_arena))}"
        )

    expected_runtime = backend_runtime_production_ids(registry)
    if set(cpp_production) != expected_runtime:
        fail(
            "C++ production runtime ids drifted from backend production runtime ids\n"
            f"  cpp_only={sorted(set(cpp_production) - expected_runtime)}\n"
            f"  backend_only={sorted(expected_runtime - set(cpp_production))}"
        )

    swift_known_ids = set(cases.values())
    unresolved = sorted(expected_swift_production - swift_known_ids)
    if unresolved:
        fail(f"backend production ids missing Swift GameModeId cases: {unresolved}")

    assert_source_patterns()

    print(
        "PASS: Swift mode registry sync "
        f"({len(swift_production)} production app modes, "
        f"{len(swift_arena)} arena modes, {len(cpp_production)} C++ runtime modes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
