"""
FEL OS — NASM-CNC Bio-Fuel Suite

Endpoints:
  POST /api/biofuel/scan              — image → macros (athlete picks Gemini 2.5 Flash | GPT-5.2)
  GET  /api/biofuel/recipes           — 3D cookbook
  GET  /api/biofuel/recipes/{id}      — recipe detail (ingredients + macros + steps)
  POST /api/biofuel/log               — log a meal/scan into today's tracker
  GET  /api/biofuel/today             — NASM-CNC daily macro target vs consumed
  GET  /api/biofuel/cues              — supportive AI Coach Neuro-Cues
  POST /api/biofuel/instacart-cart    — generates Instacart deep-link from recipe ingredients
  POST /api/biofuel/doordash-search   — macro-filtered DoorDash search deep-link

Notes:
  - Instacart Connect & DoorDash Marketplace APIs are partner-gated. We generate deep links
    + provide a copy-friendly ingredient list. Real cart-push goes live once partner keys land.
  - Tone: SUPPORTIVE coach by user directive.
  - Vision model: chosen per-request from {gemini-2.5-flash, gpt-5.2}.
"""
import json
import re
import urllib.parse
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from core import EMERGENT_KEY, User, db, get_current_user

try:
    from emergentintegrations.llm.chat import ImageContent, LlmChat, UserMessage
except ImportError:
    ImageContent = None
    LlmChat = None
    UserMessage = None

router = APIRouter(prefix="/api/biofuel", tags=["biofuel"])

# ============================================================
# NASM-CNC Macro Engine
# ============================================================

ALLOWED_MODELS = {"gemini-2.5-flash", "gpt-5.2"}
MAX_SCAN_IMAGE_BASE64_BYTES = 4 * 1024 * 1024
ATHLETIC_INTENTS = {
    "fascial_hydration": "Connective tissue hydration & joint resilience",
    "cns_ignition": "Pre-training neural priming",
    "post_dunk_recovery": "High-impact / plyometric recovery",
    "endurance_base": "Aerobic base & glycogen restoration",
    "sleep_anabolic": "Pre-sleep parasympathetic & overnight protein synthesis",
}

NUTRI_SHARDS_PER_SCAN = 12  # base award


def nasm_macro_target(weight_kg: float, sport: str, intent: str) -> Dict[str, Any]:
    """NASM-CNC certified macro target for the day. Uses athlete-first defaults."""
    # Protein: 1.6–2.2 g/kg (we hit 1.9 g/kg as the FEL-CNC default)
    protein_g = round(weight_kg * 1.9)
    # Carbs: scale with sport intent. Power sports → 4.5g/kg; endurance → 6g/kg
    carb_per_kg = 4.5 if sport in ("basketball", "football", "training") else 6.0
    if intent == "endurance_base":
        carb_per_kg = 6.5
    if intent == "sleep_anabolic":
        carb_per_kg = 3.5
    carbs_g = round(weight_kg * carb_per_kg)
    # Fats: 0.9 g/kg baseline
    fats_g = round(weight_kg * 0.9)
    calories = protein_g * 4 + carbs_g * 4 + fats_g * 9
    return {
        "calories": calories,
        "protein_g": protein_g,
        "carbs_g": carbs_g,
        "fats_g": fats_g,
        "hydration_ml": int(weight_kg * 40),
        "intent": intent,
        "intent_label": ATHLETIC_INTENTS.get(intent, intent),
    }


def _today_key() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


# ============================================================
# 3D COOKBOOK — Seeded recipes
# ============================================================

