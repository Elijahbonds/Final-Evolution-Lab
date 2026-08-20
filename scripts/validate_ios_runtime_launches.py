#!/usr/bin/env python3
"""Validate Swift arena launch IDs resolve to canonical NEXUS runtime modes."""
from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
CPP_REGISTRY_H = REPO_ROOT / "app" / "gameplay" / "include" / "nexus" / "gameplay" / "arena_mode_registry.h"
SWIFT_GAME_MODE = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
AGENT_SERVICE = REPO_ROOT / "FinalEvolutionLab" / "Services" / "NEXUSAgentService.swift"
CONTENT_VIEW = REPO_ROOT / "FinalEvolutionLab" / "ContentView.swift"
GAMEPLAY_VIEW = REPO_ROOT / "FinalEvolutionLab" / "Views" / "GamePlayView.swift"
BACKEND_CLIENT = REPO_ROOT / "FinalEvolutionLab" / "Services" / "NexusBackendClient.swift"
RECEIPT_COORDINATOR = REPO_ROOT / "FinalEvolutionLab" / "Services" / "GameplaySessionReceiptCoordinator.swift"

ERRORS: list[str] = []


def ok(message: str) -> None:
    print(f"  PASS: {message}")


def err(message: str) -> None:
    ERRORS.append(message)
    print(f"  FAIL: {message}")


def extract_cpp_production_modes() -> set[str]:
    source = CPP_REGISTRY_H.read_text()
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(?P<body>.*?)\};", source, re.DOTALL)
    if not match:
        err(f"Could not find kProductionModeIds in {CPP_REGISTRY_H}")
        return set()
    return set(re.findall(r'"([^"]+)"', match.group("body")))


def extract_swift_cases(source: str) -> dict[str, str]:
    match = re.search(r"enum\s+GameModeId:.*?\{(?P<body>.*?)\n\}", source, re.DOTALL)
    if not match:
        err("Could not find GameModeId enum in GameMode.swift")
        return {}
    return {
        swift_case: raw_value
        for swift_case, raw_value in re.findall(r"case\s+(\w+)\s*=\s*\"([^\"]+)\"", match.group("body"))
    }


def extract_runtime_overrides(source: str) -> dict[str, str]:
    match = re.search(r"var\s+nexusRuntimeModeId:\s*String\s*\{(?P<body>.*?)\n\s*\}", source, re.DOTALL)
    if not match:
        err("Could not find nexusRuntimeModeId switch in GameMode.swift")
        return {}
    body = match.group("body")
    overrides: dict[str, str] = {}
    for swift_case, runtime_id in re.findall(r"case\s+\.([A-Za-z0-9_]+):\s*return\s+\"([^\"]*)\"", body):
        overrides[swift_case] = runtime_id
    if "case .venicePickup: return GameModeId.basketballHeadToHead.rawValue" in body:
        overrides["venicePickup"] = "basketball_h2h"
    return overrides


def extract_subtracted_cases(source: str) -> set[str]:
    match = re.search(r"nexusSprintModeIds:.*?subtracting\(\[(?P<body>.*?)\]\)", source, re.DOTALL)
    if not match:
        err("Could not find nexusSprintModeIds subtracting list")
        return set()
    return set(re.findall(r"\.([A-Za-z0-9_]+)", match.group("body")))


def runtime_id_for_case(swift_case: str, raw_value: str, overrides: dict[str, str]) -> str:
    return overrides.get(swift_case, raw_value)


def validate_launchable_set(
    cpp_production_modes: set[str],
    swift_cases: dict[str, str],
    overrides: dict[str, str],
    excluded_cases: set[str],
) -> None:
    launchable_runtime_ids: dict[str, list[str]] = {}
    for swift_case, raw_value in swift_cases.items():
        if swift_case in excluded_cases:
            continue
        runtime_id = runtime_id_for_case(swift_case, raw_value, overrides)
        launchable_runtime_ids.setdefault(runtime_id, []).append(raw_value)

    invalid = {
        runtime_id: raw_values
        for runtime_id, raw_values in launchable_runtime_ids.items()
        if runtime_id not in cpp_production_modes
    }
    if not invalid:
        ok("every Swift sprint-launchable mode resolves to a C++ production runtime id")
    else:
        formatted = ", ".join(f"{runtime_id} via {raw_values}" for runtime_id, raw_values in sorted(invalid.items()))
        err(f"Swift launchable modes resolve outside C++ production registry: {formatted}")

    missing_runtime_ids = sorted(cpp_production_modes.difference(launchable_runtime_ids.keys()))
    if not missing_runtime_ids:
        ok("Swift sprint launch coverage reaches every C++ production runtime mode")
    else:
        err(f"Swift sprint launch coverage missing runtime modes: {', '.join(missing_runtime_ids)}")

    expected_aliases = {
        "basketball_h2h": {"basketball_h2h", "venice_pickup"},
        "basketball_dunk": {"basketball_dunk_3d"},
    }
    for runtime_id, expected_raw_values in expected_aliases.items():
        actual = set(launchable_runtime_ids.get(runtime_id, []))
        if expected_raw_values.issubset(actual):
            ok(f"{runtime_id} has expected Swift launch aliases")
        else:
            err(f"{runtime_id} launch aliases {sorted(actual)} missing {sorted(expected_raw_values - actual)}")


