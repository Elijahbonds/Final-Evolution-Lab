"""
coach_analytics.py — Deterministic per-play & spatial analytics for Nexus matches.

Everything here is a *pure function of the replay event stream* produced by
routers/matches.py + routers/dunk.py. There is NO separate analytics event log:
we read the same `match_events` (`_events` under MOCK_DB) that the replay export
uses, so analytics are guaranteed consistent with replays and deterministic for a
given event list.

Event types consumed (see routers/matches.py, routers/dunk.py):
  - match_start / match_end : lifecycle markers (ignored for play breakdown)
  - input                   : player input (not a scoring "play")
  - score_event             : shot / point. carries `points` and `payload.points`
  - dunk_result             : dunk. carries `total`, `j1/j2/j3`, `is_perfect`, `inputs`
  - answer_event / answer   : trivia / quiz answer. carries `payload.correct`

A "play" is any scoring/attempt event (score_event, dunk_result, answer_event).
Each play has an OUTCOME (success / attempt) and, where available, a POSITION.

Position resolution (best-effort, order of precedence):
  1. event["position"]                         -> {"x": float, "y": float}
  2. event["payload"]["position"]              -> {"x": float, "y": float}
  3. event["payload"]["pos"]                   -> {"x": float, "y": float} or [x, y]
Positions are expected in a normalized [0, 1] x [0, 1] court space. Out-of-range
values are clamped into range before bucketing so a stray coordinate never lands
outside the grid.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple

# Event types that represent a "play" (an attempt that can succeed or fail).
PLAY_EVENT_TYPES = ("score_event", "dunk_result", "answer_event", "answer")

# Non-play lifecycle / telemetry events, excluded from the play breakdown.
NON_PLAY_EVENT_TYPES = ("match_start", "match_end", "input", "snapshot", "checkpoint")

DEFAULT_GRID = 6  # default heatmap resolution (GRID x GRID cells)


def _clamp01(v: float) -> float:
    if v < 0.0:
        return 0.0
    if v > 1.0:
        return 1.0
    return v


def _extract_position(event: Dict[str, Any]) -> Optional[Tuple[float, float]]:
    """Return a normalized (x, y) in [0,1]^2 for an event, or None if absent."""
    raw = None
    if isinstance(event.get("position"), (dict, list, tuple)):
        raw = event["position"]
    else:
        payload = event.get("payload") or {}
        if isinstance(payload, dict):
            if isinstance(payload.get("position"), (dict, list, tuple)):
                raw = payload["position"]
            elif isinstance(payload.get("pos"), (dict, list, tuple)):
                raw = payload["pos"]
    if raw is None:
        return None
    try:
        if isinstance(raw, dict):
            x = float(raw["x"])
            y = float(raw["y"])
        else:  # list/tuple [x, y]
            x = float(raw[0])
            y = float(raw[1])
    except (KeyError, IndexError, TypeError, ValueError):
        return None
    return _clamp01(x), _clamp01(y)


def _is_success(event: Dict[str, Any]) -> bool:
    """Determine whether a play event was a success.

    - score_event : success if it scored points (> 0).
    - dunk_result : success if `is_perfect`, else if `total` clears a make
                    threshold (>= 30, i.e. a completed dunk, not a whiff).
    - answer_*    : success if payload.correct is truthy.
    """
    etype = event.get("type")
    if etype == "score_event":
        pts = event.get("points")
        if pts is None:
            pts = (event.get("payload") or {}).get("points", 0)
        try:
            return int(pts) > 0
        except (TypeError, ValueError):
            return False
    if etype == "dunk_result":
        if event.get("is_perfect"):
            return True
        try:
            return int(event.get("total", 0)) >= 30
        except (TypeError, ValueError):
            return False
    if etype in ("answer_event", "answer"):
        return bool((event.get("payload") or {}).get("correct", event.get("correct", False)))
    return False


def _play_points(event: Dict[str, Any]) -> int:
    """Points/score contributed by a play (0 if not applicable)."""
    etype = event.get("type")
    if etype == "score_event":
        pts = event.get("points")
        if pts is None:
            pts = (event.get("payload") or {}).get("points", 0)
    elif etype == "dunk_result":
        pts = event.get("total", 0)
    else:
        pts = 0
    try:
        return int(pts)
    except (TypeError, ValueError):
        return 0


def _play_id(event: Dict[str, Any], index: int) -> str:
    """Stable play identifier. Uses server-stamped `seq` when present (unique,
    monotonic), else falls back to positional index. Prefixed 'play-'."""
    seq = event.get("seq")
    if isinstance(seq, int):
        return f"play-{seq}"
    return f"play-idx-{index}"


def is_play_event(event: Dict[str, Any]) -> bool:
    return event.get("type") in PLAY_EVENT_TYPES


def build_play_breakdown(events: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """One record per play (scoring/attempt event), in event order.

    Deterministic: output depends only on the input event list.
    """
    plays: List[Dict[str, Any]] = []
    for i, ev in enumerate(events):
        if not is_play_event(ev):
            continue
        pos = _extract_position(ev)
        plays.append(
            {
                "play_id": _play_id(ev, i),
                "seq": ev.get("seq", i),
                "type": ev.get("type"),
                "player_id": ev.get("player_id"),
                "success": _is_success(ev),
                "points": _play_points(ev),
                "position": {"x": pos[0], "y": pos[1]} if pos else None,
                "timestamp": ev.get("timestamp"),
            }
        )
    return plays


def compute_success_rates(plays: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Aggregate success-rate stats overall, per event type, and per player."""
    def _bucket() -> Dict[str, Any]:
        return {"attempts": 0, "successes": 0, "points": 0}

    overall = _bucket()
    by_type: Dict[str, Dict[str, Any]] = {}
    by_player: Dict[str, Dict[str, Any]] = {}

    for p in plays:
        overall["attempts"] += 1
        overall["successes"] += 1 if p["success"] else 0
        overall["points"] += p["points"]

        t = p["type"]
        bt = by_type.setdefault(t, _bucket())
        bt["attempts"] += 1
        bt["successes"] += 1 if p["success"] else 0
        bt["points"] += p["points"]

        pid = p["player_id"] if p["player_id"] is not None else "unknown"
        bp = by_player.setdefault(pid, _bucket())
        bp["attempts"] += 1
        bp["successes"] += 1 if p["success"] else 0
        bp["points"] += p["points"]

    def _finish(b: Dict[str, Any]) -> Dict[str, Any]:
        att = b["attempts"]
        b["success_rate"] = round(b["successes"] / att, 4) if att else 0.0
        return b

    _finish(overall)
    for b in by_type.values():
        _finish(b)
    for b in by_player.values():
        _finish(b)

    return {"overall": overall, "by_type": by_type, "by_player": by_player}