RECIPES: List[Dict[str, Any]] = [
    {
        "id": "recipe_collagen_bone_broth",
        "title": "Collagen Bone Broth Reset",
        "intent": "fascial_hydration",
        "intent_label": "Fascial Hydration",
        "duration_min": 240,
        "macros": {"calories": 180, "protein_g": 22, "carbs_g": 6, "fats_g": 7},
        "micros": {"collagen_g": 12, "magnesium_mg": 120, "sodium_mg": 980, "hydration_ml": 480},
        "summary": "Slow-simmered grass-fed bone broth with apple-cider vinegar — fascial collagen + electrolyte stack.",
        "ingredients": [
            {"name": "Grass-fed beef knuckle bones", "qty": "2 lb"},
            {"name": "Apple cider vinegar", "qty": "2 tbsp"},
            {"name": "Celery stalks", "qty": "3"},
            {"name": "Carrots", "qty": "2"},
            {"name": "Yellow onion", "qty": "1"},
            {"name": "Garlic cloves", "qty": "4"},
            {"name": "Sea salt", "qty": "1.5 tsp"},
            {"name": "Filtered water", "qty": "8 cups"},
        ],
        "steps": [
            "Roast bones at 425°F for 30 min for richer flavor.",
            "Add bones + ACV to stock pot, cover with water, rest 30 min.",
            "Add aromatics + salt, bring to gentle boil, then reduce to simmer.",
            "Simmer 4 hours minimum (8–12 hrs is ideal). Skim foam.",
            "Strain through cheesecloth. Cool. Refrigerate up to 5 days.",
        ],
        "viz_palette": ["#fbbf24", "#f59e0b", "#92400e"],
    },
    {
        "id": "recipe_cns_espresso_protein",
        "title": "CNS Ignition Espresso-Protein Stack",
        "intent": "cns_ignition",
        "intent_label": "CNS Ignition",
        "duration_min": 5,
        "macros": {"calories": 240, "protein_g": 28, "carbs_g": 10, "fats_g": 9},
        "micros": {"caffeine_mg": 180, "magnesium_mg": 60, "sodium_mg": 240, "hydration_ml": 350},
        "summary": "Pre-training neural primer — cold espresso + whey isolate + creatine. 30–45 min before plyometrics.",
        "ingredients": [
            {"name": "Cold espresso (2 shots)", "qty": "60 ml"},
            {"name": "Whey protein isolate", "qty": "30 g"},
            {"name": "Creatine monohydrate", "qty": "5 g"},
            {"name": "Almond milk (unsweetened)", "qty": "300 ml"},
            {"name": "Pink salt", "qty": "pinch"},
            {"name": "Ice", "qty": "as needed"},
        ],
        "steps": [
            "Pull 2 shots of espresso, chill or pour over ice.",
            "Add almond milk + whey + creatine + salt to a shaker.",
            "Shake 20 seconds. Pour over the espresso.",
            "Drink 30–45 min before training.",
        ],
        "viz_palette": ["#22d3ee", "#0ea5e9", "#0c4a6e"],
    },
    {
        "id": "recipe_post_dunk_bowl",
        "title": "Post-Dunk Recovery Power Bowl",
        "intent": "post_dunk_recovery",
        "intent_label": "Post-Dunk Recovery",
        "duration_min": 25,
        "macros": {"calories": 720, "protein_g": 52, "carbs_g": 78, "fats_g": 18},
        "micros": {"omega3_mg": 1200, "magnesium_mg": 150, "sodium_mg": 600, "hydration_ml": 250},
        "summary": "Wild salmon + brown rice + roasted sweet potato + tahini drizzle — anti-inflammatory plyometric reset.",
        "ingredients": [
            {"name": "Wild salmon fillet", "qty": "6 oz"},
            {"name": "Brown rice (cooked)", "qty": "1.5 cups"},
            {"name": "Sweet potato", "qty": "1 medium"},
            {"name": "Baby spinach", "qty": "2 cups"},
            {"name": "Avocado", "qty": "1/2"},
            {"name": "Tahini", "qty": "1 tbsp"},
            {"name": "Lemon", "qty": "1/2"},
            {"name": "Olive oil", "qty": "1 tsp"},
            {"name": "Sea salt + pepper", "qty": "to taste"},
        ],
        "steps": [
            "Roast cubed sweet potato @ 425°F for 20 min with olive oil and salt.",
            "Pan-sear salmon skin-side-down 4 min, flip 3 min. Rest 2 min.",
            "Layer rice → spinach → sweet potato → salmon → avocado.",
            "Whisk tahini + lemon + 1 tbsp warm water. Drizzle.",
        ],
        "viz_palette": ["#fb923c", "#f97316", "#7c2d12"],
    },
    {
        "id": "recipe_sleep_casein_bowl",
        "title": "Anabolic Sleep Casein Bowl",
        "intent": "sleep_anabolic",
        "intent_label": "Sleep Anabolic",
        "duration_min": 5,
        "macros": {"calories": 320, "protein_g": 32, "carbs_g": 22, "fats_g": 11},
        "micros": {"magnesium_mg": 180, "tryptophan_mg": 320, "hydration_ml": 200},
        "summary": "Slow-digesting casein + tart cherry — overnight protein synthesis + melatonin priming.",
        "ingredients": [
            {"name": "Micellar casein", "qty": "30 g"},
            {"name": "Tart cherry juice (no sugar)", "qty": "180 ml"},
            {"name": "Greek yogurt (full-fat)", "qty": "1/2 cup"},
            {"name": "Walnuts", "qty": "1 tbsp"},
            {"name": "Cinnamon", "qty": "pinch"},
        ],
        "steps": [
            "Whisk casein into yogurt — let sit 2 min.",
            "Top with walnuts, cherry juice swirl, cinnamon.",
            "Eat 60–90 min before bed.",
        ],
        "viz_palette": ["#a78bfa", "#7c3aed", "#3b0764"],
    },
    {
        "id": "recipe_endurance_overnight_oats",
        "title": "Endurance Overnight Oats",
        "intent": "endurance_base",
        "intent_label": "Endurance Base",
        "duration_min": 5,
        "macros": {"calories": 540, "protein_g": 28, "carbs_g": 78, "fats_g": 12},
        "micros": {"omega3_mg": 800, "magnesium_mg": 140, "sodium_mg": 220, "hydration_ml": 240},
        "summary": "Rolled oats + chia + Greek yogurt — slow-release carbs for the long-game session.",
        "ingredients": [
            {"name": "Rolled oats", "qty": "3/4 cup"},
            {"name": "Chia seeds", "qty": "1 tbsp"},
            {"name": "Almond milk", "qty": "1 cup"},
            {"name": "Greek yogurt", "qty": "1/2 cup"},
            {"name": "Banana (sliced)", "qty": "1"},
            {"name": "Honey", "qty": "1 tsp"},
            {"name": "Cinnamon", "qty": "1/4 tsp"},
        ],
        "steps": [
            "Combine oats + chia + milk + yogurt in a jar; stir.",
            "Refrigerate overnight.",
            "Top with banana + honey + cinnamon in the morning.",
        ],
        "viz_palette": ["#34d399", "#059669", "#064e3b"],
    },
]


