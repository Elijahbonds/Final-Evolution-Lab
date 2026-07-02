#!/usr/bin/env python3
"""Validate Swift sprint launch modes map to supported NEXUS C++ runtime ids."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_MODE_SWIFT = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
ARENA_REGISTRY_HEADER = (
    REPO_ROOT / "app" / "gameplay" / "include" / "nexus" / "gameplay" / "arena_mode_registry.h"
)

DEDICATED_NATIVE_FLOW_CASES = {"basketballDunkContestIRL"}


def extract_swift_enum_raw_values(source: str) -> dict[str, str]:
    return dict(re.findall(r"case\s+([A-Za-z0-9_]+)\s*=\s*\"([^\"]+)\"", source))


def extract_swift_case_set(source: str, name: str) -> set[str]:
    match = re.search(
        rf"static\s+let\s+{re.escape(name)}\s*:\s*Set<GameModeId>\s*=\s*\[(.*?)\]",
        source,
        flags=re.DOTALL,
    )
    if not match:
        raise ValueError(f"Unable to locate GameModeRegistry.{name}")
    return set(re.findall(r"\.([A-Za-z0-9_]+)", match.group(1)))


def extract_runtime_overrides(source: str, enum_raw_values: dict[str, str]) -> dict[str, str]:
    match = re.search(
        r"var\s+nexusRuntimeModeId:\s*String\s*\{(.*?)\n\s*}\n",
        source,
        flags=re.DOTALL,
    )
    if not match:
        raise ValueError("Unable to locate GameModeId.nexusRuntimeModeId")

    overrides: dict[str, str] = {}
    for case_list, return_value in re.findall(
        r"case\s+([^:]+):\s*return\s+([^\n]+)", match.group(1)
    ):
        resolved_value = return_value.strip()
        string_match = re.fullmatch(r'"([^"]+)"', resolved_value)
        raw_value_match = re.fullmatch(r"GameModeId\.([A-Za-z0-9_]+)\.rawValue", resolved_value)
        if string_match:
            runtime_id = string_match.group(1)
        elif raw_value_match:
            runtime_id = enum_raw_values[raw_value_match.group(1)]
        else:
            continue

        for swift_case in re.findall(r"\.([A-Za-z0-9_]+)", case_list):
            overrides[swift_case] = runtime_id
    return overrides


def extract_cpp_production_runtime_ids(source: str) -> set[str]:
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(.*?)\};", source, flags=re.DOTALL)
    if not match:
        raise ValueError("Unable to locate kProductionModeIds")
    return set(re.findall(r'"([^"]+)"', match.group(1)))


def main() -> int:
    swift_source = GAME_MODE_SWIFT.read_text(encoding="utf-8")
    cpp_source = ARENA_REGISTRY_HEADER.read_text(encoding="utf-8")

    enum_raw_values = extract_swift_enum_raw_values(swift_source)
    sprint_cases = extract_swift_case_set(swift_source, "nexusSprintModeIds")
    runtime_overrides = extract_runtime_overrides(swift_source, enum_raw_values)
    cpp_runtime_ids = extract_cpp_production_runtime_ids(cpp_source)

    errors: list[str] = []
    native_sprint_cases = sprint_cases & DEDICATED_NATIVE_FLOW_CASES
    for swift_case in sorted(native_sprint_cases):
        errors.append(f"{swift_case}: dedicated native IRL flow must not be a NEXUS sprint runtime mode")

    resolved_sprint_modes: list[tuple[str, str, str]] = []
    for swift_case in sorted(sprint_cases):
        raw_id = enum_raw_values.get(swift_case)
        if raw_id is None:
            errors.append(f"{swift_case}: missing GameModeId raw value")
            continue
        runtime_id = runtime_overrides.get(swift_case, raw_id)
        resolved_sprint_modes.append((swift_case, raw_id, runtime_id))
        if runtime_id not in cpp_runtime_ids:
            errors.append(
                f"{swift_case}: Swift raw id {raw_id!r} maps to unsupported C++ runtime id {runtime_id!r}"
            )

    if "basketballDunkContest3D" not in sprint_cases:
        errors.append("basketballDunkContest3D: expected 3D dunk to remain a sprint runtime mode")
    elif runtime_overrides.get("basketballDunkContest3D") != "basketball_dunk":
        errors.append("basketballDunkContest3D: expected nexusRuntimeModeId override to basketball_dunk")

    print("FEL iOS runtime launch validation")
    print(f"  swift_sprint_modes={len(sprint_cases)}")
    print(f"  cpp_production_runtime_modes={len(cpp_runtime_ids)}")
    for swift_case, raw_id, runtime_id in resolved_sprint_modes:
        print(f"  {swift_case:28} raw={raw_id:24} runtime={runtime_id}")

    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("All iOS runtime launch assertions passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
