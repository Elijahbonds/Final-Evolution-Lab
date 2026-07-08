"""
FEL OS — Server-authoritative ball-sports resolution (Nexus AAA).

POST /api/sports/soccer/resolve-kick

Resolves a soccer penalty kick server-side through the shared deterministic
ball-physics core (lib/ball_physics.py) + soccer adjudication rule
(lib/sports/soccer.py). Same inputs (+ optional wind_seed) → byte-identical
trajectory + identical outcome, every call.

The resolved kick is appended to the match replay event store as a
`soccer_kick_result` event, echoing the raw inputs and the trajectory path
hash so `tools/replay_validator.py` can re-derive the outcome and verify it.
"""
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

import lib.sports  # noqa: F401 — registers sports into REGISTRY on import
from lib.ball_physics import REGISTRY
from routers.matches import _broadcast, _load_match, _persist_event

router = APIRouter(tags=["sports"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


class SoccerKickRequest(BaseModel):
    match_id: Optional[str] = None       # if set, append result to that match's replay log
    player_id: Optional[str] = None
    speed: float = Field(default=25.0, gt=0.0, le=60.0)     # m/s
    aim_x: float = Field(default=0.0, ge=-10.0, le=10.0)    # m, horizontal aim at goal line
    aim_z: float = Field(default=1.0, ge=0.0, le=5.0)       # m, target height
    spin_rps: float = Field(default=0.0, ge=-15.0, le=15.0)  # rev/s sidespin
    wind_seed: Optional[int] = None
    keeper_dive_x: Optional[float] = Field(default=None, ge=-5.0, le=5.0)
    keeper_reach: float = Field(default=1.9, ge=0.0, le=4.0)
    keeper_seed: Optional[int] = None
    include_trajectory: bool = True      # return full sample path in response


def _inputs_from(body: SoccerKickRequest) -> Dict[str, Any]:
    """The exact, replayable input dict fed to the deterministic core."""
    return {
        "speed": body.speed,
        "aim_x": body.aim_x,
        "aim_z": body.aim_z,
        "spin_rps": body.spin_rps,
        "wind_seed": body.wind_seed,
        "keeper_dive_x": body.keeper_dive_x,
        "keeper_reach": body.keeper_reach,
        "keeper_seed": body.keeper_seed,
    }


@router.post("/api/sports/soccer/resolve-kick")
async def resolve_soccer_kick(body: SoccerKickRequest) -> Dict[str, Any]:
    """Deterministically resolve a soccer penalty kick and (optionally) log it."""
    inputs = _inputs_from(body)
    try:
        trajectory, outcome = REGISTRY.resolve("soccer", inputs)
    except KeyError as exc:  # pragma: no cover — soccer is always registered
        raise HTTPException(status_code=500, detail=str(exc))

    path_hash = trajectory.path_hash()

    # Append to the replay event store when tied to a match.
    if body.match_id:
        match = await _load_match(body.match_id)
        if not match:
            raise HTTPException(status_code=404, detail="Match not found")
        if match.get("status") == "finished":
            raise HTTPException(status_code=409, detail="Match already finished")
        event = {
            "type": "soccer_kick_result",
            "match_id": body.match_id,
            "player_id": body.player_id,
            "sport": "soccer",
            "outcome": outcome.outcome,
            "detail": outcome.detail,
            "crossing": outcome.crossing,
            "path_hash": path_hash,
            "wind": list(trajectory.wind.quantized().as_tuple()),
            "stop_reason": trajectory.stop_reason,
            "inputs": inputs,           # echoed for deterministic re-derivation
            "timestamp": _now(),
        }
        await _persist_event(body.match_id, event)
        await _broadcast(body.match_id, event)

    response: Dict[str, Any] = {
        "sport": "soccer",
        "outcome": outcome.outcome,
        "detail": outcome.detail,
        "crossing": outcome.crossing,
        "path_hash": path_hash,
        "wind": list(trajectory.wind.quantized().as_tuple()),
        "stop_reason": trajectory.stop_reason,
        "sample_count": len(trajectory.samples),
    }
    if body.include_trajectory:
        response["trajectory"] = trajectory.as_dict()
    return response