# Seeded restaurant catalogue (used by DoorDash macro filter — to be replaced by Marketplace API)
DOORDASH_SEED: List[Dict[str, Any]] = [
    {"name": "Cava — Build Your Own", "macros": {"protein_g": 38, "carbs_g": 60, "fats_g": 18, "calories": 590}, "intent": "post_dunk_recovery", "city_query": "Cava"},
    {"name": "Sweetgreen — Harvest Bowl", "macros": {"protein_g": 30, "carbs_g": 70, "fats_g": 22, "calories": 640}, "intent": "endurance_base", "city_query": "Sweetgreen Harvest Bowl"},
    {"name": "Chipotle — Double Chicken Bowl", "macros": {"protein_g": 60, "carbs_g": 55, "fats_g": 20, "calories": 700}, "intent": "post_dunk_recovery", "city_query": "Chipotle Double Chicken"},
    {"name": "Just Salad — Power Bowl", "macros": {"protein_g": 35, "carbs_g": 25, "fats_g": 15, "calories": 410}, "intent": "fascial_hydration", "city_query": "Just Salad Power Bowl"},
    {"name": "Dig — Salmon Plate", "macros": {"protein_g": 42, "carbs_g": 50, "fats_g": 20, "calories": 590}, "intent": "post_dunk_recovery", "city_query": "Dig salmon"},
    {"name": "Joe & The Juice — Tunacado", "macros": {"protein_g": 28, "carbs_g": 38, "fats_g": 22, "calories": 470}, "intent": "cns_ignition", "city_query": "Joe and the Juice Tunacado"},
    {"name": "Pret — Egg Pot Stack", "macros": {"protein_g": 18, "carbs_g": 5, "fats_g": 14, "calories": 220}, "intent": "cns_ignition", "city_query": "Pret egg pot"},
    {"name": "Whole Foods Hot Bar — Bone Broth", "macros": {"protein_g": 22, "carbs_g": 6, "fats_g": 7, "calories": 180}, "intent": "fascial_hydration", "city_query": "Whole Foods bone broth"},
]


