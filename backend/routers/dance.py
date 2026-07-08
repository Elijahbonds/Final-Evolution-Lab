"""
FEL OS — Dance Game Router (foundation + Dance Mode)

Foundation (creative-models):
  POST /api/dance/projects                      — create a dance project
  GET  /api/dance/projects/{project_id}         — fetch a dance project
  POST /api/dance/projects/{project_id}/export  — JSON project export

Dance Mode (nexus/dance-mode-core) — rhythm performance + choreography:
  GET  /api/dance/projects/{id}/beatmap         — deterministic beatmap (seed+bpm)
  POST /api/dance/projects/{id}/score           — score submitted hits (deterministic)
  POST /api/dance/projects/{id}/record          — persist a performance run as replay events
  POST /api/dance/projects/{id}/choreography    — save/update choreography timeline

Storage: lib/creative_store.py (MOCK_DB=1 -> in-memory, else db.dance_projects).
Performance replay events reuse the existing match event store (routers.matches).
Scoring/beatmap live in lib/dance_beatmap.py (pure, deterministic).
"""
import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from core import User
from lib import creative_store
from lib import dance_beatmap
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


# ── Dance Mode: rhythm performance + choreography ──────────────────────────

class HitModel(BaseModel):
    time_ms: float = Field(..., description="Client hit time from performance start (t=0)")
    lane: int = Field(0, ge=0, le=7)


class ScoreRequest(BaseModel):
    hits: List[HitModel] = []
    latency_ms: float = Field(0.0, ge=0.0, le=1000.0, description="Client latency, normalised out")
    difficulty: str = Field(dance_beatmap.DEFAULT_DIFFICULTY)
    beats: int = Field(32, ge=4, le=256)
    subdivision: int = Field(2, ge=1, le=8)
    # Beatmap variant to score against — must mirror what the client played so the
    # server rebuilds the identical map. Defaults reproduce the classic map.
    style: str = Field("classic", description="classic (default) | phrased")
    curve: bool = Field(False, description="Density ramp (phrased only)")
    holds: bool = Field(False, description="Annotate hold events with duration fields")
    chords: bool = Field(False, description="2-lane chords on hard/expert (phrased only)")
    contest_seed: Optional[int] = Field(None, ge=0, lt=1 << 64,
                                        description="Seeded judge offsets for reproducible contests")


class RecordRequest(ScoreRequest):
    recording: bool = Field(False, description="RECORDING_LOCAL: locally-authoritative solo run")


class ChoreographyRequest(BaseModel):
    timeline: Dict[str, Any] = Field(..., description="{entries:[{animation,start_beat,speed?,transition?}]}")
    save_as_pack: bool = Field(False, description="Creator Card tie-in: card_choreo_01 pack")


def _beatmap_for(
    project: Dict[str, Any], *, difficulty: str, beats: int, subdivision: int,
    style: str = "classic", curve: bool = False, holds: bool = False, chords: bool = False,
) -> Dict[str, Any]:
    return dance_beatmap.generate_beatmap(
        project["seed"], project["bpm"],
        beats=beats, subdivision=subdivision, difficulty=difficulty,
        style=style, curve=curve, holds=holds, chords=chords,
    )


