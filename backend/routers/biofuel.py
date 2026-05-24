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
  - APPSTORE-02: deep links open third-party grocery/meal ordering for real-world food — not in-app
    digital IAP. Keep separate from StoreKit digital goods; surfaces should be user-initiated and
    non-gamified ordering aids only.
  - Tone: SUPPORTIVE coach by user directive.
  - Vision model: chosen per-request from {gemini-2.5-flash, gpt-5.2}.
"""
import json
import re
import urllib.parse
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

from emergentintegrations.llm.chat import ImageContent, LlmChat, UserMessage
from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, field_validator

from core import EMERGENT_KEY, User, db, get_current_user

router = APIRouter(prefix="/api/biofuel", tags=["biofuel"])

async def get_current_user_optional(request: Request) -> Optional[User]:
    try:
        return await get_current_user(request)
    except Exception:
        return None

# ============================================================
# NASM-CNC Macro Engine
# ============================================================

ALLOWED_MODELS = {"gemini-2.5-flash", "gpt-5.2"}
ATHLETIC_INTENTS = {
    "fascial_hydration": "Connective tissue hydration & joint resilience",
    "cns_ignition": "Pre-training neural priming",
    "post_dunk_recovery": "High-impact / plyometric recovery",
    "endurance_base": "Aerobic base & glycogen restoration",
    "sleep_anabolic": "Pre-sleep parasympathetic & overnight protein synthesis",
}

NUTRI_SHARDS_PER_SCAN = 12  # base award (applied only after /scan/confirm)
MAX_IMAGE_BASE64_CHARS = 4_500_000  # ~3.3 MiB payload guard for WKWebView / vision routes
ALLOWED_LOG_SOURCES = frozenset({"scan", "recipe", "manual", "doordash", "instacart", "pending_scan_confirm"})
SCAN_CONFIRM_RATE_LIMIT_PER_HOUR = 24

# Single-meal log sanity caps (per eating occasion — prevents corrupted daily totals / LLM glitches)
MEAL_MAX_CALORIES = 3500
MEAL_MAX_PROTEIN_G = 220
MEAL_MAX_CARBS_G = 450
MEAL_MAX_FATS_G = 180
MEAL_MAX_HYDRATION_ML = 2500


def _clamp_meal_int(v: Any, cap: int) -> int:
    try:
        x = int(v or 0)
    except (TypeError, ValueError):
        x = 0
    return max(0, min(cap, x))


def _recipe_ingredient_blob(r: Dict[str, Any]) -> str:
    parts = [str(r.get("title", "")), str(r.get("summary", ""))]
    for ing in r.get("ingredients") or []:
        if isinstance(ing, dict):
            parts.append(str(ing.get("name", "")))
    return " ".join(parts).lower()


def _avoid_tokens(user: User) -> List[str]:
    """Flatten allergies + diet keywords for naive substring filtering (NUTRI-07)."""
    toks: List[str] = []
    for a in getattr(user, "allergies", None) or []:
        if isinstance(a, str) and a.strip():
            toks.append(a.strip().lower())
    for d in getattr(user, "dietary_restrictions", None) or []:
        if not isinstance(d, str) or not d.strip():
            continue
        dl = d.strip().lower()
        if dl == "vegan":
            toks.extend(
                ["beef", "chicken", "pork", "fish", "egg", "whey", "milk", "cheese", "bone", "broth", "honey", "yogurt", "salmon"]
            )
        elif dl == "vegetarian":
            toks.extend(["beef", "chicken", "pork", "fish", "bone", "broth", "shrimp", "salmon"])
        elif dl in ("halal",):
            toks.extend(["pork", "bacon"])
        elif dl in ("kosher",):
            toks.extend(["pork", "shellfish", "shrimp"])
        elif dl in ("gluten_free", "gluten-free"):
            toks.extend(["wheat", "barley", "rye", "bread", "pasta"])
        else:
            toks.append(dl)
    return list(dict.fromkeys(toks))


def _violates_avoid(blob: str, tokens: List[str]) -> bool:
    b = blob.lower()
    for t in tokens:
        if t and t in b:
            return True
    return False


def _filter_recipes_for_user(items: List[Dict[str, Any]], user: User) -> List[Dict[str, Any]]:
    tok = _avoid_tokens(user)
    if not tok:
        return items
    return [r for r in items if not _violates_avoid(_recipe_ingredient_blob(r), tok)]


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
        "title": "Habesha Spiced Beef Bone Marak",
        "intent": "fascial_hydration",
        "intent_label": "Fascial Hydration",
        "duration_min": 240,
        "macros": {"calories": 190, "protein_g": 24, "carbs_g": 8, "fats_g": 7},
        "micros": {"collagen_g": 14, "magnesium_mg": 130, "sodium_mg": 990, "hydration_ml": 480},
        "summary": "Yard House x Habesha fusion — slow-simmered grass-fed beef marrow bones infused with ginger, rosemary, garlic, and a finishing drizzle of Berbere-spiced ghee oil. Absolute collagen power.",
        "ingredients": [
            {"name": "Grass-fed beef marrow bones", "qty": "2 lb"},
            {"name": "Berbere spice blend", "qty": "1.5 tsp"},
            {"name": "Clarified butter (ghee)", "qty": "1 tbsp"},
            {"name": "Fresh rosemary sprigs", "qty": "3"},
            {"name": "Ginger root (sliced)", "qty": "2 inches"},
            {"name": "Garlic cloves (smashed)", "qty": "5"},
            {"name": "Red onion (quartered)", "qty": "1"},
            {"name": "Apple cider vinegar", "qty": "2 tbsp"},
            {"name": "Sea salt", "qty": "1.5 tsp"},
            {"name": "Filtered water", "qty": "8 cups"},
        ],
        "steps": [
            "Roast beef bones and onions at 425°F for 30 minutes until deeply browned.",
            "Place roasted bones, onions, ginger, garlic, rosemary, and apple cider vinegar in a stockpot. Cover with water.",
            "Bring to a boil, skim any surface impurities, then reduce to a low simmer for 4 hours minimum.",
            "In a small pan, heat ghee over low heat and toast the Berbere spice for 1 minute until fragrant.",
            "Strain the rich bone broth (Marak), stir in the sea salt, and finish with a drizzle of the Berbere spiced ghee.",
        ],
        "viz_palette": ["#fbbf24", "#f59e0b", "#92400e"],
    },
    {
        "id": "recipe_cns_espresso_protein",
        "title": "Habesha Buna & Cardamom Espresso Shake",
        "intent": "cns_ignition",
        "intent_label": "CNS Ignition",
        "duration_min": 5,
        "macros": {"calories": 250, "protein_g": 30, "carbs_g": 12, "fats_g": 8},
        "micros": {"caffeine_mg": 180, "magnesium_mg": 70, "sodium_mg": 250, "hydration_ml": 350},
        "summary": "Ethiopian coffee ceremony meets modern recovery — strong cold-brew Habesha Buna shaken with ground cardamom, clean whey isolate, and a touch of coconut water.",
        "ingredients": [
            {"name": "Double shot of espresso (Habesha Buna)", "qty": "60 ml"},
            {"name": "Whey protein isolate (vanilla)", "qty": "30 g"},
            {"name": "Ground cardamom", "qty": "1/4 tsp"},
            {"name": "Coconut water", "qty": "100 ml"},
            {"name": "Almond milk (unsweetened)", "qty": "200 ml"},
            {"name": "Creatine monohydrate", "qty": "5 g"},
            {"name": "Ice", "qty": "1 cup"},
        ],
        "steps": [
            "Brew double shot of dark roast Habesha coffee (Buna) and let it chill.",
            "Add chilled coffee, whey isolate, cardamom, coconut water, almond milk, and creatine to a high-speed blender.",
            "Blend on high with ice for 30 seconds until frothy and smooth.",
            "Serve immediately 30-45 minutes prior to training for immediate neural activation.",
        ],
        "viz_palette": ["#22d3ee", "#0ea5e9", "#0c4a6e"],
    },
    {
        "id": "recipe_post_dunk_bowl",
        "title": "Caribbean Jerk Salmon & Mango Recovery Bowl",
        "intent": "post_dunk_recovery",
        "intent_label": "Post-Dunk Recovery",
        "duration_min": 25,
        "macros": {"calories": 740, "protein_g": 54, "carbs_g": 82, "fats_g": 20},
        "micros": {"omega3_mg": 1400, "magnesium_mg": 160, "sodium_mg": 650, "hydration_ml": 250},
        "summary": "Yard House inspired sweet-and-spicy Jerk glazed salmon fillet over coconut-infused black beans and rice, topped with a fresh mango-avocado salsa.",
        "ingredients": [
            {"name": "Jerk-seasoned wild-caught salmon fillet", "qty": "6 oz"},
            {"name": "Brown rice (cooked)", "qty": "1.5 cups"},
            {"name": "Black beans (cooked)", "qty": "1/2 cup"},
            {"name": "Light coconut milk", "qty": "2 tbsp"},
            {"name": "Ripe mango (diced)", "qty": "1/2 cup"},
            {"name": "Avocado (cubed)", "qty": "1/2"},
            {"name": "Red onion & cilantro mix (chopped)", "qty": "4 tbsp"},
            {"name": "Lime juice", "qty": "2 tbsp"},
            {"name": "Olive oil", "qty": "1 tsp"},
        ],
        "steps": [
            "Pan-sear the jerk-seasoned salmon fillet in olive oil skin-side down for 4-5 minutes, then flip and cook for 3 more minutes.",
            "Warm the brown rice and black beans with light coconut milk and a pinch of salt.",
            "Toss together the diced mango, avocado, red onion & cilantro mix, and lime juice to create the fresh salsa.",
            "Assemble the bowl with the coconut rice and beans, top with the jerk salmon, and finish with the mango-avocado salsa.",
        ],
        "viz_palette": ["#fb923c", "#f97316", "#7c2d12"],
    },
    {
        "id": "recipe_sleep_casein_bowl",
        "title": "Golden Milk Turmeric & Toasted Pistachio Anabolic Bowl",
        "intent": "sleep_anabolic",
        "intent_label": "Sleep Anabolic",
        "duration_min": 5,
        "macros": {"calories": 340, "protein_g": 34, "carbs_g": 24, "fats_g": 12},
        "micros": {"magnesium_mg": 190, "tryptophan_mg": 340, "hydration_ml": 200},
        "summary": "Ayurvedic-inspired post-workout recovery cream. Micellar casein slow-release protein whipped with Greek yogurt, turmeric, ginger, cardamom, and toasted pistachios.",
        "ingredients": [
            {"name": "Micellar casein (vanilla)", "qty": "30 g"},
            {"name": "Greek yogurt (plain, full-fat)", "qty": "1/2 cup"},
            {"name": "Ground turmeric", "qty": "1/2 tsp"},
            {"name": "Ground ginger", "qty": "1/4 tsp"},
            {"name": "Ground cardamom", "qty": "pinch"},
            {"name": "Toasted pistachios (chopped)", "qty": "2 tbsp"},
            {"name": "Tart cherry juice", "qty": "2 tbsp"},
            {"name": "Honey or maple syrup", "qty": "1 tsp"},
        ],
        "steps": [
            "In a small mixing bowl, vigorously whisk the micellar casein into the Greek yogurt until it reaches a thick, pudding-like consistency.",
            "Fold in the turmeric, ginger, cardamom, and honey until the color is a uniform, vibrant golden yellow.",
            "Top the bowl with the toasted chopped pistachios and drizzle the tart cherry juice on top.",
            "Enjoy 60-90 minutes before bed to allow casein and tryptophan to support overnight muscle recovery and sleep.",
        ],
        "viz_palette": ["#a78bfa", "#7c3aed", "#3b0764"],
    },
    {
        "id": "recipe_endurance_overnight_oats",
        "title": "Tres Leches & Horchata Chia Overnight Oats",
        "intent": "endurance_base",
        "intent_label": "Endurance Base",
        "duration_min": 5,
        "macros": {"calories": 560, "protein_g": 30, "carbs_g": 80, "fats_g": 14},
        "micros": {"omega3_mg": 900, "magnesium_mg": 150, "sodium_mg": 230, "hydration_ml": 240},
        "summary": "Traditional Mexican flavor profiles meeting endurance athletic needs — rolled oats soaked in vanilla Horchata almond milk, cinnamon, chia seeds, topped with toasted pepitas.",
        "ingredients": [
            {"name": "Rolled oats", "qty": "3/4 cup"},
            {"name": "Chia seeds", "qty": "1.5 tbsp"},
            {"name": "Vanilla Horchata almond milk", "qty": "1 cup"},
            {"name": "Greek yogurt (plain)", "qty": "1/2 cup"},
            {"name": "Ground cinnamon", "qty": "1/2 tsp"},
            {"name": "Toasted pumpkin seeds (pepitas)", "qty": "2 tbsp"},
            {"name": "Slivered almonds", "qty": "1 tbsp"},
            {"name": "Honey", "qty": "1 tsp"},
        ],
        "steps": [
            "In a jar or airtight container, combine the rolled oats, chia seeds, cinnamon, honey, Horchata almond milk, and Greek yogurt.",
            "Stir the mixture thoroughly to ensure the chia seeds are evenly distributed, then seal and refrigerate overnight.",
            "In the morning, top the oats with the toasted pumpkin seeds (pepitas) and slivered almonds for added texture and healthy fats.",
            "Consume prior to your endurance workout for sustained, slow-release glycogen refueling.",
        ],
        "viz_palette": ["#34d399", "#059669", "#064e3b"],
    },
]


# Seeded restaurant catalogue (used by DoorDash macro filter — to be replaced by Marketplace API)
DOORDASH_SEED: List[Dict[str, Any]] = [
    {"name": "Yard House — Jerk Chicken Rice Bowl", "macros": {"protein_g": 45, "carbs_g": 75, "fats_g": 16, "calories": 620}, "intent": "post_dunk_recovery", "city_query": "Yard House Jerk Chicken"},
    {"name": "Habesha Palace — Beef Tibs & Injera", "macros": {"protein_g": 48, "carbs_g": 70, "fats_g": 22, "calories": 670}, "intent": "endurance_base", "city_query": "Habesha Palace Beef Tibs"},
    {"name": "Yard House — Poke Salad Bowl", "macros": {"protein_g": 36, "carbs_g": 48, "fats_g": 18, "calories": 500}, "intent": "fascial_hydration", "city_query": "Yard House Poke Salad"},
    {"name": "Cantina Mexicana — Grilled Chicken Fajita Bowl", "macros": {"protein_g": 52, "carbs_g": 58, "fats_g": 18, "calories": 600}, "intent": "post_dunk_recovery", "city_query": "Cantina Grilled Chicken Fajita"},
    {"name": "Kona Grill — Macadamia Nut Chicken Bowl", "macros": {"protein_g": 42, "carbs_g": 85, "fats_g": 24, "calories": 720}, "intent": "endurance_base", "city_query": "Kona Grill Macadamia Nut Chicken"},
    {"name": "Asian Ginger — Spicy Basil Chicken & Rice", "macros": {"protein_g": 38, "carbs_g": 62, "fats_g": 14, "calories": 520}, "intent": "cns_ignition", "city_query": "Asian Ginger Spicy Basil Chicken"},
    {"name": "Caribbean Grill — Escovitch Fish Filet Bowl", "macros": {"protein_g": 34, "carbs_g": 54, "fats_g": 12, "calories": 460}, "intent": "cns_ignition", "city_query": "Caribbean Grill Escovitch Fish"},
    {"name": "Ethnic Bistro — Habesha Gomen & Lentils", "macros": {"protein_g": 24, "carbs_g": 66, "fats_g": 10, "calories": 450}, "intent": "fascial_hydration", "city_query": "Ethnic Bistro Habesha Gomen"},
]


# ============================================================
# REQUEST MODELS
# ============================================================

class ScanRequest(BaseModel):
    model: str = "gemini-2.5-flash"
    image_base64: str = Field(..., min_length=3)
    hint: Optional[str] = Field(None, max_length=500)

    @field_validator("image_base64")
    @classmethod
    def image_not_huge(cls, v: str) -> str:
        if len(v) > MAX_IMAGE_BASE64_CHARS:
            raise ValueError(f"image_base64 exceeds max length ({MAX_IMAGE_BASE64_CHARS} chars); compress on client")
        return v


class ScanConfirmRequest(BaseModel):
    scan_id: str = Field(..., min_length=8, max_length=80)


class LogRequest(BaseModel):
    label: str = Field(..., min_length=1, max_length=120)
    calories: float = Field(..., ge=0, le=MEAL_MAX_CALORIES)
    protein_g: float = Field(..., ge=0, le=MEAL_MAX_PROTEIN_G)
    carbs_g: float = Field(..., ge=0, le=MEAL_MAX_CARBS_G)
    fats_g: float = Field(..., ge=0, le=MEAL_MAX_FATS_G)
    intent: Optional[str] = Field(None, max_length=64)
    source: str = Field(default="manual")
    micros: Optional[Dict[str, Any]] = None
    hydration_ml: Optional[int] = Field(
        None,
        ge=0,
        le=MEAL_MAX_HYDRATION_ML,
        description="Fluids for this meal (ml). When set, counts toward hydration for today (see consumed_totals).",
    )
    client_event_id: Optional[str] = Field(None, max_length=128)

    @field_validator("source")
    @classmethod
    def source_allowlist(cls, v: str) -> str:
        if v not in ALLOWED_LOG_SOURCES:
            raise ValueError(f"source must be one of {sorted(ALLOWED_LOG_SOURCES)}")
        return v


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
    """Photo → macro estimate. Result is **pending** until ``POST /scan/confirm`` — no XP or diary write until confirmed."""
    if req.model not in ALLOWED_MODELS:
        raise HTTPException(status_code=400, detail=f"model must be one of {sorted(ALLOWED_MODELS)}")
    if not EMERGENT_KEY:
        raise HTTPException(status_code=500, detail="EMERGENT_LLM_KEY not configured")

    provider = "gemini" if req.model.startswith("gemini") else "openai"
    session_id = f"biofuel-scan-{uuid.uuid4().hex[:10]}"

    chat = LlmChat(
        api_key=EMERGENT_KEY,
        session_id=session_id,
        system_message=SYSTEM_SCAN_PROMPT,
    ).with_model(provider, req.model)

    mime_type = "image/jpeg"
    data = req.image_base64
    if data.startswith("data:"):
        try:
            header, data = data.split(",", 1)
            mime_type = header.split(";")[0].split(":")[1]
        except Exception:
            pass
    image = ImageContent(mime_type, data)
    message = UserMessage(
        text=(req.hint or "Analyze this meal photo and return the JSON."),
        content=[image],
    )

    try:
        raw = await chat.send_message(message)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"vision provider error: {e}")

    try:
        parsed = _extract_json(raw if isinstance(raw, str) else str(raw))
    except (ValueError, json.JSONDecodeError) as e:
        raise HTTPException(status_code=502, detail=f"could not parse vision response: {e}")

    intent = parsed.get("athletic_intent", "post_dunk_recovery")
    if intent not in ATHLETIC_INTENTS:
        intent = "post_dunk_recovery"

    scan_id = f"scan_{uuid.uuid4().hex[:10]}"
    now = datetime.now(timezone.utc).isoformat()

    mc = parsed.get("micros") if isinstance(parsed.get("micros"), dict) else {}
    hyd_micro = _clamp_meal_int(mc.get("hydration_ml"), MEAL_MAX_HYDRATION_ML)
    mc = {**mc, "hydration_ml": hyd_micro}

    out = {
        "scan_id": scan_id,
        "model": req.model,
        "label": str(parsed.get("label", "Meal"))[:80],
        "calories": _clamp_meal_int(parsed.get("calories"), MEAL_MAX_CALORIES),
        "protein_g": _clamp_meal_int(parsed.get("protein_g"), MEAL_MAX_PROTEIN_G),
        "carbs_g": _clamp_meal_int(parsed.get("carbs_g"), MEAL_MAX_CARBS_G),
        "fats_g": _clamp_meal_int(parsed.get("fats_g"), MEAL_MAX_FATS_G),
        "micros": mc,
        "athletic_intent": intent,
        "nutri_shards_awarded": 0,
        "pending_confirmation": True,
        "scanned_at": now,
    }

    await db.biofuel_scans.insert_one({
        **out,
        "user_id": user.user_id,
        "confirmed": False,
    })

    return out


@router.post("/scan/confirm")
async def confirm_scan(body: ScanConfirmRequest, user: User = Depends(get_current_user)):
    """Confirm a pending vision estimate — awards Nutri-Shards (XP) once and appends today's log (idempotent)."""
    since = datetime.now(timezone.utc) - timedelta(hours=1)
    recent = await db.biofuel_scans.count_documents({
        "user_id": user.user_id,
        "confirmed": True,
        "confirmed_at_ts": {"$gte": since},
    })
    if recent >= SCAN_CONFIRM_RATE_LIMIT_PER_HOUR:
        raise HTTPException(status_code=429, detail="Too many scan confirmations this hour — try again later.")

    doc = await db.biofuel_scans.find_one({"scan_id": body.scan_id, "user_id": user.user_id})
    if not doc:
        raise HTTPException(status_code=404, detail="scan not found")
    if doc.get("confirmed"):
        return {"ok": True, "already_confirmed": True, "scan_id": body.scan_id}

    res = await db.biofuel_scans.update_one(
        {"scan_id": body.scan_id, "user_id": user.user_id, "confirmed": {"$ne": True}},
        {"$set": {"confirmed": True, "confirmed_at": datetime.now(timezone.utc).isoformat(), "confirmed_at_ts": datetime.now(timezone.utc)}},
    )
    if res.modified_count != 1:
        return {"ok": True, "already_confirmed": True, "scan_id": body.scan_id}

    await db.users.update_one({"user_id": user.user_id}, {"$inc": {"xp": NUTRI_SHARDS_PER_SCAN}})

    intent = doc.get("athletic_intent", "post_dunk_recovery")
    micros = doc.get("micros") or {}
    if isinstance(micros, dict) and "hydration_ml" in micros:
        micros = {
            **micros,
            "hydration_ml": _clamp_meal_int(micros.get("hydration_ml"), MEAL_MAX_HYDRATION_ML),
        }
    await _append_log(user.user_id, {
        "label": doc["label"],
        "calories": doc["calories"],
        "protein_g": doc["protein_g"],
        "carbs_g": doc["carbs_g"],
        "fats_g": doc["fats_g"],
        "intent": intent,
        "source": "scan",
        "scan_id": body.scan_id,
        "micros": micros,
    })

    return {
        "ok": True,
        "nutri_shards_awarded": NUTRI_SHARDS_PER_SCAN,
        "scan_id": body.scan_id,
        "pending_confirmation": False,
    }


