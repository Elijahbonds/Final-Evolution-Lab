"""
FEL OS — Brain Brawl round engine (nexus/brainbrawl-demo).

Server-authoritative trivia rounds on top of the Nexus match contract:

  POST /api/brainbrawl/rounds/start                — start a Blitz / Deep Dive round
  POST /api/brainbrawl/rounds/{round_id}/answer    — grade one answer (server-side)
  GET  /api/brainbrawl/rounds/{round_id}           — round state (client-safe)
  GET  /api/brainbrawl/rounds/{round_id}/export-replay — {metadata, events} replay
  GET  /api/brainbrawl/content/summary             — bank taxonomy/counts (no answers)
  GET  /api/brainbrawl/recording-pack              — RECORDING_LOCAL=1 only: full pack
                                                     for locally-authoritative recording

Adaptive ELO ladder (nexus/brainbrawl-ladder, stacks on #126):
  POST /api/brainbrawl/ladder/start                — start an adaptive ladder run
  POST /api/brainbrawl/ladder/{round_id}/answer    — grade + Elo-update + adapt next
  GET  /api/brainbrawl/ladder/rating               — a player's current ladder rating
  GET  /api/brainbrawl/practice-suggestions        — weakest-skill drill recommendations

  The ladder reuses the server-authoritative scoring engine, then folds each
  graded answer into a standard Elo rating (lib/brainbrawl_ladder.py). The next
  question's difficulty is derived from the running rating, so a winning player
  is fed progressively harder questions. Rating + per-skill accuracy are held in
  an in-memory per-player store (demo scope, same as rounds).

Security model (EDU-06/07 style):
  * Question text/options are fetched server-side from backend/content/*.json.
  * Correct answers, explanations, and micro-lessons are NEVER shipped to the
    client before that question is resolved.
  * match.seed (64-bit, lib/match_utils.generate_seed) drives the question
    order deterministically; the replay re-derives it (tools/replay_validator).
  * The only exception is the recording pack, which requires the operator to
    set RECORDING_LOCAL=1 on the server (screen-recording demo mode).

Rounds are kept in an in-memory store (same pattern as routers/matches.py in
MOCK_DB mode) — demo scope; persistence noted in the PR.
"""
import os
import time
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, Field

from lib import brainbrawl as bb
from lib import brainbrawl_ladder as ladder
from lib.match_utils import generate_seed

router = APIRouter(tags=["brainbrawl"])

_rounds: Dict[str, Dict[str, Any]] = {}

# Per-player ladder state (demo scope, in-memory like _rounds):
#   rating: int Elo rating
#   skills: {skill: {"attempts": int, "correct": int}} accuracy history
_ladder_players: Dict[str, Dict[str, Any]] = {}


def _player_state(player_id: str) -> Dict[str, Any]:
    st = _ladder_players.get(player_id)
    if st is None:
        st = {"rating": ladder.DEFAULT_RATING, "skills": {}}
        _ladder_players[player_id] = st
    return st


def _record_skill(state: Dict[str, Any], question: Dict[str, Any],
                  full_correct: bool) -> None:
    skill = question["taxonomy"].get("skill", "unknown")
    bucket = state["skills"].setdefault(skill, {"attempts": 0, "correct": 0})
    bucket["attempts"] += 1
    if full_correct:
        bucket["correct"] += 1

_RECORDING_LOCAL = lambda: os.environ.get("RECORDING_LOCAL", "0") == "1"  # noqa: E731


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _append_event(rnd: Dict[str, Any], event: Dict[str, Any]) -> Dict[str, Any]:
    event["seq"] = len(rnd["events"])
    event.setdefault("timestamp", _now_iso())
    rnd["events"].append(event)
    return event


# ── Schemas ─────────────────────────────────────────────────────────────────

