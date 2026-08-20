"""Shell-safe gameplay, coaching, critique, and nutrition mechanics.

These endpoints intentionally avoid hard dependencies on external providers so
the game shell remains usable before live integrations are configured.

Persistence note: mechanics routes use in-process memory stores (_biofuel_logs,
_brain_brawl_sessions, etc.) for shell/dev UX only. Authoritative session
receipts, XP/shard/PRQ commits, and economy ledger writes go through
``POST /api/games/session`` or the Vault WebSocket ``session_end`` event, which
persist via ``session_processor`` to Postgres (or SQLite when USE_SQLITE_DEV=true).
"""
from __future__ import annotations

import random
import time
import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import APIRouter, File, Query, UploadFile
from pydantic import BaseModel, Field

router = APIRouter(tags=["mechanics"])

NUTRI_SHARDS_PER_SCAN = 12

_SERVER_STARTED_AT = time.monotonic()

_biofuel_logs: list[dict[str, Any]] = []
_pending_scans: dict[str, dict[str, Any]] = {}
_confirmed_scans: set[str] = set()
_critique_requests: list[dict[str, Any]] = []
_brain_brawl_sessions: dict[str, dict[str, Any]] = {}
_workout_logs: list[dict[str, Any]] = []

ARENA_MODES = [
    ("basketball_h2h", "Street · 1v1", "Basketball", "VeniceBeach", "1v1", "3 min"),
    ("basketball_dunk_3d", "3D H2H Dunk Contest", "Basketball", "VeniceBeachBlueCourt", "1v1", "5 min"),
    ("basketball_dunk_irl", "IRL H2H Dunk Contest", "Basketball", "RegulationCourtIRL", "Camera", "5 min"),
    ("basketball_3v3", "Street · 3v3", "Basketball", "VeniceBeach", "3v3", "8 min"),
    ("karate", "Karate · Dojo", "Combat", "Dojo", "Solo", "3 min"),
    ("karate_h2h", "Karate · 1v1", "Combat", "Dojo", "1v1", "3 min"),
    ("karate_endless", "Karate · Endless", "Combat", "Dojo", "Solo", "Endless"),
    ("baseball", "Baseball · Ballpark", "Field", "BaseballPark", "Solo", "5 min"),
    ("football", "Football · Kick Return", "Field", "Gridiron", "Solo", "4 min"),
    ("soccer", "Soccer · Stadium", "Field", "SoccerStadium", "Solo", "3 min"),
    ("golf", "Golf · Links", "Precision", "Links", "Solo", "5 min"),
    ("tennis", "Tennis · Court", "Court", "TennisCourt", "1v1", "3 min"),
    ("volleyball", "Volleyball · Sand Court", "Court", "SandCourt", "2v2", "3 min"),
    ("gymnastics", "Gymnastics · Floor", "Performance", "TrainingFloor", "Solo", "4 min"),
    ("brain_brawl", "Academy · Brain Brawl", "Academy", "NeuroArena", "Solo", "2 min"),
    ("who_scene_it", "Who Scene It", "Academy", "NeuroArena", "2-8", "15 min"),
    ("court_carnival", "Court Carnival", "Party", "VeniceBeach", "2-4", "30 min"),
    ("surfing", "Surf · Line", "Board", "VeniceBeach", "Solo", "3 min"),
    ("skateboarding", "Skate · Park", "Board", "SkatePark", "Solo", "3 min"),
    ("snowboarding", "Snow · Line", "Board", "MountainSlope", "Solo", "3 min"),
    ("market_browse", "Sovereign Shop", "Academy", "Luma_Venice_Shop", "Browse", "Open"),
]

INTENTS = {
    "fascial_hydration": "Fascial Hydration",
    "cns_ignition": "CNS Ignition",
    "post_dunk_recovery": "Post-Dunk Recovery",
    "endurance_base": "Endurance Base",
    "sleep_anabolic": "Sleep Anabolic",
}

