#!/usr/bin/env python3
"""Validate production app/game mode IDs across NEXUS registries.

The product surface intentionally has a split iOS/backend dunk model
(`basketball_dunk_3d` + `basketball_dunk_irl`) while the C++ runtime still uses
the single `basketball_dunk` simulator ID.  This check makes that alias explicit
so C++, Swift, backend JSON, and validate-only shell gates cannot drift silently.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "backend"))

from registry_utils import load_json, load_ue_mode_maps, normalized_modes  # noqa: E402


def _quoted_strings(text: str) -> list[str]:
    return re.findall(r'"([^"]+)"', text)


def _extract_block(path: Path, pattern: str, label: str) -> str:
    text = path.read_text()
    match = re.search(pattern, text, flags=re.DOTALL)
    if not match:
        raise ValueError(f"{label}: could not find registry block in {path}")
    return match.group("body")


def _cpp_production_ids() -> list[str]:
    block = _extract_block(
        REPO_ROOT / "app/gameplay/include/nexus/gameplay/arena_mode_registry.h",
        r"kProductionModeIds\[\]\s*=\s*\{(?P<body>.*?)\};",
        "C++ kProductionModeIds",
    )
    return _quoted_strings(block)


def _swift_production_ids() -> list[str]:
    block = _extract_block(
        REPO_ROOT / "FinalEvolutionLab/Models/GameMode.swift",
        r"static\s+let\s+productionModeIds:\s*\[String\]\s*=\s*\[(?P<body>.*?)\]",
        "Swift productionModeIds",
    )
    return _quoted_strings(block)


def _shell_production_ids() -> list[str]:
    block = _extract_block(
        REPO_ROOT / "scripts/nexus_validate_production_modes.sh",
        r"PRODUCTION_MODES=\((?P<body>.*?)\)",
        "shell PRODUCTION_MODES",
    )
    tokens: list[str] = []
    for line in block.splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        tokens.extend(part.strip('"\'') for part in line.split() if part.strip('"\''))
    return tokens


def _backend_modes() -> list[dict]:
    backend_dir = REPO_ROOT / "backend"
    mode_manager = load_json(backend_dir / "FEL_ModeManager.production.json")
    venue_registry = load_json(backend_dir / "FEL_VenueRegistry.production.json")
    ue_mode_maps = load_ue_mode_maps(backend_dir)
    return normalized_modes(mode_manager, venue_registry, ue_mode_maps)


def _ordered_unique(values: list[str]) -> list[str]:
    seen: set[str] = set()
    unique: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            unique.append(value)
    return unique


def _duplicates(values: list[str]) -> list[str]:
    seen: set[str] = set()
    duplicates: list[str] = []
    for value in values:
        if value in seen and value not in duplicates:
            duplicates.append(value)
        seen.add(value)
    return duplicates


def _compare_sets(label: str, actual: list[str], expected: list[str], errors: list[str]) -> None:
    actual_set = set(actual)
    expected_set = set(expected)
    missing = sorted(expected_set - actual_set)
    extra = sorted(actual_set - expected_set)
    if missing:
        errors.append(f"{label}: missing {missing}")
    if extra:
        errors.append(f"{label}: unexpected {extra}")


def main() -> int:
    errors: list[str] = []

    cpp_runtime_ids = _cpp_production_ids()
    shell_runtime_ids = _shell_production_ids()
    swift_product_ids = _swift_production_ids()

    production_modes = [mode for mode in _backend_modes() if mode.get("status") == "production"]
    backend_product_ids = [str(mode["mode_id"]) for mode in production_modes]
    backend_product_set = set(backend_product_ids)

    runtime_alias_ids = {
        str(mode["nexus_runtime_mode_id"])
        for mode in production_modes
        if mode.get("nexus_runtime_mode_id") != mode.get("mode_id")
        and mode.get("nexus_runtime_mode_id") in backend_product_set
    }
    backend_swift_ids = [mode_id for mode_id in backend_product_ids if mode_id not in runtime_alias_ids]

    backend_runtime_ids = _ordered_unique(
        [
            str(mode["nexus_runtime_mode_id"])
            for mode in production_modes
            if mode.get("render_mode") != "IRL"
        ]
    )
    irl_product_ids = [str(mode["mode_id"]) for mode in production_modes if mode.get("render_mode") == "IRL"]

    for label, values in (
        ("C++ runtime production IDs", cpp_runtime_ids),
        ("shell validate production IDs", shell_runtime_ids),
        ("Swift production IDs", swift_product_ids),
        ("backend production IDs", backend_product_ids),
    ):
        duplicates = _duplicates(values)
        if duplicates:
            errors.append(f"{label}: duplicate entries {duplicates}")

    _compare_sets("shell validate production IDs vs C++ runtime IDs", shell_runtime_ids, cpp_runtime_ids, errors)
    _compare_sets("backend runtime IDs vs C++ runtime IDs", backend_runtime_ids, cpp_runtime_ids, errors)
    _compare_sets("Swift product IDs vs backend product IDs minus runtime aliases", swift_product_ids, backend_swift_ids, errors)

    if set(irl_product_ids) & set(cpp_runtime_ids):
        errors.append(f"IRL product IDs must not appear in C++ runtime production IDs: {irl_product_ids}")
    if not runtime_alias_ids:
        errors.append("expected at least one explicit backend runtime alias for split app/game modes")

    print("NEXUS arena registry sync validation")
    print(f"  cpp_runtime_modes={len(cpp_runtime_ids)}")
    print(f"  shell_validate_modes={len(shell_runtime_ids)}")
    print(f"  backend_product_modes={len(backend_product_ids)}")
    print(f"  backend_runtime_modes={len(backend_runtime_ids)}")
    print(f"  swift_product_modes={len(swift_product_ids)}")
    print(f"  runtime_aliases={', '.join(sorted(runtime_alias_ids)) or '-'}")
    print(f"  irl_product_modes={', '.join(irl_product_ids) or '-'}")

    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("All app/game production registries are synchronized")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