class StartRoundRequest(BaseModel):
    mode: str = "blitz"                      # blitz | deep_dive
    player_id: Optional[str] = None
    category: Optional[str] = None           # taxonomy category or "all"
    question_count: Optional[int] = Field(default=None, ge=1, le=25)
    seed: Optional[int] = None               # fixed seed for QA/recording; else random 64-bit
    time_limit_ms: Optional[int] = Field(default=None, ge=5_000, le=60_000)


class AnswerRequest(BaseModel):
    question_index: int = Field(ge=0)
    selected: List[int] = Field(default_factory=list)   # option indices (multi-select capable)
    client_ts: Optional[float] = None                   # client wall-clock at submit (replay input)
    response_ms: int = Field(default=0, ge=0)           # client-measured question->answer time
    latency_ms: int = Field(default=0, ge=0)            # client's RTT/2 estimate (normalization)


# ── Helpers ─────────────────────────────────────────────────────────────────

def _get_round(round_id: str) -> Dict[str, Any]:
    rnd = _rounds.get(round_id)
    if not rnd:
        raise HTTPException(status_code=404, detail="Round not found")
    return rnd


def _issue_question(rnd: Dict[str, Any]) -> Dict[str, Any]:
    """Mark the current question issued (server timestamp) and emit its event."""
    idx = rnd["current_index"]
    q = rnd["questions"][idx]
    rnd["issued_at_monotonic"] = time.monotonic()
    _append_event(rnd, {
        "type": "question_presented",
        "index": idx,
        "question_id": q["id"],
        "player_id": rnd["player_id"],
    })
    return bb.public_question(q, idx, rnd["time_limit_ms"])


def _standings(rnd: Dict[str, Any]) -> List[Dict[str, Any]]:
    return bb.resolve_standings([{
        "player_id": rnd["player_id"],
        "score": rnd["score"],
        "total_normalized_ms": rnd["total_normalized_ms"],
    }])


# ── Endpoints ───────────────────────────────────────────────────────────────

@router.post("/api/brainbrawl/rounds/start")
async def start_round(body: StartRoundRequest, request: Request) -> Dict[str, Any]:
    if body.mode not in bb.MODES:
        raise HTTPException(status_code=422, detail=f"mode must be one of {sorted(bb.MODES)}")
    mode_cfg = bb.MODES[body.mode]
    doc = bb.load_content()

    seed = body.seed if body.seed is not None else generate_seed()
    count = body.question_count or mode_cfg["default_question_count"]
    time_limit_ms = body.time_limit_ms or mode_cfg["time_limit_ms"]
    if body.mode == "deep_dive":
        count = 1
        time_limit_ms = max(30_000, min(60_000, time_limit_ms))

    order = bb.derive_question_order(seed, body.mode, count, body.category, doc)
    if not order:
        raise HTTPException(status_code=422, detail="No questions for that mode/category")
    questions = [bb.question_by_id(qid, doc) for qid in order]

    player_id = body.player_id or request.headers.get("X-FEL-Sim-Player", "quickplay_guest")
    round_id = f"bbr_{uuid.uuid4().hex[:12]}"
    rnd: Dict[str, Any] = {
        "round_id": round_id,
        "mode": body.mode,
        "mode_id": mode_cfg["mode_id"],
        "seed": seed,
        "category": body.category,
        "content_hash": bb.content_hash(doc),
        "time_limit_ms": time_limit_ms,
        "player_id": player_id,
        "questions": questions,
        "current_index": 0,
        "score": 0,
        "streak": 0,
        "total_normalized_ms": 0,
        "status": "active",
        "created_at": _now_iso(),
        "finished_at": None,
        "events": [],
        "issued_at_monotonic": None,
    }
    _rounds[round_id] = rnd
    _append_event(rnd, {
        "type": "round_start",
        "round_id": round_id,
        "mode": body.mode,
        "mode_id": mode_cfg["mode_id"],
        "seed": seed,
        "category": body.category,
        "content_hash": rnd["content_hash"],
        "time_limit_ms": time_limit_ms,
        "question_count": len(questions),
        "player_id": player_id,
    })
    first_question = _issue_question(rnd)

    return {
        "round_id": round_id,
        "mode": body.mode,
        "mode_id": mode_cfg["mode_id"],
        "seed": seed,                      # shown in UI for QA / recording
        "status": "active",
        "player_id": player_id,
        "time_limit_ms": time_limit_ms,
        "question_count": len(questions),
        "question": first_question,       # answer/explanation stripped
        "scoring": {
            "base_points": bb.BASE_POINTS,
            "streak_step_pct": bb.STREAK_STEP_PCT,
            "streak_cap": bb.STREAK_CAP,
        },
    }