def validate_non_launchable_modes(
    cpp_production_modes: set[str],
    swift_cases: dict[str, str],
    overrides: dict[str, str],
    excluded_cases: set[str],
) -> None:
    required_exclusions = {
        "basketballDunkContestIRL": "basketball_dunk_irl",
        "marketBrowse": "market_browse",
        "movementLab": "movement_lab",
    }
    for swift_case, raw_value in required_exclusions.items():
        if swift_case not in swift_cases:
            err(f"Swift case {swift_case} is missing")
            continue
        if swift_case in excluded_cases:
            ok(f"{raw_value} excluded from C++ sprint launch set")
        else:
            err(f"{raw_value} must be excluded from C++ sprint launch set")

    irl_runtime = runtime_id_for_case("basketballDunkContestIRL", swift_cases.get("basketballDunkContestIRL", ""), overrides)
    if irl_runtime == "":
        ok("IRL dunk mode intentionally has no C++ runtime id")
    else:
        err(f"IRL dunk runtime id should be empty, got {irl_runtime!r}")

    for swift_case in ("marketBrowse", "movementLab"):
        runtime_id = runtime_id_for_case(swift_case, swift_cases.get(swift_case, ""), overrides)
        if runtime_id not in cpp_production_modes:
            ok(f"{swift_cases.get(swift_case, swift_case)} cannot resolve to a C++ production runtime")
        else:
            err(f"{swift_cases.get(swift_case, swift_case)} unexpectedly resolves to runtime mode {runtime_id}")


def validate_agent_launch_surface(source: str) -> None:
    agent_source = AGENT_SERVICE.read_text()
    required_guards = [
        "GameModeRegistry.playableMode(forRegistryId: modeId)",
        "mode.isLaunchableInCurrentBuild",
        "mode.isNexusSprintPlayable, !mode.id.isIRLDunkContest",
        '"nexus_runtime_mode_id": mode.id.nexusRuntimeModeId',
    ]
    for snippet in required_guards:
        if snippet in agent_source:
            ok(f"agent launch guard present: {snippet}")
        else:
            err(f"agent launch guard missing: {snippet}")

    required_registry_aliases = [
        'case "basketball_dunk":',
        "return mode(for: .basketballDunkContest3D)",
        'case "market_browse", "module_library", "vault_shop":',
        'case "movement_lab", "movement_education", "education_lab":',
    ]
    for snippet in required_registry_aliases:
        if snippet in source:
            ok(f"registry launch alias present: {snippet}")
        else:
            err(f"registry launch alias missing: {snippet}")


def validate_swift_receipt_and_launch_wiring() -> None:
    content_source = CONTENT_VIEW.read_text()
    content_alias_uses = content_source.count("GameModeRegistry.playableMode(forRegistryId: modeId)")
    if content_alias_uses >= 2 and "GameModeId(rawValue: modeId)" not in content_source:
        ok("ContentView agent/deep-link launches resolve registry aliases")
    else:
        err("ContentView launch handlers must use GameModeRegistry.playableMode(forRegistryId:)")

    receipt_source = RECEIPT_COORDINATOR.read_text()
    if "GameModeRegistry.playableMode(forRegistryId: modeStr)?.id" in receipt_source:
        ok("receipt ingestion resolves C++ runtime mode aliases")
    else:
        err("receipt ingestion must resolve mode aliases before GameModeId(rawValue:)")

    backend_source = BACKEND_CLIENT.read_text()
    if "FirebaseBootstrap.isPreviewMode && resolvedBackendAuthToken == nil" in backend_source:
        ok("preview receipt lane allows explicit backend-token POSTs")
    else:
        err("preview receipt lane must not block explicit backend-token POSTs")

    gameplay_source = GAMEPLAY_VIEW.read_text()
    if "nexusEngine.stop(playerScore: score, opponentScore: opponentScore)" in gameplay_source:
        ok("GamePlayView teardown passes final Swift scores into NEXUS stop")
    else:
        err("GamePlayView teardown must stop NEXUS with final player/opponent scores")


def main() -> int:
    print("== iOS NEXUS runtime launch validation ==")
    swift_source = SWIFT_GAME_MODE.read_text()
    cpp_production_modes = extract_cpp_production_modes()
    swift_cases = extract_swift_cases(swift_source)
    overrides = extract_runtime_overrides(swift_source)
    excluded_cases = extract_subtracted_cases(swift_source)

    if len(cpp_production_modes) == 18:
        ok("C++ production runtime set has 18 modes")
    else:
        err(f"C++ production runtime set has {len(cpp_production_modes)} modes, expected 18")

    validate_launchable_set(cpp_production_modes, swift_cases, overrides, excluded_cases)
    validate_non_launchable_modes(cpp_production_modes, swift_cases, overrides, excluded_cases)
    validate_agent_launch_surface(swift_source)
    validate_swift_receipt_and_launch_wiring()

    print()
    if ERRORS:
        print(f"{len(ERRORS)} error(s)")
        return 1
    print("PASS: iOS runtime launch validation")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
