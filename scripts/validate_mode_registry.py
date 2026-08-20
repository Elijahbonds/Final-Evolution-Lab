#!/usr/bin/env python3
"""Validate the NEXUS mode registry across backend JSON, C++ runtime, and Swift."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_REGISTRY = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
UE_MODE_MAPS = REPO_ROOT / "backend" / "ue_mode_maps.json"
CPP_REGISTRY_H = REPO_ROOT / "app" / "gameplay" / "include" / "nexus" / "gameplay" / "arena_mode_registry.h"
CPP_REGISTRY_CPP = REPO_ROOT / "app" / "gameplay" / "src" / "arena_mode_registry.cpp"
SWIFT_GAME_MODE = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"

ERRORS: list[str] = []
WARNINGS: list[str] = []


def ok(message: str) -> None:
    print(f"  PASS: {message}")


def err(message: str) -> None:
    ERRORS.append(message)
    print(f"  FAIL: {message}")


def warn(message: str) -> None:
    WARNINGS.append(message)
    print(f"  WARN: {message}")


def load_backend_registry() -> dict[str, object]:
    payload = json.loads(BACKEND_REGISTRY.read_text())
    return payload.get("mode_manager", {})


def extract_string_array(source: str, symbol: str) -> list[str]:
    match = re.search(rf"{re.escape(symbol)}\[\]\s*=\s*\{{(?P<body>.*?)\}};", source, re.DOTALL)
    if not match:
        err(f"Could not find {symbol} in {CPP_REGISTRY_H}")
        return []
    return re.findall(r'"([^"]+)"', match.group("body"))


def extract_cpp_mode_blocks(source: str) -> dict[str, str]:
    modes: dict[str, str] = {}
    for match in re.finditer(r"\{\.id\s*=\s*\"(?P<id>[^\"]+)\"(?P<body>.*?)(?=\n\s*\{\.id\s*=|\n\s*\}\};)", source, re.DOTALL):
        modes[match.group("id")] = match.group(0)
    return modes


def extract_swift_raw_values(source: str) -> set[str]:
    match = re.search(r"enum\s+GameModeId:.*?\{(?P<body>.*?)\n\}", source, re.DOTALL)
    if not match:
        err("Could not find GameModeId enum in GameMode.swift")
        return set()
    return set(re.findall(r"case\s+\w+\s*=\s*\"([^\"]+)\"", match.group("body")))


def validate_declared_counts(mode_manager: dict[str, object], registry: dict[str, dict[str, object]]) -> None:
    declared_total = mode_manager.get("total_modes")
    declared_production = mode_manager.get("production_modes")
    actual_total = len(registry)
    actual_production = sum(1 for entry in registry.values() if entry.get("status") == "production")

    if declared_total == actual_total:
        ok(f"backend total_modes={declared_total}")
    else:
        err(f"backend total_modes={declared_total}, actual={actual_total}")

    if declared_production == actual_production:
        ok(f"backend production_modes={declared_production}")
    else:
        err(f"backend production_modes={declared_production}, actual={actual_production}")


def validate_cpp_runtime_modes(registry: dict[str, dict[str, object]], ue_maps: dict[str, object]) -> list[str]:
    header_source = CPP_REGISTRY_H.read_text()
    cpp_source = CPP_REGISTRY_CPP.read_text()
    production_ids = extract_string_array(header_source, "kProductionModeIds")
    cpp_blocks = extract_cpp_mode_blocks(cpp_source)
    missing_blocks = [mode for mode in production_ids if mode not in cpp_blocks]

    if len(production_ids) == 18:
        ok("C++ runtime declares 18 canonical production modes")
    else:
        err(f"C++ runtime production mode count is {len(production_ids)}, expected 18")

    if not missing_blocks:
        ok("every C++ production mode has an ArenaModeConfig block")
    else:
        err(f"C++ production modes missing config blocks: {', '.join(missing_blocks)}")

    extra_cpp_production = sorted(
        mode
        for mode, block in cpp_blocks.items()
        if "ArenaReleaseState::kProduction" in block and mode not in production_ids
    )
    if not extra_cpp_production:
        ok("C++ production blocks match kProductionModeIds")
    else:
        err(f"C++ config has production modes outside kProductionModeIds: {', '.join(extra_cpp_production)}")

    for mode in production_ids:
        entry = registry.get(mode)
        if entry and entry.get("status") == "production":
            ok(f"{mode} backend status is production")
        elif entry:
            err(f"{mode} backend status={entry.get('status')}, expected production")
        else:
            err(f"{mode} missing from backend registry")

        if mode in ue_maps and ue_maps[mode]:
            ok(f"{mode} has UE/NEXUS map token")
        else:
            err(f"{mode} missing launch map token in ue_mode_maps.json")

        block = cpp_blocks.get(mode, "")
        if 'scoringEnabled = true' in block:
            ok(f"{mode} scoring state is explicit")
        else:
            err(f"{mode} does not explicitly enable scoring")

        expected_scoring = bool(entry.get("scoring_enabled", True)) if entry else True
        cpp_scoring = 'scoringEnabled = true' in block
        if cpp_scoring == expected_scoring:
            ok(f"{mode} C++ scoring matches backend registry")
        else:
            err(
                f"{mode} C++ scoringEnabled={cpp_scoring}, "
                f"backend scoring_enabled={expected_scoring}"
            )

    return production_ids


def validate_backend_special_modes(registry: dict[str, dict[str, object]], ue_maps: dict[str, object]) -> None:
    dunk_3d = registry.get("basketball_dunk_3d", {})
    if dunk_3d.get("nexus_runtime_mode_id") == "basketball_dunk" and ue_maps.get("basketball_dunk_3d"):
        ok("basketball_dunk_3d aliases to canonical basketball_dunk runtime")
    else:
        err("basketball_dunk_3d must alias to basketball_dunk and have a launch map")

    irl = registry.get("basketball_dunk_irl", {})
    if irl.get("status") == "production" and irl.get("render_mode") == "IRL" and ue_maps.get("basketball_dunk_irl") is None:
        ok("basketball_dunk_irl is production IRL with no UE/NEXUS map")
    else:
        err("basketball_dunk_irl must be production render_mode=IRL with null launch map")

    market = registry.get("market_browse", {})
    if market.get("status") == "non-game-module" and float(market.get("prq_weight", 1.0)) == 0.0:
        ok("market_browse is non-game module with zero PRQ weight")
    else:
        err("market_browse must stay non-game-module with prq_weight=0")

    movement = registry.get("movement_lab", {})
    if (
        movement.get("status") == "preview"
        and movement.get("release_state") == "preview"
        and movement.get("scoring_enabled") is False
        and float(movement.get("prq_weight", 1.0)) == 0.0
    ):
        ok("movement_lab is preview education with scoring disabled")
    else:
        err("movement_lab must stay preview education with scoring disabled and prq_weight=0")


def validate_swift_surface(registry: dict[str, dict[str, object]], production_ids: list[str]) -> None:
    swift_source = SWIFT_GAME_MODE.read_text()
    swift_raw_values = extract_swift_raw_values(swift_source)

    missing_swift = []
    for mode in production_ids:
        swift_id = "basketball_dunk_3d" if mode == "basketball_dunk" else mode
        if swift_id not in swift_raw_values:
            missing_swift.append(f"{mode} -> {swift_id}")
    if not missing_swift:
        ok("Swift GameModeId covers every C++ runtime production mode")
    else:
        err(f"Swift GameModeId missing production coverage: {', '.join(missing_swift)}")

    for special in ("basketball_dunk_irl", "market_browse", "movement_lab"):
        if special in swift_raw_values and special in registry:
            ok(f"Swift exposes {special} with backend registry entry")
        else:
            err(f"Swift/backend special-mode coverage missing for {special}")


def main() -> int:
    print("== NEXUS mode registry validation ==")
    mode_manager = load_backend_registry()
    registry = mode_manager.get("mode_registry", {})
    if not isinstance(registry, dict):
        err("backend mode_registry is missing or malformed")
        registry = {}
    ue_maps_payload = json.loads(UE_MODE_MAPS.read_text())
    ue_maps = ue_maps_payload.get("mode_to_unreal_map", {})

    validate_declared_counts(mode_manager, registry)
    production_ids = validate_cpp_runtime_modes(registry, ue_maps)
    validate_backend_special_modes(registry, ue_maps)
    validate_swift_surface(registry, production_ids)

    print()
    if WARNINGS:
        print(f"{len(WARNINGS)} warning(s)")
    if ERRORS:
        print(f"{len(ERRORS)} error(s)")
        return 1
    print("PASS: NEXUS mode registry validation")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
