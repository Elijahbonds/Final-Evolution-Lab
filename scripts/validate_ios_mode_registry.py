#!/usr/bin/env python3
"""Validate Swift game mode registry parity with NEXUS C++ production modes."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_MODE_SWIFT = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
CPP_REGISTRY = REPO_ROOT / "app" / "gameplay" / "include" / "nexus" / "gameplay" / "arena_mode_registry.h"
SWIFT_ROOTS = [REPO_ROOT / "FinalEvolutionLab", REPO_ROOT / "FinalEvolutionLabTests"]


def string_array(source: str, name: str) -> list[str]:
    match = re.search(
        rf"static\s+let\s+{re.escape(name)}\s*:\s*\[String\]\s*=\s*\[(.*?)\]",
        source,
        flags=re.DOTALL,
    )
    if not match:
        raise ValueError(f"missing Swift string array {name}")
    return re.findall(r'"([^"]+)"', match.group(1))


def cpp_production_ids(source: str) -> list[str]:
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(.*?)\};", source, flags=re.DOTALL)
    if not match:
        raise ValueError("missing C++ kProductionModeIds array")
    return re.findall(r'"([^"]+)"', match.group(1))


def game_mode_cases(source: str) -> dict[str, str]:
    enum_match = re.search(r"enum\s+GameModeId\b.*?\{(.*?)\n\}", source, flags=re.DOTALL)
    if not enum_match:
        raise ValueError("missing Swift GameModeId enum")
    return dict(re.findall(r"\bcase\s+([A-Za-z][A-Za-z0-9_]*)\s*=\s*\"([^\"]+)\"", enum_match.group(1)))


def stale_case_references() -> list[str]:
    stale_names = (".basketballDunkContest", ".basketballIRL")
    hits: list[str] = []
    for root in SWIFT_ROOTS:
        for path in root.rglob("*.swift"):
            text = path.read_text(errors="replace")
            for line_no, line in enumerate(text.splitlines(), start=1):
                if any(name in line for name in stale_names):
                    hits.append(f"{path.relative_to(REPO_ROOT)}:{line_no}: {line.strip()}")
    return hits


def main() -> int:
    errors: list[str] = []
    swift_source = GAME_MODE_SWIFT.read_text()
    cpp_source = CPP_REGISTRY.read_text()

    try:
        swift_case_raw_values = game_mode_cases(swift_source)
        swift_production = string_array(swift_source, "productionModeIds")
        swift_runtime_production = string_array(swift_source, "nexusRuntimeProductionModeIds")
        cpp_runtime_production = cpp_production_ids(cpp_source)
    except ValueError as exc:
        errors.append(str(exc))
        swift_case_raw_values = {}
        swift_production = []
        swift_runtime_production = []
        cpp_runtime_production = []

    known_swift_raw_values = set(swift_case_raw_values.values())
    for raw_id in swift_production:
        if raw_id not in known_swift_raw_values:
            errors.append(f"Swift production id {raw_id} is not a GameModeId raw value")

    if swift_runtime_production != cpp_runtime_production:
        errors.append(
            "nexusRuntimeProductionModeIds mismatch with C++ kProductionModeIds: "
            f"swift={swift_runtime_production}, cpp={cpp_runtime_production}"
        )

    if "basketball_dunk_irl" in swift_runtime_production:
        errors.append("IRL dunk camera mode must not be in C++ runtime production ids")
    if "market_browse" in swift_runtime_production:
        errors.append("market_browse must not be in C++ runtime production ids")
    if "basketball_dunk" not in swift_runtime_production:
        errors.append("3D dunk runtime alias basketball_dunk missing from C++ runtime production ids")

    stale_hits = stale_case_references()
    if stale_hits:
        errors.append("stale GameModeId case references found:\n  " + "\n  ".join(stale_hits))

    required_cases = {"basketballDunkContestIRL", "basketballDunkContest3D"}
    missing_cases = sorted(required_cases - set(swift_case_raw_values))
    if missing_cases:
        errors.append(f"missing split dunk Swift enum cases: {missing_cases}")

    print("iOS/NEXUS mode registry validation")
    print(f"  swift_production_entries={len(swift_production)}")
    print(f"  swift_runtime_production_ids={len(swift_runtime_production)}")
    print(f"  cpp_runtime_production_ids={len(cpp_runtime_production)}")

    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("All iOS/NEXUS mode registry assertions passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
