"""HUD WebSocket channel for 30Hz realtime overlay relay."""
from __future__ import annotations

from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.websockets.connection_manager import ConnectionManager

hud_ws_router = APIRouter()
hud_manager = ConnectionManager("hud", max_connections_per_user=6)


def _hud_user_id(websocket: WebSocket) -> str:
    return (
        websocket.query_params.get("user_id")
        or websocket.cookies.get("fel_user_id")
        or websocket.cookies.get("session_user_id")
        or "anonymous"
    )


def _normalize_hud_frame(frame: dict[str, Any]) -> dict[str, Any]:
    """Accept iOS `fel.hud.frame` envelopes or legacy flat HUD payloads."""

    event = frame.get("event") or frame.get("type")
    if event == "fel.hud.frame":
        inner = frame.get("payload")
        if isinstance(inner, dict):
            normalized: dict[str, Any] = {
                "event": "fel.hud.frame",
                "seq": frame.get("seq", 0),
                "frame": inner,
            }
            if "mode_state" in inner:
                normalized["mode_state"] = inner["mode_state"]
            return normalized
        return frame
    return frame


@hud_ws_router.websocket("/ws/hud")
async def hud_websocket(websocket: WebSocket) -> None:
    """Relay HUD frames from game client to every HUD consumer for the same user."""

    user_id = _hud_user_id(websocket)
    await hud_manager.connect(websocket, user_id)
    try:
        await websocket.send_json({"event": "hud_connected", "user_id": user_id})
        while True:
            frame: dict[str, Any] = await websocket.receive_json()
            if frame.get("event") == "ping":
                await websocket.send_json({"event": "pong"})
                continue
            relay = _normalize_hud_frame(frame)
            delivered = await hud_manager.send_to_user(user_id, relay)
            if frame.get("event") == "frame_ack_request":
                await websocket.send_json({"event": "frame_ack", "delivered": delivered})
    except WebSocketDisconnect:
        await hud_manager.disconnect(websocket, user_id)
    except Exception:
        await hud_manager.disconnect(websocket, user_id, close=True)


@hud_ws_router.get("/ws/hud/stats")
async def hud_stats() -> dict[str, int | str]:
    """Return basic HUD connection stats."""

    return {
        "channel": hud_manager.channel,
        "connections": hud_manager.get_connected_count(),
        "users": hud_manager.get_user_count(),
    }

