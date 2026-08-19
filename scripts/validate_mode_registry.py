#!/usr/bin/env python3
"""Validate NEXUS mode registry alignment across backend, launch maps, and Swift."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
ERRORS: list[str] = []

NON_LAUNCHABLE_STATUSES = {"preview", "non-game-module"}
SWIFT_MODE_ALIASES = {
    # Backend/NEXUS runtime id; iOS exposes split 3D/IRL choices.
    "basketball_dunk": "basketball_dunk_3d",
}


def err(message: str) -> None:
    ERRORS.append(message)


def load_json_checked(path: Path, label: str) -> Any:
    def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        out: dict[str, Any] = {}
        for key, value in pairs:
            if key in out:
                err(f"{label} has duplicate key: {key}")
            out[key] = value
        return out

    try:
        return json.loads(path.read_text(), object_pairs_hook=reject_duplicates)
    except FileNotFoundError:
        err(f"{label} missing: {path.relative_to(REPO_ROOT)}")
    except json.JSONDecodeError as exc:
        err(f"{label} invalid JSON: {exc}")
    return {}


def validate_mode_counts(mode_manager: dict[str, Any]) -> dict[str, dict[str, Any]]:
    manager = mode_manager.get("mode_manager", {})
    registry = manager.get("mode_registry", {})
    if not isinstance(registry, dict):
        err("mode_manager.mode_registry must be an object")
        return {}

    declared_total = manager.get("total_modes")
    actual_total = len(registry)
    if declared_total != actual_total:
        err(f"total_modes mismatch: declared={declared_total}, actual={actual_total}")

    declared_production = manager.get("production_modes")
    actual_production = sum(1 for entry in registry.values() if entry.get("status") == "production")
    if declared_production != actual_production:
        err(f"production_modes mismatch: declared={declared_production}, actual={actual_production}")

    for mode_id, entry in registry.items():
        status = entry.get("status")
        if status not in {"production", "staging", "preview", "non-game-module"}:
            err(f"{mode_id} has unknown status: {status}")
    return registry


def validate_launch_maps(registry: dict[str, dict[str, Any]], ue_maps: dict[str, Any]) -> None:
    for mode_id, entry in registry.items():
        status = entry.get("status")
        render_mode = entry.get("render_mode")
        if status in NON_LAUNCHABLE_STATUSES or render_mode == "IRL":
            continue
        if mode_id not in ue_maps:
            err(f"{mode_id} missing from backend/ue_mode_maps.json")
        elif ue_maps[mode_id] is None:
            err(f"{mode_id} has null UE map but is production launchable")


def validate_swift_catalog(registry: dict[str, dict[str, Any]]) -> None:
    swift_path = REPO_ROOT / "FinalEvolutionLab" / "Models" / "GameMode.swift"
    try:
        swift = swift_path.read_text()
    except FileNotFoundError:
        err("FinalEvolutionLab/Models/GameMode.swift missing")
        return

    for mode_id, entry in registry.items():
        status = entry.get("status")
        if status == "preview":
            continue
        raw_value = SWIFT_MODE_ALIASES.get(mode_id, mode_id)
        if f'= "{raw_value}"' not in swift:
            err(f"{mode_id} missing Swift GameModeId rawValue (expected {raw_value})")


def main() -> int:
    mode_manager = load_json_checked(REPO_ROOT / "backend" / "FEL_ModeManager.production.json", "ModeManager")
    ue_maps_doc = load_json_checked(REPO_ROOT / "backend" / "ue_mode_maps.json", "UE mode maps")
    load_json_checked(
        REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Content" / "FEL" / "Config" / "ArenaSettings.json",
        "ArenaSettings",
    )
    load_json_checked(
        REPO_ROOT / "UnrealStarter" / "BasketballGame" / "Config" / "FEL_VenueRegistry.production.json",
        "VenueRegistry",
    )

    registry = validate_mode_counts(mode_manager)
    ue_maps = ue_maps_doc.get("mode_to_unreal_map", {}) if isinstance(ue_maps_doc, dict) else {}
    validate_launch_maps(registry, ue_maps)
    validate_swift_catalog(registry)

    if ERRORS:
        print("❌ NEXUS mode registry validation failed")
        for message in ERRORS:
            print(f"   ✗ {message}")
        return 1

    print(f"✅ NEXUS mode registry validation passed ({len(registry)} entries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
