"""Registry routes backed by the canonical FEL production JSON files."""
from __future__ import annotations

import json
import os
from datetime import UTC, datetime
from functools import lru_cache
from pathlib import Path
from typing import Any

from fastapi import APIRouter

router = APIRouter(prefix="/registry", tags=["registry"])

BACKEND_ROOT = Path(__file__).resolve().parents[2]


@lru_cache(maxsize=None)
def _load_json(filename: str) -> dict[str, Any]:
    path = BACKEND_ROOT / filename
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def _mode_registry() -> dict[str, dict[str, Any]]:
    return _load_json("FEL_ModeManager.production.json").get("mode_manager", {}).get("mode_registry", {})


def _ue_mode_maps() -> dict[str, str | None]:
    return _load_json("ue_mode_maps.json").get("mode_to_unreal_map", {})


def _venue_registry() -> dict[str, Any]:
    return _load_json("FEL_VenueRegistry.production.json")


def _mode_metadata(mode_id: str) -> dict[str, Any]:
    for row in _venue_registry().get("modes", []):
        if row.get("id") == mode_id:
            return row
    return {}


def _venue_data_for_key(key: Any) -> dict[str, Any]:
    if not key:
        return {}

    normalized = str(key).lower()
    venues = {
        str(row.get("venueKey", "")).lower(): row
        for row in _venue_registry().get("venues", [])
        if row.get("venueKey")
    }
    return venues.get(normalized) or venues.get(normalized.replace(" ", "_")) or {}


def _resolve_mode_launch_target(mode_id: str, config: dict[str, Any]) -> dict[str, Any] | None:
    if not isinstance(config, dict):
        return None

    status = config.get("status", "staging")
    metadata = _mode_metadata(mode_id)
    ue_map_token = _ue_mode_maps().get(mode_id)
    map_path = config.get("map") or config.get("map_path")
    if not map_path and ue_map_token:
        map_path = f"/Game/FEL/Maps/{ue_map_token}"

    venue_key = (
        metadata.get("venueKey")
        or ue_map_token
        or config.get("venue_id")
        or (str(map_path).split("/")[-1] if map_path else None)
    )
    map_token = ue_map_token or venue_key
    if not map_token:
        return None

    render_mode = (
        config.get("render_mode")
        or metadata.get("renderMode")
        or ("IRL" if metadata.get("isIRLMode") else "3D_UE5")
    )
    is_irl_mode = render_mode == "IRL" or bool(metadata.get("isIRLMode"))
    venue_data = _venue_data_for_key(venue_key) or _venue_data_for_key(map_token)
    launchable = status in {"production", "staging"} and status != "non-game-module" and bool(map_path or is_irl_mode)

    return {
        "mode_id": mode_id,
        "status": status,
        "map_path": map_path,
        "map_token": map_token,
        "venue_key": venue_key,
        "venue_display": (
            metadata.get("displayVenue")
            or venue_data.get("display_name")
            or venue_data.get("analyticsPolicyName")
            or str(venue_key).replace("_", " ")
        ),
        "category": venue_data.get("category", "Unknown"),
        "render_mode": render_mode,
        "is_irl_mode": is_irl_mode,
        "launchable": launchable,
    }


@router.get("/venues")
async def get_venue_registry() -> dict[str, Any]:
    """Return centralized launch metadata for app startup and shell dashboards."""

    ws_url = os.environ.get("HUB_GAME_WS_URL", "wss://finalevolutiongroup.com/ws/vault")
    modes = []
    for mode_id, config in _mode_registry().items():
        target = _resolve_mode_launch_target(mode_id, config)
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


@router.get("/config")
async def get_client_config() -> dict[str, Any]:
    """Return app launch settings paired with the registry endpoint."""

    ws_url = os.environ.get("HUB_GAME_WS_URL", "wss://finalevolutiongroup.com/ws/vault")
    return {
        "vault_hub_url": ws_url,
        "deep_link_scheme": "finalevolution://",
        "encryption": "AES-256-GCM",
        "handshake": {
            "mode": "state_aware",
            "signal": "MapLoaded",
            "timeout_seconds": 10,
            "timeout_action": "system_re_auth",
            "no_browser_fallback": True,
        },
        "integrity_guard": {
            "required": True,
            "secure_enclave": True,
            "back_camera_verify": True,
            "imu_visual_sync": True,
        },
        "telemetry": {
            "encrypted": True,
            "algorithm": "AES-256-GCM",
            "stream_interval_ms": 500,
        },
        "registry_endpoint": "/api/registry/venues",
        "version": "2.0.0",
    }
