"""
FEL OS — Unified System Scan

Single endpoint that aggregates the four pillars:
  1. SCAN     — PRQ, biomechanics, streak, level
  2. CARDS    — Creator Card portfolio (owned + recommended)
  3. ARENA    — Game mode unlocks + recent sessions + Nexus bridge
  4. ACADEMY  — Education track progress + Kinesiology cert status
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone

from core import db, get_current_user, User

# Lazy import to avoid circular dependency — cache is populated after response built
def _maybe_cache_snapshot(data: dict) -> None:
    try:
        from routers.matches import cache_system_scan_snapshot
        cache_system_scan_snapshot(data)
    except Exception:
        pass
from routers.education_tracks import (
    TRACKS as EDU_TRACKS,
    _build_kinesiology_eligibility,
    BIO_DIGITAL_REQUIRED_MODULES,
)
from routers.biofuel import (
    nasm_macro_target,
    _today_intent,
    _athlete_weight_kg,
    _consumed_totals,
    _supportive_cues,
    ATHLETIC_INTENTS,
    _today_key,
)

router = APIRouter(prefix="/api/system-scan", tags=["system-scan"])


# ── Pydantic response models ───────────────────────────────────────────────

class MetricsPayload(BaseModel):
    strength: float = 0.0
    speed: float = 0.0
    endurance: float = 0.0
    agility: float = 0.0
    power: float = 0.0
    flexibility: float = 0.0
    recovery: float = 0.0
    mental: float = 0.0


class HealthPayload(BaseModel):
    resting_hr: float = 0.0
    hrv: float = 0.0
    sleep_hours: float = 0.0
    vo2_max: float = 0.0


class ScanPayload(BaseModel):
    prq_score: float = 75.0
    level: int = 1
    xp: int = 0
    streak_days: int = 0
    coins: int = 0
    metrics: MetricsPayload = Field(default_factory=MetricsPayload)
    health: HealthPayload = Field(default_factory=HealthPayload)
    last_vertical_jump: Dict[str, Any] = Field(default_factory=dict)


class CardsPayload(BaseModel):
    owned_count: int = 0
    lifetime_purchases: int = 0
    recent: List[Dict[str, Any]] = Field(default_factory=list)


class ArenaPayload(BaseModel):
    modes_played: int = 0
    last_game: Dict[str, Any] = Field(default_factory=dict)
    modes_unlocked: List[str] = Field(default_factory=list)
    sovereign_sessions: int = 0
    nexus_bridge: str = "ready"


class AcademyTrack(BaseModel):
    track_id: str
    title: str
    completion_pct: float = 0.0
    is_certificate: bool = False
    certificate_issued: bool = False
    certificate_id: Optional[str] = None


class AcademyPayload(BaseModel):
    overall_completion_pct: float = 0.0
    lessons_completed: int = 0
    lessons_total: int = 0
    tracks: List[AcademyTrack] = Field(default_factory=list)
    certificates: List[Dict[str, Any]] = Field(default_factory=list)
    kinesiology_certificate: Dict[str, Any] = Field(default_factory=dict)
    bio_digital: Dict[str, Any] = Field(default_factory=dict)


class UnifiedScanResponse(BaseModel):
    user: Dict[str, Any]
    scanned_at: str
    scan: ScanPayload
    cards: CardsPayload
    arena: ArenaPayload
    academy: AcademyPayload
    biofuel: Dict[str, Any] = Field(default_factory=dict)


# ── Endpoint ───────────────────────────────────────────────────────────────

@router.get("/unified", response_model=UnifiedScanResponse)
async def unified_system_scan(user: User = Depends(get_current_user)) -> UnifiedScanResponse:
    """Return the four-quadrant FEL OS snapshot for the current athlete."""

    # ---- 1. SCAN ----
    prq_doc = await db.prq_metrics.find_one({"user_id": user.user_id}, {"_id": 0}) or {}
    health_doc = await db.health_metrics.find_one({"user_id": user.user_id}, {"_id": 0}) or {}
    vj_docs = await db.vertical_jump_log.find(
        {"user_id": user.user_id}, {"_id": 0}
    ).sort("recorded_at", -1).limit(1).to_list(1)
    last_vj = vj_docs[0] if vj_docs else {}

    scan = ScanPayload(
        prq_score=user.prq_score,
        level=user.level,
        xp=user.xp,
        streak_days=user.streak_days,
        coins=user.coins,
        metrics=MetricsPayload(**{
            k: float(prq_doc.get(k) or 0.0)
            for k in ("strength", "speed", "endurance", "agility", "power", "flexibility", "recovery", "mental")
        }),
        health=HealthPayload(**{
            k: float(health_doc.get(k) or 0.0)
            for k in ("resting_hr", "hrv", "sleep_hours", "vo2_max")
        }),
        last_vertical_jump=last_vj,
    )

    # ---- 2. CARDS ----
    owned = await db.user_cards.find({"user_id": user.user_id}, {"_id": 0}).to_list(50)
    payment_count = await db.payments.count_documents({"user_id": user.user_id, "status": "completed"})
    cards = CardsPayload(
        owned_count=len(owned),
        lifetime_purchases=payment_count,
        recent=owned[-3:] if owned else [],
    )

    # ---- 3. ARENA ----
    game_count = await db.game_sessions.count_documents({"user_id": user.user_id})
    last_game_docs = await db.game_sessions.find(
        {"user_id": user.user_id}, {"_id": 0}
    ).sort("created_at", -1).limit(1).to_list(1)
    collection_names = await db.list_collection_names()
    sov_count = (
        await db.sovereign_sessions.count_documents({"user_id": user.user_id})
        if "sovereign_sessions" in collection_names
        else 0
    )
    # Derive unlocked modes from distinct game sessions
    modes_unlocked: List[str] = []
    if game_count > 0:
        # Best-effort distinct mode list (graceful if collection missing)
        try:
            mode_docs = await db.game_sessions.find(
                {"user_id": user.user_id}, {"_id": 0, "mode": 1}
            ).to_list(500)
            modes_unlocked = list({d["mode"] for d in mode_docs if d.get("mode")})
        except Exception:
            modes_unlocked = []

    arena = ArenaPayload(
        modes_played=game_count,
        last_game=last_game_docs[0] if last_game_docs else {},
        modes_unlocked=modes_unlocked,
        sovereign_sessions=sov_count,
        nexus_bridge="ready",
    )

    # ---- 4. ACADEMY ----
    edu_docs = await db.education_progress.find({"user_id": user.user_id}, {"_id": 0}).to_list(50)
    by_track = {d["track_id"]: d for d in edu_docs}
    academy_tracks: List[AcademyTrack] = []
    total_lessons = 0
    total_done = 0
    for tid, t in EDU_TRACKS.items():
        prog = by_track.get(tid, {})
        done = len(prog.get("completed_lessons", []))
        total = len(t["lessons"])
        total_lessons += total
        total_done += done
        academy_tracks.append(AcademyTrack(
            track_id=tid,
            title=t["title"],
            completion_pct=round(100 * done / total, 1) if total else 0.0,
            is_certificate=t.get("is_certificate", False),
            certificate_issued=prog.get("certificate_issued", False),
            certificate_id=prog.get("certificate_id"),
        ))

    kin_elig = await _build_kinesiology_eligibility(user)
    bd_doc = await db.bio_digital_progress.find_one({"user_id": user.user_id}, {"_id": 0}) or {}
    certificates = [
        {"track_id": t.track_id, "certificate_id": t.certificate_id, "issued": t.certificate_issued}
        for t in academy_tracks
        if t.is_certificate and t.certificate_issued
    ]

    academy = AcademyPayload(
        overall_completion_pct=round(100 * total_done / total_lessons, 1) if total_lessons else 0.0,
        lessons_completed=total_done,
        lessons_total=total_lessons,
        tracks=academy_tracks,
        certificates=certificates,
        kinesiology_certificate={
            "eligibility": kin_elig,
            "issued": (
                kin_elig["all_met"]
                and any(t.certificate_issued for t in academy_tracks if t.track_id == "kinesiology")
            ),
        },
        bio_digital={
            "modules_completed": bd_doc.get("modules_completed", []),
            "modules_required": BIO_DIGITAL_REQUIRED_MODULES,
        },
    )

    response = UnifiedScanResponse(
        user={"user_id": user.user_id, "name": user.name, "sport": user.sport, "picture": user.picture},
        scanned_at=datetime.now(timezone.utc).isoformat(),
        scan=scan,
        cards=cards,
        arena=arena,
        academy=academy,
        biofuel=await _biofuel_summary(user),
    )
    _maybe_cache_snapshot(response.model_dump())
    return response


async def _biofuel_summary(user: User) -> dict:
    """5th pillar — NASM-CNC Bio-Fuel snapshot for the FEL OS stripe."""
    weight_kg = _athlete_weight_kg(user)
    intent = _today_intent(user)
    target = nasm_macro_target(weight_kg, user.sport, intent)
    log = await db.biofuel_logs.find_one({"user_id": user.user_id, "day": _today_key()}, {"_id": 0}) or {}
    entries = log.get("entries", [])
    consumed = _consumed_totals(entries)
    pct = {
        k: min(100, round(100 * consumed.get(k, 0) / target[k])) if target.get(k) else 0
        for k in ("calories", "protein_g", "carbs_g", "fats_g")
    }
    cues = _supportive_cues(target, consumed, pct, ATHLETIC_INTENTS.get(intent, intent))
    scan_count = await db.biofuel_scans.count_documents({"user_id": user.user_id})
    return {
        "intent": intent,
        "intent_label": ATHLETIC_INTENTS.get(intent, intent),
        "target": target,
        "consumed": consumed,
        "pct": pct,
        "scan_count": scan_count,
        "cues": cues[:2],
        "entries_today": len(entries),
    }
