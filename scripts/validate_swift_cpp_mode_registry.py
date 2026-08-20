#!/usr/bin/env python3
"""Validate Swift, C++ and backend NEXUS mode registry alignment.

The production iOS shell exposes split dunk cartridges:
  - basketball_dunk_3d -> C++ runtime basketball_dunk
  - basketball_dunk_irl -> camera-native IRL mode, no C++ mesh runtime
This script keeps that aliasing explicit so completion gates do not compare
raw counts without checking semantics.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SWIFT_PATH = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
CPP_HEADER_PATH = REPO_ROOT / "app" / "gameplay" / "include" / "nexus" / "gameplay" / "arena_mode_registry.h"
CPP_SOURCE_PATH = REPO_ROOT / "app" / "gameplay" / "src" / "arena_mode_registry.cpp"
MODE_MANAGER_PATH = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
NEXUS_STARTER_VENUE_PATH = (
    REPO_ROOT / "NexusStarter" / "BasketballGame" / "Config" / "VenueRegistry.nexus.json"
)

SWIFT_RUNTIME_ALIASES = {
    "basketball_dunk_3d": "basketball_dunk",
    "venice_pickup": "basketball_h2h",
}
SWIFT_NATIVE_ONLY_MODES = {"basketball_dunk_irl"}
BACKEND_ONLY_PREVIEW_MODULES = {"movement_lab"}
LEGACY_STALE_MODE_RE = re.compile(r"(?<![A-Za-z0-9_])basketball_irl(?![A-Za-z0-9_])")


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)


def extract_block(source: str, start_pattern: str) -> str:
    match = re.search(start_pattern, source, re.DOTALL)
    if not match:
        raise ValueError(f"could not find block matching {start_pattern!r}")
    return match.group("body")


def parse_swift_enum_cases(source: str) -> dict[str, str]:
    enum_body = extract_block(
        source,
        r"enum\s+GameModeId\b[^{]*\{(?P<body>.*?)\n\}",
    )
    return dict(re.findall(r"case\s+([A-Za-z0-9_]+)\s*=\s*\"([^\"]+)\"", enum_body))


def parse_swift_string_array(source: str, name: str) -> list[str]:
    body = extract_block(
        source,
        rf"static\s+let\s+{re.escape(name)}\s*:\s*\[[^\]]+\]\s*=\s*\[(?P<body>.*?)\]",
    )
    return re.findall(r"\"([^\"]+)\"", body)


def parse_swift_case_array(source: str, name: str, enum_cases: dict[str, str]) -> list[str]:
    body = extract_block(
        source,
        rf"static\s+let\s+{re.escape(name)}\s*:\s*\[[^\]]+\]\s*=\s*\[(?P<body>.*?)\]",
    )
    missing_cases: list[str] = []
    raw_values: list[str] = []
    for case_name in re.findall(r"\.([A-Za-z0-9_]+)", body):
        raw_value = enum_cases.get(case_name)
        if raw_value is None:
            missing_cases.append(case_name)
        else:
            raw_values.append(raw_value)
    if missing_cases:
        raise ValueError(f"{name} references unknown Swift enum cases: {sorted(missing_cases)}")
    return raw_values


def parse_cpp_production_modes(header_source: str) -> set[str]:
    body = extract_block(
        header_source,
        r"kProductionModeIds\[\]\s*=\s*\{(?P<body>.*?)\};",
    )
    return set(re.findall(r"\"([^\"]+)\"", body))


def parse_cpp_all_modes(cpp_source: str) -> set[str]:
    return set(re.findall(r"\.id\s*=\s*\"([^\"]+)\"", cpp_source))


def normalize_swift_runtime_modes(mode_ids: list[str] | set[str]) -> set[str]:
    normalized: set[str] = set()
    for mode_id in mode_ids:
        if mode_id in SWIFT_NATIVE_ONLY_MODES:
            continue
        normalized.add(SWIFT_RUNTIME_ALIASES.get(mode_id, mode_id))
    return normalized


def find_legacy_mode_literals() -> list[str]:
    offenders: list[str] = []
    roots = [REPO_ROOT / "FinalEvolutionLab", REPO_ROOT / "backend", REPO_ROOT / "NexusStarter"]
    suffixes = {".swift", ".py", ".json"}
    for root in roots:
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix not in suffixes:
                continue
            text = path.read_text(errors="replace")
            if LEGACY_STALE_MODE_RE.search(text):
                offenders.append(str(path.relative_to(REPO_ROOT)))
    return offenders


def main() -> int:
    failures: list[str] = []

    swift_source = SWIFT_PATH.read_text()
    cpp_header = CPP_HEADER_PATH.read_text()
    cpp_source = CPP_SOURCE_PATH.read_text()
    mode_manager = json.loads(MODE_MANAGER_PATH.read_text())["mode_manager"]["mode_registry"]
    nexus_venue_modes = {
        entry["modeId"]
        for entry in json.loads(NEXUS_STARTER_VENUE_PATH.read_text())["venues"]
    }

    try:
        enum_cases = parse_swift_enum_cases(swift_source)
        swift_production = parse_swift_string_array(swift_source, "productionModeIds")
        swift_arena = parse_swift_case_array(swift_source, "arenaRegistryModeIds", enum_cases)
    except ValueError as exc:
        failures.append(str(exc))
        enum_cases = {}
        swift_production = []
        swift_arena = []

    cpp_production = parse_cpp_production_modes(cpp_header)
    cpp_all = parse_cpp_all_modes(cpp_source)

    normalized_swift_production = normalize_swift_runtime_modes(swift_production)
    if normalized_swift_production != cpp_production:
        failures.append(
            "Swift production modes do not normalize to C++ production modes: "
            f"missing={sorted(cpp_production - normalized_swift_production)} "
            f"extra={sorted(normalized_swift_production - cpp_production)}"
        )

    normalized_swift_arena = normalize_swift_runtime_modes(swift_arena)
    if normalized_swift_arena != cpp_all:
        failures.append(
            "Swift arena modes do not normalize to C++ arena registry: "
            f"missing={sorted(cpp_all - normalized_swift_arena)} "
            f"extra={sorted(normalized_swift_arena - cpp_all)}"
        )

    expected_nexus_venue_modes = cpp_all | SWIFT_NATIVE_ONLY_MODES
    if nexus_venue_modes != expected_nexus_venue_modes:
        failures.append(
            "NexusStarter venue registry does not match C++ arena modes plus native IRL: "
            f"missing={sorted(expected_nexus_venue_modes - nexus_venue_modes)} "
            f"extra={sorted(nexus_venue_modes - expected_nexus_venue_modes)}"
        )

    irl_info = mode_manager.get("basketball_dunk_irl")
    if not irl_info:
        failures.append("backend ModeManager missing basketball_dunk_irl")
    elif irl_info.get("status") != "production" or irl_info.get("render_mode") != "IRL":
        failures.append(
            "basketball_dunk_irl must remain production render_mode=IRL in backend ModeManager"
        )

    dunk_3d_info = mode_manager.get("basketball_dunk_3d")
    if not dunk_3d_info:
        failures.append("backend ModeManager missing basketball_dunk_3d")
    elif dunk_3d_info.get("status") != "production":
        failures.append("basketball_dunk_3d must remain production in backend ModeManager")

    backend_preview = {
        mode_id
        for mode_id, info in mode_manager.items()
        if info.get("status") == "preview"
    }
    swift_raw_values = set(enum_cases.values())
    undocumented_preview = backend_preview - swift_raw_values - BACKEND_ONLY_PREVIEW_MODULES
    if undocumented_preview:
        failures.append(
            "backend preview modes need Swift enum cases or explicit backend-only allow-list entries: "
            f"{sorted(undocumented_preview)}"
        )

    legacy_offenders = find_legacy_mode_literals()
    if legacy_offenders:
        failures.append(
            "legacy basketball_irl literals remain in runtime sources: "
            + ", ".join(legacy_offenders)
        )

    for failure in failures:
        fail(failure)

    if failures:
        return 1

    print(
        "PASS: Swift production/arena modes align with C++ NEXUS registry "
        f"({len(cpp_production)} production runtime modes, {len(cpp_all)} arena modes; "
        "basketball_dunk_irl is native IRL)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
