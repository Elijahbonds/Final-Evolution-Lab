"""Helpers for resolving FEL mode registry records into launch metadata."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def load_ue_mode_maps(root_dir: Path) -> dict[str, Any]:
    path = root_dir / "ue_mode_maps.json"
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        return {}
    return data.get("mode_to_unreal_map", {})


def venues_by_key(venue_registry: dict[str, Any]) -> dict[str, dict[str, Any]]:
    venues = venue_registry.get("venues", {})
    if isinstance(venues, dict):
        return {str(key): value for key, value in venues.items() if isinstance(value, dict)}
    if isinstance(venues, list):
        return {
            str(venue["venueKey"]): venue
            for venue in venues
            if isinstance(venue, dict) and venue.get("venueKey")
        }
    return {}


def mode_venue_entry(venue_registry: dict[str, Any], mode_id: str) -> dict[str, Any]:
    for entry in venue_registry.get("modes", []):
        if isinstance(entry, dict) and entry.get("id") == mode_id:
            return entry
    return {}


def resolve_mode_launch_fields(
    mode_id: str,
    config: dict[str, Any],
    *,
    venue_registry: dict[str, Any],
    ue_mode_maps: dict[str, Any],
) -> dict[str, Any]:
    """Resolve current and legacy mode records into API launch/display fields.

    Current `FEL_ModeManager.production.json` records are intentionally compact
    (`venue_id`/`status`/`render_mode`) while older handlers expected concrete
    `map`, `gamemode_class`, and `binary` fields. This function bridges both
    shapes without making IRL/null-map modes look stream-launchable.
    """

    venue_entry = mode_venue_entry(venue_registry, mode_id)
    venues = venues_by_key(venue_registry)

    raw_map_path = config.get("map") or config.get("map_path")
    map_token = ue_mode_maps.get(mode_id)

    if raw_map_path:
        map_path = str(raw_map_path)
        venue_key = map_path.rstrip("/").split("/")[-1]
    elif map_token:
        venue_key = str(map_token)
        venue_data = venues.get(venue_key) or venues.get(venue_key.lower()) or {}
        map_path = venue_data.get("map_path") or f"/Game/FEL/Maps/{venue_key}"
    else:
        map_path = None
        venue_key = (
            venue_entry.get("venueKey")
            or config.get("venue_key")
            or config.get("venue_id")
            or mode_id
        )

    venue_key = str(venue_key) if venue_key is not None else mode_id
    venue_data = venues.get(venue_key) or venues.get(venue_key.lower()) or {}
    render_mode = config.get("render_mode") or venue_entry.get("renderMode")

    return {
        "mode_id": mode_id,
        "map_path": map_path,
        "venue_key": venue_key,
        "venue_data": venue_data,
        "gamemode_class": config.get("gamemode_class") or f"BP_GameMode_{venue_key}",
        "binary": config.get("binary") or f"FEL_{venue_key}",
        "status": config.get("status", "staging"),
        "render_mode": render_mode,
        "launchable": bool(map_path)
        and config.get("status") in ("production", "staging")
        and render_mode != "IRL",
    }