def _cell_index(v: float, grid: int) -> int:
    """Map a normalized coord in [0,1] to a cell index in [0, grid-1]."""
    idx = int(v * grid)
    if idx >= grid:  # v == 1.0 lands exactly on the boundary
        idx = grid - 1
    if idx < 0:
        idx = 0
    return idx


def build_heatmap(
    plays: List[Dict[str, Any]], grid: int = DEFAULT_GRID
) -> Dict[str, Any]:
    """Bucket play positions into a grid x grid grid, counting attempts/successes.

    Returns a dense grid (every cell present) so the frontend can render without
    sparse-handling. Plays with no position are counted in `unpositioned`.
    Deterministic for a given (plays, grid).
    """
    if grid < 1:
        grid = 1
    # cells[row][col] with row = y bucket, col = x bucket
    cells = [
        [{"row": r, "col": c, "attempts": 0, "successes": 0, "points": 0}
         for c in range(grid)]
        for r in range(grid)
    ]
    unpositioned = {"attempts": 0, "successes": 0, "points": 0}

    for p in plays:
        pos = p.get("position")
        if not pos:
            unpositioned["attempts"] += 1
            unpositioned["successes"] += 1 if p["success"] else 0
            unpositioned["points"] += p["points"]
            continue
        col = _cell_index(pos["x"], grid)
        row = _cell_index(pos["y"], grid)
        cell = cells[row][col]
        cell["attempts"] += 1
        cell["successes"] += 1 if p["success"] else 0
        cell["points"] += p["points"]

    # attach per-cell success_rate for convenience
    max_attempts = 0
    for row in cells:
        for cell in row:
            att = cell["attempts"]
            cell["success_rate"] = round(cell["successes"] / att, 4) if att else 0.0
            if att > max_attempts:
                max_attempts = att

    return {
        "grid": grid,
        "cells": cells,
        "unpositioned": unpositioned,
        "max_cell_attempts": max_attempts,
        "positioned_plays": sum(1 for p in plays if p.get("position")),
        "total_plays": len(plays),
    }


def build_match_analytics(
    match: Dict[str, Any],
    events: List[Dict[str, Any]],
    grid: int = DEFAULT_GRID,
) -> Dict[str, Any]:
    """Full analytics payload for a match, computed from its event stream."""
    ordered = sorted(events, key=lambda e: e.get("seq", 0))
    plays = build_play_breakdown(ordered)
    rates = compute_success_rates(plays)
    heatmap = build_heatmap(plays, grid=grid)
    return {
        "match_id": match.get("match_id"),
        "mode_id": match.get("mode_id"),
        "status": match.get("status"),
        "players": match.get("players", []),
        "seed": match.get("seed"),
        "event_count": len(ordered),
        "play_count": len(plays),
        "plays": plays,
        "success_rates": rates,
        "heatmap": heatmap,
    }


def slice_play_events(
    events: List[Dict[str, Any]], play_id: str
) -> List[Dict[str, Any]]:
    """Return the event-slice for a single play, reusing the replay event shape.

    The slice is the play event itself plus any immediately-preceding `input`
    events that belong to the same play window (inputs since the previous play
    or match_start). This gives a downloadable, self-contained mini-replay.
    """
    ordered = sorted(events, key=lambda e: e.get("seq", 0))
    # locate the target play
    target_idx = None
    for i, ev in enumerate(ordered):
        if is_play_event(ev) and _play_id(ev, i) == play_id:
            target_idx = i
            break
    if target_idx is None:
        return []

    # walk back to the previous play or a lifecycle boundary
    start = 0
    for j in range(target_idx - 1, -1, -1):
        ev = ordered[j]
        if is_play_event(ev) or ev.get("type") in ("match_start", "match_end"):
            start = j + 1 if is_play_event(ev) else j + 1
            break
    return ordered[start : target_idx + 1]
