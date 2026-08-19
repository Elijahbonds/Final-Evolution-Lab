#!/usr/bin/env python3
"""Validate backend mode, UE-map, and venue registry alignment."""

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

EXPECTED_PRODUCTION_MODES = {
    "basketball_h2h",
    "basketball_dunk",
    "basketball_dunk_3d",
    "basketball_dunk_irl",
    "basketball_3v3",
    "court_carnival",
    "karate_h2h",
    "karate_endless",
    "baseball",
    "football",
    "soccer",
    "golf",
    "tennis",
    "volleyball",
    "gymnastics",
    "surfing",
    "skateboarding",
    "snowboarding",
    "brain_brawl",
    "who_scene_it",
}
EXPECTED_NON_GAME = {"market_browse"}
EXPECTED_PREVIEW = {"movement_lab"}
IRL_MODES = {"basketball_dunk_irl"}


def load_json(relative_path):
    return json.loads((REPO_ROOT / relative_path).read_text())


def main():
    errors = []
    mode_manager = load_json("backend/FEL_ModeManager.production.json")["mode_manager"]
    registry = mode_manager["mode_registry"]
    ue_maps = load_json("backend/ue_mode_maps.json")["mode_to_unreal_map"]
    venue_registry = load_json("backend/FEL_VenueRegistry.production.json")
    venue_keys = {venue["venueKey"] for venue in venue_registry["venues"]}

    actual_total = len(registry)
    declared_total = mode_manager.get("total_modes")
    if declared_total != actual_total:
        errors.append(f"total_modes declared={declared_total} actual={actual_total}")

    actual_production = {mode for mode, entry in registry.items() if entry.get("status") == "production"}
    declared_production = mode_manager.get("production_modes")
    if declared_production != len(actual_production):
        errors.append(f"production_modes declared={declared_production} actual={len(actual_production)}")

    if actual_production != EXPECTED_PRODUCTION_MODES:
        missing = sorted(EXPECTED_PRODUCTION_MODES - actual_production)
        extra = sorted(actual_production - EXPECTED_PRODUCTION_MODES)
        errors.append(f"production mode set mismatch missing={missing} extra={extra}")

    for mode in EXPECTED_NON_GAME:
        if registry.get(mode, {}).get("status") != "non-game-module":
            errors.append(f"{mode} must be status=non-game-module")

    for mode in EXPECTED_PREVIEW:
        if registry.get(mode, {}).get("status") != "preview":
            errors.append(f"{mode} must be status=preview")

    for mode, entry in registry.items():
        if mode not in ue_maps and mode not in EXPECTED_PREVIEW:
            errors.append(f"{mode} missing from ue_mode_maps.json")
        if mode in IRL_MODES and ue_maps.get(mode) is not None:
            errors.append(f"{mode} must have null UE map")
        venue_id = entry.get("venue_id")
        if entry.get("status") == "production" and mode not in IRL_MODES and not venue_id:
            errors.append(f"{mode} production entry missing venue_id")

    mode_venue_keys = {
        mode["venueKey"]
        for mode in venue_registry["modes"]
        if mode.get("venueKey")
    }
    for venue_key in sorted(mode_venue_keys - venue_keys):
        errors.append(f"venue registry mode references unknown venueKey={venue_key}")

    if errors:
        print("FEL mode registry validation failed:")
        for error in errors:
            print(f"  - {error}")
        return 1

    print(
        "FEL mode registry validation passed "
        f"({actual_total} entries, {len(actual_production)} production)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
