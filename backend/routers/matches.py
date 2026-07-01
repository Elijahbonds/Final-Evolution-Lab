from fastapi import APIRouter, HTTPException, WebSocket, WebSocketDisconnect, BackgroundTasks
from pydantic import BaseModel
from typing import List, Dict, Any
import uuid
import os
import asyncio
from datetime import datetime, timezone

# Use existing core db when available; fall back to in-memory stores when MOCK_DB=1
try:
    from core import db  # type: ignore
except Exception:
    db = None

MOCK_DB = os.getenv("MOCK_DB", "0") == "1"

router = APIRouter(prefix="/api/matches", tags=["matches"])

# In-memory stores for MOCK_DB mode
matches_store: Dict[str, Dict[str, Any]] = {}
match_events_store: Dict[str, List[Dict[str, Any]]] = {}

# WebSocket connection registry per match
ws_connections: Dict[str, List[WebSocket]] = {}


class CreateMatchRequest(BaseModel):
    mode_id: str = "default_mode"


class JoinMatchRequest(BaseModel):
    match_id: str
    user_id: str


class PlayerLoadout(BaseModel):
    id: str
    title: str
    modifiers_summary: Dict[str, Any] = {}


class Player(BaseModel):
    user_id: str
    loadout: PlayerLoadout | None = None


class MatchPayload(BaseModel):
    match_id: str
    mode_id: str
    state: str
    players: List[Player]
    created_at: datetime


# Helper functions (usable by tests)

def _now():
    return datetime.now(timezone.utc)


async def create_match(mode_id: str = "default_mode") -> Dict[str, Any]:
    match_id = str(uuid.uuid4())
    match = {
        "match_id": match_id,
        "mode_id": mode_id,
        "state": "waiting",
        "players": [],
        "created_at": _now(),
    }
    if MOCK_DB or db is None:
        matches_store[match_id] = match
        match_events_store[match_id] = []
    else:
        await db.matches.insert_one({**match, "created_at": match["created_at"]})
        match_events_store[match_id] = []
    return match


async def _read_user_cards(user_id: str) -> List[Dict[str, Any]]:
    # Returns simplified loadout info for the user
    if MOCK_DB or db is None:
        # look for seeded user_cards in in-memory store if present
        # fallback: return a sample loadout
        return [{"id": "card-sample-1", "title": "Baseline Card", "modifiers_summary": {"speed": 1.0}}]
    docs = await db.user_cards.find({"user_id": user_id}, {"_id": 0}).to_list(10)
    return docs or []


async def join_match_logic(match_id: str, user_id: str) -> Dict[str, Any]:
    # add player; if two players present, activate and broadcast
    if MOCK_DB or db is None:
        match = matches_store.get(match_id)
        if not match:
            raise HTTPException(status_code=404, detail="Match not found")
        # prevent duplicate
        if any(p["user_id"] == user_id for p in match["players"]):
            return match
        loadouts = await _read_user_cards(user_id)
        player = {"user_id": user_id, "loadout": loadouts[0] if loadouts else None}
        match["players"].append(player)
        # persist
        matches_store[match_id] = match
    else:
        match = await db.matches.find_one({"match_id": match_id}, {"_id": 0})
        if not match:
            raise HTTPException(status_code=404, detail="Match not found")
        if any(p["user_id"] == user_id for p in match.get("players", [])):
            return match
        loadouts = await _read_user_cards(user_id)
        player = {"user_id": user_id, "loadout": loadouts[0] if loadouts else None}
        match.setdefault("players", []).append(player)
        await db.matches.update_one({"match_id": match_id}, {"$set": {"players": match["players"]}})

    # If we now have 2 players, activate
    if len(match["players"]) >= 2 and match["state"] != "active":
        match["state"] = "active"
        match["started_at"] = _now()
        # persist changed state
        if MOCK_DB or db is None:
            matches_store[match_id] = match
        else:
            await db.matches.update_one({"match_id": match_id}, {"$set": {"state": "active", "started_at": match["started_at"]}})
        # broadcast match_start and schedule simulated scoring
        asyncio.create_task(_broadcast_match_start_and_simulate(match_id))
    return match


