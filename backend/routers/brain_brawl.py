"""
Brain Brawl router — trivia + cognitive game mode.

Session lifecycle:
  POST /api/brain-brawl/session                           start session, get first question
  POST /api/brain-brawl/session/{id}/answer               submit trivia answer, get next question
  POST /api/brain-brawl/session/{id}/cognitive-answer     submit cognitive round answer
  GET  /api/brain-brawl/session/{id}/result               final BrawnScore + ghost comparison
  POST /api/brain-brawl/ghost/record                      persist completed session as ghost
  GET  /api/brain-brawl/ghost/{ghost_id}                  fetch ghost for replay

All server state is in-memory (_sessions, _ghost_module, _card_module). The
client MUST NOT compute scores; it receives them from this server.
"""
import os
import time
import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

import core
from core import User
from lib.brain_brawl.interfaces import IQuestionProvider
from lib.brain_brawl.providers import (
    InMemoryCardModule,
    InMemoryGhostModule,
    LocalCognitiveModule,
    LocalQuestionProvider,
    SpinCategoryModule,
)
from lib.brain_brawl.schemas import Category, Question
from lib.brain_brawl.scoring import DefaultScoringModule, compute_brawn_score

router = APIRouter()

# ── Module-level singletons (reset in tests via _ghost_module._store etc.) ────

_sessions: Dict[str, Dict] = {}
_ghost_module = InMemoryGhostModule()
_card_module = InMemoryCardModule()

_MOCK_DB = os.environ.get("MOCK_DB") == "1"


# ── Mock question provider (offline / test mode) ───────────────────────

class _MockQuestionProvider(IQuestionProvider):
    """Minimal in-memory question set for MOCK_DB=1 / test runs."""

    _POOL: List[Question] = [
        Question(
            id=f"mock_{cat.value}_{i}",
            prompt=f"Test question {i+1} for {cat.value}?",
            options=["Correct Answer", "Wrong B", "Wrong C", "Wrong D"],
            correct_index=0,
            category=cat,
            difficulty=i + 1,
            did_you_know=f"Did you know fact {i+1} about {cat.value}.",
        )
        for cat in [c for c in Category if c != Category.crown]
        for i in range(5)
    ]

    def get_question(self, category, difficulty, exclude_ids=None):
        exclude_ids = exclude_ids or set()
        candidates = [
            q for q in self._POOL
            if q.category == category and q.id not in exclude_ids
        ]
        return candidates[0] if candidates else None

    def get_categories(self):
        return [c for c in Category if c != Category.crown]

    def get_question_count(self, category):
        return sum(1 for q in self._POOL if q.category == category)

    def find_by_id(self, question_id: str) -> Optional[Question]:
        for q in self._POOL:
            if q.id == question_id:
                return q
        return None


def _make_provider() -> IQuestionProvider:
    return _MockQuestionProvider() if _MOCK_DB else LocalQuestionProvider()


# ── Request / response models ──────────────────────────────────────────────

class StartSessionRequest(BaseModel):
    mode: str = "blitz"             # blitz | deep_dive | ladder
    ghost_id: Optional[str] = None
    question_count: int = 10
    time_limit_ms: int = 10_000


class AnswerRequest(BaseModel):
    question_id: str
    chosen_index: int
    response_ms: int


class CognitiveAnswerRequest(BaseModel):
    answer: Any


class RecordGhostRequest(BaseModel):
    session_id: str


# ── Internal helpers ────────────────────────────────────────────────────

def _get_session(session_id: str) -> Dict:
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    return _sessions[session_id]