# ============================================================
# RECIPES (3D Cookbook)
# ============================================================

@router.get("/recipes")
async def list_recipes(intent: Optional[str] = None, user: Optional[User] = Depends(get_current_user_optional)):
    items = RECIPES if not intent else [r for r in RECIPES if r["intent"] == intent]
    if user:
        items = _filter_recipes_for_user(items, user)
    return {
        "intents": [{"id": k, "label": v} for k, v in ATHLETIC_INTENTS.items()],
        "nutrition_filters_active": bool(user and _avoid_tokens(user)),
        "recipes": [{
            "id": r["id"], "title": r["title"], "intent": r["intent"],
            "intent_label": r["intent_label"], "duration_min": r["duration_min"],
            "macros": r["macros"], "summary": r["summary"], "viz_palette": r["viz_palette"],
        } for r in items],
    }


@router.get("/recipes/{recipe_id}")
async def get_recipe(recipe_id: str, user: Optional[User] = Depends(get_current_user_optional)):
    r = next((x for x in RECIPES if x["id"] == recipe_id), None)
    if not r:
        raise HTTPException(status_code=404, detail="Recipe not found")
    if user and r not in _filter_recipes_for_user([r], user):
        raise HTTPException(status_code=404, detail="Recipe not available for your allergy / diet profile")
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
    entry = req.model_dump(exclude_none=True)
    day = _today_key()
    if req.client_event_id:
        dup = await db.biofuel_logs.find_one(
            {"user_id": user.user_id, "day": day, "entries.client_event_id": req.client_event_id},
            {"_id": 1},
        )
        if dup:
            return {"ok": True, "day": day, "deduped": True}
    await _append_log(user.user_id, entry)
    return {"ok": True, "day": day}


