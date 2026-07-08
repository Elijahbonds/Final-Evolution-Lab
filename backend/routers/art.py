"""
FEL OS — Art Showcase Mode Router

Foundation (creative-models base):
  POST /api/art/exhibits                        — create an art exhibit
  GET  /api/art/exhibits/{exhibit_id}           — fetch an art exhibit
  POST /api/art/exhibits/{exhibit_id}/publish   — marketplace stub state change
                                                  (draft -> published)

Art Showcase Mode (this branch):
  GET  /api/art/sample-exhibit                  — seeded sample gallery content
  GET  /api/art/guess-technique/round           — deterministic quiz round
                                                  (answers hidden server-side)
  POST /api/art/guess-technique/answer          — resolve + reveal + lesson
  POST /api/art/exhibits/{id}/sketch            — save timed-sketch derivative
  POST /api/art/exhibits/{id}/critique          — save a critique card

Storage: lib/creative_store.py (MOCK_DB=1 -> in-memory, else db.art_exhibits).
Micro-game content: lib/art_content.py (original / CC0). Replay events reuse
the existing match event store (no parallel log).
"""
import uuid
from typing import Any, Dict, List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from core import User
from lib import art_content, creative_store
from lib.creative_store import get_creative_user, now
from routers import matches as matches_router

router = APIRouter(tags=["art"])


# ── Pydantic schemas ───────────────────────────────────────────────────────

class ExhibitItemModel(BaseModel):
    id: str = Field(default_factory=lambda: f"item_{uuid.uuid4().hex[:8]}")
    type: Literal["image", "3d", "model"] = "image"
    path: str = Field(..., description="Asset path/URL (asset pipeline reference, not a binary)")
    meta: Dict[str, Any] = {}


class CreateArtExhibitRequest(BaseModel):
    title: str = "Untitled Exhibit"
    items: List[ExhibitItemModel] = []


class ArtExhibitResponse(BaseModel):
    exhibit_id: str
    owner_id: str
    title: str
    items: List[ExhibitItemModel]
    created_at: str
    status: str  # draft | published
    published_at: Optional[str] = None  # null until publish
    marketplace: Dict[str, Any] = {}
    applied_card_packs: List[Dict[str, Any]] = []
    critiques: List[Dict[str, Any]] = []


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.post("/api/art/exhibits")
async def create_art_exhibit(
    body: CreateArtExhibitRequest,
    user: User = Depends(get_creative_user),
) -> ArtExhibitResponse:
    exhibit: Dict[str, Any] = {
        "exhibit_id": f"art_{uuid.uuid4().hex[:12]}",
        "owner_id": user.user_id,
        "title": body.title,
        "items": [i.model_dump() for i in body.items],
        "created_at": now(),
        "status": "draft",
        "published_at": None,
        "marketplace": {"listed": False, "listing_id": None},
        "applied_card_packs": [],
    }
    await creative_store.persist_project("art", exhibit)
    return ArtExhibitResponse(**exhibit)


@router.get("/api/art/exhibits/{exhibit_id}")
async def get_art_exhibit(exhibit_id: str) -> ArtExhibitResponse:
    exhibit = await creative_store.load_project("art", exhibit_id)
    if not exhibit:
        raise HTTPException(status_code=404, detail="Art exhibit not found")
    return ArtExhibitResponse(**exhibit)


@router.post("/api/art/exhibits/{exhibit_id}/publish")
async def publish_art_exhibit(exhibit_id: str) -> Dict[str, Any]:
    """Marketplace STUB: transitions the exhibit draft -> published and marks a
    stub marketplace listing. Real marketplace flows are a mode-branch concern."""
    exhibit = await creative_store.load_project("art", exhibit_id)
    if not exhibit:
        raise HTTPException(status_code=404, detail="Art exhibit not found")
    if exhibit["status"] == "published":
        raise HTTPException(status_code=409, detail="Exhibit already published")
    exhibit["status"] = "published"
    exhibit["published_at"] = now()
    exhibit["marketplace"] = {
        "listed": True,
        "listing_id": f"list_{uuid.uuid4().hex[:12]}",
        "stub": True,
    }
    await creative_store.persist_project("art", exhibit)
    return {
        "exhibit_id": exhibit_id,
        "status": "published",
        "published_at": exhibit["published_at"],
        "marketplace": exhibit["marketplace"],
    }


# ── Art Showcase Mode: sample content ──────────────────────────────────────

@router.get("/api/art/sample-exhibit")
async def get_sample_exhibit() -> Dict[str, Any]:
    """Seeded sample gallery: ~3 original/CC0 images + 1 CC0 glTF model.

    Used by the frontend gallery and the recording flow. Content is served
    from the asset pipeline (paths only, never binaries) and every item
    carries alt text + source/license for attribution and accessibility.
    """
    return {
        "title": "FEL Art Showcase — Sample Exhibit",
        "items": art_content.SAMPLE_EXHIBIT_ITEMS,
    }


# ── Micro-game 1: Guess the Technique ──────────────────────────────────────

class GuessAnswerRequest(BaseModel):
    seed: int
    question_id: str
    selected: str
    exhibit_id: Optional[str] = None  # optional: attach reveal to a replay