# ============================================================
# REQUEST MODELS
# ============================================================

class ScanRequest(BaseModel):
    model: str = "gemini-2.5-flash"
    image_base64: str
    hint: Optional[str] = None  # e.g., "post-workout"


class LogRequest(BaseModel):
    label: str
    calories: float
    protein_g: float
    carbs_g: float
    fats_g: float
    intent: Optional[str] = None
    source: str = "scan"  # scan | recipe | manual | doordash | instacart


class CartRequest(BaseModel):
    recipe_id: str


class DoorDashRequest(BaseModel):
    intent: Optional[str] = None
    max_calories: Optional[int] = None
    min_protein_g: Optional[int] = None


# ============================================================
# AI VISION SCAN
# ============================================================

SYSTEM_SCAN_PROMPT = """You are a NASM-CNC certified nutrition coach evaluating an athlete's meal photo.
Return ONLY a single valid JSON object — no markdown, no commentary — with these fields:
{
  "label": "<short dish name, max 60 chars>",
  "calories": <integer kcal>,
  "protein_g": <integer grams>,
  "carbs_g": <integer grams>,
  "fats_g": <integer grams>,
  "micros": {
    "collagen_g": <integer or 0>,
    "omega3_mg": <integer or 0>,
    "magnesium_mg": <integer or 0>,
    "sodium_mg": <integer or 0>,
    "hydration_ml": <integer or 0>
  },
  "athletic_intent": "fascial_hydration|cns_ignition|post_dunk_recovery|endurance_base|sleep_anabolic"
}
Estimate per typical adult-athlete portion. Be honest and conservative — these numbers feed the athlete's daily macro tracker."""


def _extract_json(text: str) -> Dict[str, Any]:
    """Extract the first valid JSON object from an LLM response."""
    # Strip code fences if present
    text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip(), flags=re.MULTILINE)
    # Find first {...} block
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise ValueError(f"No JSON object found in response: {text[:200]}")
    return json.loads(match.group(0))


