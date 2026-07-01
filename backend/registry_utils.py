"""Shared FEL mode/venue registry normalization helpers.

The production registry has evolved from a list of mode objects into a
``mode_registry`` dictionary.  Backend routes, CI validators, and app clients
should all consume the same normalized shape so schema drift does not make the
game appear incomplete or unlaunchable.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional


NON_LAUNCH_STATUSES = {"non_game", "non-game", "non-game-module"}
PLAYABLE_STATUSES = {"production", "staging"}


def load_json(path: Path, default: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    if path.exists():
        return json.loads(path.read_text())
    return default or {}


def load_ue_mode_maps(root_dir: Path) -> Dict[str, Optional[str]]:
    data = load_json(root_dir / "ue_mode_maps.json", {"mode_to_unreal_map": {}})
    return data.get("mode_to_unreal_map", {})


def mode_registry(mode_manager: Mapping[str, Any]) -> Dict[str, Dict[str, Any]]:
    manager = mode_manager.get("mode_manager", {})
    registry = manager.get("mode_registry")
    if isinstance(registry, dict):
        return {str(k): dict(v) for k, v in registry.items() if isinstance(v, dict)}

    legacy_modes = manager.get("modes", [])
    if isinstance(legacy_modes, list):
        return {
            str(mode["id"]): dict(mode)
            for mode in legacy_modes
            if isinstance(mode, dict) and mode.get("id")
        }
    return {}


def venue_modes_by_id(venue_registry: Mapping[str, Any]) -> Dict[str, Dict[str, Any]]:
    modes = venue_registry.get("modes", [])
    if not isinstance(modes, list):
        return {}
    return {
        str(mode["id"]): dict(mode)
        for mode in modes
        if isinstance(mode, dict) and mode.get("id")
    }


def venues_by_key(venue_registry: Mapping[str, Any]) -> Dict[str, Dict[str, Any]]:
    venues = venue_registry.get("venues", {})
    if isinstance(venues, dict):
        return {str(k): dict(v) for k, v in venues.items() if isinstance(v, dict)}
    if isinstance(venues, list):
        return {
            str(venue["venueKey"]): dict(venue)
            for venue in venues
            if isinstance(venue, dict) and venue.get("venueKey")
        }
    return {}


def _title_from_id(mode_id: str) -> str:
    return mode_id.replace("_", " ").title()


def _mode_map_token(
    mode_id: str,
    config: Mapping[str, Any],
    venue_mode: Mapping[str, Any],
    ue_mode_maps: Mapping[str, Optional[str]],
) -> Optional[str]:
    explicit_map = config.get("map") or config.get("map_path") or venue_mode.get("mapPath")
    if isinstance(explicit_map, str) and explicit_map:
        return explicit_map.rstrip("/").split("/")[-1]

    token = ue_mode_maps.get(mode_id)
    if token:
        return token

    venue_key = venue_mode.get("venueKey") or config.get("venue_token")
    if isinstance(venue_key, str) and venue_key:
        return venue_key
    return None


def normalize_mode(
    mode_id: str,
    config: Mapping[str, Any],
    venue_mode: Mapping[str, Any],
    venues: Mapping[str, Mapping[str, Any]],
    ue_mode_maps: Mapping[str, Optional[str]],
) -> Dict[str, Any]:
    status = str(config.get("status") or config.get("release_state") or "preview")
    map_token = _mode_map_token(mode_id, config, venue_mode, ue_mode_maps)
    map_path = config.get("map") or config.get("map_path")
    if not map_path and map_token:
        map_path = f"/Game/FEL/Maps/{map_token}"

    healthkit = bool(config.get("healthkit_tracked") or venue_mode.get("healthKitTracked"))
    render_mode = config.get("render_mode") or venue_mode.get("renderMode")
    if not render_mode:
        if healthkit:
            render_mode = "IRL"
        elif map_token:
            render_mode = "3D_UE5"
        else:
            render_mode = "NONE"

    venue_key = venue_mode.get("venueKey") or config.get("venue_id") or map_token
    venue_data = venues.get(str(venue_key), {}) if venue_key is not None else {}
    venue_display = (
        venue_mode.get("displayVenue")
        or venue_data.get("display_name")
        or venue_data.get("analyticsPolicyName")
        or venue_key
        or "Unassigned"
    )

    launchable = (
        status in PLAYABLE_STATUSES
        and status not in NON_LAUNCH_STATUSES
        and render_mode != "IRL"
        and bool(map_token)
    )

    return {
        "id": mode_id,
        "mode_id": mode_id,
        "name": config.get("name") or config.get("display_name") or _title_from_id(mode_id),
        "status": status,
        "release_state": config.get("release_state", status),
        "render_mode": render_mode,
        "venue_id": config.get("venue_id"),
        "venue_key": venue_key,
        "venue": map_token,
        "venue_display": venue_display,
        "map": map_token,
        "map_path": map_path,
        "gamemode_class": config.get("gamemode_class", f"BP_GameMode_{map_token or mode_id}"),
        "binary": config.get("binary", f"FEL_{map_token or mode_id}"),
        "nexus_runtime_mode_id": config.get("nexus_runtime_mode_id", mode_id),
        "prq_weight": config.get("prq_weight", 0.0),
        "scoring_enabled": config.get("scoring_enabled", status == "production"),
        "healthkit_tracked": healthkit,
        "launchable": launchable,
    }


def normalized_modes(
    mode_manager: Mapping[str, Any],
    venue_registry: Mapping[str, Any],
    ue_mode_maps: Optional[Mapping[str, Optional[str]]] = None,
) -> List[Dict[str, Any]]:
    registry = mode_registry(mode_manager)
    venue_modes = venue_modes_by_id(venue_registry)
    venues = venues_by_key(venue_registry)
    maps = ue_mode_maps or {}
    return [
        normalize_mode(mode_id, config, venue_modes.get(mode_id, {}), venues, maps)
        for mode_id, config in registry.items()
    ]


def launchable_mode_maps(
    mode_manager: Mapping[str, Any],
    venue_registry: Mapping[str, Any],
    ue_mode_maps: Mapping[str, Optional[str]],
) -> Dict[str, str]:
    return {
        mode["mode_id"]: mode["map"]
        for mode in normalized_modes(mode_manager, venue_registry, ue_mode_maps)
        if mode["launchable"] and mode.get("map")
    }


def production_count(modes: Iterable[Mapping[str, Any]]) -> int:
    return sum(1 for mode in modes if mode.get("status") == "production")
