"""
carnival.py (router) — Court Carnival hybrid party-mode HTTP + replay shell.

Thin server-authoritative wrapper over :mod:`lib.carnival`. Every mutating
call appends a ``carnival_*`` event to a per-match replay stream so the whole
match — board spins and mini-game resolutions — can be exported and replayed
through ``tools/replay_validator.py``.

Endpoints
---------
  POST /api/carnival/create                  create a match (players, seed, rounds)
  GET  /api/carnival/{mid}                    full board state + standings
  POST /api/carnival/{mid}/spin              advance active player (seeded spinner)
  GET  /api/carnival/{mid}/minigame          pending mini-game instance (client build)
  POST /api/carnival/{mid}/minigame/submit    submit inputs; server resolves + awards
  GET  /api/carnival/{mid}/standings         current standings
  GET  /api/carnival/{mid}/export-replay      {metadata, events} replay export
  GET  /api/carnival/{mid}/highlights         top plays derived from the event stream

MOCK_DB=1 uses in-memory stores identical to the matches router pattern.
No wall-clock or ``Math.random`` touches authoritative state — all randomness
derives from the match seed via :mod:`lib.carnival`.
"""
import os
import sys
import uuid
from dataclasses import asdict
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel

from core import get_current_user, User
from lib.match_utils import generate_seed, derive_judge_offsets
from lib import carnival as C

router = APIRouter(tags=["carnival"])

_MOCK_DB = os.environ.get("MOCK_DB", "0") == "1" or (
    len(sys.argv) > 0 and "pytest" in sys.argv[0]
)

# In-memory stores (MOCK_DB). Board is stored as a serialized dict; events are
# the replay stream.
_boards: Dict[str, Dict[str, Any]] = {}
_events: Dict[str, List[Dict[str, Any]]] = {}
_meta: Dict[str, Dict[str, Any]] = {}


# ── Auth (guest fallback under MOCK_DB, like matches router) ─────────────────

async def get_carnival_user(request: Request) -> User:
    try:
        return await get_current_user(request)
    except Exception:
        if not _MOCK_DB:
            raise
        pid = request.headers.get("X-FEL-Sim-Player", "sim_guest")
        return User(user_id=pid, email=f"{pid}@sim.fellab.io", name=pid)


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


# ── Board (de)serialization ──────────────────────────────────────────────────

def _serialize(board: C.CarnivalBoard) -> Dict[str, Any]:
    d = asdict(board)
    return d


def _deserialize(d: Dict[str, Any]) -> C.CarnivalBoard:
    players = [C.CarnivalPlayer(**p) for p in d["players"]]
    return C.CarnivalBoard(
        seed=d["seed"],
        players=players,
        board=d["board"],
        rounds=d["rounds"],
        turn_index=d["turn_index"],
        round_index=d["round_index"],
        active_player=d["active_player"],
        status=d["status"],
        pending_minigame=d.get("pending_minigame"),
        history=d.get("history", []),
    )


def _append_event(mid: str, event: Dict[str, Any]) -> Dict[str, Any]:
    ev = dict(event)
    ev["seq"] = len(_events.get(mid, []))
    _events.setdefault(mid, []).append(ev)
    return ev


# ── Schemas ──────────────────────────────────────────────────────────────────

class PlayerSpec(BaseModel):
    player_id: str
    display_name: Optional[str] = None
    is_ai: bool = False


class CreateCarnivalRequest(BaseModel):
    players: List[PlayerSpec] = []
    rounds: int = C.DEFAULT_ROUNDS
    seed: Optional[int] = None          # override for deterministic recording
    recording: bool = False             # RECORDING_LOCAL solo mode


class SubmitMinigameRequest(BaseModel):
    # player_id -> game-specific input payload (see lib.carnival resolvers).
    # For maze_chase: {pid: [{"tick":int,"move":str}]}
    # For target_burst/rhythm_tap: {pid: {"latency_ms":float,"taps":[...]}}
    inputs: Dict[str, Any] = {}


# ── State builders ───────────────────────────────────────────────────────────

def _public_state(mid: str, board: C.CarnivalBoard) -> Dict[str, Any]:
    meta = _meta.get(mid, {})
    pending = None
    if board.pending_minigame:
        # do not leak resolver-only fields; client gets the full instance to
        # render, which is fine — it is deterministic and server re-resolves.
        pending = {
            "game": board.pending_minigame["game"],
            "instance": board.pending_minigame["instance"],
        }
    return {
        "match_id": mid,
        "mode_id": "carnival_board",
        "seed": board.seed,
        "recording": meta.get("recording", False),
        "status": board.status,
        "rounds": board.rounds,
        "turn_index": board.turn_index,
        "round_index": board.round_index,
        "active_player": board.players[board.active_player].player_id,
        "board": board.board,
        "players": [
            {
                "player_id": p.player_id,
                "display_name": p.display_name,
                "is_ai": p.is_ai,
                "shape": p.shape,
                "color": p.color,
                "position": p.position,
                "coins": p.coins,
                "tokens": p.tokens,
                "total": p.total(),
            }
            for p in board.players
        ],
        "standings": board.standings(),
        "pending_minigame": pending,
    }


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/api/carnival/create")
async def create_carnival(
    body: CreateCarnivalRequest,
    user: User = Depends(get_carnival_user),
) -> Dict[str, Any]:
    mid = "carn_" + str(uuid.uuid4())[:8]
    seed = body.seed if body.seed is not None else generate_seed()

    specs: List[Dict[str, Any]] = [p.dict() for p in body.players]
    if not specs:
        # default: the requesting user + AI fill (solo recording friendly)
        specs = [{"player_id": user.user_id, "display_name": user.name, "is_ai": False}]
    if body.recording:
        # RECORDING_LOCAL: fill up to 4 seats with AI so one person records a
        # full exciting match. Human is player 0.
        i = len(specs)
        while len(specs) < 4:
            specs.append({"player_id": f"cpu_{i}", "display_name": f"CPU {i}", "is_ai": True})
            i += 1

    board = C.CarnivalBoard.create(seed, specs, rounds=body.rounds)
    _boards[mid] = _serialize(board)
    _meta[mid] = {
        "created_at": _now(),
        "recording": body.recording,
        "judge_offsets": derive_judge_offsets(seed),
        "player_ids": [p.player_id for p in board.players],
    }
    _events[mid] = []
    _append_event(mid, {
        "type": "carnival_match_start",
        "seed": seed,
        "rounds": board.rounds,
        "players": [p.player_id for p in board.players],
        "board": board.board,
    })
    return {"match_id": mid, **_public_state(mid, board)}


