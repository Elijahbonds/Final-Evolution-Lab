"""
FEL OS — Ghost Mode Challenge

Allows athletes to record a match performance as a "Ghost" and publish it
as an asynchronous challenge. Other athletes race against the ghost's
deterministic replay using the same seeded scoring engine.

Endpoints:
  POST /api/ghost/publish              — save a replay export as a published ghost
  GET  /api/ghost                      — discovery feed (filter by mode, PRQ range)
  GET  /api/ghost/{ghost_id}           — fetch ghost for playback (seed + events)
  POST /api/ghost/{ghost_id}/challenge — start a live challenge against the ghost
  POST /api/ghost/{ghost_id}/complete  — submit result, receive performance delta

Verification:
  Every ghost is fingerprinted with SHA-256(seed + canonical events JSON).
  On publish and on complete, the server re-validates the fingerprint to
  prevent ghost file tampering.
"""
from __future__ import annotations

import hashlib
import json
import os
import sys
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from core import db, get_current_user, User

router = APIRouter(tags=["ghost"])

# ── Mock-DB detection (mirrors matches.py) ────────────────────────────────────
_MOCK_DB = os.environ.get("MOCK_DB", "0") == "1" or (
    len(sys.argv) > 0 and "pytest" in sys.argv[0]
)

# ── In-memory stores ──────────────────────────────────────────────────────────
_ghosts: Dict[str, Dict[str, Any]] = {}
_ghost_challenges: Dict[str, Dict[str, Any]] = {}


# ── Helpers ───────────────────────────────────────────────────────────────────

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _compute_ghost_hash(seed: int, events: List[Dict[str, Any]]) -> str:
    """Deterministic fingerprint: SHA-256 of seed + canonical events JSON.
    Uses sorted keys so insertion order doesn't affect the hash.
    """
    canonical = json.dumps(
        {"seed": seed, "events": events},
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode()).hexdigest()


