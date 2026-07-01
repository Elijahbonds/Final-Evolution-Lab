"""
FEL OS — Unified System Scan

Single endpoint that aggregates the four pillars:
  1. SCAN     — PRQ, biomechanics, streak, level
  2. CARDS    — Creator Card portfolio (owned + recommended)
  3. ARENA    — Game mode unlocks + recent sessions + UE5 readiness
  4. ACADEMY  — Education track progress + Kinesiology cert status
"""
from fastapi import APIRouter, Depends
from typing import Dict, Any
from datetime import datetime, timezone

from core import db, get_current_user, User
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


@router.get("/unified")
async def unified_system_scan(user: User = Depends(get_current_user)) -> Dict[str, Any]:
    """Return the four-quadrant FEL OS snapshot for the current athlete."""
    # ---- 1. SCAN ----
    prq_doc = await db.prq_metrics.find_one({"user_id": user.user_id}, {"_id": 0}) or {}
    health_doc = await db.health_metrics.find_one({"user_id": user.user_id}, {"_id": 0}) or {}
    vj_doc = await db.vertical_jump_log.find({"user_id": user.user_id}, {"_id": 0}).sort("recorded_at", -1).limit(1).to_list(1)
    last_vj = vj_doc[0] if vj_doc else None

    scan = {
        "prq_score": user.prq_score,
        "level": user.level,
        "xp": user.xp,
        "streak_days": user.streak_days,
        "coins": user.coins,
        "metrics": {k: prq_doc.get(k) for k in ("strength", "speed", "endurance", "agility", "power", "flexibility", "recovery", "mental")},
        "health": {k: health_doc.get(k) for k in ("resting_hr", "hrv", "sleep_hours", "vo2_max")} if health_doc else None,
        "last_vertical_jump": last_vj,
    }

    # ---- 2. CARDS ----
    owned = await db.user_cards.find({"user_id": user.user_id}, {"_id": 0}).to_list(50)
    payment_count = await db.payments.count_documents({"user_id": user.user_id, "status": "completed"})
    cards = {
        "owned_count": len(owned),
        "lifetime_purchases": payment_count,
        "recent": owned[-3:] if owned else [],
    }

    # ---- 3. ARENA ----
    game_count = await db.game_sessions.count_documents({"user_id": user.user_id})
    last_game = await db.game_sessions.find({"user_id": user.user_id}, {"_id": 0}).sort("created_at", -1).limit(1).to_list(1)
    sov_count = await db.vault_sessions.count_documents({"user_id": user.user_id}) if "vault_sessions" in await db.list_collection_names() else 0
    arena = {
        "modes_played": game_count,
        "last_session": last_game[0] if last_game else None,
        "vault_sessions": sov_count,
        "ue5_bridge": "ready",  # native iOS deep-link bridge present
    }

    # ---- 4. ACADEMY ----
    edu_docs = await db.education_progress.find({"user_id": user.user_id}, {"_id": 0}).to_list(50)
    by_track = {d["track_id"]: d for d in edu_docs}
    academy_tracks = []
    total_lessons = 0
    total_done = 0
    for tid, t in EDU_TRACKS.items():
        prog = by_track.get(tid, {})
        done = len(prog.get("completed_lessons", []))
        total = len(t["lessons"])
        total_lessons += total
        total_done += done
        academy_tracks.append({
            "track_id": tid,
            "title": t["title"],
            "completion_pct": round(100 * done / total, 1) if total else 0.0,
            "is_certificate": t.get("is_certificate", False),
            "certificate_issued": prog.get("certificate_issued", False),
            "certificate_id": prog.get("certificate_id"),
        })

    kin_elig = await _build_kinesiology_eligibility(user)
    bd_doc = await db.bio_digital_progress.find_one({"user_id": user.user_id}, {"_id": 0}) or {}

    academy = {
        "overall_completion_pct": round(100 * total_done / total_lessons, 1) if total_lessons else 0.0,
        "lessons_completed": total_done,
        "lessons_total": total_lessons,
        "tracks": academy_tracks,
        "kinesiology_certificate": {
            "eligibility": kin_elig,
            "issued": kin_elig["all_met"] and any(t["certificate_issued"] for t in academy_tracks if t["track_id"] == "kinesiology"),
        },
        "bio_digital": {
            "modules_completed": bd_doc.get("modules_completed", []),
            "modules_required": BIO_DIGITAL_REQUIRED_MODULES,
        },
    }

    return {
        "user": {"user_id": user.user_id, "name": user.name, "sport": user.sport, "picture": user.picture},
        "scanned_at": datetime.now(timezone.utc).isoformat(),
        "scan": scan,
        "cards": cards,
        "arena": arena,
        "academy": academy,
        "biofuel": await _biofuel_summary(user),
    }


async def _biofuel_summary(user: User) -> dict:
    """5th pillar — NASM-CNC Bio-Fuel snapshot for the FEL OS stripe."""
    weight_kg = _athlete_weight_kg(user)
    intent = _today_intent(user)
    target = nasm_macro_target(weight_kg, user.sport, intent)
    log = await db.biofuel_logs.find_one({"user_id": user.user_id, "day": _today_key()}, {"_id": 0}) or {}
    entries = log.get("entries", [])
    consumed = _consumed_totals(entries)
    pct = {
        k: min(100, round(100 * consumed.get(k, 0) / target[k])) if target[k] else 0
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
        "cues": cues[:2],  # top 2 supportive cues for the stripe
        "entries_today": len(entries),
    }