def _consumed_totals(entries: List[Dict[str, Any]]) -> Dict[str, int]:
    hyd = 0
    for e in entries:
        m = e.get("micros") if isinstance(e.get("micros"), dict) else {}
        mh = int(m.get("hydration_ml") or 0)
        th = int(e.get("hydration_ml") or 0)
        # Prefer explicit top-level hydration_ml when present (manual / partner logs);
        # otherwise use vision micros estimate — avoids double-counting the same meal.
        hyd += th if th else mh
    return {
        "calories": int(sum((e.get("calories") or 0) for e in entries)),
        "protein_g": int(sum((e.get("protein_g") or 0) for e in entries)),
        "carbs_g": int(sum((e.get("carbs_g") or 0) for e in entries)),
        "fats_g": int(sum((e.get("fats_g") or 0) for e in entries)),
        "hydration_ml": hyd,
    }


def _athlete_weight_kg(user: User) -> float:
    w = getattr(user, "weight_kg", None)
    if w is not None:
        try:
            wf = float(w)
            if 30.0 <= wf <= 250.0:
                return wf
        except (TypeError, ValueError):
            pass
    return 75.0


def _nutrition_target_meta(user: User) -> Dict[str, Any]:
    w = getattr(user, "weight_kg", None)
    try:
        has = w is not None and 30.0 <= float(w) <= 250.0
    except (TypeError, ValueError):
        has = False
    if has:
        return {
            "targets_confidence": "personalized",
            "weight_kg_source": "profile",
            "assumption_note": None,
        }
    return {
        "targets_confidence": "default_assumption",
        "weight_kg_source": "default_75kg",
        "assumption_note": "Profile weight not set — using 75 kg reference until you add weight_kg, goal, and preferences.",
    }


