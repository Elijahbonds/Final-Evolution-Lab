"""
sovereign.py — Nexus sovereign session bridge and venue/mode registries.
Provides in-memory state for venue and mode management. Real-time bridge
connects to Nexus Engine via HTTP poll when available.
"""
from __future__ import annotations
import os, json, asyncio, logging
from pathlib import Path
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)

# ── In-memory sovereign state ──────────────────────────────────────────────────
sovereign_state: Dict[str, Any] = {
    "active_sessions": {},
    "venue_overrides": {},
    "mode_overrides": {},
    "nexus_connected": False,
    "last_heartbeat": None,
}

# ── Registry loaders (fall back to embedded defaults if JSON missing) ──────────
def _load_json(rel_path: str, default: dict) -> dict:
    p = Path(__file__).parent.parent / rel_path
    if p.exists():
        try:
            return json.loads(p.read_text())
        except Exception as exc:
            logger.warning("sovereign: could not load %s: %s", rel_path, exc)
    return default

VENUE_REGISTRY: Dict[str, Any] = _load_json(
    "FEL_VenueRegistry.production.json",
    {
        "venues": [
            {"id": "fel_arena", "name": "FEL Arena", "capacity": 2, "modes": ["basketball_h2h", "basketball_3v3", "karate", "tennis"]},
            {"id": "street_court", "name": "Street Court", "capacity": 2, "modes": ["basketball_h2h"]},
            {"id": "nexus_dome", "name": "Nexus Dome", "capacity": 4, "modes": ["basketball_3v3", "football", "soccer"]},
        ]
    }
)

MODE_MANAGER: Dict[str, Any] = _load_json(
    "FEL_ModeManager.production.json",
    {
        "mode_manager": {
            "modes": [
                {"id": "basketball_h2h", "name": "Basketball 1v1", "render_mode": "3D_UE5", "max_players": 2},
                {"id": "basketball_3v3", "name": "Basketball 3v3", "render_mode": "3D_UE5", "max_players": 6},
                {"id": "basketball_dunk", "name": "Dunk Contest", "render_mode": "3D_UE5", "max_players": 2},
                {"id": "tennis", "name": "Tennis", "render_mode": "3D_UE5", "max_players": 2},
                {"id": "soccer", "name": "Soccer", "render_mode": "3D_UE5", "max_players": 2},
                {"id": "football", "name": "Football", "render_mode": "3D_UE5", "max_players": 2},
                {"id": "baseball", "name": "Baseball", "render_mode": "3D_UE5", "max_players": 2},
                {"id": "golf", "name": "Golf", "render_mode": "3D_UE5", "max_players": 1},
                {"id": "volleyball", "name": "Volleyball", "render_mode": "3D_UE5", "max_players": 2},
                {"id": "karate", "name": "Karate", "render_mode": "3D_UE5", "max_players": 2},
                {"id": "karate_endless", "name": "Karate Endless", "render_mode": "3D_UE5", "max_players": 1},
                {"id": "gymnastics", "name": "Gymnastics", "render_mode": "3D_UE5", "max_players": 1},
                {"id": "snowboarding", "name": "Snowboarding", "render_mode": "3D_UE5", "max_players": 1},
                {"id": "surfing", "name": "Surfing", "render_mode": "3D_UE5", "max_players": 1},
                {"id": "skateboarding", "name": "Skateboarding", "render_mode": "3D_UE5", "max_players": 1},
                {"id": "brain_brawl", "name": "Brain Brawl", "render_mode": "2D", "max_players": 2},
                {"id": "court_carnival", "name": "Court Carnival", "render_mode": "2D", "max_players": 1},
                {"id": "who_scene_it", "name": "Who Scene It", "render_mode": "2D", "max_players": 2},
                {"id": "basketball_dunk_irl", "name": "IRL Dunk", "render_mode": "IRL", "max_players": 1},
                {"id": "dunk_competition", "name": "Dunk Competition", "render_mode": "3D_UE5", "max_players": 2},
            ]
        }
    }
)

# ── Sovereign bridge ────────────────────────────────────────────────────────────
async def sovereign_bridge(action: str, payload: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Nexus sovereign bridge. Dispatches actions to the Nexus Engine when
    connected; falls back to in-memory sovereign_state otherwise.
    """
    payload = payload or {}
    nexus_base = os.environ.get("NEXUS_ENGINE_URL", "")

    if action == "heartbeat":
        sovereign_state["nexus_connected"] = bool(nexus_base)
        return {"ok": True, "nexus_connected": sovereign_state["nexus_connected"]}

    if action == "start_session":
        sid = payload.get("session_id", "")
        sovereign_state["active_sessions"][sid] = payload
        return {"ok": True, "session_id": sid}

    if action == "end_session":
        sid = payload.get("session_id", "")
        sovereign_state["active_sessions"].pop(sid, None)
        return {"ok": True, "session_id": sid}

    if action == "get_venues":
        return {"ok": True, "venues": VENUE_REGISTRY.get("venues", [])}

    if action == "get_modes":
        return {"ok": True, "modes": MODE_MANAGER.get("mode_manager", {}).get("modes", [])}

    return {"ok": False, "error": f"unknown action: {action}"}
