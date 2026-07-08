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
from lib import music_theory
from lib.creative_store import CREATOR_CARD_PACKS, get_creative_user, now
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


# ── Auto-generation (deterministic auto-beat / auto-harmony) ────────────────

class AutoGenerateRequest(BaseModel):
    bars: int = Field(4, ge=1, le=16)
    # Optional explicit seed override; otherwise the project seed is used so
    # the same project always auto-generates the same beat/harmony.
    seed: Optional[int] = Field(None, ge=0, lt=1 << 64)


@router.post("/api/music/projects/{project_id}/auto-generate")
async def auto_generate(project_id: str, body: AutoGenerateRequest) -> Dict[str, Any]:
    """Deterministic rule-based auto-beat + auto-harmony for a project.

    Seeded from the project seed (or an explicit override). Same project state
    -> byte-identical composition. NO external ML.
    """
    project = await creative_store.load_project("music", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Music project not found")
    seed = body.seed if body.seed is not None else int(project["seed"])
    comp = music_theory.generate_composition(seed, project["key"], bars=body.bars)
    return {"project_id": project_id, "composition": comp}


# ── Composer Challenge (deterministic, seeded, reproducible scoring) ────────

class ChallengeConstraints(BaseModel):
    bpm: int = Field(120, ge=20, le=300)
    key: str = "C"
    instruments: List[str] = ["instrument", "sample"]
    length_beats: float = Field(16.0, gt=0.0)   # ~15-30s at typical BPM
    max_tracks: int = Field(4, ge=1, le=8)


class GenerateChallengeRequest(BaseModel):
    seed: Optional[int] = Field(None, ge=0, lt=1 << 64)
    constraints: Optional[ChallengeConstraints] = None


class ScoreChallengeRequest(BaseModel):
    seed: int = Field(..., ge=0, lt=1 << 64)
    constraints: ChallengeConstraints
    # The submitted loop is the music-project `tracks` shape (+ bpm/key).
    tracks: List[TrackModel] = []
    bpm: Optional[int] = Field(None, ge=20, le=300)
    key: Optional[str] = None


@router.post("/api/music/composer-challenge/generate")
async def generate_challenge(body: GenerateChallengeRequest) -> Dict[str, Any]:
    """Produce a seeded composer challenge: constraints + a reference
    composition the player is invited to beat. Same seed -> same challenge."""
    seed = body.seed if body.seed is not None else generate_seed()
    constraints = (body.constraints or ChallengeConstraints()).model_dump()
    # Seed can bias the target key/genre deterministically when none supplied.
    reference = music_theory.generate_composition(
        seed, constraints["key"], bars=max(1, int(constraints["length_beats"] // 4))
    )
    challenge_id = music_theory.score_submission(
        seed, constraints, {"tracks": []}
    )["challenge_id"]
    return {
        "challenge_id": challenge_id,
        "seed": seed,
        "constraints": constraints,
        "reference": reference,
        "brief": (
            "Compose a %.0f-beat loop in %s at %d BPM using %s. Maximize variety, "
            "rhythmic interest, and constraint adherence."
            % (constraints["length_beats"], reference["key"], constraints["bpm"],
               " / ".join(constraints["instruments"]))
        ),
    }


@router.post("/api/music/composer-challenge/score")
async def score_challenge(body: ScoreChallengeRequest) -> Dict[str, Any]:
    """Deterministically score a submitted loop against a seeded challenge.

    Same (seed, constraints, loop) -> identical score. Reproducible & seeded.
    """
    loop = {
        "tracks": [t.model_dump() for t in body.tracks],
        "bpm": body.bpm if body.bpm is not None else body.constraints.bpm,
        "key": body.key if body.key is not None else body.constraints.key,
    }
    return music_theory.score_submission(body.seed, body.constraints.model_dump(), loop)


# ── Save as pack (Creator-Card-shaped payload via the existing contract) ────

class SaveAsPackRequest(BaseModel):
    # Which contract Creator Card this pack presents as. Must be a music card
    # from the foundation registry (docs/creative_models.md).
    card_id: str = "card_sampler_01"
    title: Optional[str] = None


@router.post("/api/music/projects/{project_id}/save-as-pack")
async def save_as_pack(project_id: str, body: SaveAsPackRequest) -> Dict[str, Any]:
    """Produce a Creator-Card-shaped sample-pack + lesson payload for a project.

    Reuses the foundation's Creator Card contract (card ids + lesson packs from
    lib/creative_store.CREATOR_CARD_PACKS); does NOT invent a parallel system.
    The returned payload is ready to POST to /api/creator-cards/apply and to
    surface as a shareable pack (samples derived from the project's tracks).
    """
    project = await creative_store.load_project("music", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Music project not found")
    card = CREATOR_CARD_PACKS.get(body.card_id)
    if card is None:
        raise HTTPException(status_code=404, detail=f"Unknown Creator Card: {body.card_id}")
    if card["mode"] != "music":
        raise HTTPException(
            status_code=422,
            detail=f"Card {body.card_id} is a {card['mode']} pack; save-as-pack needs a music card",
        )
    # Derive sample-pack entries deterministically from the project's clips.
    samples: List[Dict[str, Any]] = []
    for track in project.get("tracks", []):
        for clip in track.get("clips", []):
            samples.append({
                "sample_id": "smp_%s_%s" % (track.get("track_id", "trk"), clip.get("clip_id", "clip")),
                "track_type": track.get("type", "instrument"),
                "start": clip.get("start", 0.0),
                "length": clip.get("length", 1.0),
            })
    return {
        "ok": True,
        "project_id": project_id,
        "card_id": body.card_id,
        "pack": {
            "pack_id": card["pack_id"],
            "title": body.title or card["title"],
            "lessons": card["lessons"],
        },
        "samples": samples,
        "sample_count": len(samples),
        "seed": project["seed"],
        # Ready-to-apply body for POST /api/creator-cards/apply.
        "apply": {
            "card_id": body.card_id,
            "project_type": "music",
            "project_id": project_id,
        },
    }