def _advance_question(session: Dict) -> Optional[Question]:
    """Pick the next question and cache it in session[\"current_question\"]."""
    if session["questions_asked"] >= session["question_count"]:
        session["current_question"] = None
        return None
    provider = session["provider"]
    cat = Category(session["current_category"])
    difficulty = min(6, 1 + session["questions_asked"] // 2)
    exclude = session["used_ids"]
    q = provider.get_question(cat, difficulty, exclude_ids=exclude)
    if q is None:
        session["current_question"] = None
        return None
    session["used_ids"].add(q.id)
    session["current_question"] = q
    return q


def _q_to_dict(q: Optional[Question]) -> Optional[Dict]:
    if q is None:
        return None
    return {
        "id": q.id,
        "prompt": q.prompt,
        "options": q.options,
        "category": q.category.value,
        "difficulty": q.difficulty,
    }


def _item_to_dict(item) -> Optional[Dict]:
    if item is None:
        return None
    return {
        "item_id": item.item_id,
        "category": item.category.value,
        "name": item.name,
        "description": item.description,
        "image_placeholder": item.image_placeholder,
    }


# ── Endpoints ────────────────────────────────────────────────────────────

@router.post("/api/brain-brawl/session")
async def start_session(
    req: StartSessionRequest,
    user: User = Depends(core.get_current_user),
):
    provider = _make_provider()
    seed = int.from_bytes(os.urandom(4), "big")
    cat_module = SpinCategoryModule()
    first_cat = cat_module.spin(seed)
    cat_module.select(first_cat)

    session_id = str(uuid.uuid4())
    _sessions[session_id] = {
        "session_id": session_id,
        "user_id": user.user_id,
        "mode": req.mode,
        "ghost_id": req.ghost_id,
        "question_count": req.question_count,
        "time_limit_ms": req.time_limit_ms,
        "questions_asked": 0,
        "answers": [],
        "used_ids": set(),
        "current_category": first_cat.value,
        "cat_module": cat_module,
        "crown_meter": 0,
        "provider": provider,
        "scoring": DefaultScoringModule(),
        "cog_module": LocalCognitiveModule(),
        "current_question": None,
        "current_cognitive_round": None,
        "seed": seed,
        "started_at": time.time(),
        "status": "active",
    }

    first_q = _advance_question(_sessions[session_id])
    return {
        "session_id": session_id,
        "mode": req.mode,
        "seed": seed,
        "current_category": first_cat.value,
        "question": _q_to_dict(first_q),
    }


@router.post("/api/brain-brawl/session/{session_id}/answer")
async def submit_answer(
    session_id: str,
    req: AnswerRequest,
    user: User = Depends(core.get_current_user),
):
    session = _get_session(session_id)
    if session["status"] != "active":
        raise HTTPException(status_code=409, detail="Session not active")

    current_q = session.get("current_question")
    if current_q is None or current_q.id != req.question_id:
        raise HTTPException(status_code=400, detail="Question ID mismatch or no active question")

    scoring = session["scoring"]
    result = scoring.score_answer(current_q, req.chosen_index, req.response_ms, session["time_limit_ms"])
    session["answers"].append(result)
    session["questions_asked"] += 1

    if result.is_correct:
        session["crown_meter"] += 1
    else:
        session["crown_meter"] = 0

    card_award = _card_module.check_award(Category(session["current_category"]), session["crown_meter"])
    if card_award:
        _card_module.award(user.user_id, card_award)

    next_q = _advance_question(session)
    if next_q is None:
        session["status"] = "complete"

    return {
        "is_correct": result.is_correct,
        "correct_index": result.correct_index,
        "points_earned": result.points_earned,
        "speed_bonus": result.speed_bonus,
        "did_you_know": result.did_you_know,
        "crown_meter": session["crown_meter"],
        "card_awarded": _item_to_dict(card_award),
        "next_question": _q_to_dict(next_q),
        "session_complete": next_q is None,
    }


@router.post("/api/brain-brawl/session/{session_id}/cognitive-answer")
async def submit_cognitive_answer(
    session_id: str,
    req: CognitiveAnswerRequest,
    user: User = Depends(core.get_current_user),
):
    session = _get_session(session_id)
    cog_round = session.get("current_cognitive_round")
    if cog_round is None:
        raise HTTPException(status_code=400, detail="No active cognitive round")

    cog_module = session["cog_module"]
    is_correct = cog_module.validate_answer(cog_round, req.answer)
    session["current_cognitive_round"] = None
    return {
        "is_correct": is_correct,
        "expected_answer": cog_round.expected_answer,
        "did_you_know": cog_round.did_you_know,
    }


@router.get("/api/brain-brawl/session/{session_id}/result")
async def get_session_result(
    session_id: str,
    user: User = Depends(core.get_current_user),
):
    session = _get_session(session_id)
    brawn = compute_brawn_score(session["answers"])
    ghost_comparison = None
    if session.get("ghost_id"):
        ghost = _ghost_module.get_ghost(session["ghost_id"])
        if ghost:
            ghost_comparison = {
                "ghost_raw": ghost.brawn_score.raw,
                "player_raw": brawn.raw,
                "beat_ghost": brawn.raw > ghost.brawn_score.raw,
            }
    return {
        "session_id": session_id,
        "brawn_score": {
            "raw": brawn.raw,
            "max_raw": brawn.max_raw,
            "percentage": brawn.percentage,
            "grade": brawn.grade,
            "question_count": brawn.question_count,
            "correct_count": brawn.correct_count,
            "avg_response_ms": brawn.avg_response_ms,
        },
        "ghost_comparison": ghost_comparison,
        "collection": [_item_to_dict(i) for i in _card_module.get_collection(user.user_id)],
    }


@router.post("/api/brain-brawl/ghost/record")
async def record_ghost(
    req: RecordGhostRequest,
    user: User = Depends(core.get_current_user),
):
    session = _get_session(req.session_id)
    brawn = compute_brawn_score(session["answers"])
    ghost = _ghost_module.record_run(
        user_id=user.user_id,
        match_id=req.session_id,
        category_sequence=[session["current_category"]],
        answers=session["answers"],
        brawn_score=brawn,
    )
    return {"ghost_id": ghost.ghost_id}


@router.get("/api/brain-brawl/ghost/{ghost_id}")
async def get_ghost(
    ghost_id: str,
    user: User = Depends(core.get_current_user),
):
    ghost = _ghost_module.get_ghost(ghost_id)
    if ghost is None:
        raise HTTPException(status_code=404, detail="Ghost not found")
    return {
        "ghost_id": ghost.ghost_id,
        "user_id": ghost.user_id,
        "match_id": ghost.match_id,
        "brawn_score": {
            "raw": ghost.brawn_score.raw,
            "max_raw": ghost.brawn_score.max_raw,
            "grade": ghost.brawn_score.grade,
            "percentage": ghost.brawn_score.percentage,
            "correct_count": ghost.brawn_score.correct_count,
            "question_count": ghost.brawn_score.question_count,
        },
        "recorded_at": ghost.recorded_at,
    }