@router.post("/scan")
async def scan_meal(req: ScanRequest, user: User = Depends(get_current_user)):
    """Photo → macros via athlete-chosen vision model. Awards Nutri-Shards."""
    if req.model not in ALLOWED_MODELS:
        raise HTTPException(status_code=400, detail=f"model must be one of {sorted(ALLOWED_MODELS)}")
    if len(req.image_base64.encode("utf-8")) > MAX_SCAN_IMAGE_BASE64_BYTES:
        raise HTTPException(status_code=413, detail="image_base64 must be 4MB or smaller")
    if not all((ImageContent, LlmChat, UserMessage)):
        raise HTTPException(status_code=503, detail="Vision AI integration is not installed")
    if not EMERGENT_KEY:
        raise HTTPException(status_code=500, detail="EMERGENT_LLM_KEY not configured")

    provider = "gemini" if req.model.startswith("gemini") else "openai"
    session_id = f"biofuel-scan-{uuid.uuid4().hex[:10]}"

    chat = LlmChat(
        api_key=EMERGENT_KEY,
        session_id=session_id,
        system_message=SYSTEM_SCAN_PROMPT,
    ).with_model(provider, req.model)

    image = ImageContent(image_base64=req.image_base64)
    message = UserMessage(
        text=(req.hint or "Analyze this meal photo and return the JSON."),
        file_contents=[image],
    )

    try:
        raw = await chat.send_message(message)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"vision provider error: {e}")

    try:
        parsed = _extract_json(raw if isinstance(raw, str) else str(raw))
    except (ValueError, json.JSONDecodeError) as e:
        raise HTTPException(status_code=502, detail=f"could not parse vision response: {e}")

    # Coerce + safe defaults
    intent = parsed.get("athletic_intent", "post_dunk_recovery")
    if intent not in ATHLETIC_INTENTS:
        intent = "post_dunk_recovery"

    scan_id = f"scan_{uuid.uuid4().hex[:10]}"
    out = {
        "scan_id": scan_id,
        "model": req.model,
        "label": str(parsed.get("label", "Meal"))[:80],
        "calories": int(parsed.get("calories", 0) or 0),
        "protein_g": int(parsed.get("protein_g", 0) or 0),
        "carbs_g": int(parsed.get("carbs_g", 0) or 0),
        "fats_g": int(parsed.get("fats_g", 0) or 0),
        "micros": parsed.get("micros") or {},
        "athletic_intent": intent,
        "nutri_shards_awarded": NUTRI_SHARDS_PER_SCAN,
        "scanned_at": datetime.now(timezone.utc).isoformat(),
    }

    # Persist scan record
    await db.biofuel_scans.insert_one({**out, "user_id": user.user_id})

    # Award Nutri-Shards (stored as XP)
    await db.users.update_one(
        {"user_id": user.user_id}, {"$inc": {"xp": NUTRI_SHARDS_PER_SCAN}}
    )

    # Auto-log to today's tracker
    await _append_log(user.user_id, {
        "label": out["label"], "calories": out["calories"], "protein_g": out["protein_g"],
        "carbs_g": out["carbs_g"], "fats_g": out["fats_g"], "intent": intent,
        "source": "scan", "scan_id": scan_id,
    })

    return out


# ============================================================
# RECIPES (3D Cookbook)
# ============================================================

@router.get("/recipes")
async def list_recipes(intent: Optional[str] = None):
    items = RECIPES if not intent else [r for r in RECIPES if r["intent"] == intent]
    return {
        "intents": [{"id": k, "label": v} for k, v in ATHLETIC_INTENTS.items()],
        "recipes": [{
            "id": r["id"], "title": r["title"], "intent": r["intent"],
            "intent_label": r["intent_label"], "duration_min": r["duration_min"],
            "macros": r["macros"], "summary": r["summary"], "viz_palette": r["viz_palette"],
        } for r in items],
    }


@router.get("/recipes/{recipe_id}")
async def get_recipe(recipe_id: str):
    r = next((x for x in RECIPES if x["id"] == recipe_id), None)
    if not r:
        raise HTTPException(status_code=404, detail="Recipe not found")
    return r


# ============================================================
# DAILY TRACKER + LOGGING
# ============================================================

async def _append_log(user_id: str, entry: Dict[str, Any]):
    """Append a meal log to today's bucket for the user."""
    day = _today_key()
    entry["logged_at"] = datetime.now(timezone.utc).isoformat()
    await db.biofuel_logs.update_one(
        {"user_id": user_id, "day": day},
        {"$push": {"entries": entry}, "$setOnInsert": {"user_id": user_id, "day": day}},
        upsert=True,
    )


@router.post("/log")
async def log_meal(req: LogRequest, user: User = Depends(get_current_user)):
    entry = req.model_dump()
    await _append_log(user.user_id, entry)
    return {"ok": True, "day": _today_key()}


