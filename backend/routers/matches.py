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

from fastapi import APIRouter, Depends, HTTPException, Request, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

from core import db, get_current_user, User
from lib.match_utils import generate_seed, derive_judge_offsets
from lib.card_effects import compute_loadout_modifiers

router = APIRouter(tags=["matches"])

# ── Detect mock-DB mode ────────────────────────────────────────────────────
_MOCK_DB = os.environ.get("MOCK_DB", "0") == "1" or (
    len(sys.argv) > 0 and "pytest" in sys.argv[0]
)


async def get_match_user(request: Request) -> User:
    """Auth for match endpoints.

    Production (MOCK_DB unset): identical to get_current_user.
    MOCK_DB=1: falls back to a guest identity so the local sim harness
    (scripts/simulate_matches.py) can drive matches without a session.
    Guest player id may be supplied via the X-FEL-Sim-Player header.
    """
    try:
        return await get_current_user(request)
    except Exception:
        if not _MOCK_DB:
            raise
        pid = request.headers.get("X-FEL-Sim-Player", "sim_guest")
        return User(user_id=pid, email=f"{pid}@sim.fellab.io", name=pid)

# ── In-memory stores (used when _MOCK_DB=True) ─────────────────────────────
_matches: Dict[str, Dict[str, Any]] = {}
_events: Dict[str, List[Dict[str, Any]]] = {}
_system_scan_snapshot: Dict[str, Any] = {}
_ws_connections: Dict[str, Set[WebSocket]] = {}


# ── Pydantic schemas ───────────────────────────────────────────────────────

class CreateMatchRequest(BaseModel):
    mode_id: str = "basketball_h2h"
    player_id: Optional[str] = None  # override; defaults to authenticated user
    auto_simulate: bool = False  # demo mode: emit random score_events in background


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
    seed: Optional[int] = None
    judge_offsets: List[int] = []


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
    # Server-authoritative sequence number for replay ordering (Agent 3).
    if "seq" not in event:
        event["seq"] = len(_events.get(match_id, []))
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


def _card_bonus(loadout: list) -> float:
    """Returns total bonus multiplier from loadout modifiers (0.0 = no bonus)."""
    import re
    total = 0.0
    for card in loadout:
        summary = card.get("modifiers_summary", "")
        for pct in re.findall(r'\+(\d+(?:\.\d+)?)%', summary):
            total += float(pct) / 100.0
    return min(total, 0.5)  # cap at 50% bonus


async def _simulate_scoring(
    match_id: str,
    players: List[str],
    loadouts: Dict[str, List[Dict[str, Any]]],
    n_events: int = 8,
) -> None:
    """Background task: emit simulated score_events for dev/testing."""
    import random
    scores: Dict[str, int] = {p: 0 for p in players}
    seq = 0
    for _ in range(n_events):
        await asyncio.sleep(1.5)
        # Weight scoring by card bonuses
        weights = []
        for p in players:
            base = 1.0
            bonus = _card_bonus(loadouts.get(p, []))
            weights.append(base + bonus)
        total_w = sum(weights)
        rand = random.random() * total_w
        scorer = players[0]
        cumulative = 0.0
        for i, p in enumerate(players):
            cumulative += weights[i]
            if rand <= cumulative:
                scorer = p
                break
        points = random.choices([1, 2, 3], weights=[0.3, 0.5, 0.2])[0]
        scores[scorer] = scores.get(scorer, 0) + points
        seq += 1
        event: Dict[str, Any] = {
            "type": "score_event",
            "player_id": scorer,
            "points": points,
            "seq": seq,
            "timestamp": _now(),
            "score_snapshot": dict(scores),
        }
        await _persist_event(match_id, event)
        await _broadcast(match_id, event)

    # match_end
    end_event: Dict[str, Any] = {
        "type": "match_end",
        "match_id": match_id,
        "score": scores,
        "timestamp": _now(),
    }
    await _persist_event(match_id, end_event)
    await _broadcast(match_id, end_event)
    _matches[match_id]["status"] = "finished"
    _matches[match_id]["score"] = scores


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.post("/api/matches/create")
async def create_match(
    body: CreateMatchRequest,
    user: User = Depends(get_match_user),
) -> Dict[str, Any]:
    """Create a new match and return its match_id."""
    match_id = str(uuid.uuid4())[:12]
    player_id = body.player_id or user.user_id
    loadout = await _load_loadout(player_id)
    seed = generate_seed()
    judge_offsets = derive_judge_offsets(seed)
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
        "auto_simulate": body.auto_simulate,
        "seed": seed,
        "judge_offsets": judge_offsets,
    }
    await _persist_match(match)
    return {
        "match_id": match_id,
        "state": "waiting",
        "status": "waiting",  # legacy alias for existing clients
        "mode_id": body.mode_id,
        "seed": seed,
        "judge_offsets": judge_offsets,
    }