@router.post("/api/brainbrawl/rounds/{round_id}/answer")
async def submit_answer(round_id: str, body: AnswerRequest) -> Dict[str, Any]:
    rnd = _get_round(round_id)
    if rnd["status"] != "active":
        raise HTTPException(status_code=409, detail=f"Round already {rnd['status']}")
    if body.question_index != rnd["current_index"]:
        raise HTTPException(
            status_code=409,
            detail=f"Expected answer for question {rnd['current_index']}, got {body.question_index}",
        )

    q = rnd["questions"][rnd["current_index"]]
    time_limit_ms = rnd["time_limit_ms"]

    # Server-authoritative timing: the client-claimed response time may never
    # exceed the server-observed elapsed time (small grace for transport).
    server_elapsed_ms = int((time.monotonic() - rnd["issued_at_monotonic"]) * 1000) + 1500
    response_ms = min(int(body.response_ms), server_elapsed_ms, time_limit_ms)

    result = bb.score_answer(q, body.selected, response_ms, body.latency_ms,
                             time_limit_ms, rnd["streak"])
    rnd["streak"] = result["streak_after"]
    rnd["score"] += result["points"]
    rnd["total_normalized_ms"] += result["normalized_ms"]

    # Original inputs are echoed verbatim so the replay validator can re-score
    # this answer with zero access to live state.
    inputs = {
        "selected": result["selected"],
        "client_ts": body.client_ts,
        "response_ms": response_ms,          # post-clamp value used for scoring
        "claimed_response_ms": int(body.response_ms),
        "latency_ms": int(body.latency_ms),
    }
    _append_event(rnd, {
        "type": "answer_submitted",
        "index": rnd["current_index"],
        "question_id": q["id"],
        "player_id": rnd["player_id"],
        "inputs": inputs,
    })
    _append_event(rnd, {
        "type": "answer_result",
        "index": rnd["current_index"],
        "question_id": q["id"],
        "player_id": rnd["player_id"],
        "inputs": inputs,
        "points": result["points"],
        "raw_points": result["raw_points"],
        "streak_bonus": result["streak_bonus"],
        "full_correct": result["full_correct"],
        "credit": [result["credit_numerator"], result["credit_denominator"]],
        "streak_after": result["streak_after"],
        "score_snapshot": {rnd["player_id"]: rnd["score"]},
    })

    # Post-resolution reveal: answer + explanation + micro-lesson are only
    # released now that this question can no longer be answered.
    reveal = {
        "correct_answer": result["correct_answer"],
        "explanation": q.get("explanation"),
        "micro_lesson": q.get("micro_lesson"),
    }

    rnd["current_index"] += 1
    next_question = None
    if rnd["current_index"] < len(rnd["questions"]):
        next_question = _issue_question(rnd)
    else:
        rnd["status"] = "finished"
        rnd["finished_at"] = _now_iso()
        _append_event(rnd, {
            "type": "round_end",
            "round_id": round_id,
            "score": {rnd["player_id"]: rnd["score"]},
            "total_normalized_ms": {rnd["player_id"]: rnd["total_normalized_ms"]},
            "standings": _standings(rnd),
            "tie_break_rule": "latency_normalized_time",
        })

    return {
        "round_id": round_id,
        "status": rnd["status"],
        "result": {
            "full_correct": result["full_correct"],
            "points": result["points"],
            "raw_points": result["raw_points"],
            "streak_bonus": result["streak_bonus"],
            "streak": result["streak_after"],
            "credit": [result["credit_numerator"], result["credit_denominator"]],
            "normalized_ms": result["normalized_ms"],
            **reveal,
        },
        "score": rnd["score"],
        "next_question": next_question,
        "standings": _standings(rnd) if rnd["status"] == "finished" else None,
    }