def _consumed_totals(entries: List[Dict[str, Any]]) -> Dict[str, int]:
    return {
        "calories": int(sum((e.get("calories") or 0) for e in entries)),
        "protein_g": int(sum((e.get("protein_g") or 0) for e in entries)),
        "carbs_g": int(sum((e.get("carbs_g") or 0) for e in entries)),
        "fats_g": int(sum((e.get("fats_g") or 0) for e in entries)),
    }


def _athlete_weight_kg(user: User) -> float:
    # Until a `weight_kg` field is captured, derive a reasonable default from PRQ (75kg baseline)
    return 75.0


def _today_intent(user: User) -> str:
    # Heuristic: tie to sport. Will be overridden by AI Coach in a later pass.
    return "post_dunk_recovery" if user.sport in ("basketball", "football") else "endurance_base"


@router.get("/today")
async def get_today(user: User = Depends(get_current_user)):
    weight_kg = _athlete_weight_kg(user)
    intent = _today_intent(user)
    target = nasm_macro_target(weight_kg, user.sport, intent)
    log = await db.biofuel_logs.find_one({"user_id": user.user_id, "day": _today_key()}, {"_id": 0}) or {}
    entries = log.get("entries", [])
    consumed = _consumed_totals(entries)
    deltas = {k: max(0, target[k] - consumed.get(k, 0)) for k in ("calories", "protein_g", "carbs_g", "fats_g")}
    pct = {
        k: min(100, round(100 * consumed.get(k, 0) / target[k])) if target[k] else 0
        for k in ("calories", "protein_g", "carbs_g", "fats_g")
    }
    return {
        "day": _today_key(),
        "weight_kg": weight_kg,
        "intent": intent,
        "intent_label": ATHLETIC_INTENTS.get(intent, intent),
        "target": target,
        "consumed": consumed,
        "remaining": deltas,
        "pct": pct,
        "entries": entries,
    }


# ============================================================
# AI COACH NEURO-CUES (supportive tone)
# ============================================================

def _supportive_cues(target: Dict, consumed: Dict, pct: Dict, intent_label: str) -> List[Dict[str, str]]:
    cues: List[Dict[str, str]] = []
    p_pct = pct.get("protein_g", 0)
    c_pct = pct.get("carbs_g", 0)
    f_pct = pct.get("fats_g", 0)
    cal_pct = pct.get("calories", 0)
    hour = datetime.now().hour

    # Protein gap (supportive, not aggressive)
    if p_pct < 50 and hour >= 11:
        cues.append({
            "id": "protein_gap",
            "tone": "supportive",
            "icon": "Beef",
            "title": "Protein runway",
            "message": f"You're at {p_pct}% of today's protein. A high-quality source in your next meal would round out recovery beautifully.",
            "action_label": "See post-workout meals",
            "action": "doordash:post_dunk_recovery",
        })
    if c_pct > 90 and p_pct < 60:
        cues.append({
            "id": "carb_protein_balance",
            "tone": "supportive",
            "icon": "Scale",
            "title": "Macros are leaning carb-heavy",
            "message": "Hey, you're crushing carbs today. Adding a protein source would round out recovery.",
            "action_label": "Browse 3D Cookbook",
            "action": "cookbook:post_dunk_recovery",
        })
    # Hydration nudge after lunch
    hyd = consumed.get("hydration_ml", 0)
    hyd_target = target.get("hydration_ml", 0) or 1
    if hour >= 13 and hyd / hyd_target < 0.5:
        cues.append({
            "id": "hydration_low",
            "tone": "supportive",
            "icon": "Droplet",
            "title": "Fascial hydration window",
            "message": "Water's been quiet today. A bone-broth or lemon-water reset right now would protect connective tissue for tonight's session.",
            "action_label": "Open Bone Broth recipe",
            "action": "recipe:recipe_collagen_bone_broth",
        })
    # Sleep anabolic nudge
    if hour >= 20 and p_pct < 80:
        cues.append({
            "id": "sleep_anabolic",
            "tone": "supportive",
            "icon": "Moon",
            "title": "Overnight protein synthesis",
            "message": "A small slow-digest snack 60–90 min before bed will keep recovery rolling through the night — no pressure, just an option.",
            "action_label": "Anabolic Sleep Bowl",
            "action": "recipe:recipe_sleep_casein_bowl",
        })
    # Fat overshoot — gentle reframe
    if f_pct > 110:
        cues.append({
            "id": "fats_high",
            "tone": "supportive",
            "icon": "Wind",
            "title": "Fats are well-stocked",
            "message": "You're already over today's fat target — totally fine. A leaner protein for the next meal will keep things balanced.",
            "action_label": "Lean meals",
            "action": "doordash:cns_ignition",
        })
    # Win-state encouragement
    if not cues and cal_pct >= 80:
        cues.append({
            "id": "on_track",
            "tone": "supportive",
            "icon": "Sparkles",
            "title": f"{intent_label} dialed in",
            "message": f"Macros are tracking — you're at {cal_pct}% of today's energy target. Stay the course.",
            "action_label": "Open dashboard",
            "action": "felos:scan",
        })
    return cues


