"""Production mode and venue registry helpers for shell-safe API routes."""
from __future__ import annotations

import json
import os
from datetime import UTC, datetime
from functools import lru_cache
from pathlib import Path
from typing import Any

BACKEND_ROOT = Path(__file__).resolve().parents[2]


@lru_cache(maxsize=None)
def _load_json(filename: str) -> dict[str, Any]:
    path = BACKEND_ROOT / filename
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as handle:
        data = json.load(handle)
    return data if isinstance(data, dict) else {}


def mode_manager() -> dict[str, Any]:
    return _load_json("FEL_ModeManager.production.json")


def ue_mode_maps() -> dict[str, str | None]:
    maps = _load_json("ue_mode_maps.json").get("mode_to_unreal_map", {})
    return maps if isinstance(maps, dict) else {}


def mode_registry() -> dict[str, dict[str, Any]]:
    registry = mode_manager().get("mode_manager", {}).get("mode_registry", {})
    return registry if isinstance(registry, dict) else {}


def mode_prq_weights() -> dict[str, float]:
    weights: dict[str, float] = {}
    for mode_id, config in mode_registry().items():
        if isinstance(config, dict) and "prq_weight" in config:
            weights[mode_id] = float(config["prq_weight"])
    return weights


def venue_registry() -> dict[str, Any]:
    return _load_json("FEL_VenueRegistry.production.json")


def _venue_mode_metadata(mode_id: str) -> dict[str, Any]:
    for mode in venue_registry().get("modes", []):
        if isinstance(mode, dict) and (mode.get("id") == mode_id or mode.get("nexusRuntimeModeId") == mode_id):
            return mode
    return {}


def _venue_data_for_key(venue_key: str | None) -> dict[str, Any]:
    if not venue_key:
        return {}

    venues = venue_registry().get("venues", {})
    if isinstance(venues, list):
        venues = {venue.get("venueKey"): venue for venue in venues if isinstance(venue, dict)}
    if not isinstance(venues, dict):
        return {}

    candidates = [
        venue_key,
        venue_key.lower(),
        venue_key.replace(" ", "_"),
        venue_key.replace(" ", "_").lower(),
    ]
    for candidate in candidates:
        venue = venues.get(candidate)
        if isinstance(venue, dict):
            return venue
    return {}


def resolve_mode_launch_target(mode_id: str, config: dict[str, Any]) -> dict[str, Any] | None:
    """Resolve registry schema into a client launch target.

    IRL modes intentionally have no UE map, but remain launchable app payloads.
    """
    if not isinstance(config, dict):
        return None

    status = config.get("status", "staging")
    mode_metadata = _venue_mode_metadata(mode_id)
    ue_map_token = ue_mode_maps().get(mode_id)
    map_path = config.get("map") or config.get("map_path")

    if not map_path and ue_map_token:
        map_path = f"/Game/FEL/Maps/{ue_map_token}"

    venue_key = (
        mode_metadata.get("venueKey")
        or ue_map_token
        or config.get("venue_id")
        or (map_path.split("/")[-1] if map_path else None)
    )
    map_token = ue_map_token or venue_key
    render_mode = (
        config.get("render_mode")
        or mode_metadata.get("renderMode")
        or ("IRL" if mode_metadata.get("isIRLMode") else "3D_UE5")
    )
    is_irl_mode = render_mode == "IRL" or bool(mode_metadata.get("isIRLMode"))
    venue_data = _venue_data_for_key(venue_key) or _venue_data_for_key(map_token)

    if not map_token:
        return None

    return {
        "mode_id": mode_id,
        "status": status,
        "map_path": map_path,
        "map_token": map_token,
        "venue_key": venue_key,
        "venue_display": (
            mode_metadata.get("displayVenue")
            or venue_data.get("display_name")
            or venue_data.get("analyticsPolicyName")
            or str(venue_key).replace("_", " ")
        ),
        "category": venue_data.get("category", "Unknown"),
        "db_collection": venue_data.get("db_collection", f"sessions_{str(venue_key or map_token).lower()}"),
        "render_mode": render_mode,
        "is_irl_mode": is_irl_mode,
        "launchable": status in ("production", "staging") and status != "non-game-module" and bool(map_path or is_irl_mode),
    }


def build_venue_registry_payload() -> dict[str, Any]:
    ws_url = os.environ.get("HUB_GAME_WS_URL", "wss://finalevolutiongroup.com/ws/vault")
    modes: list[dict[str, Any]] = []
    for mode_id, config in mode_registry().items():
        target = resolve_mode_launch_target(mode_id, config)
        if target is None:
            continue
        modes.append(
            {
                "mode_id": mode_id,
                "deep_link": f"finalevolution://launch?map={target['map_token']}&mode={mode_id}",
                "map_path": target["map_path"],
                "map_token": target["map_token"],
                "venue_token": target["map_token"],
                "venue_key": target["venue_key"],
                "venue_display": target["venue_display"],
                "category": target["category"],
                "render_mode": target["render_mode"],
                "is_irl_mode": target["is_irl_mode"],
                "launchable": target["launchable"],
                "binary": config.get("binary", ""),
                "status": config.get("status", "staging"),
                "gamemode_class": config.get("gamemode_class", ""),
            }
        )

    return {
        "version": "2.0.0",
        "total_modes": len(modes),
        "vault_hub": ws_url,
        "deep_link_scheme": "finalevolution://",
        "encryption": "AES-256-GCM",
        "handshake_mode": "state_aware",
        "timeout_action": "system_re_auth",
        "timeout_seconds": 10,
        "modes": modes,
        "updated_at": datetime.now(UTC).isoformat(),
    }
