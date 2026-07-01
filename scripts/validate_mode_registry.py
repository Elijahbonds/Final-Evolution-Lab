#!/usr/bin/env python3
"""Validate FEL mode, venue, and launch-map registry consistency."""
from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "backend"))

from registry_utils import (  # noqa: E402
    launchable_mode_maps,
    load_json,
    load_ue_mode_maps,
    normalized_modes,
    production_count,
)


def main() -> int:
    errors: list[str] = []
    backend_dir = REPO_ROOT / "backend"
    mode_manager = load_json(backend_dir / "FEL_ModeManager.production.json")
    venue_registry = load_json(backend_dir / "FEL_VenueRegistry.production.json")
    ue_mode_maps = load_ue_mode_maps(backend_dir)

    modes = normalized_modes(mode_manager, venue_registry, ue_mode_maps)
    manager = mode_manager.get("mode_manager", {})
    declared_total = manager.get("total_modes")
    declared_production = manager.get("production_modes")
    actual_total = len(modes)
    actual_production = production_count(modes)

    if declared_total != actual_total:
        errors.append(f"total_modes mismatch: declared={declared_total}, actual={actual_total}")
    if declared_production != actual_production:
        errors.append(
            f"production_modes mismatch: declared={declared_production}, actual={actual_production}"
        )

    by_id = {mode["mode_id"]: mode for mode in modes}
    required_modes = {
        "basketball_h2h": {"status": "production", "render_mode": "3D_UE5"},
        "basketball_dunk_3d": {"status": "production", "render_mode": "3D_UE5"},
        "basketball_dunk_irl": {"status": "production", "render_mode": "IRL"},
        "karate_endless": {"status": "production", "render_mode": "3D_UE5"},
        "court_carnival": {"status": "production"},
        "gymnastics": {"status": "production"},
        "brain_brawl": {"status": "production"},
        "skateboarding": {"status": "production"},
        "snowboarding": {"status": "production"},
        "who_scene_it": {"status": "production"},
        "market_browse": {"status": "non-game-module", "launchable": False},
        "movement_lab": {"status": "preview", "launchable": False},
    }

    for mode_id, expected in required_modes.items():
        mode = by_id.get(mode_id)
        if not mode:
            errors.append(f"{mode_id}: missing from mode registry")
            continue
        for key, expected_value in expected.items():
            if mode.get(key) != expected_value:
                errors.append(f"{mode_id}: {key}={mode.get(key)!r}, expected {expected_value!r}")

    launch_maps = launchable_mode_maps(mode_manager, venue_registry, ue_mode_maps)
    for mode_id, mode in by_id.items():
        if mode["launchable"] and not launch_maps.get(mode_id):
            errors.append(f"{mode_id}: marked launchable but has no launch map")
        if mode["render_mode"] == "IRL" and mode["launchable"]:
            errors.append(f"{mode_id}: IRL mode must not be UE launchable")

    print("FEL mode registry validation")
    print(f"  total_modes={actual_total}")
    print(f"  production_modes={actual_production}")
    print(f"  launchable_modes={len(launch_maps)}")
    for mode in modes:
        print(
            "  "
            f"{mode['mode_id']:24} status={mode['status']:15} "
            f"render={mode['render_mode']:6} launchable={str(mode['launchable']).lower():5} "
            f"map={mode.get('map') or '-'}"
        )

    if errors:
        print("\nErrors:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("All mode registry assertions passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
