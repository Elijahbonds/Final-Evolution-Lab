#!/usr/bin/env python3
"""Validate Swift GameModeId registry alignment with the backend NEXUS registry.

This gate is intentionally text-based so Linux CI can catch app/backend mode drift
without requiring Xcode. The Swift compiler remains the authoritative syntax gate.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SWIFT_MODE_FILE = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"

sys.path.insert(0, str(REPO_ROOT / "backend"))
from registry_utils import load_json, load_ue_mode_maps, normalized_modes  # noqa: E402

RUNTIME_ONLY_BACKEND_ALIASES = {"basketball_dunk"}
APP_ONLY_ALIASES = {"venice_pickup"}
BACKEND_PREVIEW_MODULES_NOT_IN_IOS_ARENA = {"movement_lab"}
REMOVED_SWIFT_CASES = {
    "basketballDunkContest": "Use basketballDunkContest3D or basketballDunkContestIRL.",
    "basketballIRL": "Use basketballDunkContestIRL.",
}


def extract_bracket_body(source: str, marker: str) -> str:
    start = source.find(marker)
    if start == -1:
        raise ValueError(f"Missing Swift marker: {marker}")
    assignment = source.find("=", start)
    if assignment == -1:
        raise ValueError(f"Missing Swift assignment after: {marker}")
    bracket = source.find("[", assignment)
    if bracket == -1:
        raise ValueError(f"Missing Swift list bracket after: {marker}")
    depth = 0
    for index in range(bracket, len(source)):
        char = source[index]
        if char == "[":
            depth += 1
        elif char == "]":
            depth -= 1
            if depth == 0:
                return source[bracket + 1 : index]
    raise ValueError(f"Unclosed Swift list after: {marker}")


def extract_brace_body(source: str, marker: str) -> str:
    start = source.find(marker)
    if start == -1:
        raise ValueError(f"Missing Swift marker: {marker}")
    brace = source.find("{", start)
    if brace == -1:
        raise ValueError(f"Missing Swift body after: {marker}")
    depth = 0
    for index in range(brace, len(source)):
        char = source[index]
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return source[brace + 1 : index]
    raise ValueError(f"Unclosed Swift body after: {marker}")


def swift_enum_cases(source: str) -> dict[str, str]:
    enum_body = extract_brace_body(source, "enum GameModeId")
    return dict(re.findall(r"case\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\"([^\"]+)\"", enum_body))


def swift_string_list(source: str, marker: str) -> list[str]:
    body = extract_bracket_body(source, marker)
    return re.findall(r"\"([^\"]+)\"", body)


def swift_case_list(source: str, marker: str, cases: dict[str, str]) -> list[str]:
    body = extract_bracket_body(source, marker)
    names = re.findall(r"\.([A-Za-z_][A-Za-z0-9_]*)", body)
    return [cases[name] for name in names if name in cases]


def find_game_mode_entries(source: str, cases: dict[str, str]) -> set[str]:
    names = re.findall(r"id:\s*\.([A-Za-z_][A-Za-z0-9_]*)", source)
    return {cases[name] for name in names if name in cases}


def main() -> int:
    errors: list[str] = []
    source = SWIFT_MODE_FILE.read_text()

    cases = swift_enum_cases(source)
    production_ids = set(swift_string_list(source, "static let productionModeIds"))
    sprint_ids = set(swift_case_list(source, "static let nexusSprintModeIds", cases))
    arena_ids = set(swift_case_list(source, "static let arenaRegistryModeIds", cases))
    game_mode_entries = find_game_mode_entries(source, cases)

    backend_dir = REPO_ROOT / "backend"
    mode_manager = load_json(backend_dir / "FEL_ModeManager.production.json")
    venue_registry = load_json(backend_dir / "FEL_VenueRegistry.production.json")
    ue_mode_maps = load_ue_mode_maps(backend_dir)
    modes = normalized_modes(mode_manager, venue_registry, ue_mode_maps)
    backend_by_id = {mode["mode_id"]: mode for mode in modes}
    backend_production = {mode_id for mode_id, mode in backend_by_id.items() if mode["status"] == "production"}
    backend_catalog_for_ios = set(backend_by_id) - RUNTIME_ONLY_BACKEND_ALIASES - BACKEND_PREVIEW_MODULES_NOT_IN_IOS_ARENA

    stale_cases = (set(cases.values()) - set(backend_by_id) - APP_ONLY_ALIASES)
    if stale_cases:
        errors.append(f"Swift GameModeId has ids missing from backend registry: {sorted(stale_cases)}")

    missing_cases = backend_catalog_for_ios - set(cases.values())
    if missing_cases:
        errors.append(f"Backend modes missing from Swift GameModeId: {sorted(missing_cases)}")

    expected_production = backend_production - RUNTIME_ONLY_BACKEND_ALIASES
    if production_ids != expected_production:
        errors.append(
            "GameModeRegistry.productionModeIds mismatch: "
            f"missing={sorted(expected_production - production_ids)} "
            f"extra={sorted(production_ids - expected_production)}"
        )

    if arena_ids != backend_catalog_for_ios:
        errors.append(
            "GameModeRegistry.arenaRegistryModeIds mismatch: "
            f"missing={sorted(backend_catalog_for_ios - arena_ids)} "
            f"extra={sorted(arena_ids - backend_catalog_for_ios)}"
        )

    missing_game_modes = arena_ids - game_mode_entries
    if missing_game_modes:
        errors.append(f"Swift GameModeRegistry.all missing entries: {sorted(missing_game_modes)}")

    non_launchable_sprint = [
        mode_id
        for mode_id in sprint_ids
        if mode_id in backend_by_id
        and not backend_by_id[mode_id]["launchable"]
        and backend_by_id[mode_id]["render_mode"] != "IRL"
    ]
    if non_launchable_sprint:
        errors.append(f"nexusSprintModeIds includes non-launchable backend modes: {sorted(non_launchable_sprint)}")

    if "case .basketballDunkContest3D: return \"basketball_dunk\"" not in source:
        errors.append("basketballDunkContest3D must map to C++ runtime alias basketball_dunk")

    for removed_case, guidance in REMOVED_SWIFT_CASES.items():
        if re.search(rf"\bcase\s+{removed_case}\b", source):
            errors.append(f"Removed Swift case still declared: {removed_case}. {guidance}")

    print("FEL iOS mode registry validation")
    print(f"  swift_cases={len(cases)}")
    print(f"  swift_production_modes={len(production_ids)}")
    print(f"  swift_arena_modes={len(arena_ids)}")
    print(f"  backend_modes={len(backend_by_id)}")
    print(f"  backend_production_modes={len(backend_production)}")
    print(f"  nexus_sprint_modes={len(sprint_ids)}")

    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("All iOS mode registry assertions passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
