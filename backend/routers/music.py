"""
FEL OS — Music Creation Foundation Router

Provides:
  POST /api/music/projects                        — create a music project
  GET  /api/music/projects/{project_id}           — fetch a music project
  POST /api/music/projects/{project_id}/export    — JSON project export + audio placeholder
  POST /api/music/projects/{project_id}/render-preview
        — MOCK: deterministic placeholder render manifest derived from the
          project seed. Real audio rendering is a mode-branch concern.

Storage: lib/creative_store.py (MOCK_DB=1 -> in-memory, else db.music_projects).
Replay events reuse the existing match event store (routers.matches).
"""
import random
import uuid
from typing import Any, Dict, List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from core import User
from lib import creative_store
from lib.creative_store import get_creative_user, now
from lib.match_utils import generate_seed
from routers import matches as matches_router

router = APIRouter(tags=["music"])

_SEED_MASK = (1 << 64) - 1  # seeds are 64-bit ints (lib/match_utils contract)


# ── Pydantic schemas ───────────────────────────────────────────────────────

class ClipModel(BaseModel):
    clip_id: str = Field(default_factory=lambda: f"clip_{uuid.uuid4().hex[:8]}")
    start: float = Field(0.0, ge=0.0, description="Start position in beats")
    length: float = Field(1.0, gt=0.0, description="Length in beats")


class TrackModel(BaseModel):
    track_id: str = Field(default_factory=lambda: f"trk_{uuid.uuid4().hex[:8]}")
    type: Literal["instrument", "sample"] = "instrument"
    clips: List[ClipModel] = []
    volume: float = Field(1.0, ge=0.0, le=2.0)
    pan: float = Field(0.0, ge=-1.0, le=1.0)
    effects: List[Dict[str, Any]] = []


class CreateMusicProjectRequest(BaseModel):
    name: str = "Untitled Music Project"
    bpm: int = Field(120, ge=20, le=300)
    key: str = "C"
    tracks: List[TrackModel] = []
    seed: Optional[int] = Field(None, ge=0, lt=1 << 64)
    metadata: Dict[str, Any] = {}


class MusicProjectResponse(BaseModel):
    project_id: str
    owner_id: str
    name: str
    bpm: int
    key: str
    tracks: List[TrackModel]
    created_at: str
    seed: int
    metadata: Dict[str, Any]
    applied_card_packs: List[Dict[str, Any]] = []


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.post("/api/music/projects")
async def create_music_project(
    body: CreateMusicProjectRequest,
    user: User = Depends(get_creative_user),
) -> MusicProjectResponse:
    """Create a music project. Seed is persisted for deterministic renders."""
    project_id = f"mus_{uuid.uuid4().hex[:12]}"
    seed = body.seed if body.seed is not None else generate_seed()
    project: Dict[str, Any] = {
        "project_id": project_id,
        "owner_id": user.user_id,
        "name": body.name,
        "bpm": body.bpm,
        "key": body.key,
        "tracks": [t.model_dump() for t in body.tracks],
        "created_at": now(),
        "seed": seed,
        "metadata": body.metadata,
        "applied_card_packs": [],
    }
    await creative_store.persist_project("music", project)
    # Composition replay log reuses the existing match event store.
    await matches_router._persist_event(project_id, {
        "type": "project_created",
        "project_type": "music",
        "project_id": project_id,
        "player_id": user.user_id,
        "seed": seed,
        "timestamp": project["created_at"],
    })
    return MusicProjectResponse(**project)


@router.get("/api/music/projects/{project_id}")
async def get_music_project(project_id: str) -> MusicProjectResponse:
    project = await creative_store.load_project("music", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Music project not found")
    return MusicProjectResponse(**project)


@router.post("/api/music/projects/{project_id}/export")
async def export_music_project(project_id: str) -> Dict[str, Any]:
    """Export the full project as JSON. Audio payload is a placeholder —
    real audio rendering/bounce is a Music-mode branch concern."""
    project = await creative_store.load_project("music", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Music project not found")
    events = await matches_router._load_events(project_id, limit=10_000)
    events = sorted(events, key=lambda e: e.get("seq", 0))
    return {
        "export_version": "1.0",
        "project_type": "music",
        "project": project,
        "audio": {
            "status": "placeholder",
            "format": None,
            "url": None,
            "note": "Audio bounce is produced by the Music mode branch.",
        },
        "replay": {
            "replay_id": project_id,
            "seed": project["seed"],
            "event_count": len(events),
        },
    }


@router.post("/api/music/projects/{project_id}/render-preview")
async def render_preview(project_id: str) -> Dict[str, Any]:
    """MOCK: deterministic placeholder render manifest.

    Same project state (seed, bpm, key, tracks) -> identical manifest.
    Real preview rendering is a Music-mode branch concern.
    """
    project = await creative_store.load_project("music", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Music project not found")
    seed = int(project["seed"]) & _SEED_MASK
    rng = random.Random(seed)
    sections = [
        {
            "index": i,
            "start_beat": i * 16,
            "length_beats": 16,
            "energy": round(rng.random(), 6),
        }
        for i in range(4)
    ]
    return {
        "render_id": "render_%016x" % seed,
        "project_id": project_id,
        "status": "mock_rendered",
        "engine": "placeholder",
        "deterministic": True,
        "seed": project["seed"],
        "bpm": project["bpm"],
        "key": project["key"],
        "track_count": len(project.get("tracks", [])),
        "sample_rate": 44100,
        "bit_depth": 16,
        "sections": sections,
        "waveform_checksum": "%08x" % rng.getrandbits(32),
        "note": "MOCK render manifest; real audio rendering is a mode-branch concern.",
    }
