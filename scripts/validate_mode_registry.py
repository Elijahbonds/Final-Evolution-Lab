#!/usr/bin/env python3
"""Validate NEXUS mode registry alignment across backend, C++, scripts, and Swift."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent

RUNTIME_PRODUCTION_MODES = {
    "basketball_h2h",
    "basketball_dunk",
    "basketball_3v3",
    "court_carnival",
    "karate_h2h",
    "karate_endless",
    "baseball",
    "football",
    "soccer",
    "golf",
    "tennis",
    "volleyball",
    "gymnastics",
    "surfing",
    "skateboarding",
    "snowboarding",
    "brain_brawl",
    "who_scene_it",
}

BACKEND_PRODUCTION_ENTRIES = RUNTIME_PRODUCTION_MODES | {
    "basketball_dunk_3d",
    "basketball_dunk_irl",
}

SWIFT_PRODUCTION_IDS = (RUNTIME_PRODUCTION_MODES - {"basketball_dunk"}) | {
    "basketball_dunk_3d",
    "basketball_dunk_irl",
}


errors: list[str] = []


def err(message: str) -> None:
    errors.append(message)


def parse_quoted_strings(block: str) -> set[str]:
    return set(re.findall(r'"([^"]+)"', block))


def parse_cpp_production_modes() -> set[str]:
    content = (REPO_ROOT / "app/gameplay/include/nexus/gameplay/arena_mode_registry.h").read_text()
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(?P<body>.*?)\};", content, re.S)
    if not match:
        err("Could not parse kProductionModeIds from arena_mode_registry.h")
        return set()
    return parse_quoted_strings(match.group("body"))


def parse_validate_script_modes() -> set[str]:
    content = (REPO_ROOT / "scripts/nexus_validate_production_modes.sh").read_text()
    match = re.search(r"PRODUCTION_MODES=\((?P<body>.*?)\)", content, re.S)
    if not match:
        err("Could not parse PRODUCTION_MODES from nexus_validate_production_modes.sh")
        return set()
    return set(match.group("body").split())


def parse_swift_production_ids() -> set[str]:
    content = (REPO_ROOT / "FinalEvolutionLab/Models/GameMode.swift").read_text()
    match = re.search(r"productionModeIds:\s*\[String\]\s*=\s*\[(?P<body>.*?)\]", content, re.S)
    if not match:
        err("Could not parse GameModeRegistry.productionModeIds from GameMode.swift")
        return set()
    return parse_quoted_strings(match.group("body"))


def validate_backend_registry() -> None:
    payload = json.loads((REPO_ROOT / "backend/FEL_ModeManager.production.json").read_text())
    mode_manager = payload["mode_manager"]
    registry = mode_manager["mode_registry"]

    if mode_manager.get("total_modes") != len(registry):
        err(f"Backend total_modes={mode_manager.get('total_modes')} but registry has {len(registry)}")

    production_count = sum(1 for entry in registry.values() if entry.get("status") == "production")
    if mode_manager.get("production_modes") != production_count:
        err(
            "Backend production_modes="
            f"{mode_manager.get('production_modes')} but registry has {production_count}"
        )

    for mode_id in sorted(BACKEND_PRODUCTION_ENTRIES):
        if registry.get(mode_id, {}).get("status") != "production":
            err(f"Backend mode {mode_id} is not production")

    if registry.get("market_browse", {}).get("status") != "non-game-module":
        err("Backend market_browse must remain non-game-module")

    if registry.get("movement_lab", {}).get("status") != "preview":
        err("Backend movement_lab must remain preview education module")

    dunk_3d = registry.get("basketball_dunk_3d", {})
    if dunk_3d.get("nexus_runtime_mode_id") != "basketball_dunk":
        err("basketball_dunk_3d must route to NEXUS runtime mode basketball_dunk")

    dunk_irl = registry.get("basketball_dunk_irl", {})
    if dunk_irl.get("render_mode") != "IRL" or dunk_irl.get("venue_id") is not None:
        err("basketball_dunk_irl must remain IRL with no UE venue_id")


def validate_cross_surface_sets() -> None:
    cpp_modes = parse_cpp_production_modes()
    validate_script_modes = parse_validate_script_modes()
    swift_modes = parse_swift_production_ids()

    if cpp_modes != RUNTIME_PRODUCTION_MODES:
        err(f"C++ production modes drifted: {sorted(cpp_modes ^ RUNTIME_PRODUCTION_MODES)}")

    if validate_script_modes != RUNTIME_PRODUCTION_MODES:
        err(
            "nexus_validate_production_modes.sh drifted from runtime production set: "
            f"{sorted(validate_script_modes ^ RUNTIME_PRODUCTION_MODES)}"
        )

    if swift_modes != SWIFT_PRODUCTION_IDS:
        err(f"Swift productionModeIds drifted: {sorted(swift_modes ^ SWIFT_PRODUCTION_IDS)}")


def validate_ue_mode_maps() -> None:
    payload = json.loads((REPO_ROOT / "backend/ue_mode_maps.json").read_text())
    mode_map = payload["mode_to_unreal_map"]

    for mode_id in sorted(RUNTIME_PRODUCTION_MODES):
        if not mode_map.get(mode_id):
            err(f"Runtime production mode {mode_id} is missing a UE map token")

    if mode_map.get("basketball_dunk_3d") != mode_map.get("basketball_dunk"):
        err("basketball_dunk_3d must share the basketball_dunk UE map token")

    if "basketball_dunk_irl" not in mode_map or mode_map["basketball_dunk_irl"] is not None:
        err("basketball_dunk_irl must be present in ue_mode_maps.json with null map")


def main() -> int:
    validate_backend_registry()
    validate_cross_surface_sets()
    validate_ue_mode_maps()

    if errors:
        print("NEXUS mode registry validation failed:")
        for message in errors:
            print(f"  - {message}")
        return 1

    print(
        "NEXUS mode registry validation passed "
        f"({len(RUNTIME_PRODUCTION_MODES)} runtime production modes, "
        f"{len(BACKEND_PRODUCTION_ENTRIES)} backend production entries)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
