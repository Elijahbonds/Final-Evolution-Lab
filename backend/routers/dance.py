"""
FEL OS — Dance Game Foundation Router

Provides:
  POST /api/dance/projects                      — create a dance project
  GET  /api/dance/projects/{project_id}         — fetch a dance project
  POST /api/dance/projects/{project_id}/export  — JSON project export

Storage: lib/creative_store.py (MOCK_DB=1 -> in-memory, else db.dance_projects).
Performance replay events reuse the existing match event store (routers.matches).
"""
import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from core import User
from lib import creative_store
from lib.creative_store import get_creative_user, now
from lib.match_utils import generate_seed
from routers import matches as matches_router

router = APIRouter(tags=["dance"])


# ── Pydantic schemas ───────────────────────────────────────────────────────

class AnimationModel(BaseModel):
    id: str = Field(default_factory=lambda: f"anim_{uuid.uuid4().hex[:8]}")
    name: str = "untitled_animation"
    duration: float = Field(0.0, ge=0.0, description="Duration in seconds")
    source: str = Field("library", description="e.g. library | mocap | deepmotion | custom")


class CreateDanceProjectRequest(BaseModel):
    name: str = "Untitled Dance Project"
    skeleton: str = Field("humanoid_v1", description="Rig identifier the animations target")
    animations: List[AnimationModel] = []
    timeline: Dict[str, Any] = Field(
        default_factory=lambda: {"entries": []},
        description="Timeline placement of animation clips (mode-branch defined entries)",
    )
    bpm: int = Field(120, ge=20, le=300)
    seed: Optional[int] = Field(None, ge=0, lt=1 << 64)


class DanceProjectResponse(BaseModel):
    project_id: str
    owner_id: str
    name: str
    skeleton: str
    animations: List[AnimationModel]
    timeline: Dict[str, Any]
    bpm: int
    created_at: str
    seed: int
    applied_card_packs: List[Dict[str, Any]] = []


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.post("/api/dance/projects")
async def create_dance_project(
    body: CreateDanceProjectRequest,
    user: User = Depends(get_creative_user),
) -> DanceProjectResponse:
    """Create a dance project. Seed is persisted for deterministic playback."""
    project_id = f"dan_{uuid.uuid4().hex[:12]}"
    seed = body.seed if body.seed is not None else generate_seed()
    project: Dict[str, Any] = {
        "project_id": project_id,
        "owner_id": user.user_id,
        "name": body.name,
        "skeleton": body.skeleton,
        "animations": [a.model_dump() for a in body.animations],
        "timeline": body.timeline,
        "bpm": body.bpm,
        "created_at": now(),
        "seed": seed,
        "applied_card_packs": [],
    }
    await creative_store.persist_project("dance", project)
    # Performance replay log reuses the existing match event store.
    await matches_router._persist_event(project_id, {
        "type": "project_created",
        "project_type": "dance",
        "project_id": project_id,
        "player_id": user.user_id,
        "seed": seed,
        "timestamp": project["created_at"],
    })
    return DanceProjectResponse(**project)


@router.get("/api/dance/projects/{project_id}")
async def get_dance_project(project_id: str) -> DanceProjectResponse:
    project = await creative_store.load_project("dance", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Dance project not found")
    return DanceProjectResponse(**project)


@router.post("/api/dance/projects/{project_id}/export")
async def export_dance_project(project_id: str) -> Dict[str, Any]:
    """Export the full project as JSON (skeleton + animations + timeline)."""
    project = await creative_store.load_project("dance", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Dance project not found")
    events = await matches_router._load_events(project_id, limit=10_000)
    events = sorted(events, key=lambda e: e.get("seq", 0))
    return {
        "export_version": "1.0",
        "project_type": "dance",
        "project": project,
        "replay": {
            "replay_id": project_id,
            "seed": project["seed"],
            "event_count": len(events),
        },
    }
