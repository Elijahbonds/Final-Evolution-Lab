"""Vault WebSocket channel for session lifecycle and economy updates."""
from __future__ import annotations

from datetime import UTC, datetime
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect, status
from pydantic import ValidationError

from app.auth.jwt_handler import decode_access_token
from app.dependencies import SessionLocal
from app.schemas.session_receipt import SessionReceiptIn, SessionReceiptOut
from app.services.session_processor import session_processor
from app.websockets.connection_manager import ConnectionManager

vault_ws_router = APIRouter()
vault_manager = ConnectionManager("vault")


def _extract_token(websocket: WebSocket) -> str | None:
    token = websocket.query_params.get("token")
    if token:
        return token
    auth_header = websocket.headers.get("authorization", "")
    if auth_header.startswith("Bearer "):
        return auth_header.removeprefix("Bearer ").strip()
    return None


def _economy_payload(processed: SessionReceiptOut) -> dict[str, Any]:
    economy = processed.economy
    return {
        "xp_awarded": economy.xp,
        "shards_total": economy.shards,
        "prq_delta": economy.prq_delta,
        "mri": economy.mri,
        "pacing_bonus_applied": economy.pacing_bonus_applied,
    }


def receipt_from_ws_event(data: dict[str, Any]) -> SessionReceiptIn:
    """Map the guide's Vault `session_end` envelope to Phase 1 receipt schema."""

    session = data.get("session") if isinstance(data.get("session"), dict) else {}
    mri = session.get("mri") if isinstance(session.get("mri"), dict) else {}
    neuro = data.get("neurocognitive") if isinstance(data.get("neurocognitive"), dict) else {}
    telemetry = {
        "session_id": data.get("session_id"),
        "venue": data.get("venue"),
        "map_path": data.get("map_path"),
        "neurocognitive": neuro,
        "arcade_physics_snapshot": data.get("arcade_physics_snapshot", {}),
        "prq_attributes": data.get("prq_attributes", {}),
    }
    return SessionReceiptIn(
        mode_id=str(data.get("mode_id") or session.get("mode_id") or "basketball_h2h"),
        score=int(session.get("score", data.get("score", 0))),
        outcome=str(session.get("outcome", data.get("outcome", "loss"))),
        duration_seconds=int(session.get("duration_seconds", session.get("duration_sec", 60))),
        completed=bool(session.get("completed", True)),
        combo_count=int(session.get("max_combo", session.get("combo_count", 0))),
        critical_count=int(session.get("critical_count", 0)),
        pacing_score=float(
            mri.get("pacing", neuro.get("tier_c_pacing", session.get("pacing_score", 0)))
        ),
        arv=float(mri.get("arv", neuro.get("tier_a_arv", 50))),
        esi=float(mri.get("esi", neuro.get("tier_b_esi", 50))),
        telemetry=telemetry,
    )


async def _send_error(websocket: WebSocket, code: str, message: str) -> None:
    await websocket.send_json({"event": "error", "code": code, "message": message})


@vault_ws_router.websocket("/ws/vault")
async def vault_websocket(websocket: WebSocket) -> None:
    """Session lifecycle channel.

    Auth: FEL Bearer token via `Authorization` header or `?token=`.
    """

    token = _extract_token(websocket)
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Missing token")
        return
    try:
        claims = decode_access_token(token)
        user_id = str(claims["sub"])
    except Exception:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION, reason="Invalid token")
        return

    await vault_manager.connect(websocket, user_id)
    try:
        while True:
            data = await websocket.receive_json()
            event = data.get("event")

            if event == "ping":
                await websocket.send_json({"event": "pong", "ts": datetime.now(UTC).isoformat()})
            elif event == "session_start":
                await websocket.send_json(
                    {
                        "event": "session_ack",
                        "session_id": data.get("session_id") or str(uuid4()),
                        "status": "active",
                        "timestamp": data.get("timestamp") or datetime.now(UTC).isoformat(),
                    }
                )
            elif event == "session_update":
                await websocket.send_json(
                    {
                        "event": "session_update_ack",
                        "session_id": data.get("session_id"),
                        "status": "received",
                    }
                )
            elif event == "session_end":
                try:
                    receipt = receipt_from_ws_event(data)
                    async with SessionLocal() as db:
                        processed = await session_processor.process(
                            db=db,
                            user_id=user_id,
                            receipt=receipt,
                        )
                    await websocket.send_json(
                        {
                            "event": "economy_update",
                            "session_id": data.get("session_id") or processed.session_id,
                            "user_id": user_id,
                            "mode_id": receipt.mode_id,
                            "economy": _economy_payload(processed),
                            "persisted": processed.persisted,
                        }
                    )
                except HTTPException as exc:
                    await _send_error(websocket, "VALIDATION_ERROR", str(exc.detail))
                except (ValidationError, ValueError, TypeError) as exc:
                    await _send_error(websocket, "BAD_SESSION_RECEIPT", str(exc))
            elif event == "market_action":
                await websocket.send_json(
                    {
                        "event": "market_action_ack",
                        "action": data.get("action"),
                        "status": "queued",
                    }
                )
            else:
                await _send_error(websocket, "UNKNOWN_EVENT", str(event))
    except WebSocketDisconnect:
        await vault_manager.disconnect(websocket, user_id)
    except Exception:
        await vault_manager.disconnect(websocket, user_id, close=True)


@vault_ws_router.get("/ws/vault/stats")
async def vault_stats() -> dict[str, int | str]:
    """Return basic Vault connection stats."""

    return {
        "channel": vault_manager.channel,
        "connections": vault_manager.get_connected_count(),
        "users": vault_manager.get_user_count(),
    }

