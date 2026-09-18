#!/usr/bin/env python3
"""Validate NEXUS production runtime mode sources stay in sync."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent


def parse_cpp_production_modes() -> list[str]:
    header = REPO_ROOT / "app/gameplay/include/nexus/gameplay/arena_mode_registry.h"
    text = header.read_text()
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(?P<body>.*?)\};", text, re.S)
    if match is None:
        raise ValueError(f"could not find kProductionModeIds in {header}")
    return re.findall(r'"([a-z0-9_]+)"', match.group("body"))


def parse_validate_script_modes() -> list[str]:
    script = REPO_ROOT / "scripts/nexus_validate_production_modes.sh"
    text = script.read_text()
    match = re.search(r"PRODUCTION_MODES=\(\s*(?P<body>.*?)\s*\)", text, re.S)
    if match is None:
        raise ValueError(f"could not find PRODUCTION_MODES in {script}")
    return re.findall(r"\b([a-z][a-z0-9_]*)\b", match.group("body"))


def backend_runtime_mode_ids() -> dict[str, str]:
    registry_path = REPO_ROOT / "backend/FEL_ModeManager.production.json"
    registry = json.loads(registry_path.read_text())["mode_manager"]["mode_registry"]
    runtime_ids: dict[str, str] = {}
    for mode_id, info in registry.items():
        if info.get("status") != "production":
            continue
        if info.get("render_mode") == "IRL":
            continue
        runtime_ids[mode_id] = info.get("nexus_runtime_mode_id", mode_id)
    return runtime_ids


def duplicate_values(values: list[str]) -> list[str]:
    seen: set[str] = set()
    duplicates: set[str] = set()
    for value in values:
        if value in seen:
            duplicates.add(value)
        seen.add(value)
    return sorted(duplicates)


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def main() -> int:
    cpp_modes = parse_cpp_production_modes()
    validate_modes = parse_validate_script_modes()

    cpp_duplicates = duplicate_values(cpp_modes)
    validate_duplicates = duplicate_values(validate_modes)
    if cpp_duplicates:
        fail(f"duplicate C++ production modes: {cpp_duplicates}")
    if validate_duplicates:
        fail(f"duplicate validate-only modes: {validate_duplicates}")

    if cpp_modes != validate_modes:
        cpp_set = set(cpp_modes)
        validate_set = set(validate_modes)
        fail(
            "C++ kProductionModeIds and nexus_validate_production_modes.sh drifted\n"
            f"  cpp_only={sorted(cpp_set - validate_set)}\n"
            f"  script_only={sorted(validate_set - cpp_set)}\n"
            f"  cpp_order={cpp_modes}\n"
            f"  script_order={validate_modes}"
        )

    backend_ids = backend_runtime_mode_ids()
    missing_runtime_ids = {
        mode_id: runtime_id
        for mode_id, runtime_id in backend_ids.items()
        if runtime_id not in cpp_modes
    }
    if missing_runtime_ids:
        fail(f"backend production modes map to unknown NEXUS runtime ids: {missing_runtime_ids}")

    print(
        "PASS: NEXUS production registry sync "
        f"({len(cpp_modes)} runtime modes, {len(backend_ids)} backend production entries checked)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
