"""
FEL OS — Coach Analytics (Nexus AAA).

Per-play breakdown, aggregate success rates, spatial success heatmaps, and
downloadable single-play replay slices — all computed deterministically FROM
the existing match/replay event stream (routers/matches.py). There is no
parallel event log: we read the same events the replay export reads.

Endpoints:
  GET /api/analytics/match/{match_id}                      -> full analytics
  GET /api/analytics/match/{match_id}/heatmap              -> heatmap grid only
  GET /api/analytics/match/{match_id}/play/{play_id}/export -> one play's events
"""
from datetime import datetime, timezone
from typing import Any, Dict

from fastapi import APIRouter, HTTPException, Query

from lib.coach_analytics import (
    DEFAULT_GRID,
    build_heatmap,
    build_match_analytics,
    build_play_breakdown,
    slice_play_events,
)
from routers.matches import _load_events, _load_match

router = APIRouter(tags=["analytics"])

# Cap the grid so a caller can't request an absurdly large allocation.
_MAX_GRID = 24
# Read the entire event stream for analytics (replay export uses the same bound).
_EVENT_READ_LIMIT = 10_000


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _require_match(match_id: str) -> Dict[str, Any]:
    match = await _load_match(match_id)
    if not match:
        raise HTTPException(status_code=404, detail="Match not found")
    return match


def _clamp_grid(grid: int) -> int:
    if grid < 1:
        return 1
    if grid > _MAX_GRID:
        return _MAX_GRID
    return grid


@router.get("/api/analytics/match/{match_id}")
async def match_analytics(
    match_id: str,
    grid: int = Query(DEFAULT_GRID, ge=1, le=_MAX_GRID),
) -> Dict[str, Any]:
    """Per-play breakdown + aggregate success rates + spatial heatmap grid."""
    match = await _require_match(match_id)
    events = await _load_events(match_id, limit=_EVENT_READ_LIMIT)
    return build_match_analytics(match, events, grid=_clamp_grid(grid))


@router.get("/api/analytics/match/{match_id}/heatmap")
async def match_heatmap(
    match_id: str,
    grid: int = Query(DEFAULT_GRID, ge=1, le=_MAX_GRID),
) -> Dict[str, Any]:
    """Spatial hit-map / success-heatmap grid data only."""
    match = await _require_match(match_id)
    events = await _load_events(match_id, limit=_EVENT_READ_LIMIT)
    plays = build_play_breakdown(sorted(events, key=lambda e: e.get("seq", 0)))
    heatmap = build_heatmap(plays, grid=_clamp_grid(grid))
    return {
        "match_id": match_id,
        "mode_id": match.get("mode_id"),
        "heatmap": heatmap,
    }


@router.get("/api/analytics/match/{match_id}/play/{play_id}/export")
async def export_play(match_id: str, play_id: str) -> Dict[str, Any]:
    """Downloadable event-slice for a single play (reuses the replay shape)."""
    match = await _require_match(match_id)
    events = await _load_events(match_id, limit=_EVENT_READ_LIMIT)
    slice_events = slice_play_events(events, play_id)
    if not slice_events:
        raise HTTPException(status_code=404, detail="Play not found")
    metadata = {
        "match_id": match_id,
        "play_id": play_id,
        "mode_id": match.get("mode_id"),
        "seed": match.get("seed"),
        "judge_offsets": match.get("judge_offsets", []),
        "players": match.get("players", []),
        "export_kind": "play_slice",
        "export_version": "1.0",
        "exported_at": _now(),
        "event_count": len(slice_events),
    }
    return {"metadata": metadata, "events": slice_events}