@router.get("/api/dance/projects/{project_id}/beatmap")
async def get_beatmap(
    project_id: str,
    difficulty: str = Query(dance_beatmap.DEFAULT_DIFFICULTY),
    beats: int = Query(32, ge=4, le=256),
    subdivision: int = Query(2, ge=1, le=8),
    style: str = Query("classic", description="classic (default, byte-identical) | phrased"),
    curve: bool = Query(False, description="Density ramp (phrased only)"),
    holds: bool = Query(False, description="Annotate hold events with duration fields"),
    chords: bool = Query(False, description="2-lane chords on hard/expert (phrased only)"),
) -> Dict[str, Any]:
    """Deterministic beatmap from the project's persisted seed + bpm.

    The frontend generates the identical beatmap so the scrolling notes match
    exactly what the server scores against. The default (style="classic") is
    byte-identical to the first pass; style="phrased" + curve/holds/chords opt
    into the richer engine.
    """
    project = await creative_store.load_project("dance", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Dance project not found")
    return _beatmap_for(project, difficulty=difficulty, beats=beats, subdivision=subdivision,
                        style=style, curve=curve, holds=holds, chords=chords)


@router.post("/api/dance/projects/{project_id}/score")
async def score_run(project_id: str, body: ScoreRequest) -> Dict[str, Any]:
    """Score submitted hit timestamps against the deterministic beatmap.

    Pure function of (seed, bpm, hits, latency, contest_seed) — same inputs
    always produce the same score. Does not persist anything.
    """
    project = await creative_store.load_project("dance", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Dance project not found")
    beatmap = _beatmap_for(project, difficulty=body.difficulty, beats=body.beats,
                           subdivision=body.subdivision, style=body.style,
                           curve=body.curve, holds=body.holds, chords=body.chords)
    result = dance_beatmap.score_performance(
        beatmap,
        [h.model_dump() for h in body.hits],
        latency_ms=body.latency_ms,
        contest_seed=body.contest_seed,
    )
    return {"project_id": project_id, "beatmap_seed": project["seed"], "result": result}


@router.post("/api/dance/projects/{project_id}/record")
async def record_run(
    project_id: str,
    body: RecordRequest,
    user: User = Depends(get_creative_user),
) -> Dict[str, Any]:
    """Score a run AND persist it to the replay event store (reused match store).

    Used by RECORDING_LOCAL / ?recording=1 solo runs: locally-authoritative,
    seed visible, replayable via /api/replays/{id}/export.
    """
    project = await creative_store.load_project("dance", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Dance project not found")
    beatmap = _beatmap_for(project, difficulty=body.difficulty, beats=body.beats,
                           subdivision=body.subdivision, style=body.style,
                           curve=body.curve, holds=body.holds, chords=body.chords)
    result = dance_beatmap.score_performance(
        beatmap,
        [h.model_dump() for h in body.hits],
        latency_ms=body.latency_ms,
        contest_seed=body.contest_seed,
    )
    await matches_router._persist_event(project_id, {
        "type": "performance_recorded",
        "project_type": "dance",
        "project_id": project_id,
        "player_id": user.user_id,
        "seed": project["seed"],
        "difficulty": body.difficulty,
        "style": body.style,
        "recording": body.recording,
        "score": result["score"],
        "score_with_bonus": result["score_with_bonus"],
        "max_combo": result["max_combo"],
        "accuracy": result["accuracy"],
        "grade": result["grade"],
        "sub_grade": result["sub_grade"],
        "full_combo": result["full_combo"],
        "tallies": result["tallies"],
        "hit_count": len(body.hits),
        "contest_seed": body.contest_seed,
        "timestamp": now(),
    })
    return {"project_id": project_id, "recorded": True, "result": result}


@router.post("/api/dance/projects/{project_id}/choreography")
async def save_choreography(
    project_id: str,
    body: ChoreographyRequest,
    user: User = Depends(get_creative_user),
) -> Dict[str, Any]:
    """Persist the choreography timeline; optionally emit a Creator Card pack event.

    Creator Card tie-in uses the foundation contract (card_choreo_01 ->
    pack_choreography_101) — no parallel system; apply the card itself via
    POST /api/creator-cards/apply.
    """
    project = await creative_store.load_project("dance", project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Dance project not found")
    project["timeline"] = body.timeline
    await creative_store.persist_project("dance", project)
    await matches_router._persist_event(project_id, {
        "type": "choreography_saved",
        "project_type": "dance",
        "project_id": project_id,
        "player_id": user.user_id,
        "entry_count": len(body.timeline.get("entries", [])),
        "saved_as_pack": body.save_as_pack,
        "pack_card_id": "card_choreo_01" if body.save_as_pack else None,
        "timestamp": now(),
    })
    return {"project_id": project_id, "saved": True, "timeline": project["timeline"]}