RECIPES = [
    {
        "id": "recipe_post_dunk_bowl",
        "title": "Jerk Salmon Recovery Bowl",
        "intent": "post_dunk_recovery",
        "intent_label": INTENTS["post_dunk_recovery"],
        "duration_min": 25,
        "macros": {"calories": 740, "protein_g": 54, "carbs_g": 82, "fats_g": 20},
        "micros": {"omega3_mg": 1400, "hydration_ml": 250},
        "summary": "High-protein post-impact meal for plyometric recovery.",
        "ingredients": [
            {"name": "Jerk salmon", "qty": "6 oz"},
            {"name": "Brown rice", "qty": "1.5 cups"},
            {"name": "Black beans", "qty": "1/2 cup"},
            {"name": "Mango avocado salsa", "qty": "1 cup"},
        ],
        "steps": ["Sear salmon.", "Warm rice and beans.", "Top with salsa and lime."],
        "viz_palette": ["#fb923c", "#f97316", "#7c2d12"],
    },
    {
        "id": "recipe_cns_shake",
        "title": "Buna Espresso Protein Shake",
        "intent": "cns_ignition",
        "intent_label": INTENTS["cns_ignition"],
        "duration_min": 5,
        "macros": {"calories": 250, "protein_g": 30, "carbs_g": 12, "fats_g": 8},
        "micros": {"caffeine_mg": 180, "hydration_ml": 350},
        "summary": "Fast pre-training neural primer with protein and creatine.",
        "ingredients": [
            {"name": "Espresso", "qty": "2 shots"},
            {"name": "Whey isolate", "qty": "30 g"},
            {"name": "Coconut water", "qty": "100 ml"},
            {"name": "Creatine", "qty": "5 g"},
        ],
        "steps": ["Blend all ingredients with ice.", "Drink 30 minutes before training."],
        "viz_palette": ["#22d3ee", "#0ea5e9", "#0c4a6e"],
    },
]


class BioFuelScanIn(BaseModel):
    model: str = "gemini-2.5-flash"
    image_base64: str = Field(min_length=1)
    hint: str | None = None


class ScanConfirmIn(BaseModel):
    scan_id: str


class MealLogIn(BaseModel):
    label: str
    calories: int = Field(ge=0, le=3500)
    protein_g: int = Field(default=0, ge=0, le=220)
    carbs_g: int = Field(default=0, ge=0, le=450)
    fats_g: int = Field(default=0, ge=0, le=180)
    hydration_ml: int = Field(default=0, ge=0, le=2500)
    intent: str | None = None
    source: str = "manual"
    client_event_id: str | None = None


class ChatIn(BaseModel):
    message: str
    model: str = "gpt-5.2"
    conversation_id: str | None = None


class CritiqueIn(BaseModel):
    coach_id: str
    video_id: str
    sport: str = "basketball"
    notes: str = ""


def _now() -> str:
    return datetime.now(UTC).isoformat()


def _mode(row: tuple[str, str, str, str, str, str]) -> dict[str, Any]:
    mode_id, display_name, category, venue, players, duration = row
    return {
        "id": mode_id,
        "name": display_name,
        "display_name": display_name,
        "category": category,
        "venue": venue,
        "player_count": players,
        "duration": duration,
        "difficulty": "Cognitive" if category == "Academy" else "Adaptive",
        "game_type": "quiz" if mode_id in {"brain_brawl", "who_scene_it"} else ("party" if mode_id == "court_carnival" else "reflex"),
        "playable": mode_id != "market_browse",
        "image_url": "/images/ue5_basketball.png" if category == "Basketball" else "/images/ue5_board.png",
        "description": f"{display_name} is wired through the FEL shell economy and HUD pipeline.",
    }