@router.get("/api/brainbrawl/rounds/{round_id}")
async def get_round(round_id: str) -> Dict[str, Any]:
    rnd = _get_round(round_id)
    current = None
    if rnd["status"] == "active":
        current = bb.public_question(
            rnd["questions"][rnd["current_index"]], rnd["current_index"], rnd["time_limit_ms"])
    return {
        "round_id": round_id,
        "mode": rnd["mode"],
        "mode_id": rnd["mode_id"],
        "seed": rnd["seed"],
        "status": rnd["status"],
        "player_id": rnd["player_id"],
        "score": rnd["score"],
        "streak": rnd["streak"],
        "question_count": len(rnd["questions"]),
        "current_index": rnd["current_index"],
        "question": current,
        "time_limit_ms": rnd["time_limit_ms"],
    }


@router.get("/api/brainbrawl/rounds/{round_id}/export-replay")
async def export_round_replay(round_id: str) -> Dict[str, Any]:
    """Replay export — same {metadata, events} contract as match export (Agent 3),
    with original inputs (client timestamps + answers) inside each event."""
    rnd = _get_round(round_id)
    metadata = {
        "match_id": round_id,
        "mode_id": rnd["mode_id"],
        "brainbrawl_mode": rnd["mode"],
        "seed": rnd["seed"],
        "judge_offsets": [],               # N/A for trivia; kept for contract shape
        "category": rnd["category"],
        "content_hash": rnd["content_hash"],
        "time_limit_ms": rnd["time_limit_ms"],
        "question_count": len(rnd["questions"]),
        "players": [rnd["player_id"]],
        "start_time": rnd["created_at"],
        "finished_at": rnd["finished_at"],
        "status": rnd["status"],
        "export_version": "1.1",
        "event_count": len(rnd["events"]),
    }
    return {"metadata": metadata, "events": rnd["events"]}


@router.get("/api/brainbrawl/content/summary")
async def content_summary() -> Dict[str, Any]:
    """QA probe: bank size + taxonomy. Never includes answers."""
    doc = bb.load_content()
    by_cat: Dict[str, int] = {}
    by_diff: Dict[str, int] = {}
    for q in doc["questions"]:
        by_cat[q["taxonomy"]["category"]] = by_cat.get(q["taxonomy"]["category"], 0) + 1
        by_diff[q["difficulty"]] = by_diff.get(q["difficulty"], 0) + 1
    return {
        "content_id": doc.get("content_id"),
        "question_count": len(doc["questions"]),
        "content_hash": bb.content_hash(doc),
        "categories": by_cat,
        "difficulties": by_diff,
        "deep_dive_pool": sum(1 for q in doc["questions"] if "deep_dive" in q["modes"]),
        "multi_select_pool": sum(1 for q in doc["questions"] if q["type"] == "multi"),
        "sources": doc.get("sources", {}),
    }


