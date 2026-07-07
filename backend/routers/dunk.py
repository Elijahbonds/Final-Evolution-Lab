"""
FEL OS — Server-authoritative dunk scoring (Nexus AAA Sprint 0, Agent 2).

POST /api/matches/{match_id}/score_dunk

Reads the match's seeded `judge_offsets` (see lib/match_utils.derive_judge_offsets)
and computes a deterministic dunk score. Two payload shapes are accepted:

  1. Engine-3D (production parity with Swift DunkContestScoring/WDAScoringEngine):
     {"engine3d": {"jump_height": 0.9, "launch_quality": 0.85, ...}}
  2. Legacy simplified (sim harness / older clients):
     {"approach_quality": 0.8, "execution_quality": 0.9, "style_difficulty": 0.5}

The result is persisted to match_events as a `dunk_result` event (with the raw
inputs echoed so replays can re-verify scoring deterministically).
"""
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from lib.dunk_scoring import (
    DunkEngine3DInput,
    DunkResult,
    TRICK_TABLE,
    score_dunk,
    score_engine3d_dunk,
)
from routers.matches import _broadcast, _load_match, _persist_event

router = APIRouter(tags=["dunk"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


class Engine3DPayload(BaseModel):
    jump_height: float = Field(ge=0.0, le=1.0)
    launch_quality: float = Field(ge=0.0, le=1.0)
    landing_quality: float = Field(ge=0.0, le=1.0)
    completed_rotation: float = Field(ge=0.0, le=1.0)
    trick: str = "rim_grazer"
    ball_rotation_degrees: Optional[float] = None
    flight_hang_time_seconds: Optional[float] = None
    attempts_count: int = Field(default=1, ge=1)
    time_spent_seconds: float = Field(default=0.0, ge=0.0)
    freestyle_points: int = Field(default=0, ge=0)
    mid_air_branch_count: int = Field(default=0, ge=0)
    style_landing_success: bool = False
    modifier_score_multiplier: float = Field(default=1.0, ge=1.0, le=2.0)
    knee_valgus_detected: bool = False
    ankle_pronation_detected: bool = False
    signature_difficulty_bonus: Optional[float] = None


class ScoreDunkRequest(BaseModel):
    # Engine-3D payload (preferred; Swift/NEXUS parity)
    engine3d: Optional[Engine3DPayload] = None
    # Legacy simplified payload
    approach_quality: Optional[float] = None
    execution_quality: Optional[float] = None
    style_difficulty: float = 0.5
    player_id: Optional[str] = None


def _score(body: ScoreDunkRequest, judge_offsets: List[int]) -> tuple:
    """Returns (result, scoring_model, inputs_echo)."""
    if body.engine3d is not None:
        if body.engine3d.trick not in TRICK_TABLE:
            raise HTTPException(status_code=422, detail=f"Unknown trick '{body.engine3d.trick}'")
        payload = body.engine3d.model_dump()
        result = score_engine3d_dunk(DunkEngine3DInput(**payload), judge_offsets)
        return result, "wda_engine3d", {"engine3d": payload}
    if body.approach_quality is None or body.execution_quality is None:
        raise HTTPException(
            status_code=422,
            detail="Provide either 'engine3d' payload or legacy 'approach_quality'+'execution_quality'",
        )
    result = score_dunk(
        approach_quality=max(0.0, min(1.0, body.approach_quality)),
        execution_quality=max(0.0, min(1.0, body.execution_quality)),
        style_difficulty=max(0.0, min(1.0, body.style_difficulty)),
        judge_offsets=judge_offsets,
    )
    inputs = {
        "approach_quality": body.approach_quality,
        "execution_quality": body.execution_quality,
        "style_difficulty": body.style_difficulty,
    }
    return result, "legacy_simple", inputs


@router.post("/api/matches/{match_id}/score_dunk")
async def score_dunk_endpoint(match_id: str, body: ScoreDunkRequest) -> Dict[str, Any]:
    """Compute server-authoritative dunk score using the match's seeded judge_offsets."""
    match = await _load_match(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    judge_offsets = match.get("judge_offsets", [0, 0, 0])

    result, scoring_model, inputs = _score(body, judge_offsets)

    event = {
        "type": "dunk_result",
        "match_id": match_id,
        "player_id": body.player_id,
        "scoring_model": scoring_model,
        "j1": result.j1, "j2": result.j2, "j3": result.j3,
        "total": result.total, "message": result.message,
        "is_perfect": result.is_perfect,
        "judge_offsets": judge_offsets,
        "inputs": inputs,
        "timestamp": _now(),
    }
    await _persist_event(match_id, event)
    await _broadcast(match_id, event)
    return {
        "j1": result.j1, "j2": result.j2, "j3": result.j3,
        "total": result.total, "message": result.message,
        "is_perfect": result.is_perfect, "scoring_model": scoring_model,
    }
