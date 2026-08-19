#!/usr/bin/env python3
"""Cross-check the NEXUS iOS app mode registry against runtime validators."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
SWIFT_ONLY_PRODUCTION_IDS = {"basketball_dunk_irl"}
ERRORS: list[str] = []
WARNINGS: list[str] = []


def err(message: str) -> None:
    ERRORS.append(message)


def warn(message: str) -> None:
    WARNINGS.append(message)


def read(path: Path) -> str:
    if not path.exists():
        err(f"Missing required file: {path.relative_to(REPO_ROOT)}")
        return ""
    return path.read_text()


def parse_swift_cases(content: str) -> dict[str, str]:
    return {
        case_name: raw_value
        for case_name, raw_value in re.findall(r"case\s+([A-Za-z0-9_]+)\s*=\s*\"([^\"]+)\"", content)
    }


def parse_swift_production_ids(content: str) -> list[str]:
    match = re.search(
        r"static\s+let\s+productionModeIds\s*:\s*\[String\]\s*=\s*\[(.*?)\]",
        content,
        re.DOTALL,
    )
    if not match:
        err("GameMode.swift: could not find GameModeRegistry.productionModeIds")
        return []
    return re.findall(r"\"([^\"]+)\"", match.group(1))


def parse_swift_runtime_aliases(content: str, cases: dict[str, str]) -> dict[str, str]:
    aliases: dict[str, str] = {}
    match = re.search(r"var\s+nexusRuntimeModeId\s*:\s*String\s*\{(.*?)\n\s*\}", content, re.DOTALL)
    if not match:
        err("GameMode.swift: could not find GameModeId.nexusRuntimeModeId")
        return aliases

    body = match.group(1)
    for case_name, runtime_literal in re.findall(
        r"case\s+\.([A-Za-z0-9_]+)\s*:\s*return\s+\"([^\"]+)\"",
        body,
    ):
        if case_name in cases:
            aliases[cases[case_name]] = runtime_literal

    for case_name, referenced_case in re.findall(
        r"case\s+\.([A-Za-z0-9_]+)\s*:\s*return\s+GameModeId\.([A-Za-z0-9_]+)\.rawValue",
        body,
    ):
        if case_name in cases and referenced_case in cases:
            aliases[cases[case_name]] = cases[referenced_case]

    return aliases


def parse_cpp_production_ids() -> list[str]:
    content = read(REPO_ROOT / "app/gameplay/include/nexus/gameplay/arena_mode_registry.h")
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(.*?)\};", content, re.DOTALL)
    if not match:
        err("arena_mode_registry.h: could not find kProductionModeIds[]")
        return []
    return re.findall(r"\"([^\"]+)\"", match.group(1))


def parse_shell_production_modes() -> list[str]:
    content = read(REPO_ROOT / "scripts/nexus_validate_production_modes.sh")
    match = re.search(r"PRODUCTION_MODES=\((.*?)\)", content, re.DOTALL)
    if not match:
        err("nexus_validate_production_modes.sh: could not find PRODUCTION_MODES")
        return []
    body = "\n".join(line.split("#", 1)[0] for line in match.group(1).splitlines())
    return re.findall(r"[A-Za-z0-9_]+", body)


def load_backend_registry() -> tuple[dict, dict[str, dict]]:
    path = REPO_ROOT / "backend/FEL_ModeManager.production.json"
    if not path.exists():
        err("Missing backend/FEL_ModeManager.production.json")
        return {}, {}
    payload = json.loads(path.read_text())
    mode_manager = payload.get("mode_manager", {})
    registry = mode_manager.get("mode_registry", {})
    if not isinstance(registry, dict):
        err("FEL_ModeManager.production.json: mode_registry must be an object")
        return mode_manager, {}
    return mode_manager, registry


def validate_counts(mode_manager: dict, backend_registry: dict[str, dict]) -> None:
    declared_total = mode_manager.get("total_modes")
    declared_production = mode_manager.get("production_modes")
    actual_total = len(backend_registry)
    actual_production = sum(1 for info in backend_registry.values() if info.get("status") == "production")

    if declared_total != actual_total:
        err(f"Backend total_modes mismatch: declared={declared_total}, actual={actual_total}")
    if declared_production != actual_production:
        err(
            "Backend production_modes mismatch: "
            f"declared={declared_production}, actual={actual_production}"
        )


def validate_unique(label: str, ids: list[str]) -> None:
    duplicates = sorted({mode_id for mode_id in ids if ids.count(mode_id) > 1})
    if duplicates:
        err(f"{label} contains duplicate ids: {', '.join(duplicates)}")


def main() -> int:
    swift_content = read(REPO_ROOT / "FinalEvolutionLab/Models/GameMode.swift")
    swift_cases = parse_swift_cases(swift_content)
    swift_production_ids = parse_swift_production_ids(swift_content)
    swift_aliases = parse_swift_runtime_aliases(swift_content, swift_cases)
    cpp_production_ids = parse_cpp_production_ids()
    shell_production_ids = parse_shell_production_modes()
    mode_manager, backend_registry = load_backend_registry()

    validate_unique("Swift productionModeIds", swift_production_ids)
    validate_unique("C++ kProductionModeIds", cpp_production_ids)
    validate_unique("Shell PRODUCTION_MODES", shell_production_ids)
    validate_counts(mode_manager, backend_registry)

    runtime_ids_from_swift = []
    for swift_id in swift_production_ids:
        if swift_id not in swift_cases.values():
            err(f"Swift production id has no GameModeId case: {swift_id}")
        if swift_id in SWIFT_ONLY_PRODUCTION_IDS:
            continue
        runtime_ids_from_swift.append(swift_aliases.get(swift_id, swift_id))

    if set(runtime_ids_from_swift) != set(cpp_production_ids):
        missing = sorted(set(cpp_production_ids) - set(runtime_ids_from_swift))
        extra = sorted(set(runtime_ids_from_swift) - set(cpp_production_ids))
        if missing:
            err(f"Swift production runtime aliases missing C++ ids: {', '.join(missing)}")
        if extra:
            err(f"Swift production runtime aliases include non-production C++ ids: {', '.join(extra)}")

    if shell_production_ids != cpp_production_ids:
        missing = sorted(set(cpp_production_ids) - set(shell_production_ids))
        extra = sorted(set(shell_production_ids) - set(cpp_production_ids))
        if missing or extra:
            err(
                "Shell PRODUCTION_MODES must match C++ kProductionModeIds exactly "
                f"(missing={missing}, extra={extra})"
            )
        else:
            err("Shell PRODUCTION_MODES order differs from C++ kProductionModeIds")

    for runtime_id in cpp_production_ids:
        status = backend_registry.get(runtime_id, {}).get("status")
        if status != "production":
            err(f"Backend registry status for runtime production mode {runtime_id!r} is {status!r}")

    for swift_id in swift_production_ids:
        status = backend_registry.get(swift_id, {}).get("status")
        if status != "production":
            warn(f"Swift production app id {swift_id!r} has backend status {status!r}")

    print("NEXUS iOS mode registry validation")
    print(f"  Swift production app ids: {len(swift_production_ids)}")
    print(f"  Swift runtime production ids: {len(set(runtime_ids_from_swift))}")
    print(f"  C++ production runtime ids: {len(cpp_production_ids)}")
    print(f"  Shell production modes: {len(shell_production_ids)}")
    print(f"  Backend registry modes: {len(backend_registry)}")

    if WARNINGS:
        print("\nWarnings:")
        for warning in WARNINGS:
            print(f"  - {warning}")

    if ERRORS:
        print("\nErrors:")
        for error in ERRORS:
            print(f"  - {error}")
        return 1

    print("\nPASS: NEXUS iOS/C++/backend mode registries are aligned")
    return 0


if __name__ == "__main__":
    sys.exit(main())
