"""
FEL OS — Nexus Telemetry & Dashboards (Nexus AAA, Telemetry workstream).

Event ingest + deterministic metric aggregation for the Nexus backend.

Endpoints:
  POST /api/telemetry/event      — ingest a single telemetry event
  GET  /api/telemetry/events     — list recent events (debug / verification)
  GET  /api/telemetry/dashboard  — computed metrics over all ingested events
  POST /api/telemetry/reset      — clear the in-memory store (MOCK_DB only; test aid)

In-memory store is used automatically when:
  - MOCK_DB=1 env var is set, or
  - the module is imported under pytest (sys.argv[0] ends in 'pytest').

This mirrors the storage pattern in routers/matches.py: an in-memory list is
the source of truth under MOCK_DB, with a best-effort MongoDB write-through in
production. Aggregation is a pure function of the event list, so
GET /api/telemetry/dashboard is deterministic given the same set of events.
"""
import os
import sys
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

try:
    # Available in the full server; unused under MOCK_DB but imported for parity.
    from core import db  # type: ignore
except Exception:  # pragma: no cover - defensive for isolated unit apps
    db = None  # type: ignore

router = APIRouter(tags=["telemetry"])

# ── Detect mock-DB mode ────────────────────────────────────────────────────
_MOCK_DB = os.environ.get("MOCK_DB", "0") == "1" or (
    len(sys.argv) > 0 and "pytest" in sys.argv[0]
)

# ── Event taxonomy ─────────────────────────────────────────────────────────
EVENT_TYPES = {
    "match_start",
    "match_end",
    "replay_export",
    "creator_card_apply",
    "question_answer",
    "dunk_score",
    "latency_sample",
}

# ── In-memory store (used when _MOCK_DB=True) ──────────────────────────────
_events: List[Dict[str, Any]] = []


# ── Pydantic schemas ───────────────────────────────────────────────────────

class TelemetryEvent(BaseModel):
    event_type: str = Field(..., description="One of the supported EVENT_TYPES")
    match_id: Optional[str] = None
    payload: Dict[str, Any] = Field(default_factory=dict)
    ts: Optional[str] = None  # ISO8601; server-stamped if omitted


# ── Helpers ────────────────────────────────────────────────────────────────

def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


async def _persist_event(event: Dict[str, Any]) -> None:
    """Append to in-memory store; best-effort MongoDB write-through in prod."""
    _events.append(event)
    if _MOCK_DB or db is None:
        return
    try:  # pragma: no cover - requires a live Mongo
        await db.telemetry_events.insert_one({**event})
    except Exception:
        pass  # in-memory list is already authoritative


async def _load_events() -> List[Dict[str, Any]]:
    """Return all events. In prod, merge Mongo docs with the in-memory list."""
    if _MOCK_DB or db is None:
        return list(_events)
    try:  # pragma: no cover - requires a live Mongo
        docs = await db.telemetry_events.find({}, {"_id": 0}).to_list(100_000)
        return list(docs)
    except Exception:
        return list(_events)


def _percentile(values: List[float], pct: float) -> float:
    """Deterministic nearest-rank percentile (pct in [0,100]).

    Nearest-rank avoids interpolation ambiguity so the value is exactly one of
    the observed samples — reproducible across runs and platforms.
    """
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return round(ordered[0], 4)
    # rank = ceil(pct/100 * N), clamped to [1, N]; index = rank - 1
    import math
    rank = math.ceil((pct / 100.0) * len(ordered))
    rank = max(1, min(rank, len(ordered)))
    return round(ordered[rank - 1], 4)


