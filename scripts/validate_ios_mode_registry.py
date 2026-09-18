#!/usr/bin/env python3
"""Validate Swift, backend, and NEXUS C++ mode registry alignment."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SWIFT_GAME_MODE = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
CPP_REGISTRY = REPO_ROOT / "app" / "gameplay" / "include" / "nexus" / "gameplay" / "arena_mode_registry.h"
PRODUCTION_VALIDATE_SCRIPT = REPO_ROOT / "scripts" / "nexus_validate_production_modes.sh"
BACKEND_MODE_MANAGER = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"

APP_TO_RUNTIME_ALIAS = {
    "basketball_dunk_3d": "basketball_dunk",
    "basketball_dunk_irl": "basketball_dunk",
}


def extract_swift_string_array(source: str, name: str) -> list[str]:
    match = re.search(rf"static\s+let\s+{name}\s*:\s*\[String\]\s*=\s*\[(.*?)\]", source, re.S)
    if not match:
        raise ValueError(f"Swift array {name} not found")
    return re.findall(r'"([^"]+)"', match.group(1))


def extract_cpp_production_ids(source: str) -> list[str]:
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(.*?)\};", source, re.S)
    if not match:
        raise ValueError("kProductionModeIds not found")
    return re.findall(r'"([^"]+)"', match.group(1))


def extract_shell_production_ids(source: str) -> list[str]:
    match = re.search(r"PRODUCTION_MODES=\((.*?)\)", source, re.S)
    if not match:
        raise ValueError("PRODUCTION_MODES not found")
    return re.findall(r"\b[a-z0-9_]+\b", match.group(1))


def add_set_diff_error(errors: list[str], label: str, left: set[str], right: set[str]) -> None:
    missing = sorted(right - left)
    extra = sorted(left - right)
    if missing:
        errors.append(f"{label} missing: {', '.join(missing)}")
    if extra:
        errors.append(f"{label} extra: {', '.join(extra)}")


def main() -> int:
    errors: list[str] = []

    swift_source = SWIFT_GAME_MODE.read_text()
    cpp_source = CPP_REGISTRY.read_text()
    validate_source = PRODUCTION_VALIDATE_SCRIPT.read_text()
    mode_manager = json.loads(BACKEND_MODE_MANAGER.read_text())["mode_manager"]
    backend_registry = mode_manager["mode_registry"]

    swift_production = extract_swift_string_array(swift_source, "productionModeIds")
    swift_runtime_ids = {APP_TO_RUNTIME_ALIAS.get(mode_id, mode_id) for mode_id in swift_production}
    cpp_production = set(extract_cpp_production_ids(cpp_source))
    validate_production = set(extract_shell_production_ids(validate_source))

    add_set_diff_error(errors, "Swift production runtime ids vs C++ registry", swift_runtime_ids, cpp_production)
    add_set_diff_error(errors, "Production validate script vs C++ registry", validate_production, cpp_production)

    actual_total = len(backend_registry)
    actual_production = sum(1 for entry in backend_registry.values() if entry.get("status") == "production")
    if mode_manager.get("total_modes") != actual_total:
        errors.append(
            f"backend total_modes declared={mode_manager.get('total_modes')} actual={actual_total}"
        )
    if mode_manager.get("production_modes") != actual_production:
        errors.append(
            f"backend production_modes declared={mode_manager.get('production_modes')} actual={actual_production}"
        )

    for mode_id in sorted(cpp_production | set(swift_production)):
        status = backend_registry.get(mode_id, {}).get("status")
        if status != "production":
            errors.append(f"backend mode {mode_id} status={status!r}, expected production")

    if backend_registry.get("market_browse", {}).get("status") != "non-game-module":
        errors.append("backend market_browse must remain non-game-module")
    if backend_registry.get("movement_lab", {}).get("status") != "preview":
        errors.append("backend movement_lab must remain preview")

    required_swift_snippets = [
        'case .basketballDunkContestIRL, .basketballDunkContest3D: return "basketball_dunk"',
        'case "basketball_dunk", "basketball_irl":',
        "static func launchModeId(forRegistryId raw: String) -> GameModeId?",
    ]
    for snippet in required_swift_snippets:
        if snippet not in swift_source:
            errors.append(f"GameMode.swift missing launch alias snippet: {snippet}")

    if errors:
        print("iOS mode registry validation FAILED")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("iOS mode registry validation PASSED")
    print(f"  Swift production app ids: {len(swift_production)}")
    print(f"  NEXUS runtime production ids: {len(cpp_production)}")
    print(f"  Backend registry entries: {actual_total} total / {actual_production} production")
    return 0


if __name__ == "__main__":
    sys.exit(main())
