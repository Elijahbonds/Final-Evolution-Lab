"""
Who Scene It router — buzz-in image/audio/text/silhouette identification game.

Session lifecycle:
  POST /api/who-scene-it/session              start session, get first round
  POST /api/who-scene-it/session/{id}/buzz    submit buzz_time_ms + chosen option index
  GET  /api/who-scene-it/session/{id}/result  final score + card collection

All server state is in-memory (_si_sessions). The client MUST NOT compute
scores or check correctness; those are server-authoritative.
"""
import os
import random
import time
import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

import core
from core import User
from lib.who_scene_it.interfaces import ISceneContentModule
from lib.who_scene_it.providers import (
    InMemoryCardModule,
    LocalSceneContentModule,
    SequentialRoundTypeModule,
    CARD_THRESHOLD,
)
from lib.who_scene_it.schemas import BuzzinResult, CreatorCard, RoundType, SceneContent
from lib.who_scene_it.scoring import (
    ANSWER_TIME_LIMIT_MS,
    DefaultBuzzinScoringModule,
    INITIAL_SCORE,
    WRONG_BUZZ_PENALTY,
)

router = APIRouter()

_si_sessions: Dict[str, Dict] = {}
_si_card_module = InMemoryCardModule()

_MOCK_DB = os.environ.get("MOCK_DB") == "1"

_NUM_OPTIONS = 4  # correct answer + 3 decoys


# ── Mock content provider (offline / test mode) ───────────────────────────────

_MOCK_TITLES = [
    "Mock Alpha", "Mock Beta", "Mock Gamma", "Mock Delta",
    "Mock Epsilon", "Mock Zeta", "Mock Eta", "Mock Theta",
]


class _MockSceneContentModule(ISceneContentModule):
    """In-memory content for MOCK_DB=1 / test runs."""

    _POOL: List[SceneContent] = [
        SceneContent(
            content_id=f"mock_{rt.value}_{i}",
            title=_MOCK_TITLES[i % len(_MOCK_TITLES)],
            description=f"Mock content {i} for {rt.value}",
            image_path=f"mock/{rt.value}_{i}.png",
            round_type=rt,
            difficulty=(i % 3) + 1,
            license="FEL Studios Test Content",
            source="test",
            content_provider_id="mock_v1",
            tags=["mock"],
            did_you_know=f"Mock fact {i} about {rt.value}.",
        )
        for rt in RoundType
        for i in range(4)
    ]

    def get_content(
        self,
        round_type: RoundType,
        difficulty: int,
        exclude_ids=None,
    ) -> Optional[SceneContent]:
        exclude_ids = exclude_ids or set()
        pool = [c for c in self._POOL if c.round_type == round_type and c.content_id not in exclude_ids]
        return pool[0] if pool else None

    def get_content_by_id(self, content_id: str) -> Optional[SceneContent]:
        for c in self._POOL:
            if c.content_id == content_id:
                return c
        return None

    def list_content(self, round_type=None) -> List[SceneContent]:
        if round_type is None:
            return list(self._POOL)
        return [c for c in self._POOL if c.round_type == round_type]


def _make_content_module() -> ISceneContentModule:
    return _MockSceneContentModule() if _MOCK_DB else LocalSceneContentModule()


# ── Request / response models ──────────────────────────────────────────────────

class StartSessionRequest(BaseModel):
    round_count: int = 6


class BuzzRequest(BaseModel):
    content_id: str
    buzz_time_ms: int
    chosen_index: int    # index into the options list sent with the round


# ── Internal helpers ───────────────────────────────────────────────────────────

def _get_si_session(session_id: str) -> Dict:
    if session_id not in _si_sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    return _si_sessions[session_id]


def _build_options(
    correct: SceneContent,
    content_module: ISceneContentModule,
    used_ids: set,
    rng: random.Random,
) -> tuple[List[str], int]:
    """
    Build a shuffled 4-option list (titles) and return (options, correct_index).
    Decoys come from other content items (any round type, different title).
    """
    all_content = content_module.list_content()
    decoy_pool = [
        c for c in all_content
        if c.content_id != correct.content_id and c.title != correct.title
    ]
    # Deduplicate decoy titles
    seen = set()
    decoys: List[str] = []
    for c in rng.sample(decoy_pool, min(len(decoy_pool), _NUM_OPTIONS * 3)):
        if c.title not in seen and len(decoys) < _NUM_OPTIONS - 1:
            seen.add(c.title)
            decoys.append(c.title)
    # Pad with generic labels if pool is thin
    for k in range(_NUM_OPTIONS - 1 - len(decoys)):
        decoys.append(f"Unknown Entity {k + 1}")

    options = decoys[:_NUM_OPTIONS - 1]
    insert_at = rng.randint(0, len(options))
    options.insert(insert_at, correct.title)
    return options, insert_at


