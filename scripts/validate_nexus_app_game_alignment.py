#!/usr/bin/env python3
"""Validate NEXUS app/game registry alignment without Xcode or device access."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ERRORS: list[str] = []


def err(message: str) -> None:
    ERRORS.append(message)


def extract_string_array(text: str, symbol: str) -> list[str]:
    match = re.search(rf"{re.escape(symbol)}[^=]*=\s*\[(.*?)\]", text, re.S)
    if not match:
        err(f"Could not find array {symbol}")
        return []
    return re.findall(r'"([^"]+)"', match.group(1))


def canonical_mode_id(mode_id: str) -> str:
    if mode_id in {"basketball_dunk_3d", "basketball_dunk_irl"}:
        return "basketball_dunk"
    if mode_id == "venice_pickup":
        return "basketball_h2h"
    return mode_id


def validate_mode_registry() -> None:
    cpp_header = (
        REPO_ROOT / "app/gameplay/include/nexus/gameplay/arena_mode_registry.h"
    ).read_text()
    cpp_match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(.*?)\};", cpp_header, re.S)
    if not cpp_match:
        err("Could not find C++ kProductionModeIds initializer")
        cpp_modes: set[str] = set()
    else:
        cpp_modes = set(re.findall(r'"([^"]+)"', cpp_match.group(1)))

    manager_path = REPO_ROOT / "backend/FEL_ModeManager.production.json"
    manager = json.loads(manager_path.read_text())
    mode_manager = manager.get("mode_manager", {})
    registry = mode_manager.get("mode_registry", {})

    declared_total = mode_manager.get("total_modes")
    actual_total = len(registry)
    if declared_total != actual_total:
        err(f"backend total_modes declared {declared_total}, actual {actual_total}")

    production_modes = {
        mode_id for mode_id, info in registry.items() if info.get("status") == "production"
    }
    declared_production = mode_manager.get("production_modes")
    if declared_production != len(production_modes):
        err(
            "backend production_modes declared "
            f"{declared_production}, actual {len(production_modes)}"
        )

    backend_canonical = {canonical_mode_id(mode_id) for mode_id in production_modes}
    missing_backend = sorted(cpp_modes - backend_canonical)
    unexpected_backend = sorted(backend_canonical - cpp_modes)
    if missing_backend:
        err(f"C++ production modes missing from backend production: {missing_backend}")
    if unexpected_backend:
        err(f"backend production modes not in C++ registry: {unexpected_backend}")

    swift_modes = set(
        extract_string_array(
            (REPO_ROOT / "FinalEvolutionLab/Models/GameMode.swift").read_text(),
            "productionModeIds",
        )
    )
    swift_canonical = {canonical_mode_id(mode_id) for mode_id in swift_modes}
    missing_swift = sorted(cpp_modes - swift_canonical)
    unexpected_swift = sorted(swift_canonical - cpp_modes)
    if missing_swift:
        err(f"C++ production modes missing from Swift productionModeIds: {missing_swift}")
    if unexpected_swift:
        err(f"Swift productionModeIds not in C++ registry: {unexpected_swift}")


def validate_agent_surface() -> None:
    config_tools = json.loads(
        (REPO_ROOT / "Config/nexus_cursor_tool_registry.json").read_text()
    ).get("mcp_surface_tools", [])

    bridge_tools = extract_string_array(
        (REPO_ROOT / "FinalEvolutionLab/Services/NEXUSCursorBridge.swift").read_text(),
        "mcpSurfaceTools",
    )
    if bridge_tools != config_tools:
        err(f"NEXUSCursorBridge mcpSurfaceTools drift: {bridge_tools} != {config_tools}")

    models_text = (REPO_ROOT / "FinalEvolutionLab/Models/NEXUSAgentModels.swift").read_text()
    case_to_raw = dict(re.findall(r"case\s+(\w+)\s*=\s*\"([^\"]+)\"", models_text))
    surface_match = re.search(r"static let mcpSurfaceTools.*?=\s*\[(.*?)\]", models_text, re.S)
    if not surface_match:
        err("Could not find NEXUSAgentToolName.mcpSurfaceTools")
        return

    model_tools: list[str] = []
    for case_name in re.findall(r"\.(\w+)", surface_match.group(1)):
        raw = case_to_raw.get(case_name)
        if raw is None:
            err(f"NEXUSAgentToolName.mcpSurfaceTools references unknown case {case_name}")
        else:
            model_tools.append(raw)

    if model_tools != config_tools:
        err(f"NEXUSAgentToolName mcpSurfaceTools drift: {model_tools} != {config_tools}")


def main() -> int:
    validate_mode_registry()
    validate_agent_surface()

    if ERRORS:
        print("NEXUS app/game alignment: FAIL")
        for message in ERRORS:
            print(f"  - {message}")
        return 1

    print("NEXUS app/game alignment: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
