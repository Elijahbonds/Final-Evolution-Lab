"""Regression tests for compact FEL mode registry launch resolution."""
from __future__ import annotations

import json
from pathlib import Path

from mode_registry_resolver import load_ue_mode_maps, resolve_mode_launch_fields


BACKEND_ROOT = Path(__file__).resolve().parents[1]
MODE_MANAGER = json.loads((BACKEND_ROOT / "FEL_ModeManager.production.json").read_text())
VENUE_REGISTRY = json.loads((BACKEND_ROOT / "FEL_VenueRegistry.production.json").read_text())
UE_MODE_MAPS = load_ue_mode_maps(BACKEND_ROOT)


def _resolve(mode_id: str) -> dict:
    registry = MODE_MANAGER["mode_manager"]["mode_registry"]
    return resolve_mode_launch_fields(
        mode_id,
        registry[mode_id],
        venue_registry=VENUE_REGISTRY,
        ue_mode_maps=UE_MODE_MAPS,
    )


def test_compact_registry_modes_resolve_streamable_maps() -> None:
    resolved = _resolve("karate_h2h")

    assert resolved["map_path"] == "/Game/FEL/Maps/Zen_Dojo"
    assert resolved["venue_key"] == "Zen_Dojo"
    assert resolved["gamemode_class"] == "BP_GameMode_Zen_Dojo"
    assert resolved["binary"] == "FEL_Zen_Dojo"
    assert resolved["launchable"] is True


def test_split_dunk_3d_resolves_to_venice_map() -> None:
    resolved = _resolve("basketball_dunk_3d")

    assert resolved["map_path"] == "/Game/FEL/Maps/Venice_Beach_Court"
    assert resolved["venue_key"] == "Venice_Beach_Court"
    assert resolved["launchable"] is True


def test_irl_dunk_remains_visible_but_not_stream_launchable() -> None:
    resolved = _resolve("basketball_dunk_irl")

    assert resolved["map_path"] is None
    assert resolved["venue_key"] == "regulation_court_irl"
    assert resolved["launchable"] is False
