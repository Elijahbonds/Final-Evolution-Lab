#!/usr/bin/env python3
"""Validate Swift arena launch ids against the NEXUS C++ production registry."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CXX_REGISTRY = ROOT / "app/gameplay/include/nexus/gameplay/arena_mode_registry.h"
PRODUCTION_SCRIPT = ROOT / "scripts/nexus_validate_production_modes.sh"
SWIFT_MODES = ROOT / "FinalEvolutionLab/Models/GameMode.swift"

IOS_RUNTIME_ALIASES = {
    "basketball_dunk_3d": "basketball_dunk",
}

# Real-world camera capture mode shares the product's dunk surface, but it is not
# a C++ runtime/mesh validate-only mode.
IOS_ONLY_PRODUCTION_MODES = {
    "basketball_dunk_irl",
}


def _read(path: Path) -> str:
    try:
        return path.read_text()
    except OSError as exc:
        raise AssertionError(f"failed to read {path.relative_to(ROOT)}: {exc}") from exc


def _extract_quoted_block(text: str, label: str) -> list[str]:
    match = re.search(rf"{re.escape(label)}[^\n]*=\s*(?:\{{\{{?|\[)(.*?)(?:\}}\}}?|\])", text, re.S)
    if not match:
        raise AssertionError(f"could not find block for {label}")
    return re.findall(r'"([^"]+)"', match.group(1))


def _extract_shell_array(text: str, label: str) -> list[str]:
    match = re.search(rf"{re.escape(label)}=\((.*?)\)", text, re.S)
    if not match:
        raise AssertionError(f"could not find shell array {label}")
    tokens: list[str] = []
    for raw in re.split(r"\s+", match.group(1).strip()):
        token = raw.strip().strip('"').strip("'")
        if token:
            tokens.append(token)
    return tokens


def _extract_swift_enum_raw_values(text: str) -> set[str]:
    match = re.search(r"enum\s+GameModeId:[^{]+\{(.*?)\n\}", text, re.S)
    if not match:
        raise AssertionError("could not find GameModeId enum")
    return set(re.findall(r'case\s+\w+\s*=\s*"([^"]+)"', match.group(1)))


def _normalize_ios_runtime_modes(mode_ids: list[str]) -> set[str]:
    normalized = set()
    for mode_id in mode_ids:
        if mode_id in IOS_ONLY_PRODUCTION_MODES:
            continue
        normalized.add(IOS_RUNTIME_ALIASES.get(mode_id, mode_id))
    return normalized


def _assert_equal(label: str, actual: set[str], expected: set[str]) -> None:
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing or extra:
        details = []
        if missing:
            details.append(f"missing={missing}")
        if extra:
            details.append(f"extra={extra}")
        raise AssertionError(f"{label} mismatch: {', '.join(details)}")


def main() -> int:
    cxx_production = set(_extract_quoted_block(_read(CXX_REGISTRY), "kProductionModeIds"))
    script_production = set(_extract_shell_array(_read(PRODUCTION_SCRIPT), "PRODUCTION_MODES"))
    swift_text = _read(SWIFT_MODES)
    swift_production = _extract_quoted_block(swift_text, "productionModeIds")
    swift_enum_values = _extract_swift_enum_raw_values(swift_text)

    unknown_swift_ids = sorted(set(swift_production) - swift_enum_values)
    if unknown_swift_ids:
        raise AssertionError(f"Swift productionModeIds not declared in GameModeId: {unknown_swift_ids}")

    _assert_equal("validate script vs C++ production ids", script_production, cxx_production)
    _assert_equal(
        "Swift normalized production runtime ids",
        _normalize_ios_runtime_modes(swift_production),
        cxx_production,
    )

    print(
        "PASS: Swift production ids normalize to "
        f"{len(cxx_production)} C++ NEXUS runtime production modes "
        f"({len(IOS_ONLY_PRODUCTION_MODES)} iOS-only production mode excluded)"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        raise SystemExit(1)
