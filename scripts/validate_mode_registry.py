#!/usr/bin/env python3
"""Validate NEXUS app/game mode registry alignment.

The C++ NEXUS runtime is the production gameplay authority. Swift exposes split
3D/IRL dunk UX IDs, while the C++ runtime keeps ``basketball_dunk`` as the 3D
runtime alias. This gate keeps those intentional aliases explicit and catches
stale counts/statuses before they reach the app shell.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MODE_MANAGER_PATH = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
CPP_REGISTRY_HEADER = REPO_ROOT / "app" / "gameplay" / "include" / "nexus" / "gameplay" / "arena_mode_registry.h"
UE_MAPS_PATH = REPO_ROOT / "backend" / "ue_mode_maps.json"
SWIFT_GAME_MODE_PATH = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"

ERRORS: list[str] = []


def error(message: str) -> None:
    ERRORS.append(message)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text())


def parse_cpp_production_modes() -> list[str]:
    content = CPP_REGISTRY_HEADER.read_text()
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(?P<body>.*?)\};", content, re.S)
    if not match:
        error("Could not parse kProductionModeIds from arena_mode_registry.h")
        return []
    return re.findall(r'"([^"]+)"', match.group("body"))


def swift_contains_raw_value(mode_id: str) -> bool:
    content = SWIFT_GAME_MODE_PATH.read_text()
    return f'= "{mode_id}"' in content


def main() -> int:
    payload = load_json(MODE_MANAGER_PATH)
    manager = payload.get("mode_manager", {})
    registry = manager.get("mode_registry", {})
    ue_maps = load_json(UE_MAPS_PATH).get("mode_to_unreal_map", {})
    cpp_production_modes = parse_cpp_production_modes()

    declared_total = manager.get("total_modes")
    declared_production = manager.get("production_modes")
    production_modes = [mode for mode, info in registry.items() if info.get("status") == "production"]

    if declared_total != len(registry):
        error(f"total_modes mismatch: declared={declared_total}, actual={len(registry)}")
    if declared_production != len(production_modes):
        error(f"production_modes mismatch: declared={declared_production}, actual={len(production_modes)}")

    for mode in cpp_production_modes:
        if registry.get(mode, {}).get("status") != "production":
            error(f"C++ production mode '{mode}' is not production in FEL_ModeManager")
        if mode not in ue_maps:
            error(f"C++ production mode '{mode}' missing from ue_mode_maps.json")

    if registry.get("basketball_dunk_3d", {}).get("nexus_runtime_mode_id") != "basketball_dunk":
        error("basketball_dunk_3d must map to C++ runtime mode basketball_dunk")
    if registry.get("basketball_dunk_irl", {}).get("render_mode") != "IRL":
        error("basketball_dunk_irl must be marked render_mode=IRL")
    if ue_maps.get("basketball_dunk_irl", "missing") is not None:
        error("basketball_dunk_irl must have a null UE map")

    swift_required = set(production_modes) - {"basketball_dunk"}
    for mode in sorted(swift_required):
        if mode == "movement_lab":
            continue
        if not swift_contains_raw_value(mode):
            error(f"Swift GameMode is missing production raw value '{mode}'")
    if not swift_contains_raw_value("basketball_dunk_3d"):
        error("Swift GameMode must expose basketball_dunk_3d for C++ basketball_dunk")

    print("NEXUS mode registry validation")
    print(f"  total entries: {len(registry)}")
    print(f"  production entries: {len(production_modes)}")
    print(f"  C++ production runtime modes: {len(cpp_production_modes)}")

    if ERRORS:
        print("\nErrors:")
        for message in ERRORS:
            print(f"  - {message}")
        return 1

    print("  OK: registry, C++ runtime modes, Swift IDs, and UE aliases align")
    return 0


if __name__ == "__main__":
    sys.exit(main())
