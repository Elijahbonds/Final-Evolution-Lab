"""
creative_store.py — Shared MOCK_DB-aware persistence for the creative-modes
foundation (Music Creation, Dance Game, Art Showcase).

Mirrors the storage conventions established in routers/matches.py:
  - MOCK_DB=1 env var (or running under pytest) -> in-memory dict stores
  - otherwise -> MongoDB collections (db.music_projects, db.dance_projects,
    db.art_exhibits, db.creator_card_refs) with in-memory fallback on error.

IMPORTANT: replay events are NOT stored here. Composition/performance replays
reuse the EXISTING match event store (routers.matches._persist_event /
_load_events) keyed by project_id, so replay recording + export stays a single
system across matches and creative projects.
"""
import os
import sys
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from fastapi import Request

from core import db, get_current_user, User

# ── Detect mock-DB mode (same rule as routers/matches.py) ──────────────────
_MOCK_DB = os.environ.get("MOCK_DB", "0") == "1" or (
    len(sys.argv) > 0 and "pytest" in sys.argv[0]
)

# ── In-memory stores (used when _MOCK_DB=True, or as DB-error fallback) ────
_memory: Dict[str, Dict[str, Dict[str, Any]]] = {
    "music_projects": {},
    "dance_projects": {},
    "art_exhibits": {},
    "creator_card_refs": {},
}

# Which store + primary-key field each creative project type uses.
PROJECT_COLLECTIONS: Dict[str, Dict[str, str]] = {
    "music": {"collection": "music_projects", "key_field": "project_id"},
    "dance": {"collection": "dance_projects", "key_field": "project_id"},
    "art": {"collection": "art_exhibits", "key_field": "exhibit_id"},
}


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def get_creative_user(request: Request) -> User:
    """Auth for creative endpoints (same contract as matches.get_match_user).

    Production (MOCK_DB unset): identical to get_current_user.
    MOCK_DB=1: falls back to a guest identity so local harnesses can drive
    the API without a session. Guest id via the X-FEL-Sim-Player header.
    """
    try:
        return await get_current_user(request)
    except Exception:
        if not _MOCK_DB:
            raise
        pid = request.headers.get("X-FEL-Sim-Player", "sim_guest")
        return User(user_id=pid, email=f"{pid}@sim.fellab.io", name=pid)


async def persist(collection: str, key_field: str, record: Dict[str, Any]) -> None:
    """Upsert a record into `collection`, keyed on record[key_field]."""
    key = record[key_field]
    if _MOCK_DB:
        _memory[collection][key] = record
        return
    try:
        await getattr(db, collection).replace_one({key_field: key}, record, upsert=True)
    except Exception:
        _memory[collection][key] = record


async def load(collection: str, key_field: str, key: str) -> Optional[Dict[str, Any]]:
    """Load a record from `collection` by primary key. None if missing."""
    if _MOCK_DB:
        return _memory[collection].get(key)
    try:
        return await getattr(db, collection).find_one({key_field: key}, {"_id": 0})
    except Exception:
        return _memory[collection].get(key)


async def load_project(project_type: str, project_id: str) -> Optional[Dict[str, Any]]:
    """Load a music/dance project or art exhibit by its id."""
    spec = PROJECT_COLLECTIONS[project_type]
    return await load(spec["collection"], spec["key_field"], project_id)


async def persist_project(project_type: str, record: Dict[str, Any]) -> None:
    spec = PROJECT_COLLECTIONS[project_type]
    await persist(spec["collection"], spec["key_field"], record)


async def find_any_project(project_id: str) -> Optional[Dict[str, Any]]:
    """Search all creative stores for `project_id`.

    Returns the record with a `project_type` key injected, or None.
    Used by the generic replay export endpoint.
    """
    for project_type in PROJECT_COLLECTIONS:
        record = await load_project(project_type, project_id)
        if record is not None:
            return {**record, "project_type": project_type}
    return None


# ── Creator Card refs: card_id -> music/dance/art lesson pack ──────────────
# Foundation registry the three mode branches build on. Mode branches may
# extend this table; card ids are stable contract identifiers.
CREATOR_CARD_PACKS: Dict[str, Dict[str, Any]] = {
    "card_maestro_01": {
        "pack_id": "pack_music_theory_101",
        "mode": "music",
        "title": "Music Theory 101",
        "lessons": ["intervals", "chord_progressions", "song_structure"],
    },
    "card_sampler_01": {
        "pack_id": "pack_beatmaking_101",
        "mode": "music",
        "title": "Sampling & Beatmaking",
        "lessons": ["chopping_samples", "drum_patterns", "swing_and_groove"],
    },
    "card_groove_01": {
        "pack_id": "pack_dance_footwork_101",
        "mode": "dance",
        "title": "Footwork Fundamentals",
        "lessons": ["two_step", "slides", "weight_transfer"],
    },
    "card_choreo_01": {
        "pack_id": "pack_choreography_101",
        "mode": "dance",
        "title": "Choreography Basics",
        "lessons": ["counts_and_phrasing", "formations", "musicality"],
    },
    "card_visionary_01": {
        "pack_id": "pack_art_composition_101",
        "mode": "art",
        "title": "Composition & Framing",
        "lessons": ["rule_of_thirds", "color_balance", "focal_points"],
    },
    "card_curator_01": {
        "pack_id": "pack_exhibit_curation_101",
        "mode": "art",
        "title": "Exhibit Curation",
        "lessons": ["sequencing_works", "gallery_lighting", "artist_statements"],
    },
}