@router.post("/api/matches/join")
async def join_match(
    body: JoinMatchRequest,
    user: User = Depends(get_match_user),
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
            "seed": match.get("seed"),
            "judge_offsets": match.get("judge_offsets", []),
            "players": [
                {
                    "user_id": p,
                    "loadout": match["loadouts"].get(p, []),
                    "computed_modifiers": compute_loadout_modifiers(match["loadouts"].get(p, [])),
                }
                for p in match["players"]
            ],
            "start_time": match["started_at"],
        }
        await _persist_event(body.match_id, start_event)
        await _broadcast(body.match_id, start_event)
        # Demo-only random scoring loop. Opt-in: it emits non-deterministic
        # events, which breaks replay validation (Agent 4) if always on.
        if match.get("auto_simulate"):
            asyncio.create_task(_simulate_scoring(body.match_id, match["players"], match["loadouts"]))
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
        seed=match.get("seed"),
        judge_offsets=match.get("judge_offsets", []),
    )


# NOTE (Agent 2): POST /api/matches/{match_id}/score_dunk moved to routers/dunk.py
# (server-authoritative WDA engine-3D scoring with seeded judge_offsets).


class AppendEventRequest(BaseModel):
    type: str  # e.g. "input" | "score_event"
    payload: Dict[str, Any] = {}
    player_id: Optional[str] = None


class EndMatchRequest(BaseModel):
    score: Optional[Dict[str, int]] = None
    reason: str = "completed"


@router.post("/api/matches/{match_id}/events")
async def append_match_event(match_id: str, body: AppendEventRequest) -> Dict[str, Any]:
    """Append a server-stamped event (input, score_event, ...) to the match log."""
    match = await _load_match(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    if match["status"] == "finished":
        raise HTTPException(status_code=409, detail="Match already finished")
    allowed = {"input", "score_event", "checkpoint", "custom"}
    if body.type not in allowed:
        raise HTTPException(status_code=422, detail=f"Event type must be one of {sorted(allowed)}")

    event: Dict[str, Any] = {
        "type": body.type,
        "match_id": match_id,
        "player_id": body.player_id,
        "payload": body.payload,
        "timestamp": _now(),
    }
    if body.type == "score_event":
        points = int(body.payload.get("points", 0))
        pid = body.player_id or (match["players"][0] if match["players"] else "unknown")
        match["score"][pid] = match["score"].get(pid, 0) + points
        event["points"] = points
        event["score_snapshot"] = dict(match["score"])
        await _persist_match(match)

    await _persist_event(match_id, event)
    await _broadcast(match_id, event)
    return {"ok": True, "seq": event["seq"], "type": body.type}


@router.post("/api/matches/{match_id}/end")
async def end_match(match_id: str, body: EndMatchRequest) -> Dict[str, Any]:
    """Finish a match: sets status, stamps finished_at, appends match_end event."""
    match = await _load_match(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    if match["status"] == "finished":
        raise HTTPException(status_code=409, detail="Match already finished")
    if body.score:
        match["score"].update(body.score)
    match["status"] = "finished"
    match["finished_at"] = _now()
    await _persist_match(match)
    end_event = {
        "type": "match_end",
        "match_id": match_id,
        "score": dict(match["score"]),
        "reason": body.reason,
        "timestamp": match["finished_at"],
    }
    await _persist_event(match_id, end_event)
    await _broadcast(match_id, end_event)
    return {"match_id": match_id, "status": "finished", "score": match["score"]}


@router.get("/api/matches/{match_id}/export-replay")
async def export_replay(match_id: str) -> Dict[str, Any]:
    """Export full match replay: {metadata: {...}, events: [...]} (Agent 3 contract).

    Flat top-level fields are kept for backwards compatibility with older
    clients; the canonical shape is `metadata` + `events`.
    """
    match = await _load_match(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    events = await _load_events(match_id, limit=10_000)
    # Guarantee chronological order regardless of storage backend: `seq` is
    # server-stamped at append time, so it is the authoritative replay order.
    events = sorted(events, key=lambda e: e.get("seq", 0))
    metadata = {
        "match_id": match_id,
        "mode_id": match.get("mode_id"),
        "seed": match.get("seed"),
        "judge_offsets": match.get("judge_offsets", []),
        "players": match.get("players", []),
        "start_time": match.get("started_at"),
        "finished_at": match.get("finished_at"),
        "status": match.get("status"),
        "export_version": "1.1",
        "event_count": len(events),
    }
    return {
        "metadata": metadata,
        "events": events,
        # Back-compat flat fields (deprecated; prefer metadata.*)
        "match_id": match_id,
        "mode_id": match.get("mode_id"),
        "seed": match.get("seed"),
        "judge_offsets": match.get("judge_offsets", []),
        "players": match.get("players", []),
        "started_at": match.get("started_at"),
        "finished_at": match.get("finished_at"),
        "status": match.get("status"),
    }


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
            try:
                # 30-second receive timeout; client must send any message or ping
                data = await asyncio.wait_for(websocket.receive_text(), timeout=30.0)
                if data == "ping":
                    await websocket.send_text("pong")
            except asyncio.TimeoutError:
                # Send ping; if client is gone this will raise on next iteration
                await websocket.send_json({"type": "ping"})
    except Exception:
        pass
    finally:
        _ws_connections[match_id].discard(websocket)


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
