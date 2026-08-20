"""Shell-safe FEL OS system scan and share-pass routes."""
from __future__ import annotations

from datetime import UTC, datetime
from io import BytesIO
from typing import Any

from fastapi import APIRouter, Response
from PIL import Image, ImageDraw, ImageFont

from app.routers.registry import _mode_registry, _resolve_mode_launch_target

router = APIRouter(prefix="/system-scan", tags=["system-scan"])

BIO_DIGITAL_MODULES = ["skeleton", "muscles", "movement_planes", "injury_prevention"]

ACADEMY_TRACKS = [
    {
        "track_id": "kinesiology",
        "title": "Kinesiology",
        "icon": "BookOpen",
        "accent": "cyan",
        "completed_lessons": 0,
        "total_lessons": 2,
        "locked": False,
    },
    {
        "track_id": "biofuel",
        "title": "Bio-Fuel",
        "icon": "Atom",
        "accent": "emerald",
        "completed_lessons": 0,
        "total_lessons": 2,
        "locked": False,
    },
    {
        "track_id": "arena",
        "title": "Arena IQ",
        "icon": "Trophy",
        "accent": "amber",
        "completed_lessons": 0,
        "total_lessons": 2,
        "locked": False,
    },
    {
        "track_id": "neuro",
        "title": "Neuro Drive",
        "icon": "Brain",
        "accent": "fuchsia",
        "completed_lessons": 0,
        "total_lessons": 2,
        "locked": False,
    },
]


def _launchable_mode_ids() -> list[str]:
    ids = []
    for mode_id, config in _mode_registry().items():
        target = _resolve_mode_launch_target(mode_id, config)
        if target and target["launchable"]:
            ids.append(mode_id)
    return ids


def _system_scan_payload(user_id: str = "dev-athlete") -> dict[str, Any]:
    launchable_modes = _launchable_mode_ids()
    metrics = {
        "strength": 75.0,
        "speed": 72.0,
        "endurance": 70.0,
        "agility": 73.0,
        "power": 76.0,
        "flexibility": 68.0,
        "recovery": 80.0,
        "mental": 78.0,
    }
    health = {
        "sleep_score": 82.0,
        "hrv_ms": 64.0,
        "resting_hr": 52.0,
        "readiness": 79.0,
    }
    return {
        "user": {
            "user_id": user_id,
            "display_name": "FEL Athlete" if user_id == "dev-athlete" else user_id,
        },
        "scan": {
            "prq_score": 75.0,
            "level": 1,
            "streak_days": 0,
            "xp": 0,
            "metrics": metrics,
            "health": health,
            "last_vertical_jump": {},
            "source": "local_shell",
        },
        "cards": {
            "owned_count": 0,
            "lifetime_purchases": 0,
            "recent": [],
        },
        "arena": {
            "modes_played": 0,
            "vault_sessions": 0,
            "ue5_bridge": "ready",
            "last_game": {},
            "modes_unlocked": launchable_modes,
            "launchable_modes": len(launchable_modes),
        },
        "academy": {
            "overall_completion_pct": 0,
            "lessons_completed": 0,
            "lessons_total": sum(track["total_lessons"] for track in ACADEMY_TRACKS),
            "tracks": ACADEMY_TRACKS,
            "certificates": [],
            "bio_digital": {
                "modules_completed": [],
                "modules_required": BIO_DIGITAL_MODULES,
                "required": BIO_DIGITAL_MODULES,
            },
        },
        "biofuel": {
            "intent": "post_dunk_recovery",
            "hydration_ml": 0,
            "nutri_shards_today": 0,
        },
        "updated_at": datetime.now(UTC).isoformat(),
    }


@router.get("/unified")
async def unified_system_scan(user_id: str = "dev-athlete") -> dict[str, Any]:
    """Return a four-quadrant FEL OS snapshot without external services."""

    return _system_scan_payload(user_id=user_id)


@router.get("/pass-meta/{user_id}")
async def get_pass_meta(user_id: str) -> dict[str, Any]:
    """Return share-card metadata used by the FEL OS pass modal."""

    payload = _system_scan_payload(user_id=user_id)
    display_name = payload["user"]["display_name"]
    prq_score = payload["scan"]["prq_score"]
    return {
        "name": display_name,
        "user_id": user_id,
        "prq_score": prq_score,
        "level": payload["scan"]["level"],
        "og_image_url_path": f"/api/system-scan/pass/{user_id}.png",
        "share_text": f"{display_name} is building a {prq_score:.1f} PRQ athlete profile in Final Evolution Lab.",
    }


@router.get("/pass/{user_id}.png")
async def get_pass_png(user_id: str) -> Response:
    """Render a deterministic local FEL OS pass preview image."""

    payload = _system_scan_payload(user_id=user_id)
    display_name = payload["user"]["display_name"][:64]
    prq_score = payload["scan"]["prq_score"]

    image = Image.new("RGB", (1200, 630), (8, 9, 11))
    draw = ImageDraw.Draw(image)
    title_font = ImageFont.load_default(size=64)
    body_font = ImageFont.load_default(size=34)
    small_font = ImageFont.load_default(size=24)

    draw.rectangle((0, 0, 1200, 630), outline=(34, 211, 238), width=6)
    draw.rectangle((42, 42, 1158, 588), outline=(39, 39, 42), width=2)
    draw.text((72, 76), "FINAL EVOLUTION LAB", fill=(34, 211, 238), font=small_font)
    draw.text((72, 150), "FEL OS ATHLETE PASS", fill=(244, 244, 245), font=title_font)
    draw.text((72, 270), display_name, fill=(244, 244, 245), font=body_font)
    draw.text((72, 360), f"PRQ {prq_score:.1f}  |  LEVEL {payload['scan']['level']}", fill=(34, 211, 238), font=body_font)
    draw.text((72, 460), "Arena · Academy · Bio-Fuel · Sovereign Cards", fill=(161, 161, 170), font=small_font)
    draw.text((820, 500), datetime.now(UTC).strftime("%Y-%m-%d"), fill=(113, 113, 122), font=small_font)

    buffer = BytesIO()
    image.save(buffer, format="PNG")
    return Response(content=buffer.getvalue(), media_type="image/png")