def _today_totals() -> dict[str, int]:
    return {
        "calories": sum(int(log.get("calories", 0)) for log in _biofuel_logs),
        "protein_g": sum(int(log.get("protein_g", 0)) for log in _biofuel_logs),
        "carbs_g": sum(int(log.get("carbs_g", 0)) for log in _biofuel_logs),
        "fats_g": sum(int(log.get("fats_g", 0)) for log in _biofuel_logs),
    }


def _target() -> dict[str, int]:
    return {"calories": 2400, "protein_g": 160, "carbs_g": 280, "fats_g": 75, "hydration_ml": 3200}


@router.get("/games/modes")
async def game_modes() -> list[dict[str, Any]]:
    return [_mode(row) for row in ARENA_MODES]


@router.post("/ai/chat")
async def ai_chat(request: ChatIn) -> dict[str, Any]:
    response = (
        "FEL Coach: keep the session simple and measurable. Pair one gameplay mode, "
        "one movement-quality focus, one BioFuel log, and one recovery cue. "
        f"For your prompt: {request.message[:240]}"
    )
    return {"response": response, "model": request.model, "conversation_id": request.conversation_id}


@router.get("/coach/available")
async def available_coaches() -> list[dict[str, Any]]:
    return [
        {"id": "coach_movement", "name": "FEL Movement Coach", "specialty": "Biomechanics", "sport": "training", "rate": 25, "rating": 4.9, "sessions": 128},
        {"id": "coach_nutrition", "name": "Bio-Fuel Coach", "specialty": "Performance Nutrition", "sport": "nutrition", "rate": 20, "rating": 4.8, "sessions": 96},
    ]


@router.get("/coach/sessions")
async def coach_sessions() -> list[dict[str, Any]]:
    return []


@router.get("/coach/critiques")
async def critiques() -> list[dict[str, Any]]:
    return _critique_requests


@router.post("/uploads/video")
async def upload_video(file: UploadFile = File(...)) -> dict[str, Any]:
    content = await file.read()
    return {
        "id": f"video_{uuid.uuid4().hex[:12]}",
        "filename": file.filename,
        "content_type": file.content_type,
        "size": len(content),
        "status": "uploaded",
        "created_at": _now(),
    }


@router.post("/coach/critique")
async def request_critique(request: CritiqueIn) -> dict[str, Any]:
    critique = {
        "id": f"critique_{uuid.uuid4().hex[:12]}",
        "coach_id": request.coach_id,
        "video_id": request.video_id,
        "sport": request.sport,
        "notes": request.notes,
        "status": "queued",
        "escrow_shards": 75,
        "economy": {"shards_spent": 75, "coach_reward_pending": 60, "platform_fee": 15},
        "summary": "Queued for form review. Local shell escrow receipt created.",
        "created_at": _now(),
    }
    _critique_requests.insert(0, critique)
    return critique


@router.get("/biofuel/today")
async def biofuel_today() -> dict[str, Any]:
    consumed = _today_totals()
    target = _target()
    pct = {key: min(100, round((consumed.get(key, 0) / value) * 100)) for key, value in target.items() if value}
    return {
        "intent": "post_dunk_recovery",
        "intent_label": INTENTS["post_dunk_recovery"],
        "targets_confidence": "local_shell",
        "assumption_note": "Local shell targets; connect profile metrics for personalized NASM-CNC targets.",
        "consumed": consumed,
        "target": target,
        "pct": pct,
        "nutri_shards_today": sum(int(log.get("nutri_shards_awarded", 0)) for log in _biofuel_logs),
    }


@router.get("/biofuel/cues")
async def biofuel_cues() -> dict[str, Any]:
    return {
        "cues": [
            {"icon": "Beef", "title": "Protein anchor", "body": "Hit protein first so Shards rewards track useful recovery behavior."},
            {"icon": "Droplet", "title": "Hydration check", "body": "Add fluids and sodium after high-sweat arena sessions."},
        ]
    }