@router.get("/api/brainbrawl/recording-pack")
async def recording_pack(mode: str = "blitz", seed: Optional[int] = None,
                         count: Optional[int] = None,
                         category: Optional[str] = None) -> Dict[str, Any]:
    """Locally-authoritative pack for screen recording (RECORDING_LOCAL=1 only).

    This is the ONLY route that ships answers pre-resolution: the client runs
    the whole round locally (no network jitter mid-recording). Gated behind an
    explicit operator env var; 403 otherwise.
    """
    if not _RECORDING_LOCAL():
        raise HTTPException(
            status_code=403,
            detail="Recording pack requires RECORDING_LOCAL=1 on the server",
        )
    if mode not in bb.MODES:
        raise HTTPException(status_code=422, detail=f"mode must be one of {sorted(bb.MODES)}")
    doc = bb.load_content()
    mode_cfg = bb.MODES[mode]
    seed = seed if seed is not None else generate_seed()
    count = count or mode_cfg["default_question_count"]
    if mode == "deep_dive":
        count = 1
    order = bb.derive_question_order(seed, mode, count, category, doc)
    questions = [bb.question_by_id(qid, doc) for qid in order]
    return {
        "mode": mode,
        "mode_id": mode_cfg["mode_id"],
        "seed": seed,
        "time_limit_ms": mode_cfg["time_limit_ms"],
        "content_hash": bb.content_hash(doc),
        "scoring": {
            "base_points": bb.BASE_POINTS,
            "streak_step_pct": bb.STREAK_STEP_PCT,
            "streak_cap": bb.STREAK_CAP,
            "max_latency_credit_ms": bb.MAX_LATENCY_CREDIT_MS,
        },
        "questions": questions,   # full payloads incl. answers — recording mode only
    }


# ── Adaptive ELO ladder ─────────────────────────────────────────────────────

class LadderStartRequest(BaseModel):
    player_id: Optional[str] = None
    category: Optional[str] = None                       # taxonomy category or "all"
    question_count: int = Field(default=10, ge=1, le=25)
    seed: Optional[int] = None                           # fixed seed for QA/recording
    time_limit_ms: Optional[int] = Field(default=None, ge=5_000, le=60_000)


class LadderAnswerRequest(BaseModel):
    question_index: int = Field(ge=0)
    selected: List[int] = Field(default_factory=list)
    client_ts: Optional[float] = None
    response_ms: int = Field(default=0, ge=0)
    latency_ms: int = Field(default=0, ge=0)