def _today_intent(user: User) -> str:
    # Heuristic: tie to sport. Will be overridden by AI Coach in a later pass.
    return "post_dunk_recovery" if user.sport in ("basketball", "football") else "endurance_base"


@router.get("/today")
async def get_today(user: User = Depends(get_current_user)):
    weight_kg = _athlete_weight_kg(user)
    meta = _nutrition_target_meta(user)
    intent = _today_intent(user)
    target = nasm_macro_target(weight_kg, user.sport, intent)
    log = await db.biofuel_logs.find_one({"user_id": user.user_id, "day": _today_key()}, {"_id": 0}) or {}
    entries = log.get("entries", [])
    consumed = _consumed_totals(entries)
    macro_keys = ("calories", "protein_g", "carbs_g", "fats_g")
    deltas = {k: max(0, target[k] - consumed.get(k, 0)) for k in macro_keys}
    pct = {
        k: min(100, round(100 * consumed.get(k, 0) / target[k])) if target[k] else 0
        for k in macro_keys
    }
    hyd_t = int(target.get("hydration_ml") or 0) or 1
    hyd_c = int(consumed.get("hydration_ml") or 0)
    pct["hydration_ml"] = min(100, round(100 * hyd_c / hyd_t)) if hyd_t else 0
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
        **meta,
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
            "message": "You're ahead on carbs today — pairing the next snack with a lean protein helps steady energy.",
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
    if not _filter_recipes_for_user([r], user):
        raise HTTPException(status_code=400, detail="Recipe conflicts with your allergy / diet profile")
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
        "policy_note": (
            "Opens external grocery ordering (real-world food). Not an in-app digital purchase — separate from App Store IAP."
        ),
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

    macro_fit = [m for m in pool if fit(m)]
    base = macro_fit if macro_fit else pool[: min(3, len(pool))]
    tok = _avoid_tokens(user)
    if tok:
        safe = [m for m in base if not _violates_avoid(str(m.get("name", "")), tok)]
        if not safe:
            return {
                "intent": intent,
                "intent_label": ATHLETIC_INTENTS.get(intent, intent),
                "remaining_today": today["remaining"],
                "min_protein_g": min_p,
                "max_calories": remaining_cal,
                "matches": [],
                "no_safe_matches": True,
                "message": (
                    "No seeded options pass your allergy / diet filters with the current macro window. "
                    "Adjust intent, log a custom meal, or order manually with your clinician-approved substitutions."
                ),
                "nutrition_filters_active": True,
                "note": "Awaiting DoorDash Marketplace partner credentials for in-app macro-aware ordering.",
                "policy_note": (
                    "Opens external restaurant/meal delivery search (real-world food). Not an in-app digital purchase — separate from App Store IAP."
                ),
            }
        matches = safe
    else:
        matches = base

    for m in matches:
        m["deep_link"] = f"https://www.doordash.com/search/store/?query={urllib.parse.quote(m['city_query'])}"
    return {
        "intent": intent,
        "intent_label": ATHLETIC_INTENTS.get(intent, intent),
        "remaining_today": today["remaining"],
        "min_protein_g": min_p,
        "max_calories": remaining_cal,
        "matches": matches,
        "no_safe_matches": False,
        "nutrition_filters_active": bool(tok),
        "note": "Awaiting DoorDash Marketplace partner credentials for in-app macro-aware ordering.",
        "policy_note": (
            "Opens external restaurant/meal delivery search (real-world food). Not an in-app digital purchase — separate from App Store IAP."
        ),
    }