@router.post("/biofuel/scan")
async def biofuel_scan(request: BioFuelScanIn) -> dict[str, Any]:
    scan_id = f"scan_{uuid.uuid4().hex[:12]}"
    result = {
        "scan_id": scan_id,
        "label": request.hint or "Performance meal",
        "model": request.model,
        "calories": 520,
        "protein_g": 38,
        "carbs_g": 54,
        "fats_g": 16,
        "hydration_ml": 250,
        "intent": "post_dunk_recovery",
        "pending_confirmation": True,
        "nutri_shards_awarded": 0,
    }
    _pending_scans[scan_id] = result
    return result


@router.post("/biofuel/scan/confirm")
async def confirm_scan(request: ScanConfirmIn) -> dict[str, Any]:
    scan = _pending_scans.get(request.scan_id)
    if scan is None:
        scan = {
            "scan_id": request.scan_id,
            "label": "Confirmed meal",
            "calories": 520,
            "protein_g": 38,
            "carbs_g": 54,
            "fats_g": 16,
            "hydration_ml": 250,
            "intent": "post_dunk_recovery",
        }
    already = request.scan_id in _confirmed_scans
    if not already:
        _confirmed_scans.add(request.scan_id)
        _biofuel_logs.append({**scan, "source": "scan", "created_at": _now(), "nutri_shards_awarded": NUTRI_SHARDS_PER_SCAN})
    return {
        **scan,
        "pending_confirmation": False,
        "already_confirmed": already,
        "nutri_shards_awarded": 0 if already else NUTRI_SHARDS_PER_SCAN,
        "economy": {"currency": "nutri_shards", "amount": 0 if already else NUTRI_SHARDS_PER_SCAN},
    }


@router.post("/biofuel/log")
async def log_meal(request: MealLogIn) -> dict[str, Any]:
    entry = request.model_dump()
    entry["id"] = f"meal_{uuid.uuid4().hex[:12]}"
    entry["created_at"] = _now()
    entry["nutri_shards_awarded"] = 4 if request.source in {"doordash", "recipe"} else 2
    _biofuel_logs.append(entry)
    return {"status": "logged", **entry, "economy": {"currency": "nutri_shards", "amount": entry["nutri_shards_awarded"]}}


@router.get("/biofuel/recipes")
async def recipes(intent: str | None = None) -> dict[str, Any]:
    items = [recipe for recipe in RECIPES if intent is None or recipe["intent"] == intent]
    return {"intents": [{"id": key, "label": value} for key, value in INTENTS.items()], "recipes": items}


@router.get("/biofuel/recipes/{recipe_id}")
async def recipe_detail(recipe_id: str) -> dict[str, Any]:
    for recipe in RECIPES:
        if recipe["id"] == recipe_id:
            return recipe
    return RECIPES[0]


@router.post("/biofuel/instacart-cart")
async def instacart_cart(payload: dict[str, Any]) -> dict[str, str]:
    recipe = await recipe_detail(str(payload.get("recipe_id", RECIPES[0]["id"])))
    terms = " ".join(ingredient["name"] for ingredient in recipe["ingredients"])
    return {"deep_link": f"https://www.instacart.com/store/s?k={terms.replace(' ', '+')}", "mode": "deep_link"}