async def _broadcast_match_start_and_simulate(match_id: str):
    # broadcast match_start
    match = matches_store.get(match_id) if MOCK_DB or db is None else await db.matches.find_one({"match_id": match_id}, {"_id": 0})
    if not match:
        return
    payload = {
        "type": "match_start",
        "match_id": match_id,
        "players": match.get("players", []),
        "start_time": match.get("started_at", _now()).isoformat(),
    }
    await _broadcast(match_id, payload)

    # simulate scoring events
    for seq in range(1, 7):
        await asyncio.sleep(1)
        # pick a player round-robin
        players = match.get("players", [])
        if not players:
            break
        player = players[(seq - 1) % len(players)]
        event = {
            "type": "score_event",
            "match_id": match_id,
            "seq": seq,
            "player_id": player.get("user_id"),
            "points": 10 if seq % 2 == 0 else 5,
            "timestamp": _now().isoformat(),
        }
        # persist
        if MOCK_DB or db is None:
            match_events_store.setdefault(match_id, []).append(event)
        else:
            await db.match_events.insert_one(event)
        await _broadcast(match_id, event)


async def _broadcast(match_id: str, message: Dict[str, Any]):
    conns = ws_connections.get(match_id, [])
    to_remove = []
    for ws in conns:
        try:
            await ws.send_json(message)
        except Exception:
            to_remove.append(ws)
    for r in to_remove:
        if r in conns:
            conns.remove(r)


# API endpoints

@router.post("/create")
async def api_create_match(req: CreateMatchRequest):
    match = await create_match(req.mode_id)
    return {"match_id": match["match_id"]}


@router.post("/join")
async def api_join_match(req: JoinMatchRequest):
    match = await join_match_logic(req.match_id, req.user_id)
    return {"match": match}


@router.get("/{match_id}")
async def api_get_match(match_id: str):
    if MOCK_DB or db is None:
        match = matches_store.get(match_id)
        events = match_events_store.get(match_id, [])
    else:
        match = await db.matches.find_one({"match_id": match_id}, {"_id": 0})
        events = await db.match_events.find({"match_id": match_id}, {"_id": 0}).sort("timestamp", -1).to_list(50)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    return {"match": match, "events": events}


@router.websocket("/ws/match/{match_id}")
async def websocket_match(websocket: WebSocket, match_id: str):
    await websocket.accept()
    ws_connections.setdefault(match_id, []).append(websocket)
    try:
        while True:
            # echo incoming pings or simple client messages; server-driven events are broadcast elsewhere
            data = await websocket.receive_text()
            # optionally, you could allow clients to submit actions here
            await websocket.send_text(f"ack: {data}")
    except WebSocketDisconnect:
        conns = ws_connections.get(match_id, [])
        if websocket in conns:
            conns.remove(websocket)


# Debug probes for Nexus

@router.get("/debug/latest-system-scan")
async def api_latest_system_scan(user_id: str | None = None):
    # Return the latest system scan for a user; for MOCK_DB, return a sample payload
    if MOCK_DB or db is None:
        sample = {
            "user_id": user_id or "demo_user",
            "schemaVersion": 1,
            "capturedAt": _now().isoformat(),
            "readiness": {"neuralReadinessScore": 72.5, "grade": "PRIMED"},
            "avatar": {"explosiveness": 0.6, "endurance": 0.7, "neuralFocus": 0.5},
        }
        return sample
    # otherwise read from Firestore/Mongo
    doc = await db.system_scans.find_one({"user_id": user_id}, {"_id": 0}, sort=[("capturedAt", -1)])
    return doc or {}


@router.get("/debug/match/{match_id}/payload")
async def api_debug_match_payload(match_id: str):
    if MOCK_DB or db is None:
        match = matches_store.get(match_id)
        events = match_events_store.get(match_id, [])
    else:
        match = await db.matches.find_one({"match_id": match_id}, {"_id": 0})
        events = await db.match_events.find({"match_id": match_id}, {"_id": 0}).to_list(100)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    return {"match": match, "events": events}