def _compute_dashboard(events: List[Dict[str, Any]]) -> Dict[str, Any]:
    """Pure aggregation over the event list. Deterministic given same events."""
    by_type: Dict[str, int] = {t: 0 for t in EVENT_TYPES}
    for e in events:
        et = e.get("event_type")
        if et in by_type:
            by_type[et] += 1
        else:
            by_type[et] = by_type.get(et, 0) + 1

    # ── Latency / frame-time percentiles ───────────────────────────────────
    # A latency_sample payload may carry frame_time_ms and/or a desync flag.
    frame_times: List[float] = []
    desync_flags = 0
    latency_total = 0
    for e in events:
        if e.get("event_type") != "latency_sample":
            continue
        latency_total += 1
        p = e.get("payload", {})
        ft = p.get("frame_time_ms")
        if isinstance(ft, (int, float)):
            frame_times.append(float(ft))
        if p.get("desync") is True:
            desync_flags += 1

    frame_time_p95 = _percentile(frame_times, 95.0)
    frame_time_p50 = _percentile(frame_times, 50.0)
    desync_rate = round(desync_flags / latency_total, 4) if latency_total else 0.0

    # ── Replay-validator failures ──────────────────────────────────────────
    # A replay_export payload carries validation status; count failures.
    replay_total = by_type.get("replay_export", 0)
    replay_failures = 0
    for e in events:
        if e.get("event_type") != "replay_export":
            continue
        p = e.get("payload", {})
        ok = p.get("valid")
        if ok is None:
            ok = p.get("validation_passed")
        if ok is False:
            replay_failures += 1
    replay_failure_rate = (
        round(replay_failures / replay_total, 4) if replay_total else 0.0
    )

    # ── Creator-card conversion rate ───────────────────────────────────────
    # Conversion = fraction of card applies whose payload marks it as applied
    # to a match (converted). Falls back to applies/starts if not marked.
    card_applies = by_type.get("creator_card_apply", 0)
    card_converted = 0
    for e in events:
        if e.get("event_type") != "creator_card_apply":
            continue
        p = e.get("payload", {})
        if p.get("converted") is True or e.get("match_id"):
            card_converted += 1
    card_conversion_rate = (
        round(card_converted / card_applies, 4) if card_applies else 0.0
    )

    # ── Per-mode play counts (from match_start events) ─────────────────────
    per_mode: Dict[str, int] = {}
    for e in events:
        if e.get("event_type") != "match_start":
            continue
        mode = e.get("payload", {}).get("mode_id", "unknown")
        per_mode[mode] = per_mode.get(mode, 0) + 1

    # ── Dunk / question stats (light rollups) ──────────────────────────────
    dunk_scores = [
        float(e.get("payload", {}).get("total", 0.0))
        for e in events
        if e.get("event_type") == "dunk_score"
        and isinstance(e.get("payload", {}).get("total"), (int, float))
    ]
    avg_dunk_score = round(sum(dunk_scores) / len(dunk_scores), 4) if dunk_scores else 0.0

    question_events = [e for e in events if e.get("event_type") == "question_answer"]
    correct = sum(
        1 for e in question_events if e.get("payload", {}).get("correct") is True
    )
    question_accuracy = (
        round(correct / len(question_events), 4) if question_events else 0.0
    )

    return {
        "total_events": len(events),
        "events_by_type": by_type,
        "desync_rate": desync_rate,
        "frame_time_p95_ms": frame_time_p95,
        "frame_time_p50_ms": frame_time_p50,
        "latency_sample_count": latency_total,
        "replay_export_count": replay_total,
        "replay_validator_failures": replay_failures,
        "replay_failure_rate": replay_failure_rate,
        "creator_card_applies": card_applies,
        "creator_card_conversions": card_converted,
        "creator_card_conversion_rate": card_conversion_rate,
        "per_mode_play_counts": per_mode,
        "avg_dunk_score": avg_dunk_score,
        "question_count": len(question_events),
        "question_accuracy": question_accuracy,
        "generated_at": _now(),
    }


# ── Endpoints ──────────────────────────────────────────────────────────────

@router.post("/api/telemetry/event")
async def ingest_event(body: TelemetryEvent) -> Dict[str, Any]:
    """Ingest a single telemetry event into the store."""
    if body.event_type not in EVENT_TYPES:
        raise HTTPException(
            status_code=422,
            detail=f"event_type must be one of {sorted(EVENT_TYPES)}",
        )
    event: Dict[str, Any] = {
        "event_type": body.event_type,
        "match_id": body.match_id,
        "payload": body.payload or {},
        "ts": body.ts or _now(),
        "received_at": _now(),
        "seq": len(_events),
    }
    await _persist_event(event)
    return {"ok": True, "seq": event["seq"], "event_type": event["event_type"]}


@router.get("/api/telemetry/events")
async def list_events(limit: int = 100) -> Dict[str, Any]:
    """Return the most recent `limit` events (verification / debug)."""
    events = await _load_events()
    return {"count": len(events), "events": events[-limit:]}


@router.get("/api/telemetry/dashboard")
async def dashboard() -> Dict[str, Any]:
    """Return computed telemetry metrics. Deterministic given the same events."""
    events = await _load_events()
    return _compute_dashboard(events)


@router.post("/api/telemetry/reset")
async def reset_events() -> Dict[str, Any]:
    """Clear the in-memory event store. Only permitted under MOCK_DB (test aid)."""
    if not _MOCK_DB:
        raise HTTPException(status_code=403, detail="reset only available under MOCK_DB")
    n = len(_events)
    _events.clear()
    return {"ok": True, "cleared": n}
