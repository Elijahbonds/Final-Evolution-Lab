"""
FEL OS Pass — server-rendered shareable card.

SHARE-01: Pass image/meta require a per-user share token (unless legacy public bypass env).
"""
from datetime import datetime, timezone
from io import BytesIO
from typing import Optional

import os
import secrets

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from PIL import Image, ImageDraw, ImageFont

from core import User, db, get_current_user
from privacy_minors import age_from_iso_dob

router = APIRouter(prefix="/api/system-scan", tags=["pass-image"])

# Color palette (FEL OS dark cyber)
BG = (8, 9, 11)             # zinc-950
PANEL = (24, 24, 27)         # zinc-900
GRID = (39, 39, 42)          # zinc-800
INK = (244, 244, 245)        # zinc-100
MUTED = (113, 113, 122)      # zinc-500
DIM = (63, 63, 70)           # zinc-700
CYAN = (34, 211, 238)        # cyan-400
ORANGE = (251, 146, 60)      # orange-400
AMBER = (251, 191, 36)       # amber-400
EMERALD = (52, 211, 153)     # emerald-400
VIOLET = (167, 139, 250)     # violet-400


def _font(size: int, weight: str = "regular"):
    """Try a stack of system fonts; fall back to default."""
    candidates = {
        "bold": [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        ],
        "regular": [
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf",
        ],
        "mono": [
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
            "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
        ],
    }
    for path in candidates.get(weight, candidates["regular"]):
        try:
            return ImageFont.truetype(path, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def _verify_pass_access(user: dict, token: Optional[str]) -> None:
    """SHARE-01 — token gate + minor consent."""
    legacy = os.environ.get("FEL_PASS_SHARE_LEGACY_PUBLIC", "").lower() in ("1", "true", "yes")
    expected = user.get("pass_share_token")
    if expected:
        if not token or token != expected:
            raise HTTPException(status_code=403, detail="Invalid or missing share token (?t=)")
    elif not legacy:
        raise HTTPException(
            status_code=403,
            detail="Pass sharing not enabled — POST /api/system-scan/pass-share-token while signed in.",
        )

    age = age_from_iso_dob(user.get("date_of_birth"))
    if age is not None and age < 18:
        if not user.get("parental_consent_acknowledged"):
            raise HTTPException(
                status_code=403,
                detail="Public athlete pass disabled for minors without guardian consent.",
            )


async def _gather_pass_data(user_id: str, token: Optional[str]) -> dict:
    """Aggregate everything needed for the pass card."""
    user = await db.users.find_one({"user_id": user_id}, {"_id": 0})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    _verify_pass_access(user, token)

    edu_docs = await db.education_progress.find({"user_id": user_id}, {"_id": 0}).to_list(20)
    kin = next((d for d in edu_docs if d.get("track_id") == "kinesiology"), {})
    cert_id = kin.get("certificate_id") if kin.get("certificate_issued") else None

    completed = sum(len(d.get("completed_lessons", [])) for d in edu_docs)
    total_lessons = 24  # 6 + 6 + 8 + 4

    games = await db.game_sessions.count_documents({"user_id": user_id})
    cards_owned = await db.user_cards.count_documents({"user_id": user_id})

    show_metrics = bool(user.get("pass_public_metrics_opt_in", False))

    base = {
        "user_id": user_id,
        "name": user.get("name", "Athlete"),
        "sport": user.get("sport", "—").upper(),
        "level": int(user.get("level", 1)),
        "lessons_done": completed,
        "lessons_total": total_lessons,
        "games_played": games,
        "cards_owned": cards_owned,
        "certificate_id": cert_id,
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }
    if show_metrics:
        base["prq_score"] = float(user.get("prq_score", 0.0))
        base["xp"] = int(user.get("xp", 0))
        base["streak_days"] = int(user.get("streak_days", 0))
    else:
        base["prq_score"] = None
        base["xp"] = None
        base["streak_days"] = None

    return base


def _render_pass(data: dict) -> bytes:
    """Render a 1200x630 OG-sized pass image."""
    W, H = 1200, 630
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    # 1) Subtle grid background
    for x in range(0, W, 40):
        d.line([(x, 0), (x, H)], fill=GRID, width=1)
    for y in range(0, H, 40):
        d.line([(0, y), (W, y)], fill=GRID, width=1)

    # 2) Cyan corner accents
    d.line([(0, 0), (180, 0)], fill=CYAN, width=4)
    d.line([(0, 0), (0, 180)], fill=CYAN, width=4)
    d.line([(W - 180, H), (W, H)], fill=CYAN, width=4)
    d.line([(W, H - 180), (W, H)], fill=CYAN, width=4)

    # 3) Wordmark (top-left)
    f_eyebrow = _font(20, "bold")
    f_brand = _font(40, "bold")
    d.text((40, 36), "FEL OS · ATHLETE PASS", fill=CYAN, font=f_eyebrow)
    d.text((40, 60), "FINAL EVOLUTION", fill=INK, font=f_brand)
    f_brand_sm = _font(40, "bold")
    bbox = d.textbbox((0, 0), "FINAL EVOLUTION", font=f_brand)
    fe_width = bbox[2] - bbox[0]
    d.text((40 + fe_width + 16, 60), "/ LAB", fill=CYAN, font=f_brand_sm)

    # 4) Athlete identity (left middle)
    f_name = _font(72, "bold")
    f_sport = _font(22, "bold")
    name = data["name"][:22]
    d.text((40, 170), name, fill=INK, font=f_name)
    d.text((40, 256), f"{data['sport']}  ·  LVL {data['level']}", fill=MUTED, font=f_sport)

    # 5) Massive PRQ score — omit when athlete opted out of public metrics
    f_prq_label = _font(24, "bold")
    f_prq = _font(220, "bold")
    if data.get("prq_score") is not None:
        d.text((40, 310), "PRQ", fill=CYAN, font=f_prq_label)
        prq_str = f"{float(data['prq_score']):.1f}"
        d.text((40, 340), prq_str, fill=INK, font=f_prq)
    else:
        d.text((40, 310), "PRQ", fill=DIM, font=f_prq_label)
        d.text((40, 340), "—", fill=DIM, font=f_prq)

    # 6) Right-rail stat blocks
    rx = 720
    rw = 440
    panel_y = 170
    panel_h = 80
    streak_val = data.get("streak_days")
    streak_txt = f"{streak_val}d" if streak_val is not None else "—"
    academy_txt = f"{data['lessons_done']}/{data['lessons_total']}"
    stats = [
        ("STREAK", streak_txt, ORANGE),
        ("ACADEMY", academy_txt, AMBER),
        ("ARENA SESSIONS", f"{data['games_played']}", VIOLET),
        ("CARDS OWNED", f"{data['cards_owned']}", EMERALD),
    ]
    f_stat_lbl = _font(18, "bold")
    f_stat_val = _font(44, "bold")
    for i, (lbl, val, col) in enumerate(stats):
        y = panel_y + i * (panel_h + 12)
        # panel
        d.rectangle([(rx, y), (rx + rw, y + panel_h)], fill=PANEL, outline=DIM, width=1)
        # left accent
        d.rectangle([(rx, y), (rx + 4, y + panel_h)], fill=col)
        # text
        d.text((rx + 22, y + 14), lbl, fill=MUTED, font=f_stat_lbl)
        d.text((rx + 22, y + 32), val, fill=INK, font=f_stat_val)

    # 7) Certificate stamp (bottom-left) if issued
    f_cert_lbl = _font(18, "bold")
    f_cert_id = _font(22, "bold")
    cert_box_y = 540
    if data["certificate_id"]:
        # gold border stamp
        d.rectangle([(40, cert_box_y), (660, cert_box_y + 64)], fill=PANEL, outline=AMBER, width=2)
        # accent
        d.rectangle([(40, cert_box_y), (44, cert_box_y + 64)], fill=AMBER)
        d.text((60, cert_box_y + 8), "APPLIED KINESIOLOGY · FEL CERTIFIED", fill=AMBER, font=f_cert_lbl)
        d.text((60, cert_box_y + 32), data["certificate_id"], fill=INK, font=f_cert_id)
    else:
        d.rectangle([(40, cert_box_y), (660, cert_box_y + 64)], fill=PANEL, outline=DIM, width=1)
        d.text((60, cert_box_y + 8), "APPLIED KINESIOLOGY", fill=MUTED, font=f_cert_lbl)
        d.text((60, cert_box_y + 32), "— certification pending —", fill=DIM, font=f_cert_id)

    # 8) Footer
    f_foot = _font(16, "mono")
    d.text((rx, 580), "finalevolutionlab.com", fill=MUTED, font=f_foot)

    buf = BytesIO()
    img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


@router.post("/pass-share-token")
async def issue_pass_share_token(user: User = Depends(get_current_user)):
    """Create or rotate share token for GET pass routes (authenticated owner)."""
    age = age_from_iso_dob(user.date_of_birth)
    if age is not None and age < 18 and not user.parental_consent_acknowledged:
        raise HTTPException(
            status_code=403,
            detail="Pass share links cannot be issued for minors without guardian consent.",
        )
    tok = secrets.token_urlsafe(24)
    await db.users.update_one(
        {"user_id": user.user_id},
        {"$set": {"pass_share_token": tok, "pass_share_enabled": True}},
    )
    return {
        "token": tok,
        "usage": "Append ?t=<token> to /api/system-scan/pass/{user_id}.png and pass-meta/{user_id}",
    }


@router.get("/pass/{user_id}.png", responses={200: {"content": {"image/png": {}}}})
async def get_pass_image(user_id: str, t: Optional[str] = Query(None, description="pass_share_token")):
    data = await _gather_pass_data(user_id, t)
    png = _render_pass(data)
    hdr_prq = ""
    if data.get("prq_score") is not None:
        hdr_prq = f"{float(data['prq_score']):.1f}"
    return Response(
        content=png,
        media_type="image/png",
        headers={
            "Cache-Control": "public, max-age=120",
            "X-FEL-PRQ": hdr_prq or "hidden",
        },
    )


@router.get("/pass-meta/{user_id}")
async def get_pass_meta(user_id: str, t: Optional[str] = Query(None)):
    """JSON sidecar for og: meta tag consumers and the share modal preview."""
    data = await _gather_pass_data(user_id, t)
    prq_part = ""
    if data.get("prq_score") is not None:
        prq_part = f"PRQ {float(data['prq_score']):.1f} · "
    share_bits = [prq_part, f"Lvl {data['level']}"]
    if data.get("streak_days") is not None:
        share_bits.append(f"{data['streak_days']}-day streak")
    share_text = "My FEL OS Pass: " + " ".join(x for x in share_bits if x) + (
        f" · {data['certificate_id']}" if data.get("certificate_id") else ""
    )
    safe = {k: v for k, v in data.items() if k != "user_id"}
    return {
        **safe,
        "og_image_url_path": f"/api/system-scan/pass/{user_id}.png",
        "share_text": share_text,
    }
