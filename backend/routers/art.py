"""
FEL OS — Art Showcase Foundation Router

Provides:
  POST /api/art/exhibits                        — create an art exhibit
  GET  /api/art/exhibits/{exhibit_id}           — fetch an art exhibit
  POST /api/art/exhibits/{exhibit_id}/publish   — marketplace stub state change
                                                  (draft -> published)

Storage: lib/creative_store.py (MOCK_DB=1 -> in-memory, else db.art_exhibits).
"""
import uuid
from typing import Any, Dict, List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from core import User
from lib import creative_store
from lib.creative_store import get_creative_user, now

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
