#!/usr/bin/env python3
"""Validate Swift app mode IDs against the C++ NEXUS runtime registry.

The iOS app exposes split dunk modes (`basketball_dunk_3d` and
`basketball_dunk_irl`). The C++ runtime keeps the 3D implementation under the
legacy runtime id `basketball_dunk`; IRL dunk is camera-native and must not be
counted as a C++ runtime mode.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
CPP_REGISTRY = REPO_ROOT / "app/gameplay/include/nexus/gameplay/arena_mode_registry.h"
SWIFT_REGISTRY = REPO_ROOT / "FinalEvolutionLab/Models/GameMode.swift"
VALIDATE_SCRIPT = REPO_ROOT / "scripts/nexus_validate_production_modes.sh"
BACKEND_REGISTRY = REPO_ROOT / "backend/FEL_ModeManager.production.json"

SWIFT_TO_CPP_RUNTIME = {
    "basketball_dunk_3d": "basketball_dunk",
}
IRL_ONLY_SWIFT_MODES = {"basketball_dunk_irl"}
NON_GAME_MODULES = {"market_browse"}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def extract_cpp_production_ids() -> list[str]:
    content = CPP_REGISTRY.read_text()
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(?P<body>.*?)\};", content, re.S)
    if not match:
        fail("could not find kProductionModeIds in arena_mode_registry.h")
    return re.findall(r'"([^"]+)"', match.group("body"))


def extract_validate_script_ids() -> list[str]:
    content = VALIDATE_SCRIPT.read_text()
    match = re.search(r"PRODUCTION_MODES=\((?P<body>.*?)\)", content, re.S)
    if not match:
        fail("could not find PRODUCTION_MODES in nexus_validate_production_modes.sh")
    return re.findall(r"[A-Za-z0-9_]+", match.group("body"))


def extract_swift_production_ids() -> list[str]:
    content = SWIFT_REGISTRY.read_text()
    match = re.search(r"productionModeIds:\s*\[String\]\s*=\s*\[(?P<body>.*?)\]", content, re.S)
    if not match:
        fail("could not find GameModeRegistry.productionModeIds in GameMode.swift")
    return re.findall(r'"([^"]+)"', match.group("body"))


def normalized_swift_runtime_ids(swift_ids: list[str]) -> list[str]:
    normalized: list[str] = []
    for mode_id in swift_ids:
        if mode_id in IRL_ONLY_SWIFT_MODES:
            continue
        normalized.append(SWIFT_TO_CPP_RUNTIME.get(mode_id, mode_id))
    return normalized


def validate_backend_registry(cpp_ids: list[str], swift_ids: list[str]) -> None:
    payload = json.loads(BACKEND_REGISTRY.read_text())
    mode_manager = payload.get("mode_manager", {})
    registry = mode_manager.get("mode_registry", {})
    if not isinstance(registry, dict):
        fail("backend mode_registry must be an object")

    declared_total = mode_manager.get("total_modes")
    if declared_total != len(registry):
        fail(f"backend total_modes={declared_total}, actual={len(registry)}")

    actual_production = sum(1 for entry in registry.values() if entry.get("status") == "production")
    declared_production = mode_manager.get("production_modes")
    if declared_production != actual_production:
        fail(
            f"backend production_modes={declared_production}, actual={actual_production}"
        )

    for mode_id in cpp_ids:
        entry = registry.get(mode_id)
        if not entry:
            fail(f"C++ production mode missing from backend registry: {mode_id}")
        if entry.get("status") != "production":
            fail(f"backend mode {mode_id} status={entry.get('status')}, expected production")

    for mode_id in swift_ids:
        entry = registry.get(mode_id)
        if not entry:
            fail(f"Swift production mode missing from backend registry: {mode_id}")
        if entry.get("status") != "production":
            fail(f"backend Swift mode {mode_id} status={entry.get('status')}, expected production")

    for mode_id in NON_GAME_MODULES:
        entry = registry.get(mode_id)
        if not entry:
            fail(f"non-game module missing from backend registry: {mode_id}")
        if entry.get("status") != "non-game-module":
            fail(
                f"backend non-game module {mode_id} status={entry.get('status')}, "
                "expected non-game-module"
            )


def main() -> int:
    cpp_ids = extract_cpp_production_ids()
    validate_ids = extract_validate_script_ids()
    swift_ids = extract_swift_production_ids()
    swift_runtime_ids = normalized_swift_runtime_ids(swift_ids)

    if len(cpp_ids) != len(set(cpp_ids)):
        fail("duplicate ids in C++ production registry")
    if len(swift_ids) != len(set(swift_ids)):
        fail("duplicate ids in Swift productionModeIds")

    if cpp_ids != validate_ids:
        fail(
            "C++ kProductionModeIds differ from nexus_validate_production_modes.sh: "
            f"cpp={cpp_ids}, validate={validate_ids}"
        )

    if set(swift_runtime_ids) != set(cpp_ids):
        fail(
            "Swift production runtime ids differ from C++ production ids: "
            f"swift_runtime={sorted(swift_runtime_ids)}, cpp={sorted(cpp_ids)}"
        )

    if len(swift_ids) != len(cpp_ids) + len(IRL_ONLY_SWIFT_MODES):
        fail(
            f"Swift production count={len(swift_ids)}, expected "
            f"{len(cpp_ids) + len(IRL_ONLY_SWIFT_MODES)}"
        )

    validate_backend_registry(cpp_ids, swift_ids)

    print(
        "PASS: Swift/C++ registry alignment "
        f"({len(swift_ids)} Swift production game ids -> {len(cpp_ids)} C++ runtime modes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