def _advance_round(session: Dict) -> Optional[Dict]:
    """Pick next content + build options; return round dict or None if session over."""
    if session["rounds_played"] >= session["round_count"]:
        return None
    rt_module = session["rt_module"]
    content_module = session["content_module"]
    used = session["used_content_ids"]
    rt_history = session["rt_history"]
    seed = session["seed"] ^ session["rounds_played"]
    rt = rt_module.next_round_type(seed, used=rt_history)
    difficulty = min(5, 1 + session["rounds_played"] // 2)
    content = content_module.get_content(rt, difficulty, exclude_ids=used)
    if content is None:
        return None
    rng = random.Random(seed)
    options, correct_index = _build_options(content, content_module, used, rng)
    session["current_content"] = content
    session["current_options"] = options
    session["current_correct_index"] = correct_index
    session["rt_history"].append(rt)
    return {
        "content_id": content.content_id,
        "round_type": content.round_type.value,
        "description": content.description,
        "image_path": content.image_path,
        "options": options,
        "difficulty": content.difficulty,
    }


def _card_to_dict(card: Optional[CreatorCard]) -> Optional[Dict]:
    if card is None:
        return None
    return {
        "card_id": card.card_id,
        "name": card.name,
        "description": card.description,
        "image_placeholder": card.image_placeholder,
        "round_type": card.round_type.value,
    }


# ── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/api/who-scene-it/session")
async def start_si_session(
    req: StartSessionRequest,
    user: User = Depends(core.get_current_user),
):
    session_id = str(uuid.uuid4())
    seed = int.from_bytes(os.urandom(4), "big")
    content_module = _make_content_module()
    _si_sessions[session_id] = {
        "session_id": session_id,
        "user_id": user.user_id,
        "seed": seed,
        "round_count": req.round_count,
        "rounds_played": 0,
        "total_score": 0,
        "buzz_streak": 0,
        "results": [],
        "used_content_ids": set(),
        "rt_history": [],
        "current_content": None,
        "current_options": [],
        "current_correct_index": -1,
        "content_module": content_module,
        "rt_module": SequentialRoundTypeModule(),
        "scoring": DefaultBuzzinScoringModule(),
        "status": "active",
        "started_at": time.time(),
    }
    first_round = _advance_round(_si_sessions[session_id])
    return {
        "session_id": session_id,
        "seed": seed,
        "round": first_round,
    }


@router.post("/api/who-scene-it/session/{session_id}/buzz")
async def submit_buzz(
    session_id: str,
    req: BuzzRequest,
    user: User = Depends(core.get_current_user),
):
    session = _get_si_session(session_id)
    if session["status"] != "active":
        raise HTTPException(status_code=409, detail="Session not active")

    current = session.get("current_content")
    if current is None or current.content_id != req.content_id:
        raise HTTPException(status_code=400, detail="Content ID mismatch or no active round")

    is_correct = req.chosen_index == session["current_correct_index"]
    scoring = session["scoring"]
    result = scoring.compute_score(req.buzz_time_ms, is_correct)
    result.content_id = current.content_id
    result.did_you_know = current.did_you_know

    session["used_content_ids"].add(current.content_id)
    session["total_score"] = max(0, session["total_score"] + result.score_awarded - result.penalty)
    session["results"].append(result)
    session["rounds_played"] += 1

    if is_correct:
        session["buzz_streak"] += 1
    else:
        session["buzz_streak"] = 0

    card_award = _si_card_module.check_award(
        current.round_type, session["buzz_streak"]
    )
    if card_award:
        _si_card_module.award(user.user_id, card_award)

    next_round = _advance_round(session)
    if next_round is None:
        session["status"] = "complete"

    return {
        "is_correct": is_correct,
        "correct_title": current.title,
        "score_awarded": result.score_awarded,
        "penalty": result.penalty,
        "total_score": session["total_score"],
        "buzz_streak": session["buzz_streak"],
        "did_you_know": result.did_you_know,
        "card_awarded": _card_to_dict(card_award),
        "next_round": next_round,
        "session_complete": next_round is None,
    }


@router.get("/api/who-scene-it/session/{session_id}/result")
async def get_si_result(
    session_id: str,
    user: User = Depends(core.get_current_user),
):
    session = _get_si_session(session_id)
    correct_count = sum(1 for r in session["results"] if r.is_correct)
    return {
        "session_id": session_id,
        "total_score": session["total_score"],
        "rounds_played": session["rounds_played"],
        "correct_count": correct_count,
        "collection": [_card_to_dict(c) for c in _si_card_module.get_collection(user.user_id)],
    }