@router.get("/cues")
async def get_cues(user: User = Depends(get_current_user)):
    today = await get_today(user)
    cues = _supportive_cues(today["target"], today["consumed"], today["pct"], today["intent_label"])
    return {"day": today["day"], "tone": "supportive", "cues": cues}


# ============================================================
# INSTACART + DOORDASH DEEP-LINK BRIDGES
# ============================================================
# NOTE: Real cart-push requires Instacart Connect / DoorDash Marketplace partner keys.
# Until then we return search deep-links + an ingredient list copy-block.

@router.post("/instacart-cart")
async def instacart_cart(req: CartRequest, user: User = Depends(get_current_user)):
    r = next((x for x in RECIPES if x["id"] == req.recipe_id), None)
    if not r:
        raise HTTPException(status_code=404, detail="Recipe not found")
    items = [i["name"] for i in r["ingredients"]]
    query = ", ".join(items)
    deep_link = f"https://www.instacart.com/store/s?k={urllib.parse.quote(query)}"
    return {
        "recipe_id": r["id"],
        "recipe_title": r["title"],
        "deep_link": deep_link,
        "fallback_url": "https://www.instacart.com",
        "items": items,
        "note": "Awaiting Instacart Connect partner credentials for one-click cart push.",
    }


@router.post("/doordash-search")
async def doordash_search(req: DoorDashRequest, user: User = Depends(get_current_user)):
    today = await get_today(user)
    intent = req.intent or today["intent"]
    pool = [r for r in DOORDASH_SEED if r["intent"] == intent] or DOORDASH_SEED
    # Macro filter: prefer items that close the protein gap and respect remaining calories
    remaining_cal = req.max_calories if req.max_calories is not None else today["remaining"]["calories"]
    min_p = req.min_protein_g if req.min_protein_g is not None else min(35, today["remaining"]["protein_g"])

    def fit(meal):
        m = meal["macros"]
        cal_ok = m["calories"] <= max(remaining_cal, 200)
        p_ok = m["protein_g"] >= min_p
        return cal_ok and p_ok

    matches = []
    for meal in ([m for m in pool if fit(m)] or pool[:3]):
        result = {**meal, "macros": {**meal["macros"]}}
        result["deep_link"] = f"https://www.doordash.com/search/store/?query={urllib.parse.quote(result['city_query'])}"
        matches.append(result)
    return {
        "intent": intent,
        "intent_label": ATHLETIC_INTENTS.get(intent, intent),
        "remaining_today": today["remaining"],
        "min_protein_g": min_p,
        "max_calories": remaining_cal,
        "matches": matches,
        "note": "Awaiting DoorDash Marketplace partner credentials for in-app macro-aware ordering.",
    }