@router.get("/api/art/guess-technique/round")
async def guess_technique_round(seed: int = 1, count: int = 5) -> Dict[str, Any]:
    """Deterministic guess-the-technique round.

    Question and option order are a pure function of `seed`. The correct
    answer and the micro-lesson are NEVER present in this payload — each
    question carries an opaque `answer_token`; the client must POST an answer
    to resolve + reveal. Same seed always yields the identical round.
    """
    if count < 1:
        raise HTTPException(status_code=422, detail="count must be >= 1")
    return art_content.build_round(seed, count)


@router.post("/api/art/guess-technique/answer")
async def guess_technique_answer(
    body: GuessAnswerRequest,
    user: User = Depends(get_creative_user),
) -> Dict[str, Any]:
    """Resolve a submitted answer server-side; return correctness + lesson."""
    result = art_content.resolve_answer(body.seed, body.question_id, body.selected)
    if result is None:
        raise HTTPException(status_code=404, detail="Unknown question id")

    # If tied to an exhibit, record the play in the shared replay event store.
    if body.exhibit_id:
        exhibit = await creative_store.load_project("art", body.exhibit_id)
        if exhibit is not None:
            await matches_router._persist_event(body.exhibit_id, {
                "type": "guess_technique_answered",
                "project_type": "art",
                "project_id": body.exhibit_id,
                "player_id": user.user_id,
                "question_id": body.question_id,
                "is_correct": result["is_correct"],
                "timestamp": now(),
            })
    return result


# ── Micro-game 2: Timed Sketch (derivative item on the exhibit) ────────────

class SketchSaveRequest(BaseModel):
    # Compact stroke list; keep tiny. Each stroke: {points:[[x,y],...], color, width}
    strokes: List[Dict[str, Any]] = Field(default_factory=list)
    thumbnail: Optional[str] = Field(
        default=None,
        description="Tiny data-URL / reference thumbnail (kept small, not a binary asset)",
    )
    duration_sec: float = 0.0
    prompt: Optional[str] = None


@router.post("/api/art/exhibits/{exhibit_id}/sketch")
async def save_sketch(
    exhibit_id: str,
    body: SketchSaveRequest,
    user: User = Depends(get_creative_user),
) -> Dict[str, Any]:
    """Save a timed sketch as a derivative item on the exhibit.

    Stores strokes + a tiny thumbnail reference (never a heavy binary). The
    sketch becomes an exhibit item of type "image" flagged derivative.
    """
    exhibit = await creative_store.load_project("art", exhibit_id)
    if not exhibit:
        raise HTTPException(status_code=404, detail="Art exhibit not found")
    if len(body.strokes) > 2000:
        raise HTTPException(status_code=422, detail="Too many strokes (max 2000)")

    item_id = f"sketch_{uuid.uuid4().hex[:8]}"
    item = {
        "id": item_id,
        "type": "image",
        "path": f"derivative://sketch/{exhibit_id}/{item_id}",
        "meta": {
            "derivative": True,
            "kind": "timed_sketch",
            "author_id": user.user_id,
            "duration_sec": body.duration_sec,
            "prompt": body.prompt,
            "stroke_count": len(body.strokes),
            "strokes": body.strokes,
            "thumbnail": body.thumbnail,
            "alt": f"User timed sketch ({len(body.strokes)} strokes)"
                   + (f" for prompt: {body.prompt}" if body.prompt else ""),
            "created_at": now(),
        },
    }
    exhibit.setdefault("items", []).append(item)
    await creative_store.persist_project("art", exhibit)
    await matches_router._persist_event(exhibit_id, {
        "type": "sketch_saved",
        "project_type": "art",
        "project_id": exhibit_id,
        "player_id": user.user_id,
        "item_id": item_id,
        "stroke_count": len(body.strokes),
        "timestamp": now(),
    })
    return {"ok": True, "exhibit_id": exhibit_id, "item_id": item_id, "item": item}


# ── Micro-game 3: Critique Cards (structured feedback tags) ─────────────────

class CritiqueSaveRequest(BaseModel):
    item_id: Optional[str] = None  # which exhibit item is being critiqued
    composition: Optional[str] = None
    color: Optional[str] = None
    execution: Optional[str] = None
    rating: Optional[int] = Field(default=None, ge=1, le=5)


@router.post("/api/art/exhibits/{exhibit_id}/critique")
async def save_critique(
    exhibit_id: str,
    body: CritiqueSaveRequest,
    user: User = Depends(get_creative_user),
) -> Dict[str, Any]:
    """Save a structured critique card (composition / color / execution)."""
    exhibit = await creative_store.load_project("art", exhibit_id)
    if not exhibit:
        raise HTTPException(status_code=404, detail="Art exhibit not found")
    if not any([body.composition, body.color, body.execution, body.rating]):
        raise HTTPException(status_code=422, detail="Critique must have at least one field")

    critique = {
        "critique_id": f"crit_{uuid.uuid4().hex[:8]}",
        "author_id": user.user_id,
        "item_id": body.item_id,
        "composition": body.composition,
        "color": body.color,
        "execution": body.execution,
        "rating": body.rating,
        "created_at": now(),
    }
    exhibit.setdefault("critiques", []).append(critique)
    await creative_store.persist_project("art", exhibit)
    await matches_router._persist_event(exhibit_id, {
        "type": "critique_saved",
        "project_type": "art",
        "project_id": exhibit_id,
        "player_id": user.user_id,
        "critique_id": critique["critique_id"],
        "timestamp": now(),
    })
    return {"ok": True, "exhibit_id": exhibit_id, "critique": critique}
