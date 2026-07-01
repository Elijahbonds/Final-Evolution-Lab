"""
FEL OS — Nexus Match Lifecycle & Realtime Stub

Provides:
  POST /api/matches/create               — create a match record
  POST /api/matches/join                 — join a match; transitions to 'active' at 2+ players
  GET  /api/matches/{match_id}           — current match state + last N events
  WS   /ws/match/{match_id}             — subscribe to live match events
  GET  /api/debug/latest-system-scan    — last system-scan JSON snapshot (Nexus HTTP probe)
  GET  /api/debug/match/{match_id}/payload — full match payload for Nexus polling

In-memory store is used automatically when:
  - MOCK_DB=1 env var is set
  - module is imported under pytest (sys.argv[0] ends in 'pytest')

Simulated scoring events are emitted via asyncio background tasks when
a match becomes 'active'. This lets two WS clients or Nexus observe
a full match lifecycle without a real physics engine.
"""
import asyncio
import os
import sys
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Set

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from core import db, get_current_user, User

router = APIRouter(tags=["matches"])

# ── Detect mock-DB mode ────────────────────────────────────────────────────
_MOCK_DB = os.environ.get("MOCK_DB", "0") == "1" or (
    len(sys.argv) > 0 and "pytest" in sys.argv[0]
)

# ── In-memory stores (used when _MOCK_DB=True) ─────────────────────────────
_matches: Dict[str, Dict[str, Any]] = {}
_events: Dict[str, List[Dict[str, Any]]] = {}
_system_scan_snapshot: Dict[str, Any] = {}
_ws_connections: Dict[str, Set[WebSocket]] = {}


# ── Pydantic schemas ───────────────────────────────────────────────────────

class CreateMatchRequest(BaseModel):
    mode_id: str = "basketball_h2h"
    player_id: Optional[str] = None  # override; defaults to authenticated user


class JoinMatchRequest(BaseModel):
    match_id: str
    player_id: Optional[str] = None


class MatchResponse(BaseModel):
    match_id: str
    mode_id: str
    status: str  # waiting | active | finished
    players: List[Dict[str, Any]]
    created_at: str
    started_at: Optional[str] = None
    finished_at: Optional[str] = None
    score: Dict[str, int]
    loadouts: Dict[str, List[Dict[str, Any]]]
    events: List[Dict[str, Any]]


# ── Internal helpers ───────────────────────────────────────────────────────

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _load_loadout(player_id: str) -> List[Dict[str, Any]]:
    """Fetch a simplified Creator Card loadout for a player (top 3 cards)."""
    if _MOCK_DB:
        return []  # empty in mock mode unless seeds provided
    try:
        cards = await db.user_cards.find(
            {"user_id": player_id}, {"_id": 0, "card_id": 1, "name": 1, "rarity": 1, "modifier_summary": 1}
        ).limit(3).to_list(3)
        return [
            {"id": c.get("card_id", ""), "title": c.get("name", ""), "rarity": c.get("rarity", "common"),
             "modifiers_summary": c.get("modifier_summary", "")}
            for c in cards
        ]
    except Exception:
        return []


async def _persist_match(match: Dict[str, Any]) -> None:
    if _MOCK_DB:
        _matches[match["match_id"]] = match
        return
    try:
        await db.game_sessions.replace_one(
            {"match_id": match["match_id"]}, match, upsert=True
        )
    except Exception:
        _matches[match["match_id"]] = match


async def _persist_event(match_id: str, event: Dict[str, Any]) -> None:
    if _MOCK_DB:
        _events.setdefault(match_id, []).append(event)
        return
    try:
        await db.match_events.insert_one({**event, "match_id": match_id})
    except Exception:
        _events.setdefault(match_id, []).append(event)


async def _load_match(match_id: str) -> Optional[Dict[str, Any]]:
    if _MOCK_DB:
        return _matches.get(match_id)
    try:
        doc = await db.game_sessions.find_one({"match_id": match_id}, {"_id": 0})
        return doc
    except Exception:
        return _matches.get(match_id)


async def _load_events(match_id: str, limit: int = 50) -> List[Dict[str, Any]]:
    if _MOCK_DB:
        return _events.get(match_id, [])[-limit:]
    try:
        cursor = db.match_events.find(
            {"match_id": match_id}, {"_id": 0}
        ).sort("seq", -1).limit(limit)
        docs = await cursor.to_list(limit)
        return list(reversed(docs))
    except Exception:
        return _events.get(match_id, [])[-limit:]


async def _broadcast(match_id: str, payload: Dict[str, Any]) -> None:
    sockets = _ws_connections.get(match_id, set())
    dead: Set[WebSocket] = set()
    for ws in list(sockets):
        try:
            await ws.send_json(payload)
        except Exception:
            dead.add(ws)
    sockets -= dead