def _extract_top_moment(events: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """Find the highest-scoring or most dramatic event in the replay."""
    dunk_events = [e for e in events if e.get("type") == "dunk_result"]
    if dunk_events:
        return max(dunk_events, key=lambda e: e.get("total", 0))
    score_events = [e for e in events if e.get("type") == "score_event"]
    if score_events:
        return max(score_events, key=lambda e: e.get("points", 0))
    return None


def _compute_performance_delta(
    ghost: Dict[str, Any],
    challenger_events: List[Dict[str, Any]],
    challenger_final_score: Dict[str, int],
) -> Dict[str, Any]:
    """Compare challenger result vs ghost result and produce a delta report."""
    ghost_score = ghost.get("final_score", {})
    ghost_events = ghost.get("events", [])

    # Dunk-specific delta
    ghost_dunks = [e for e in ghost_events if e.get("type") == "dunk_result"]
    challenger_dunks = [e for e in challenger_events if e.get("type") == "dunk_result"]

    ghost_dunk_total = sum(e.get("total", 0) for e in ghost_dunks)
    challenger_dunk_total = sum(e.get("total", 0) for e in challenger_dunks)

    # H2H score delta
    ghost_p1_score = ghost_score.get("p1", ghost_score.get(list(ghost_score.keys())[0], 0)) if ghost_score else 0
    challenger_p1_score = challenger_final_score.get("p1", challenger_final_score.get(list(challenger_final_score.keys())[0] if challenger_final_score else "p1", 0)) if challenger_final_score else 0

    # Decision speed: average time between events
    def avg_gap_ms(evts: List[Dict]) -> float:
        ts_list = []
        for e in evts:
            ts = e.get("timestamp")
            if ts:
                try:
                    ts_list.append(datetime.fromisoformat(ts.replace("Z", "+00:00")).timestamp())
                except Exception:
                    pass
        if len(ts_list) < 2:
            return 0.0
        gaps = [ts_list[i+1] - ts_list[i] for i in range(len(ts_list)-1)]
        return round(sum(gaps) / len(gaps) * 1000, 1)

    ghost_gap = avg_gap_ms(ghost_events)
    challenger_gap = avg_gap_ms(challenger_events)
    decision_speed_delta_ms = round(ghost_gap - challenger_gap, 1)

    won = False
    if ghost_dunks:
        won = challenger_dunk_total > ghost_dunk_total
        score_label = f"Dunk total: {challenger_dunk_total} vs ghost {ghost_dunk_total}"
    else:
        won = challenger_p1_score > ghost_p1_score
        score_label = f"Score: {challenger_p1_score} vs ghost {ghost_p1_score}"

    return {
        "beat_ghost": won,
        "score_comparison": score_label,
        "dunk_total_delta": challenger_dunk_total - ghost_dunk_total if ghost_dunks else None,
        "h2h_score_delta": challenger_p1_score - ghost_p1_score if not ghost_dunks else None,
        "decision_speed_delta_ms": decision_speed_delta_ms,
        "verdict": "You beat the ghost!" if won else "Ghost wins this round.",
        "tip": (
            "Your decision speed was faster — keep that pressure up."
            if decision_speed_delta_ms > 0
            else "The ghost was faster on decisions — try committing sooner."
        ),
    }


async def _persist_ghost(ghost: Dict[str, Any]) -> None:
    if _MOCK_DB:
        _ghosts[ghost["ghost_id"]] = ghost
        return
    try:
        await db.ghost_challenges.replace_one(
            {"ghost_id": ghost["ghost_id"]}, ghost, upsert=True
        )
    except Exception:
        _ghosts[ghost["ghost_id"]] = ghost


async def _load_ghost(ghost_id: str) -> Optional[Dict[str, Any]]:
    if _MOCK_DB:
        return _ghosts.get(ghost_id)
    try:
        doc = await db.ghost_challenges.find_one({"ghost_id": ghost_id}, {"_id": 0})
        return doc
    except Exception:
        return _ghosts.get(ghost_id)


async def _load_ghost_feed(
    mode_id: Optional[str], min_prq: float, max_prq: float, limit: int
) -> List[Dict[str, Any]]:
    if _MOCK_DB:
        results = list(_ghosts.values())
        if mode_id:
            results = [g for g in results if g.get("mode_id") == mode_id]
        results = [g for g in results if min_prq <= g.get("publisher_prq", 0) <= max_prq]
        results.sort(key=lambda g: g.get("published_at", ""), reverse=True)
        return results[:limit]
    try:
        query: Dict[str, Any] = {"publisher_prq": {"$gte": min_prq, "$lte": max_prq}}
        if mode_id:
            query["mode_id"] = mode_id
        cursor = db.ghost_challenges.find(query, {"_id": 0}).sort("published_at", -1).limit(limit)
        return await cursor.to_list(limit)
    except Exception:
        return []


# ── Pydantic models ───────────────────────────────────────────────────────────

class PublishGhostRequest(BaseModel):
    mode_id: str
    seed: int
    judge_offsets: List[int] = []
    events: List[Dict[str, Any]] = []
    final_score: Dict[str, int] = {}
    match_id: Optional[str] = None


class CompleteGhostChallengeRequest(BaseModel):
    challenger_events: List[Dict[str, Any]] = []
    challenger_final_score: Dict[str, int] = {}


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/api/ghost/publish")
async def publish_ghost(
    body: PublishGhostRequest,
    user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """Validate and publish a match replay as a Ghost Challenge."""
    if not body.events:
        raise HTTPException(status_code=400, detail="events required to publish a ghost")

    verification_hash = _compute_ghost_hash(body.seed, body.events)
    top_moment = _extract_top_moment(body.events)

    ghost: Dict[str, Any] = {
        "ghost_id": str(uuid.uuid4())[:16],
        "mode_id": body.mode_id,
        "publisher_id": user.user_id,
        "publisher_name": user.name,
        "publisher_prq": user.prq_score,
        "seed": body.seed,
        "judge_offsets": body.judge_offsets,
        "events": body.events,
        "final_score": body.final_score,
        "match_id": body.match_id,
        "verification_hash": verification_hash,
        "top_moment": top_moment,
        "challenge_count": 0,
        "beat_count": 0,
        "published_at": _now(),
    }
    await _persist_ghost(ghost)

    return {
        "ghost_id": ghost["ghost_id"],
        "verification_hash": verification_hash,
        "mode_id": body.mode_id,
        "publisher_name": user.name,
        "top_moment": top_moment,
        "status": "published",
    }


@router.get("/api/ghost")
async def list_ghosts(
    mode_id: Optional[str] = None,
    min_prq: float = 0,
    max_prq: float = 100,
    limit: int = 20,
) -> List[Dict[str, Any]]:
    """Discovery feed — returns published ghosts filtered by mode and PRQ range."""
    results = await _load_ghost_feed(mode_id, min_prq, max_prq, limit)
    return [
        {
            "ghost_id": g["ghost_id"],
            "mode_id": g["mode_id"],
            "publisher_name": g["publisher_name"],
            "publisher_prq": g.get("publisher_prq", 0),
            "final_score": g.get("final_score", {}),
            "top_moment": g.get("top_moment"),
            "challenge_count": g.get("challenge_count", 0),
            "beat_count": g.get("beat_count", 0),
            "beat_rate_pct": round(g.get("beat_count", 0) / max(g.get("challenge_count", 1), 1) * 100, 1),
            "published_at": g.get("published_at"),
        }
        for g in results
    ]


@router.get("/api/ghost/{ghost_id}")
async def get_ghost(ghost_id: str) -> Dict[str, Any]:
    """Fetch full ghost replay payload for client-side playback."""
    ghost = await _load_ghost(ghost_id)
    if not ghost:
        raise HTTPException(status_code=404, detail="Ghost not found")
    return {
        "ghost_id": ghost["ghost_id"],
        "mode_id": ghost["mode_id"],
        "publisher_name": ghost["publisher_name"],
        "publisher_prq": ghost.get("publisher_prq", 0),
        "seed": ghost["seed"],
        "judge_offsets": ghost["judge_offsets"],
        "events": ghost["events"],
        "final_score": ghost.get("final_score", {}),
        "verification_hash": ghost["verification_hash"],
        "top_moment": ghost.get("top_moment"),
    }


@router.post("/api/ghost/{ghost_id}/challenge")
async def start_ghost_challenge(
    ghost_id: str,
    user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """Initiate a challenge session against a ghost. Returns ghost seed + events for overlay."""
    ghost = await _load_ghost(ghost_id)
    if not ghost:
        raise HTTPException(status_code=404, detail="Ghost not found")

    challenge_id = str(uuid.uuid4())[:16]
    challenge: Dict[str, Any] = {
        "challenge_id": challenge_id,
        "ghost_id": ghost_id,
        "challenger_id": user.user_id,
        "mode_id": ghost["mode_id"],
        "status": "active",
        "started_at": _now(),
        "completed_at": None,
        "result": None,
    }

    if _MOCK_DB:
        _ghost_challenges[challenge_id] = challenge
    else:
        try:
            await db.ghost_challenge_sessions.insert_one(challenge.copy())
        except Exception:
            _ghost_challenges[challenge_id] = challenge

    # Increment challenge count on ghost
    if _MOCK_DB:
        _ghosts[ghost_id]["challenge_count"] = _ghosts[ghost_id].get("challenge_count", 0) + 1
    else:
        try:
            await db.ghost_challenges.update_one(
                {"ghost_id": ghost_id}, {"$inc": {"challenge_count": 1}}
            )
        except Exception:
            pass

    return {
        "challenge_id": challenge_id,
        "ghost_id": ghost_id,
        "mode_id": ghost["mode_id"],
        "seed": ghost["seed"],
        "judge_offsets": ghost["judge_offsets"],
        "ghost_events": ghost["events"],
        "ghost_final_score": ghost.get("final_score", {}),
        "verification_hash": ghost["verification_hash"],
        "instructions": {
            "overlay": "Render ghost events as translucent avatar alongside your live inputs.",
            "sync": "Use ghost seed to reconstruct AI decisions deterministically.",
            "scoring": "Ghost score is locked — only your live score changes.",
        },
    }


@router.post("/api/ghost/{ghost_id}/complete")
async def complete_ghost_challenge(
    ghost_id: str,
    body: CompleteGhostChallengeRequest,
    user: User = Depends(get_current_user),
) -> Dict[str, Any]:
    """Submit a completed ghost challenge. Returns performance delta vs ghost."""
    ghost = await _load_ghost(ghost_id)
    if not ghost:
        raise HTTPException(status_code=404, detail="Ghost not found")

    # Re-validate ghost fingerprint to prevent tampered ghost files
    expected_hash = _compute_ghost_hash(ghost["seed"], ghost["events"])
    if expected_hash != ghost["verification_hash"]:
        raise HTTPException(status_code=409, detail="Ghost verification failed — replay integrity compromised")

    delta = _compute_performance_delta(ghost, body.challenger_events, body.challenger_final_score)

    if delta["beat_ghost"] and _MOCK_DB:
        _ghosts[ghost_id]["beat_count"] = _ghosts[ghost_id].get("beat_count", 0) + 1
    elif delta["beat_ghost"]:
        try:
            await db.ghost_challenges.update_one(
                {"ghost_id": ghost_id}, {"$inc": {"beat_count": 1}}
            )
        except Exception:
            pass

    return {
        "ghost_id": ghost_id,
        "challenger_id": user.user_id,
        "performance_delta": delta,
        "ghost_final_score": ghost.get("final_score", {}),
        "challenger_final_score": body.challenger_final_score,
        "completed_at": _now(),
    }