def _issue_ladder_question(rnd: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    """Adaptively pick + issue the next ladder question from the running rating.

    Returns the client-safe question payload, or None when the run is complete
    (target count reached or the bank is exhausted).
    """
    if len(rnd["served"]) >= rnd["question_count"]:
        return None
    qid = ladder.select_adaptive_question(
        rating=rnd["rating"],
        seed=rnd["seed"],
        mode="blitz",
        category=rnd["category"],
        exclude=rnd["served"],
        doc=bb.load_content(),
    )
    if qid is None:
        return None
    q = bb.question_by_id(qid)
    idx = len(rnd["served"])
    rnd["served"].append(qid)
    rnd["current_question"] = q
    rnd["current_index"] = idx
    rnd["issued_at_monotonic"] = time.monotonic()
    _append_event(rnd, {
        "type": "question_presented",
        "index": idx,
        "question_id": qid,
        "player_id": rnd["player_id"],
        "target_difficulty": ladder.target_difficulty(rnd["rating"]),
        "rating_at_issue": rnd["rating"],
    })
    return {**bb.public_question(q, idx, rnd["time_limit_ms"]),
            "rating_at_issue": rnd["rating"],
            "target_difficulty": ladder.target_difficulty(rnd["rating"])}


@router.post("/api/brainbrawl/ladder/start")
async def ladder_start(body: LadderStartRequest, request: Request) -> Dict[str, Any]:
    """Start an adaptive ladder run. The player's persisted rating seeds the
    first question's difficulty; each answer re-adapts the next (see answer)."""
    doc = bb.load_content()
    player_id = body.player_id or request.headers.get("X-FEL-Sim-Player", "quickplay_guest")
    state = _player_state(player_id)

    seed = body.seed if body.seed is not None else generate_seed()
    time_limit_ms = body.time_limit_ms or bb.MODES["blitz"]["time_limit_ms"]
    round_id = f"bbl_{uuid.uuid4().hex[:12]}"
    rnd: Dict[str, Any] = {
        "round_id": round_id,
        "mode": "ladder",
        "mode_id": "brainbrawl_ladder",
        "seed": seed,
        "category": body.category,
        "content_hash": bb.content_hash(doc),
        "time_limit_ms": time_limit_ms,
        "player_id": player_id,
        "question_count": body.question_count,
        "served": [],                     # question ids served so far (exclude set)
        "current_question": None,
        "current_index": 0,
        "score": 0,
        "streak": 0,
        "total_normalized_ms": 0,
        "rating": state["rating"],        # snapshot at start; updated per answer
        "start_rating": state["rating"],
        "rating_trace": [],
        "status": "active",
        "created_at": _now_iso(),
        "finished_at": None,
        "events": [],
        "issued_at_monotonic": None,
    }
    _rounds[round_id] = rnd
    _append_event(rnd, {
        "type": "round_start",
        "round_id": round_id,
        "mode": "ladder",
        "mode_id": "brainbrawl_ladder",
        "seed": seed,
        "category": body.category,
        "content_hash": rnd["content_hash"],
        "time_limit_ms": time_limit_ms,
        "question_count": body.question_count,
        "start_rating": state["rating"],
        "player_id": player_id,
    })
    first_question = _issue_ladder_question(rnd)
    if first_question is None:
        raise HTTPException(status_code=422, detail="No questions for that category")

    return {
        "round_id": round_id,
        "mode": "ladder",
        "mode_id": "brainbrawl_ladder",
        "seed": seed,
        "status": "active",
        "player_id": player_id,
        "time_limit_ms": time_limit_ms,
        "question_count": body.question_count,
        "ladder": ladder.band_summary(rnd["rating"]),
        "question": first_question,     # answer/explanation stripped
        "scoring": {
            "base_points": bb.BASE_POINTS,
            "streak_step_pct": bb.STREAK_STEP_PCT,
            "streak_cap": bb.STREAK_CAP,
        },
    }


@router.post("/api/brainbrawl/ladder/{round_id}/answer")
async def ladder_answer(round_id: str, body: LadderAnswerRequest) -> Dict[str, Any]:
    rnd = _get_round(round_id)
    if rnd.get("mode") != "ladder":
        raise HTTPException(status_code=409, detail="Not a ladder round")
    if rnd["status"] != "active":
        raise HTTPException(status_code=409, detail=f"Round already {rnd['status']}")
    if body.question_index != rnd["current_index"]:
        raise HTTPException(
            status_code=409,
            detail=f"Expected answer for question {rnd['current_index']}, got {body.question_index}",
        )

    q = rnd["current_question"]
    time_limit_ms = rnd["time_limit_ms"]
    server_elapsed_ms = int((time.monotonic() - rnd["issued_at_monotonic"]) * 1000) + 1500
    response_ms = min(int(body.response_ms), server_elapsed_ms, time_limit_ms)

    result = bb.score_answer(q, body.selected, response_ms, body.latency_ms,
                             time_limit_ms, rnd["streak"])
    rnd["streak"] = result["streak_after"]
    rnd["score"] += result["points"]
    rnd["total_normalized_ms"] += result["normalized_ms"]

    # Elo update from this answer's credit fraction, then persist to the player.
    prior_rating = rnd["rating"]
    delta = ladder.apply_answer(prior_rating, q, result)
    rnd["rating"] = delta["new_rating"]
    rnd["rating_trace"].append(delta)
    state = _player_state(rnd["player_id"])
    state["rating"] = delta["new_rating"]
    _record_skill(state, q, result["full_correct"])

    inputs = {
        "selected": result["selected"],
        "client_ts": body.client_ts,
        "response_ms": response_ms,
        "claimed_response_ms": int(body.response_ms),
        "latency_ms": int(body.latency_ms),
    }
    _append_event(rnd, {
        "type": "answer_submitted",
        "index": rnd["current_index"],
        "question_id": q["id"],
        "player_id": rnd["player_id"],
        "inputs": inputs,
    })
    _append_event(rnd, {
        "type": "answer_result",
        "index": rnd["current_index"],
        "question_id": q["id"],
        "player_id": rnd["player_id"],
        "inputs": inputs,
        "points": result["points"],
        "raw_points": result["raw_points"],
        "streak_bonus": result["streak_bonus"],
        "full_correct": result["full_correct"],
        "credit": [result["credit_numerator"], result["credit_denominator"]],
        "streak_after": result["streak_after"],
        "score_snapshot": {rnd["player_id"]: rnd["score"]},
        "rating_before": prior_rating,
        "rating_after": delta["new_rating"],
        "rating_delta": delta["delta"],
    })

    reveal = {
        "correct_answer": result["correct_answer"],
        "explanation": q.get("explanation"),
        "micro_lesson": q.get("micro_lesson"),
    }

    # Adapt: next question difficulty is derived from the UPDATED rating.
    next_question = _issue_ladder_question(rnd)
    if next_question is None:
        rnd["status"] = "finished"
        rnd["finished_at"] = _now_iso()
        rnd["current_question"] = None
        _append_event(rnd, {
            "type": "round_end",
            "round_id": round_id,
            "score": {rnd["player_id"]: rnd["score"]},
            "total_normalized_ms": {rnd["player_id"]: rnd["total_normalized_ms"]},
            "start_rating": rnd["start_rating"],
            "final_rating": rnd["rating"],
            "tie_break_rule": "latency_normalized_time",
        })

    return {
        "round_id": round_id,
        "status": rnd["status"],
        "result": {
            "full_correct": result["full_correct"],
            "points": result["points"],
            "raw_points": result["raw_points"],
            "streak_bonus": result["streak_bonus"],
            "streak": result["streak_after"],
            "credit": [result["credit_numerator"], result["credit_denominator"]],
            "normalized_ms": result["normalized_ms"],
            "rating_before": prior_rating,
            "rating_after": delta["new_rating"],
            "rating_delta": delta["delta"],
            "expected_score": delta["expected_score"],
            "actual_score": delta["actual_score"],
            **reveal,
        },
        "score": rnd["score"],
        "ladder": ladder.band_summary(rnd["rating"]),
        "next_question": next_question,
    }


@router.get("/api/brainbrawl/ladder/rating")
async def ladder_rating(player_id: str) -> Dict[str, Any]:
    """A player's current ladder rating + band (client-safe; no answers)."""
    state = _player_state(player_id)
    summary = ladder.band_summary(state["rating"])
    total_attempts = sum(s["attempts"] for s in state["skills"].values())
    total_correct = sum(s["correct"] for s in state["skills"].values())
    return {
        "player_id": player_id,
        **summary,
        "attempts": total_attempts,
        "correct": total_correct,
        "skills_tracked": len(state["skills"]),
    }


@router.get("/api/brainbrawl/practice-suggestions")
async def practice_suggestions(player_id: str, seed: int = 0,
                               top_skills: int = 3, drill_size: int = 5,
                               mode: str = "blitz") -> Dict[str, Any]:
    """Weakest-skill drill recommendations for a player (deterministic).

    Ranks the player's tracked skills weakest-first from their accuracy history
    and returns drill sets of client-safe questions targeting them. Questions
    go through bb.public_question, so answers/explanations are never shipped.
    """
    if mode not in bb.MODES:
        raise HTTPException(status_code=422, detail=f"mode must be one of {sorted(bb.MODES)}")
    state = _player_state(player_id)
    suggestions = ladder.practice_suggestions(
        history=state["skills"],
        seed=seed,
        top_skills=top_skills,
        drill_size=drill_size,
        mode=mode,
    )
    return {
        "player_id": player_id,
        "rating": state["rating"],
        **suggestions,
    }
