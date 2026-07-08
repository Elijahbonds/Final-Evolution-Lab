"""
FEL OS — Creator Card refs + generic replay export (creative foundation)

Provides:
  GET  /api/creator-cards/packs        — card_id -> lesson-pack registry
  POST /api/creator-cards/apply        — attach a card's lesson pack to a
                                         music/dance project or art exhibit
  GET  /api/replays/{replay_id}/export — GENERIC replay export. Reuses the
        existing match replay export for match ids, and the same event store
        for creative project ids. No parallel replay system.

Storage: creator_card_refs via lib/creative_store.py; replay events via the
existing store in routers/matches.py.
"""
import uuid
from typing import Any, Dict, Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from core import User
from lib import creative_store
from lib.creative_store import CREATOR_CARD_PACKS, get_creative_user, now
from routers import matches as matches_router

router = APIRouter(tags=["creator-cards"])


# ── Pydantic schemas ───────────────────────────────────────────────────────

class ApplyCardRequest(BaseModel):
    card_id: str
    project_type: Literal["music", "dance", "art"]
    project_id: str  # music/dance project_id or art exhibit_id


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.get("/api/creator-cards/packs")
async def list_card_packs() -> Dict[str, Any]:
    """Contract registry: Creator Card IDs -> music/dance/art lesson packs."""
    return {"packs": CREATOR_CARD_PACKS}


@router.post("/api/creator-cards/apply")
async def apply_creator_card(
    body: ApplyCardRequest,
    user: User = Depends(get_creative_user),
) -> Dict[str, Any]:
    """Attach a Creator Card's lesson pack to a creative project."""
    pack = CREATOR_CARD_PACKS.get(body.card_id)
    if pack is None:
        raise HTTPException(status_code=404, detail=f"Unknown Creator Card: {body.card_id}")
    if pack["mode"] != body.project_type:
        raise HTTPException(
            status_code=422,
            detail=f"Card {body.card_id} is a {pack['mode']} pack; cannot apply to a "
                   f"{body.project_type} project",
        )
    project = await creative_store.load_project(body.project_type, body.project_id)
    if not project:
        raise HTTPException(status_code=404, detail=f"{body.project_type} project not found")

    applied = project.setdefault("applied_card_packs", [])
    if any(p.get("card_id") == body.card_id for p in applied):
        raise HTTPException(status_code=409, detail="Card already applied to this project")

    ref: Dict[str, Any] = {
        "ref_id": f"ref_{uuid.uuid4().hex[:12]}",
        "card_id": body.card_id,
        "pack_id": pack["pack_id"],
        "project_type": body.project_type,
        "project_id": body.project_id,
        "owner_id": user.user_id,
        "applied_at": now(),
    }
    applied.append({
        "card_id": body.card_id,
        "pack_id": pack["pack_id"],
        "title": pack["title"],
        "lessons": pack["lessons"],
        "ref_id": ref["ref_id"],
        "applied_at": ref["applied_at"],
    })
    await creative_store.persist_project(body.project_type, project)
    await creative_store.persist("creator_card_refs", "ref_id", ref)
    # Card application is part of the composition replay (shared event store).
    await matches_router._persist_event(body.project_id, {
        "type": "card_applied",
        "project_type": body.project_type,
        "project_id": body.project_id,
        "player_id": user.user_id,
        "card_id": body.card_id,
        "pack_id": pack["pack_id"],
        "timestamp": ref["applied_at"],
    })
    return {
        "ok": True,
        "ref_id": ref["ref_id"],
        "card_id": body.card_id,
        "pack": {"pack_id": pack["pack_id"], "title": pack["title"], "lessons": pack["lessons"]},
        "project_type": body.project_type,
        "project_id": body.project_id,
    }


@router.get("/api/replays/{replay_id}/export")
async def export_replay_generic(replay_id: str) -> Dict[str, Any]:
    """Generic replay export for match ids AND creative project ids.

    Matches delegate to the existing GET /api/matches/{id}/export-replay
    implementation; creative projects read the SAME event store, so both
    return the canonical {metadata: {...}, events: [...]} shape.
    """
    match = await matches_router._load_match(replay_id)
    if match is not None:
        return await matches_router.export_replay(replay_id)

    record = await creative_store.find_any_project(replay_id)
    if record is None:
        raise HTTPException(status_code=404, detail="Replay not found")

    events = await matches_router._load_events(replay_id, limit=10_000)
    events = sorted(events, key=lambda e: e.get("seq", 0))
    metadata = {
        "replay_id": replay_id,
        "replay_kind": "creative_project",
        "project_type": record["project_type"],
        "owner_id": record.get("owner_id"),
        "seed": record.get("seed"),
        "created_at": record.get("created_at"),
        "export_version": "1.1",
        "event_count": len(events),
    }
    return {"metadata": metadata, "events": events}
