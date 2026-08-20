#!/usr/bin/env python3
"""Validate iOS mode registry ingest against the backend NEXUS payload."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
BACKEND_REGISTRY = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
CPP_REGISTRY_H = REPO_ROOT / "app" / "gameplay" / "include" / "nexus" / "gameplay" / "arena_mode_registry.h"
SWIFT_GAME_MODE = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"

ERRORS: list[str] = []


def ok(message: str) -> None:
    print(f"  PASS: {message}")


def err(message: str) -> None:
    ERRORS.append(message)
    print(f"  FAIL: {message}")


def extract_string_array(source: str, symbol: str) -> list[str]:
    match = re.search(rf"{re.escape(symbol)}\[\]\s*=\s*\{{(?P<body>.*?)\}};", source, re.DOTALL)
    if not match:
        err(f"Could not find {symbol} in {CPP_REGISTRY_H}")
        return []
    return re.findall(r'"([^"]+)"', match.group("body"))


def extract_swift_cases(source: str) -> dict[str, str]:
    match = re.search(r"enum\s+GameModeId:.*?\{(?P<body>.*?)\n\}", source, re.DOTALL)
    if not match:
        err("Could not find GameModeId enum in GameMode.swift")
        return {}
    return {
        swift_case: raw_value
        for swift_case, raw_value in re.findall(r"case\s+(\w+)\s*=\s*\"([^\"]+)\"", match.group("body"))
    }


def extract_playable_aliases(source: str) -> dict[str, str]:
    match = re.search(
        r"static\s+func\s+playableMode\(forRegistryId raw: String\).*?\{(?P<body>.*?)\n\s*\}",
        source,
        re.DOTALL,
    )
    if not match:
        err("Could not find GameModeRegistry.playableMode(forRegistryId:)")
        return {}
    body = match.group("body")
    aliases: dict[str, str] = {}
    for raw_ids, swift_case in re.findall(
        r"case\s+([^:]+):\s*\n\s*return mode\(for: \.([A-Za-z0-9_]+)\)",
        body,
    ):
        for raw_id in re.findall(r'"([^"]+)"', raw_ids):
            aliases[raw_id] = swift_case
    return aliases


def validate_loader_source(source: str) -> None:
    required_snippets = [
        "playableMode(forRegistryId: rawId)",
        "loadedById: [GameModeId: GameMode]",
        "if rawId == modeId.rawValue || loadedById[modeId] == nil",
        "return all.compactMap { loadedById[$0.id] }",
    ]
    for snippet in required_snippets:
        if snippet in source:
            ok(f"payload loader guard present: {snippet}")
        else:
            err(f"payload loader guard missing: {snippet}")


def resolve_backend_id(raw_id: str, swift_cases: dict[str, str], aliases: dict[str, str]) -> str | None:
    alias_case = aliases.get(raw_id)
    if alias_case:
        return swift_cases.get(alias_case)
    if raw_id in swift_cases.values():
        return raw_id
    return None


def validate_payload_resolution(source: str) -> None:
    payload = json.loads(BACKEND_REGISTRY.read_text())
    registry = payload.get("mode_manager", {}).get("mode_registry", {})
    if not isinstance(registry, dict):
        err("backend mode_registry is missing or malformed")
        return

    swift_cases = extract_swift_cases(source)
    aliases = extract_playable_aliases(source)
    cpp_production = extract_string_array(CPP_REGISTRY_H.read_text(), "kProductionModeIds")

    resolved_raw: list[str] = []
    loaded_by_id: dict[str, str] = {}
    unresolved: list[str] = []
    for raw_id in registry:
        swift_raw = resolve_backend_id(raw_id, swift_cases, aliases)
        if swift_raw is None:
            unresolved.append(raw_id)
        else:
            resolved_raw.append(swift_raw)
            if raw_id == swift_raw or swift_raw not in loaded_by_id:
                loaded_by_id[swift_raw] = raw_id

    if not unresolved:
        ok("every backend mode-manager entry resolves to a Swift GameModeId or alias")
    else:
        err(f"backend entries do not resolve in Swift: {', '.join(sorted(unresolved))}")

    collapsed_aliases = sorted({mode_id for mode_id in resolved_raw if resolved_raw.count(mode_id) > 1})
    if collapsed_aliases == ["basketball_dunk_3d"]:
        ok("canonical basketball_dunk and iOS basketball_dunk_3d collapse to one Swift mode")
    elif not collapsed_aliases:
        err("backend payload should include the canonical/alias dunk pair for runtime compatibility")
    else:
        err(f"unexpected backend alias collisions: {', '.join(collapsed_aliases)}")

    if len(loaded_by_id) == len(set(loaded_by_id)):
        ok("loader de-duplicates backend aliases by Swift mode ID")
    else:
        err("loader de-duplication map is malformed")

    expected_runtime_swift_ids = {"basketball_dunk_3d" if mode == "basketball_dunk" else mode for mode in cpp_production}
    missing_runtime = sorted(expected_runtime_swift_ids.difference(loaded_by_id))
    if not missing_runtime:
        ok("backend payload covers every C++ production runtime mode in Swift")
    else:
        err(f"backend payload missing Swift runtime modes: {', '.join(missing_runtime)}")

    if aliases.get("basketball_dunk") == "basketballDunkContest3D":
        ok("canonical basketball_dunk backend id aliases to Swift basketball_dunk_3d")
    else:
        err("canonical basketball_dunk backend id must alias to Swift basketball_dunk_3d")

    for raw_id in ("basketball_dunk_irl", "market_browse", "movement_lab"):
        if raw_id in loaded_by_id:
            ok(f"{raw_id} remains visible through payload ingest")
        else:
            err(f"{raw_id} missing after payload ingest")


def main() -> int:
    print("== iOS mode registry payload validation ==")
    source = SWIFT_GAME_MODE.read_text()
    validate_loader_source(source)
    validate_payload_resolution(source)

    print()
    if ERRORS:
        print(f"{len(ERRORS)} error(s)")
        return 1
    print("PASS: iOS mode registry payload validation")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