async def _simulate_scoring(match_id: str, players: List[str], n_events: int = 8) -> None:
    """Background task: emit simulated score_events for dev/testing."""
    import random
    seq = 0
    for _ in range(n_events):
        await asyncio.sleep(1.5)
        seq += 1
        player_id = random.choice(players)
        points = random.choice([1, 2, 3])
        event: Dict[str, Any] = {
            "type": "score_event",
            "player_id": player_id,
            "points": points,
            "seq": seq,
            "timestamp": _now(),
        }
        await _persist_event(match_id, event)
        # Update score in match record
        match = await _load_match(match_id)
        if match and match.get("status") == "active":
            score = match.get("score", {})
            score[player_id] = score.get(player_id, 0) + points
            match["score"] = score
            await _persist_match(match)
            event["score_snapshot"] = score
        await _broadcast(match_id, event)

    # End match
    match = await _load_match(match_id)
    if match:
        match["status"] = "finished"
        match["finished_at"] = _now()
        await _persist_match(match)
        await _broadcast(match_id, {"type": "match_end", "match_id": match_id,
                                    "score": match.get("score", {}), "timestamp": _now()})


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.post("/api/matches/create")
async def create_match(
    body: CreateMatchRequest,
    user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """Create a new match and return its match_id."""
    match_id = str(uuid.uuid4())[:12]
    player_id = body.player_id or user.user_id
    loadout = await _load_loadout(player_id)
    match: Dict[str, Any] = {
        "match_id": match_id,
        "mode_id": body.mode_id,
        "status": "waiting",
        "players": [player_id],
        "created_at": _now(),
        "started_at": None,
        "finished_at": None,
        "score": {player_id: 0},
        "loadouts": {player_id: loadout},
        "events": [],
    }
    await _persist_match(match)
    return {"match_id": match_id, "status": "waiting", "mode_id": body.mode_id}


@router.post("/api/matches/join")
async def join_match(
    body: JoinMatchRequest,
    user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """Join an existing match. When the second player joins, match becomes active."""
    match = await _load_match(body.match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    if match["status"] not in ("waiting",):
        raise HTTPException(status_code=409, detail=f"Match already {match['status']}")

    player_id = body.player_id or user.user_id
    if player_id not in match["players"]:
        match["players"].append(player_id)
        loadout = await _load_loadout(player_id)
        match["loadouts"][player_id] = loadout
        match["score"][player_id] = 0

    if len(match["players"]) >= 2 and match["status"] == "waiting":
        match["status"] = "active"
        match["started_at"] = _now()
        await _persist_match(match)
        start_event = {
            "type": "match_start",
            "match_id": body.match_id,
            "mode_id": match["mode_id"],
            "players": [
                {"user_id": p, "loadout": match["loadouts"].get(p, [])}
                for p in match["players"]
            ],
            "start_time": match["started_at"],
        }
        await _broadcast(body.match_id, start_event)
        # Kick off simulated scoring in background
        asyncio.create_task(_simulate_scoring(body.match_id, match["players"]))
    else:
        await _persist_match(match)

    return {"match_id": body.match_id, "status": match["status"], "players": match["players"]}


@router.get("/api/matches/{match_id}")
async def get_match(match_id: str, limit: int = 20) -> MatchResponse:
    """Return current match state and last N events."""
    match = await _load_match(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    events = await _load_events(match_id, limit=limit)
    return MatchResponse(
        match_id=match["match_id"],
        mode_id=match["mode_id"],
        status=match["status"],
        players=[{"user_id": p, "score": match["score"].get(p, 0)} for p in match["players"]],
        created_at=match["created_at"],
        started_at=match.get("started_at"),
        finished_at=match.get("finished_at"),
        score=match.get("score", {}),
        loadouts=match.get("loadouts", {}),
        events=events,
    )


# ── WebSocket ──────────────────────────────────────────────────────────────

@router.websocket("/ws/match/{match_id}")
async def ws_match(websocket: WebSocket, match_id: str):
    """Subscribe to live match events. Receives match_start and score_event messages."""
    await websocket.accept()
    _ws_connections.setdefault(match_id, set()).add(websocket)
    # Send current match state on connect
    match = await _load_match(match_id)
    if match:
        await websocket.send_json({"type": "match_state", "match": {
            "match_id": match["match_id"],
            "status": match["status"],
            "players": match["players"],
            "score": match["score"],
        }})
    try:
        while True:
            # Keep connection alive; all outbound data is pushed via _broadcast
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        pass
    finally:
        _ws_connections.get(match_id, set()).discard(websocket)


# ── Debug / Nexus HTTP probes ─────────────────────────────────────────────

@router.get("/api/debug/latest-system-scan")
async def debug_latest_system_scan() -> Dict[str, Any]:
    """Return the last cached system-scan snapshot. Updated on each /unified call."""
    if not _system_scan_snapshot:
        return {"detail": "No system-scan snapshot yet. Call /api/system-scan/unified first."}
    return _system_scan_snapshot


@router.get("/api/debug/match/{match_id}/payload")
async def debug_match_payload(match_id: str) -> Dict[str, Any]:
    """Return full match payload for Nexus to poll (same data broadcast over WS)."""
    match = await _load_match(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    events = await _load_events(match_id, limit=50)
    return {
        "match_id": match_id,
        "status": match["status"],
        "mode_id": match["mode_id"],
        "players": [
            {
                "user_id": p,
                "score": match["score"].get(p, 0),
                "loadout": match["loadouts"].get(p, []),
            }
            for p in match["players"]
        ],
        "score": match["score"],
        "started_at": match.get("started_at"),
        "finished_at": match.get("finished_at"),
        "events": events,
    }


def cache_system_scan_snapshot(data: Dict[str, Any]) -> None:
    """Called from system_scan router to cache the latest scan for Nexus probe."""
    _system_scan_snapshot.clear()
    _system_scan_snapshot.update(data)