def _require_board(mid: str) -> C.CarnivalBoard:
    if mid not in _boards:
        raise HTTPException(status_code=404, detail="Carnival match not found")
    return _deserialize(_boards[mid])


@router.get("/api/carnival/{mid}")
async def get_carnival(mid: str) -> Dict[str, Any]:
    board = _require_board(mid)
    return _public_state(mid, board)


@router.post("/api/carnival/{mid}/spin")
async def spin(mid: str) -> Dict[str, Any]:
    board = _require_board(mid)
    if board.status != "active":
        raise HTTPException(status_code=409, detail=f"Match {board.status}")
    event = board.spin_and_advance()
    _boards[mid] = _serialize(board)
    _append_event(mid, event)
    return {"event": event, "state": _public_state(mid, board)}


@router.get("/api/carnival/{mid}/minigame")
async def get_minigame(mid: str) -> Dict[str, Any]:
    board = _require_board(mid)
    if not board.pending_minigame:
        raise HTTPException(status_code=404, detail="No pending mini-game")
    return {
        "game": board.pending_minigame["game"],
        "instance": board.pending_minigame["instance"],
    }


@router.post("/api/carnival/{mid}/minigame/submit")
async def submit_minigame(mid: str, body: SubmitMinigameRequest) -> Dict[str, Any]:
    board = _require_board(mid)
    if not board.pending_minigame:
        raise HTTPException(status_code=409, detail="No pending mini-game")
    event = board.submit_minigame(body.inputs)
    _boards[mid] = _serialize(board)
    _append_event(mid, event)
    if board.status == "finished":
        _append_event(mid, {
            "type": "carnival_match_end",
            "status": "finished",
            "standings": board.standings(),
        })
    return {"event": event, "state": _public_state(mid, board)}


@router.get("/api/carnival/{mid}/standings")
async def standings(mid: str) -> Dict[str, Any]:
    board = _require_board(mid)
    return {"match_id": mid, "status": board.status, "standings": board.standings()}


@router.get("/api/carnival/{mid}/export-replay")
async def export_replay(mid: str) -> Dict[str, Any]:
    if mid not in _boards:
        raise HTTPException(status_code=404, detail="Carnival match not found")
    board = _deserialize(_boards[mid])
    meta = _meta.get(mid, {})
    events = sorted(_events.get(mid, []), key=lambda e: e.get("seq", 0))
    return {
        "metadata": {
            "match_id": mid,
            "mode_id": "carnival_board",
            "seed": board.seed,
            "judge_offsets": meta.get("judge_offsets", []),
            "players": meta.get("player_ids", [p.player_id for p in board.players]),
            "rounds": board.rounds,
            "start_time": meta.get("created_at"),
            "status": board.status,
            "replay_kind": "carnival",
            "export_version": "1.0",
            "event_count": len(events),
        },
        "events": events,
    }


@router.get("/api/carnival/{mid}/highlights")
async def highlights(mid: str) -> Dict[str, Any]:
    """Derive a simple 'highlight reel' from the event stream (top plays)."""
    if mid not in _boards:
        raise HTTPException(status_code=404, detail="Carnival match not found")
    board = _deserialize(_boards[mid])
    plays: List[Dict[str, Any]] = []
    for ev in _events.get(mid, []):
        if ev.get("type") == "carnival_minigame_result":
            game = ev["game"]
            best_pid = max(ev["normalized"], key=lambda k: ev["normalized"][k]) \
                if ev["normalized"] else None
            if best_pid is None:
                continue
            awarded = ev["awards"].get(best_pid, {})
            plays.append({
                "kind": "minigame_win",
                "round": ev["round_index"],
                "game": game,
                "player_id": best_pid,
                "normalized": ev["normalized"][best_pid],
                "awarded": awarded.get("awarded", 0),
                "catchup_mult": awarded.get("catchup_mult", 1.0),
            })
        elif ev.get("type") == "carnival_spin" and ev.get("space_type") == "PRIZE":
            plays.append({
                "kind": "prize",
                "turn": ev.get("turn_index"),
                "player_id": ev.get("player_id"),
                "roll": ev.get("roll"),
            })
    # rank highlights: biggest comebacks + biggest normalized scores first
    plays.sort(
        key=lambda p: (p.get("catchup_mult", 1.0), p.get("normalized", 0)),
        reverse=True,
    )
    return {
        "match_id": mid,
        "status": board.status,
        "final_standings": board.standings(),
        "highlights": plays[:8],
    }
