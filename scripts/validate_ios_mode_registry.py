#!/usr/bin/env python3
"""Validate Swift game mode registry parity with NEXUS C++ production modes."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GAME_MODE_SWIFT = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
CONTENT_VIEW_SWIFT = REPO_ROOT / "FinalEvolutionLab" / "ContentView.swift"
GAME_MODE_ROUTER_SWIFT = REPO_ROOT / "FinalEvolutionLab" / "Views" / "GameModeRouter.swift"
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
    stale_case_pattern = re.compile(r"\.(basketballDunkContest|basketballIRL)\b")
    hits: list[str] = []
    for root in SWIFT_ROOTS:
        for path in root.rglob("*.swift"):
            text = path.read_text(errors="replace")
            for line_no, line in enumerate(text.splitlines(), start=1):
                if stale_case_pattern.search(line):
                    hits.append(f"{path.relative_to(REPO_ROOT)}:{line_no}: {line.strip()}")
    return hits


def playable_mode_aliases(source: str) -> set[str]:
    match = re.search(
        r"static\s+func\s+playableMode\(forRegistryId\s+raw:\s*String\).*?\{(.*?)\n    \}",
        source,
        flags=re.DOTALL,
    )
    if not match:
        raise ValueError("missing GameModeRegistry.playableMode(forRegistryId:)")
    return set(re.findall(r'"([^"]+)"', match.group(1)))


def main() -> int:
    errors: list[str] = []
    swift_source = GAME_MODE_SWIFT.read_text()
    content_view_source = CONTENT_VIEW_SWIFT.read_text()
    router_source = GAME_MODE_ROUTER_SWIFT.read_text()
    cpp_source = CPP_REGISTRY.read_text()

    try:
        swift_case_raw_values = game_mode_cases(swift_source)
        swift_production = string_array(swift_source, "productionModeIds")
        swift_runtime_production = string_array(swift_source, "nexusRuntimeProductionModeIds")
        cpp_runtime_production = cpp_production_ids(cpp_source)
        swift_aliases = playable_mode_aliases(swift_source)
    except ValueError as exc:
        errors.append(str(exc))
        swift_case_raw_values = {}
        swift_production = []
        swift_runtime_production = []
        cpp_runtime_production = []
        swift_aliases = set()

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

    required_playable_aliases = {"basketball_dunk", "venice_pickup", "market_browse"}
    missing_aliases = sorted(required_playable_aliases - swift_aliases)
    if missing_aliases:
        errors.append(f"playableMode(forRegistryId:) missing registry aliases: {missing_aliases}")

    if "GameModeRegistry.playableMode(forRegistryId: modeId)" not in content_view_source:
        errors.append("ContentView agent launch must resolve registry aliases via playableMode(forRegistryId:)")

    if "case .basketballHeadToHead, .venicePickup:" not in router_source:
        errors.append("GameModeRouter must route .venicePickup with .basketballHeadToHead")

    brain_brawl_tier = re.search(
        r"case\s+\.brainBrawl:\s*\n\s*return\s+\.(\w+)",
        swift_source,
    )
    if not brain_brawl_tier or brain_brawl_tier.group(1) != "prod":
        errors.append("brain_brawl must be Swift .prod tier to match backend/C++ production status")

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
