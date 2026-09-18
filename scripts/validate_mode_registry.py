#!/usr/bin/env python3
"""Validate backend mode registry totals and production/runtime boundaries."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent.parent
MODE_MANAGER = REPO_ROOT / "backend/FEL_ModeManager.production.json"
CPP_REGISTRY = REPO_ROOT / "app/gameplay/include/nexus/gameplay/arena_mode_registry.h"

APP_ONLY_PRODUCTION = {"basketball_dunk_3d", "basketball_dunk_irl"}
NON_GAME_MODULES = {"market_browse"}
PREVIEW_MODULES = {"movement_lab"}


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def cpp_production_ids() -> list[str]:
    content = CPP_REGISTRY.read_text()
    match = re.search(r"kProductionModeIds\[\]\s*=\s*\{(?P<body>.*?)\};", content, re.S)
    if not match:
        fail("could not find C++ kProductionModeIds")
    return re.findall(r'"([^"]+)"', match.group("body"))


def main() -> int:
    payload = json.loads(MODE_MANAGER.read_text())
    mode_manager = payload.get("mode_manager", {})
    registry = mode_manager.get("mode_registry", {})
    if not isinstance(registry, dict):
        fail("mode_manager.mode_registry must be an object")

    declared_total = mode_manager.get("total_modes")
    actual_total = len(registry)
    if declared_total != actual_total:
        fail(f"total_modes={declared_total}, actual={actual_total}")

    production_ids = [mode_id for mode_id, entry in registry.items() if entry.get("status") == "production"]
    declared_production = mode_manager.get("production_modes")
    if declared_production != len(production_ids):
        fail(f"production_modes={declared_production}, actual={len(production_ids)}")

    missing_cpp = [mode_id for mode_id in cpp_production_ids() if mode_id not in production_ids]
    if missing_cpp:
        fail(f"C++ production modes not marked production in backend: {missing_cpp}")

    for mode_id in APP_ONLY_PRODUCTION:
        entry = registry.get(mode_id)
        if not entry:
            fail(f"app production mode missing: {mode_id}")
        if entry.get("status") != "production":
            fail(f"app production mode {mode_id} status={entry.get('status')}")

    dunk3d_runtime = registry["basketball_dunk_3d"].get("nexus_runtime_mode_id")
    if dunk3d_runtime != "basketball_dunk":
        fail(f"basketball_dunk_3d nexus_runtime_mode_id={dunk3d_runtime}")

    if registry["basketball_dunk_irl"].get("render_mode") != "IRL":
        fail("basketball_dunk_irl must be render_mode=IRL")

    for mode_id in NON_GAME_MODULES:
        entry = registry.get(mode_id)
        if not entry or entry.get("status") != "non-game-module":
            fail(f"{mode_id} must be present as non-game-module")

    for mode_id in PREVIEW_MODULES:
        entry = registry.get(mode_id)
        if not entry or entry.get("status") != "preview":
            fail(f"{mode_id} must be present as preview")
        if entry.get("scoring_enabled", True):
            fail(f"{mode_id} preview module must not be scoring-enabled")

    print(
        "PASS: backend mode registry "
        f"({actual_total} entries, {len(production_ids)} production records, "
        f"{len(cpp_production_ids())} C++ runtime modes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