@router.post("/biofuel/doordash-search")
async def doordash_search(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    intent = (payload or {}).get("intent") or "post_dunk_recovery"
    return {
        "intent": intent,
        "intent_label": INTENTS.get(intent, intent),
        "max_calories": 800,
        "min_protein_g": 30,
        "matches": [
            {
                "name": "Grilled Chicken Recovery Bowl",
                "macros": {"calories": 620, "protein_g": 46, "carbs_g": 68, "fats_g": 16, "hydration_ml": 0},
                "deep_link": "https://www.doordash.com/search/store/chicken%20bowl",
            },
            {
                "name": "Salmon Rice Performance Plate",
                "macros": {"calories": 710, "protein_g": 52, "carbs_g": 72, "fats_g": 21, "hydration_ml": 0},
                "deep_link": "https://www.doordash.com/search/store/salmon%20rice",
            },
        ],
    }


@router.get("/streaks")
async def streaks() -> dict[str, Any]:
    today = datetime.now(UTC).date().isoformat()
    return {"current_streak": 1, "longest_streak": 1, "daily_log": [today], "xp_earned": 25, "coins_earned": 10, "rewards": ["Shell Ready"]}


@router.get("/streaks/rewards")
async def streak_rewards() -> dict[str, Any]:
    return {"milestones": [{"days": 1, "reward": "Daily check-in", "unlocked": True}, {"days": 7, "reward": "Weekly bonus", "unlocked": False}]}


@router.post("/streaks/checkin")
async def streak_checkin() -> dict[str, Any]:
    data = await streaks()
    data.update({"xp_earned": 25, "coins_earned": 10})
    return data


@router.get("/leaderboard")
async def leaderboard() -> list[dict[str, Any]]:
    return [
        {"rank": 1, "user_id": "dev-athlete", "name": "FEL Athlete", "prq_score": 75, "level": 1, "sport": "basketball"},
        {"rank": 2, "user_id": "coach-sim", "name": "Coach Simulator", "prq_score": 72, "level": 2, "sport": "training"},
        {"rank": 3, "user_id": "arena-bot", "name": "Arena Bot", "prq_score": 70, "level": 1, "sport": "soccer"},
    ]


@router.get("/profile/progress")
async def profile_progress() -> dict[str, int]:
    return {
        "total_workouts": len(_workout_logs),
        "total_games": 0,
        "total_brawls": sum(1 for s in _brain_brawl_sessions.values() if s.get("submitted")),
        "xp": 0,
    }


# ─────────────────────────────────────────────────────────────
# PRQ / stats / workouts (shell-safe; power Dashboard + System Scan)
# ─────────────────────────────────────────────────────────────
@router.get("/prq/metrics")
async def prq_metrics() -> dict[str, Any]:
    return {
        "overall_score": 75.0,
        "strength": 75, "speed": 72, "endurance": 70, "agility": 73,
        "power": 76, "flexibility": 68, "recovery": 80, "mental": 78,
        "source": "local_shell",
    }


@router.get("/stats/overview")
async def stats_overview() -> dict[str, int]:
    return {
        "total_workouts": len(_workout_logs),
        "game_sessions": 0,
        "brain_brawl_sessions": sum(1 for s in _brain_brawl_sessions.values() if s.get("submitted")),
        "xp": 0,
    }


@router.get("/workouts/recommended")
async def workouts_recommended() -> list[dict[str, Any]]:
    return [
        {
            "id": "shell-explosive-primer",
            "name": "Explosive Primer",
            "sport": "training",
            "difficulty": "Foundation",
            "duration_minutes": 14,
            "exercises": [
                {"name": "Dynamic Warmup", "sets": 1, "reps": "3 min", "rest": "30s"},
                {"name": "Lateral Bounds", "sets": 3, "reps": "8/side", "rest": "45s"},
                {"name": "Depth Drops", "sets": 3, "reps": "6", "rest": "60s"},
                {"name": "Reaction Sprints", "sets": 4, "reps": "10m", "rest": "45s"},
            ],
        },
        {
            "id": "shell-court-control",
            "name": "Court Control",
            "sport": "basketball",
            "difficulty": "Adaptive",
            "duration_minutes": 18,
            "exercises": [
                {"name": "Defensive Slides", "sets": 3, "reps": "30s", "rest": "30s"},
                {"name": "Crossover Ladders", "sets": 3, "reps": "20s", "rest": "30s"},
                {"name": "Vertical Jumps", "sets": 4, "reps": "5", "rest": "60s"},
            ],
        },
    ]


@router.post("/workouts/log")
async def workouts_log(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    entry = {**(payload or {}), "id": f"wlog_{uuid.uuid4().hex[:10]}", "created_at": _now()}
    _workout_logs.append(entry)
    return {"status": "logged", **entry, "xp_earned": 40}


@router.put("/profile")
async def update_profile(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    return {"status": "saved", **(payload or {})}


# ─────────────────────────────────────────────────────────────
# Native-launch + session-state (web returns no deep link → browser sim)
# ─────────────────────────────────────────────────────────────
def _launch_payload(mode_id: str) -> dict[str, Any]:
    return {
        "session_id": f"hub_{uuid.uuid4().hex[:12]}",
        "mode_id": mode_id,
        # No deep link on the web shell — the React PlayableGame simulator is used.
        "deep_link": None,
        "status": "registered",
        "hub": "local",
    }


@router.post("/hub/launch-mode")
async def hub_launch_mode(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    return _launch_payload(str((payload or {}).get("mode_id", "basketball_h2h")))


@router.post("/vault/launch-mode")
async def vault_launch_mode(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    return _launch_payload(str((payload or {}).get("mode_id", "basketball_h2h")))


@router.post("/session/state")
async def session_state(payload: dict[str, Any] | None = None) -> dict[str, Any]:
    data = payload or {}
    return {"status": "ok", "session_id": data.get("session_id"), "state": data.get("state", "unknown")}


# ─────────────────────────────────────────────────────────────
# Brain Brawl (server-graded cognitive quiz)
# ─────────────────────────────────────────────────────────────
BRAIN_BRAWL_BANK = [
    {"question": "Which training quality is most tied to reaction drills?", "options": ["Decision speed", "Ignoring cues", "Static posture only", "No feedback"], "answer": 0, "difficulty": "Cognitive", "category": "sports_iq"},
    {"question": "What should an athlete prioritize before increasing speed?", "options": ["Movement control", "Random reps", "Skipping warmups", "Fatigue only"], "answer": 0, "difficulty": "Foundational", "category": "sports_iq"},
    {"question": "Which plane is most associated with rotational skills?", "options": ["Transverse", "Sagittal", "Frontal", "None"], "answer": 0, "difficulty": "Kinesiology", "category": "kinesiology"},
    {"question": "A vertical jump primarily initiates in which plane?", "options": ["Sagittal", "Frontal", "Transverse", "None"], "answer": 0, "difficulty": "Kinesiology", "category": "kinesiology"},
    {"question": "Which muscle group drives hip extension in a sprint?", "options": ["Glutes/hamstrings", "Biceps", "Forearms", "Calves only"], "answer": 0, "difficulty": "Kinesiology", "category": "kinesiology"},
    {"question": "Best recovery cue after a high-strain session?", "options": ["Hydrate + protein", "Skip sleep", "Max effort again", "Ignore fatigue"], "answer": 0, "difficulty": "Foundational", "category": "sports_iq"},
    {"question": "Reaction time improves most with which practice?", "options": ["Cued response drills", "Static stretching", "Long slow runs only", "No stimulus"], "answer": 0, "difficulty": "Cognitive", "category": "sports_iq"},
    {"question": "Frontal-plane stability is most challenged by?", "options": ["Lateral bounds", "Forward jog", "Bicep curls", "Seated rest"], "answer": 0, "difficulty": "Kinesiology", "category": "kinesiology"},
    {"question": "Which is a sign of good landing mechanics?", "options": ["Soft knees, aligned hips", "Locked knees", "Collapsed arches", "Twisted spine"], "answer": 0, "difficulty": "Kinesiology", "category": "kinesiology"},
    {"question": "Focus under fatigue is best trained by?", "options": ["Decision reps when tired", "Avoiding all fatigue", "Random guessing", "Skipping practice"], "answer": 0, "difficulty": "Cognitive", "category": "sports_iq"},
]


class BrainBrawlStartIn(BaseModel):
    category: str = "all"
    count: int = Field(default=10, ge=1, le=20)


class BrainBrawlSubmitIn(BaseModel):
    session_id: str
    answers: list[int]


@router.post("/brain-brawl/session/start")
async def brain_brawl_start(request: BrainBrawlStartIn) -> dict[str, Any]:
    pool = [q for q in BRAIN_BRAWL_BANK if request.category in ("all", q["category"])] or BRAIN_BRAWL_BANK
    picked = random.sample(pool, min(request.count, len(pool)))
    session_id = f"bb_{uuid.uuid4().hex[:12]}"
    _brain_brawl_sessions[session_id] = {"answers": [q["answer"] for q in picked], "submitted": False, "created_at": _now()}
    # Public questions omit the answer key (server-verified grading).
    public = [{"question": q["question"], "options": q["options"], "difficulty": q["difficulty"], "category": q["category"]} for q in picked]
    return {"session_id": session_id, "questions": public, "count": len(public)}


@router.post("/brain-brawl/session/submit")
async def brain_brawl_submit(request: BrainBrawlSubmitIn) -> dict[str, Any]:
    session = _brain_brawl_sessions.get(request.session_id)
    answer_key = session["answers"] if session else []
    total = len(answer_key) if answer_key else len(request.answers)
    correct = sum(1 for i, key in enumerate(answer_key) if i < len(request.answers) and request.answers[i] == key)
    if session is not None:
        session["submitted"] = True
    return {
        "session_id": request.session_id,
        "score": correct * 100,
        "xp_earned": correct * 50,
        "questions_correct": correct,
        "questions_total": total or len(request.answers),
        "verified": session is not None,
    }


# ─────────────────────────────────────────────────────────────
# Trivia Arena (8-category client-graded quiz)
# ─────────────────────────────────────────────────────────────
TRIVIA_BANK: dict[str, list[dict[str, Any]]] = {
    "history": [
        {"question": "Which empire built the Colosseum?", "options": ["Roman", "Ottoman", "Mongol", "British"], "correct": 0, "difficulty": "easy"},
        {"question": "The Magna Carta was signed in which century?", "options": ["13th", "10th", "16th", "19th"], "correct": 0, "difficulty": "medium"},
    ],
    "science": [
        {"question": "What gas do plants primarily absorb?", "options": ["Carbon dioxide", "Oxygen", "Nitrogen", "Helium"], "correct": 0, "difficulty": "easy"},
        {"question": "What is the powerhouse of the cell?", "options": ["Mitochondria", "Nucleus", "Ribosome", "Vacuole"], "correct": 0, "difficulty": "easy"},
    ],
    "pop_culture": [
        {"question": "Which streaming hit features the 'Upside Down'?", "options": ["Stranger Things", "The Crown", "Ozark", "Friends"], "correct": 0, "difficulty": "easy"},
        {"question": "Who is known as the 'Queen of Pop'?", "options": ["Madonna", "Adele", "Sia", "Pink"], "correct": 0, "difficulty": "medium"},
    ],
    "sport_history": [
        {"question": "Which city hosted the first modern Olympics (1896)?", "options": ["Athens", "Paris", "London", "Rome"], "correct": 0, "difficulty": "medium"},
        {"question": "How many players are on a standard basketball team on court?", "options": ["5", "6", "7", "4"], "correct": 0, "difficulty": "easy"},
    ],
    "sport_science": [
        {"question": "Which muscle fiber type suits long-distance events?", "options": ["Slow-twitch", "Fast-twitch", "Cardiac", "Smooth"], "correct": 0, "difficulty": "medium"},
        {"question": "VO2 max measures what?", "options": ["Aerobic capacity", "Grip strength", "Flexibility", "Reaction time"], "correct": 0, "difficulty": "medium"},
    ],
    "art": [
        {"question": "Who painted the Mona Lisa?", "options": ["Da Vinci", "Picasso", "Van Gogh", "Monet"], "correct": 0, "difficulty": "easy"},
        {"question": "Which movement is Salvador Dalí associated with?", "options": ["Surrealism", "Cubism", "Baroque", "Realism"], "correct": 0, "difficulty": "medium"},
    ],
    "literature": [
        {"question": "Who wrote 'Romeo and Juliet'?", "options": ["Shakespeare", "Dickens", "Austen", "Tolstoy"], "correct": 0, "difficulty": "easy"},
        {"question": "'1984' was written by which author?", "options": ["George Orwell", "Aldous Huxley", "Ray Bradbury", "H.G. Wells"], "correct": 0, "difficulty": "medium"},
    ],
    "vocabulary": [
        {"question": "What does 'ephemeral' mean?", "options": ["Short-lived", "Enormous", "Ancient", "Loud"], "correct": 0, "difficulty": "medium"},
        {"question": "A synonym for 'tenacious' is?", "options": ["Persistent", "Lazy", "Fragile", "Brief"], "correct": 0, "difficulty": "medium"},
    ],
}


@router.get("/trivia/questions")
async def trivia_questions(
    category: str | None = Query(default=None),
    count: int = Query(default=1, ge=1, le=10),
) -> list[dict[str, Any]]:
    if category and category in TRIVIA_BANK:
        pool = list(TRIVIA_BANK[category])
        for q in pool:
            q.setdefault("category", category)
    else:
        pool = [{**q, "category": cat} for cat, items in TRIVIA_BANK.items() for q in items]
    random.shuffle(pool)
    return pool[:count]


# ─────────────────────────────────────────────────────────────
# Final Evolution Hub command-center status (shell-safe)
# ─────────────────────────────────────────────────────────────
def _uptime_seconds() -> int:
    return int(time.monotonic() - _SERVER_STARTED_AT)


@router.get("/hub/status")
async def hub_status() -> dict[str, Any]:
    return {
        "websocket": {"status": "connected", "connected_clients": [], "total_messages": 0},
        "database": {
            "status": "ready",
            "total_venues": 12,
            "venues": [
                "VeniceBeach", "Dojo", "BaseballPark", "Gridiron", "SoccerStadium",
                "Links", "TennisCourt", "SandCourt", "TrainingFloor", "NeuroArena",
                "Luma_Venice_Shop", "SecureEnclave",
            ],
        },
        "integrity": {"status": "ACTIVE", "hardware_auth": {"bIsHardwareAuthenticated": True, "back_camera_verified": True, "imu_visual_sync": True}},
        "telemetry": {"prq": 75.6, "combo_meter": 0, "buckets": 0, "vertical_jump": 0, "velocity_vectors": {"x": 0, "y": 0, "z": 0}},
        "active_creator_card": None,
        "server": {"version": "1.0.0", "uptime_seconds": _uptime_seconds()},
    }


@router.get("/production/health")
async def production_health() -> dict[str, Any]:
    return {"status": "HEALTHY", "checks": {"mode_manager": {"production_modes": 19}}}


@router.get("/production/handshake-log")
async def production_handshake_log() -> dict[str, Any]:
    now_ms = int(datetime.now(UTC).timestamp() * 1000)
    return {
        "handshake_status": "CONNECTED",
        "log": [
            {"ts": now_ms, "level": "INFO", "msg": "Local hub online. AES-256-GCM tunnels enabled."},
            {"ts": now_ms, "level": "INFO", "msg": "Venue registry loaded (12 venues)."},
        ],
    }


@router.get("/telemetry/live")
async def telemetry_live() -> dict[str, Any]:
    return {"prq": 75.6, "combo_meter": 0, "buckets": 0, "vertical_jump": 0, "velocity_vectors": {"x": 0, "y": 0, "z": 0}}

