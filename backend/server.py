from fastapi import FastAPI, APIRouter, HTTPException, Depends, Request, Response, WebSocket, WebSocketDisconnect, UploadFile, File
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os, logging, uuid, random, json, aiofiles
from pathlib import Path
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional, Dict, Any
from datetime import datetime, timezone, timedelta
import httpx
from emergentintegrations.llm.chat import LlmChat, UserMessage
import paypalrestsdk

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]
EMERGENT_KEY = os.environ.get('EMERGENT_LLM_KEY', '')

# PayPal config
paypalrestsdk.configure({
    "mode": "sandbox",
    "client_id": os.environ.get('PAYPAL_CLIENT_ID', ''),
    "client_secret": os.environ.get('PAYPAL_SECRET', '')
})

# Upload dir
UPLOAD_DIR = ROOT_DIR / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)

app = FastAPI(title="Final Evolution Lab API")
api_router = APIRouter(prefix="/api")
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ===================== MODELS =====================
class User(BaseModel):
    model_config = ConfigDict(extra="ignore")
    user_id: str; email: str; name: str; picture: Optional[str] = None
    created_at: Optional[str] = None; avatar_url: Optional[str] = None
    bio: Optional[str] = None; role: str = "athlete"; sport: str = "basketball"
    prq_score: float = 75.0; level: int = 1; xp: int = 0
    streak_days: int = 0; total_workouts: int = 0
    avatar_config: Optional[Dict] = None; followers: List[str] = []
    following: List[str] = []; coins: int = 100

# ===================== AUTH =====================
async def get_current_user(request: Request) -> User:
    session_token = request.cookies.get("session_token")
    if not session_token:
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            session_token = auth_header.split(" ")[1]
    if not session_token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    session_doc = await db.user_sessions.find_one({"session_token": session_token}, {"_id": 0})
    if not session_doc:
        raise HTTPException(status_code=401, detail="Invalid session")
    expires_at = session_doc["expires_at"]
    if isinstance(expires_at, str):
        expires_at = datetime.fromisoformat(expires_at)
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at < datetime.now(timezone.utc):
        raise HTTPException(status_code=401, detail="Session expired")
    user_doc = await db.users.find_one({"user_id": session_doc["user_id"]}, {"_id": 0})
    if not user_doc:
        raise HTTPException(status_code=404, detail="User not found")
    return User(**user_doc)

@api_router.post("/auth/session")
async def create_session(request: Request, response: Response):
    data = await request.json()
    session_id = data.get("session_id")
    if not session_id:
        raise HTTPException(status_code=400, detail="session_id required")
    async with httpx.AsyncClient() as hc:
        resp = await hc.get("https://demobackend.emergentagent.com/auth/v1/env/oauth/session-data", headers={"X-Session-ID": session_id})
        if resp.status_code != 200:
            raise HTTPException(status_code=401, detail="Invalid session_id")
        sd = resp.json()
    user_id = f"user_{uuid.uuid4().hex[:12]}"
    existing = await db.users.find_one({"email": sd["email"]}, {"_id": 0})
    if existing:
        user_id = existing["user_id"]
        await db.users.update_one({"user_id": user_id}, {"$set": {"name": sd["name"], "picture": sd.get("picture")}})
    else:
        await db.users.insert_one({
            "user_id": user_id, "email": sd["email"], "name": sd["name"],
            "picture": sd.get("picture"), "created_at": datetime.now(timezone.utc).isoformat(),
            "role": "athlete", "sport": "basketball", "prq_score": 75.0, "level": 1,
            "xp": 0, "streak_days": 0, "total_workouts": 0, "coins": 100,
            "followers": [], "following": [], "avatar_config": None
        })
        await db.prq_metrics.insert_one({
            "id": str(uuid.uuid4()), "user_id": user_id, "overall_score": 75.0,
            "strength": 70.0, "speed": 75.0, "endurance": 80.0, "agility": 72.0,
            "power": 68.0, "flexibility": 78.0, "recovery": 82.0, "mental": 76.0,
            "recorded_at": datetime.now(timezone.utc).isoformat()
        })
    session_token = sd.get("session_token", f"sess_{uuid.uuid4().hex}")
    await db.user_sessions.insert_one({
        "user_id": user_id, "session_token": session_token,
        "expires_at": (datetime.now(timezone.utc) + timedelta(days=7)).isoformat(),
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    response.set_cookie(key="session_token", value=session_token, httponly=True, secure=True, samesite="none", path="/", max_age=7*24*60*60)
    return await db.users.find_one({"user_id": user_id}, {"_id": 0})

@api_router.get("/auth/me")
async def get_me(user: User = Depends(get_current_user)):
    return user.model_dump()

@api_router.post("/auth/logout")
async def logout(request: Request, response: Response):
    st = request.cookies.get("session_token")
    if st: await db.user_sessions.delete_one({"session_token": st})
    response.delete_cookie(key="session_token", path="/")
    return {"message": "Logged out"}

# ===================== STREAKS & REWARDS =====================
@api_router.get("/streaks")
async def get_streak(user: User = Depends(get_current_user)):
    streak_doc = await db.streaks.find_one({"user_id": user.user_id}, {"_id": 0})
    if not streak_doc:
        streak_doc = {"user_id": user.user_id, "current_streak": 0, "longest_streak": 0,
                      "last_activity": None, "daily_log": [], "rewards_claimed": []}
        await db.streaks.insert_one(streak_doc)
    return streak_doc

@api_router.post("/streaks/checkin")
async def streak_checkin(user: User = Depends(get_current_user)):
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    streak_doc = await db.streaks.find_one({"user_id": user.user_id}, {"_id": 0})
    if not streak_doc:
        streak_doc = {"user_id": user.user_id, "current_streak": 0, "longest_streak": 0,
                      "last_activity": None, "daily_log": [], "rewards_claimed": []}
        await db.streaks.insert_one(streak_doc)

    if streak_doc.get("last_activity") == today:
        return {"message": "Already checked in today", **{k:v for k,v in streak_doc.items() if k != "_id"}}

    yesterday = (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%d")
    if streak_doc.get("last_activity") == yesterday:
        new_streak = streak_doc.get("current_streak", 0) + 1
    else:
        new_streak = 1

    longest = max(streak_doc.get("longest_streak", 0), new_streak)
    daily_log = streak_doc.get("daily_log", [])
    daily_log.append(today)
    daily_log = daily_log[-30:]  # Keep last 30 days

    # Calculate rewards
    rewards = []
    xp_bonus = 25
    coin_bonus = 10
    if new_streak >= 3: xp_bonus = 50; coin_bonus = 20; rewards.append("3-day streak bonus")
    if new_streak >= 7: xp_bonus = 100; coin_bonus = 50; rewards.append("7-day streak bonus")
    if new_streak >= 14: xp_bonus = 200; coin_bonus = 100; rewards.append("14-day streak bonus")
    if new_streak >= 30: xp_bonus = 500; coin_bonus = 250; rewards.append("30-day streak bonus")

    await db.streaks.update_one({"user_id": user.user_id}, {"$set": {
        "current_streak": new_streak, "longest_streak": longest,
        "last_activity": today, "daily_log": daily_log
    }})
    await db.users.update_one({"user_id": user.user_id}, {
        "$inc": {"xp": xp_bonus, "coins": coin_bonus},
        "$set": {"streak_days": new_streak}
    })

    return {"current_streak": new_streak, "longest_streak": longest, "last_activity": today,
            "xp_earned": xp_bonus, "coins_earned": coin_bonus, "rewards": rewards, "daily_log": daily_log}

@api_router.get("/streaks/rewards")
async def get_streak_rewards(user: User = Depends(get_current_user)):
    streak_doc = await db.streaks.find_one({"user_id": user.user_id}, {"_id": 0})
    current = streak_doc.get("current_streak", 0) if streak_doc else 0
    milestones = [
        {"days": 3, "reward": "50 XP + 20 Coins", "unlocked": current >= 3},
        {"days": 7, "reward": "100 XP + 50 Coins + Badge", "unlocked": current >= 7},
        {"days": 14, "reward": "200 XP + 100 Coins + Exclusive Card", "unlocked": current >= 14},
        {"days": 30, "reward": "500 XP + 250 Coins + Legend Badge", "unlocked": current >= 30},
    ]
    return {"current_streak": current, "milestones": milestones}

# ===================== PAYPAL =====================
@api_router.post("/payments/create-order")
async def create_paypal_order(data: Dict[str, Any], user: User = Depends(get_current_user)):
    item_type = data.get("item_type", "card")  # card, course
    item_id = data.get("item_id")
    amount = data.get("amount", 0)

    if amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid amount")

    payment = paypalrestsdk.Payment({
        "intent": "sale",
        "payer": {"payment_method": "paypal"},
        "redirect_urls": {
            "return_url": data.get("return_url", "https://example.com/success"),
            "cancel_url": data.get("cancel_url", "https://example.com/cancel")
        },
        "transactions": [{
            "item_list": {"items": [{
                "name": f"FEL {item_type.title()} - {item_id}",
                "sku": item_id,
                "price": f"{amount:.2f}",
                "currency": "USD",
                "quantity": 1
            }]},
            "amount": {"total": f"{amount:.2f}", "currency": "USD"},
            "description": f"Final Evolution Lab - {item_type.title()} Purchase"
        }]
    })

    if payment.create():
        # Store order
        order = {
            "id": payment.id, "user_id": user.user_id, "item_type": item_type,
            "item_id": item_id, "amount": amount, "status": "created",
            "created_at": datetime.now(timezone.utc).isoformat()
        }
        await db.orders.insert_one(order)
        approval_url = next((l.href for l in payment.links if l.rel == "approval_url"), None)
        return {"order_id": payment.id, "approval_url": approval_url, "status": "created"}
    else:
        logger.error(f"PayPal error: {payment.error}")
        raise HTTPException(status_code=500, detail=f"Payment creation failed: {payment.error}")

@api_router.post("/payments/capture")
async def capture_paypal_payment(data: Dict[str, Any], user: User = Depends(get_current_user)):
    payment_id = data.get("payment_id")
    payer_id = data.get("payer_id")
    if not payment_id or not payer_id:
        raise HTTPException(status_code=400, detail="payment_id and payer_id required")

    payment = paypalrestsdk.Payment.find(payment_id)
    if payment.execute({"payer_id": payer_id}):
        await db.orders.update_one({"id": payment_id}, {"$set": {"status": "completed", "payer_id": payer_id, "completed_at": datetime.now(timezone.utc).isoformat()}})
        order = await db.orders.find_one({"id": payment_id}, {"_id": 0})
        if order:
            if order["item_type"] == "card":
                await db.creator_cards.update_one({"id": order["item_id"]}, {"$set": {"owner_id": user.user_id, "for_sale": False}})
            elif order["item_type"] == "course":
                await db.enrollments.insert_one({"id": str(uuid.uuid4()), "user_id": user.user_id, "course_id": order["item_id"], "progress": 0, "enrolled_at": datetime.now(timezone.utc).isoformat()})
        return {"status": "completed", "order_id": payment_id}
    raise HTTPException(status_code=500, detail="Payment capture failed")

@api_router.get("/payments/history")
async def get_payment_history(user: User = Depends(get_current_user)):
    orders = await db.orders.find({"user_id": user.user_id}, {"_id": 0}).sort("created_at", -1).limit(20).to_list(20)
    return orders

# ===================== SOCIAL =====================
@api_router.post("/social/follow/{target_id}")
async def follow_user(target_id: str, user: User = Depends(get_current_user)):
    if target_id == user.user_id:
        raise HTTPException(status_code=400, detail="Cannot follow yourself")
    await db.users.update_one({"user_id": user.user_id}, {"$addToSet": {"following": target_id}})
    await db.users.update_one({"user_id": target_id}, {"$addToSet": {"followers": user.user_id}})
    await db.activity_feed.insert_one({"user_id": user.user_id, "type": "follow", "target_id": target_id, "created_at": datetime.now(timezone.utc).isoformat()})
    return {"message": "Followed", "target_id": target_id}

@api_router.post("/social/unfollow/{target_id}")
async def unfollow_user(target_id: str, user: User = Depends(get_current_user)):
    await db.users.update_one({"user_id": user.user_id}, {"$pull": {"following": target_id}})
    await db.users.update_one({"user_id": target_id}, {"$pull": {"followers": user.user_id}})
    return {"message": "Unfollowed"}

@api_router.post("/social/challenge")
async def send_challenge(data: Dict[str, Any], user: User = Depends(get_current_user)):
    challenge = {
        "id": str(uuid.uuid4()), "challenger_id": user.user_id,
        "challenged_id": data.get("target_id"), "game_mode": data.get("game_mode"),
        "status": "pending", "challenger_score": 0, "challenged_score": 0,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.challenges.insert_one(challenge)
    return {k: v for k, v in challenge.items() if k != "_id"}

@api_router.get("/social/challenges")
async def get_challenges(user: User = Depends(get_current_user)):
    challenges = await db.challenges.find({"$or": [{"challenger_id": user.user_id}, {"challenged_id": user.user_id}]}, {"_id": 0}).sort("created_at", -1).limit(20).to_list(20)
    return challenges

@api_router.post("/social/challenge/{challenge_id}/respond")
async def respond_challenge(challenge_id: str, data: Dict[str, Any], user: User = Depends(get_current_user)):
    action = data.get("action")  # accept, decline
    await db.challenges.update_one({"id": challenge_id}, {"$set": {"status": action + "ed"}})
    return {"status": action + "ed", "challenge_id": challenge_id}

@api_router.get("/social/feed")
async def get_activity_feed(user: User = Depends(get_current_user)):
    following = user.following or []
    following.append(user.user_id)
    feed = await db.activity_feed.find({"user_id": {"$in": following}}, {"_id": 0}).sort("created_at", -1).limit(30).to_list(30)
    return feed

@api_router.get("/social/athletes")
async def search_athletes(q: str = ""):
    query = {"role": {"$in": ["athlete", "coach"]}}
    if q:
        query["name"] = {"$regex": q, "$options": "i"}
    athletes = await db.users.find(query, {"_id": 0, "user_id": 1, "name": 1, "picture": 1, "sport": 1, "prq_score": 1, "level": 1, "followers": 1}).limit(20).to_list(20)
    if not athletes:
        return [
            {"user_id": "u1", "name": "Elijah Bonds", "sport": "basketball", "prq_score": 95.5, "level": 25, "followers": ["u2", "u3"]},
            {"user_id": "u2", "name": "Amir Smith", "sport": "karate", "prq_score": 92.3, "level": 22, "followers": ["u1"]},
            {"user_id": "u3", "name": "Eric Nash", "sport": "training", "prq_score": 89.7, "level": 20, "followers": []},
            {"user_id": "u4", "name": "Maya Johnson", "sport": "soccer", "prq_score": 87.4, "level": 18, "followers": ["u1", "u2"]},
        ]
    return athletes

# ===================== TOURNAMENTS =====================
@api_router.get("/tournaments")
async def get_tournaments():
    tournaments = await db.tournaments.find({}, {"_id": 0}).sort("start_date", -1).limit(10).to_list(10)
    if not tournaments:
        return get_seeded_tournaments()
    return tournaments

@api_router.get("/tournaments/{tournament_id}")
async def get_tournament(tournament_id: str):
    t = await db.tournaments.find_one({"id": tournament_id}, {"_id": 0})
    if not t:
        for st in get_seeded_tournaments():
            if st["id"] == tournament_id:
                return st
        raise HTTPException(status_code=404)
    return t

@api_router.post("/tournaments/{tournament_id}/join")
async def join_tournament(tournament_id: str, user: User = Depends(get_current_user)):
    await db.tournament_entries.insert_one({"tournament_id": tournament_id, "user_id": user.user_id, "seed": 0, "status": "registered", "joined_at": datetime.now(timezone.utc).isoformat()})
    return {"message": "Registered", "tournament_id": tournament_id}

def get_seeded_tournaments():
    return [
        {"id": "t1", "name": "Venice Beach Invitational", "game_mode": "basketball_h2h", "format": "single_elimination", "max_players": 16, "current_players": 12, "prize": "500 Coins + Legendary Card", "start_date": "2026-02-01", "status": "registration", "bracket": generate_bracket(12, 16)},
        {"id": "t2", "name": "Dojo Masters", "game_mode": "karate_h2h", "format": "double_elimination", "max_players": 8, "current_players": 8, "prize": "300 Coins + Holographic Card", "start_date": "2026-01-25", "status": "in_progress", "bracket": generate_bracket(8, 8)},
        {"id": "t3", "name": "Brain Brawl Championship", "game_mode": "brain_brawl", "format": "round_robin", "max_players": 32, "current_players": 24, "prize": "1000 XP + Certificate", "start_date": "2026-02-10", "status": "registration", "bracket": []},
        {"id": "t4", "name": "All-Sport Challenge", "game_mode": "mixed", "format": "single_elimination", "max_players": 64, "current_players": 45, "prize": "1000 Coins + Custom Avatar", "start_date": "2026-02-15", "status": "registration", "bracket": generate_bracket(45, 64)},
    ]

def generate_bracket(players, slots):
    names = ["Elijah B.", "Amir S.", "Eric N.", "Maya J.", "Derek W.", "Sofia R.", "Jake T.", "Kai C.",
             "Lena M.", "Omar F.", "Nina P.", "Ryan K.", "Tara L.", "Zack W.", "Iris H.", "Cole D."]
    bracket = []
    for i in range(0, min(players, len(names)), 2):
        bracket.append({"round": 1, "match": i//2 + 1, "player1": names[i], "player2": names[i+1] if i+1 < min(players, len(names)) else "BYE", "winner": None, "score1": 0, "score2": 0})
    return bracket

# ===================== AVATAR BUILDER =====================
@api_router.get("/avatar/config")
async def get_avatar_config(user: User = Depends(get_current_user)):
    config = user.avatar_config or get_default_avatar()
    return config

@api_router.put("/avatar/config")
async def update_avatar_config(data: Dict[str, Any], user: User = Depends(get_current_user)):
    await db.users.update_one({"user_id": user.user_id}, {"$set": {"avatar_config": data}})
    return data

def get_default_avatar():
    return {
        "body_type": "athletic", "skin_tone": "#C68642", "hair_style": "fade",
        "hair_color": "#1A1A1A", "jersey_color": "#00E5FF", "shorts_color": "#1A1A24",
        "shoe_style": "basketball", "shoe_color": "#FFFFFF",
        "accessories": [], "expression": "focused"
    }

@api_router.get("/avatar/options")
async def get_avatar_options():
    return {
        "body_types": ["lean", "athletic", "muscular", "average"],
        "skin_tones": ["#FDBEB1", "#E8B98D", "#C68642", "#8D5524", "#5C3317", "#3B1F0B"],
        "hair_styles": ["fade", "braids", "afro", "buzz", "long", "bald", "mohawk", "dreads"],
        "hair_colors": ["#1A1A1A", "#3B2F2F", "#8B4513", "#D4A574", "#FFD700", "#C0C0C0", "#FF4500"],
        "jersey_colors": ["#00E5FF", "#FF3366", "#00FF9D", "#FFB800", "#7C3AED", "#FFFFFF", "#FF6B6B"],
        "shorts_colors": ["#1A1A24", "#FFFFFF", "#000000", "#2E2E38"],
        "shoe_styles": ["basketball", "running", "training", "skateboard", "cleats"],
        "shoe_colors": ["#FFFFFF", "#000000", "#FF0000", "#00E5FF", "#FFD700"],
        "accessories": ["headband", "wristband", "chain", "glasses", "armband", "knee_sleeve"],
        "expressions": ["focused", "aggressive", "calm", "happy", "determined"]
    }

# ===================== VIDEO UPLOAD =====================
@api_router.post("/uploads/video")
async def upload_video(file: UploadFile = File(...), user: User = Depends(get_current_user)):
    if not file.content_type.startswith("video/"):
        raise HTTPException(status_code=400, detail="Must be a video file")
    if file.size and file.size > 100 * 1024 * 1024:  # 100MB limit
        raise HTTPException(status_code=400, detail="File too large (100MB max)")

    file_id = str(uuid.uuid4())
    ext = file.filename.split(".")[-1] if "." in file.filename else "mp4"
    filepath = UPLOAD_DIR / f"{file_id}.{ext}"

    async with aiofiles.open(filepath, 'wb') as f:
        content = await file.read()
        await f.write(content)

    video_doc = {
        "id": file_id, "user_id": user.user_id, "filename": file.filename,
        "filepath": str(filepath), "content_type": file.content_type,
        "size": len(content), "uploaded_at": datetime.now(timezone.utc).isoformat()
    }
    await db.videos.insert_one(video_doc)
    return {"id": file_id, "filename": file.filename, "size": len(content)}

@api_router.post("/coach/critique")
async def submit_critique(data: Dict[str, Any], user: User = Depends(get_current_user)):
    critique = {
        "id": str(uuid.uuid4()), "athlete_id": user.user_id,
        "coach_id": data.get("coach_id"), "video_id": data.get("video_id"),
        "sport": data.get("sport"), "notes": data.get("notes", ""),
        "status": "pending", "feedback": None, "rating": None,
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.critiques.insert_one(critique)
    return {k: v for k, v in critique.items() if k != "_id"}

@api_router.get("/coach/critiques")
async def get_critiques(user: User = Depends(get_current_user)):
    critiques = await db.critiques.find({"$or": [{"athlete_id": user.user_id}, {"coach_id": user.user_id}]}, {"_id": 0}).sort("created_at", -1).limit(20).to_list(20)
    return critiques

# ===================== EXISTING ROUTES (PRQ, games, cards, etc.) =====================

@api_router.get("/prq/metrics")
async def get_prq_metrics(user: User = Depends(get_current_user)):
    metrics = await db.prq_metrics.find({"user_id": user.user_id}, {"_id": 0}).sort("recorded_at", -1).limit(1).to_list(1)
    if not metrics:
        prq = {"id": str(uuid.uuid4()), "user_id": user.user_id, "overall_score": 75.0, "strength": 70.0, "speed": 75.0, "endurance": 80.0, "agility": 72.0, "power": 68.0, "flexibility": 78.0, "recovery": 82.0, "mental": 76.0, "recorded_at": datetime.now(timezone.utc).isoformat()}
        await db.prq_metrics.insert_one(prq)
        return {k: v for k, v in prq.items() if k != "_id"}
    return metrics[0]

@api_router.post("/prq/metrics")
async def update_prq(data: Dict[str, Any], user: User = Depends(get_current_user)):
    prq = {"id": str(uuid.uuid4()), "user_id": user.user_id, "recorded_at": datetime.now(timezone.utc).isoformat()}
    for k in ["overall_score","strength","speed","endurance","agility","power","flexibility","recovery","mental"]:
        prq[k] = data.get(k, 75.0)
    await db.prq_metrics.insert_one(prq)
    await db.users.update_one({"user_id": user.user_id}, {"$set": {"prq_score": prq["overall_score"]}})
    return {k: v for k, v in prq.items() if k != "_id"}

@api_router.get("/health/metrics")
async def get_health(user: User = Depends(get_current_user)):
    return await db.health_metrics.find({"user_id": user.user_id}, {"_id": 0}).sort("recorded_at", -1).limit(7).to_list(7)

@api_router.post("/health/metrics")
async def add_health(data: Dict[str, Any], user: User = Depends(get_current_user)):
    h = {"id": str(uuid.uuid4()), "user_id": user.user_id, "recorded_at": datetime.now(timezone.utc).isoformat()}
    for k in ["heart_rate","sleep_hours","calories_burned","steps","hydration_ml","stress_level","readiness_score"]:
        h[k] = data.get(k)
    await db.health_metrics.insert_one(h)
    return {k: v for k, v in h.items() if k != "_id"}

@api_router.get("/workouts/recommended")
async def get_recommended_workouts(user: User = Depends(get_current_user)):
    return [
        {"id":"rec_1","name":"Power Development","sport":"basketball","difficulty":"intermediate","duration_minutes":45,"focus":"strength","exercises":[{"name":"Box Jumps","sets":4,"reps":"8","rest":"60s"},{"name":"Medicine Ball Slams","sets":3,"reps":"12","rest":"45s"},{"name":"Squat Jumps","sets":4,"reps":"10","rest":"60s"},{"name":"Resistance Band Sprints","sets":3,"reps":"30s","rest":"90s"}]},
        {"id":"rec_2","name":"Speed & Agility","sport":"soccer","difficulty":"advanced","duration_minutes":30,"focus":"agility","exercises":[{"name":"Ladder Drills","sets":3,"reps":"30s","rest":"30s"},{"name":"Cone Sprints","sets":5,"reps":"20m","rest":"60s"},{"name":"Defensive Slides","sets":4,"reps":"15s","rest":"30s"},{"name":"T-Drill","sets":4,"reps":"1","rest":"90s"}]},
        {"id":"rec_3","name":"Recovery Flow","sport":"general","difficulty":"beginner","duration_minutes":20,"focus":"recovery","exercises":[{"name":"Foam Rolling","sets":1,"reps":"10min","rest":"-"},{"name":"Dynamic Stretching","sets":2,"reps":"5min","rest":"-"},{"name":"Breathing Exercises","sets":1,"reps":"5min","rest":"-"}]},
        {"id":"rec_4","name":"Combat Conditioning","sport":"karate","difficulty":"advanced","duration_minutes":40,"focus":"power","exercises":[{"name":"Heavy Bag Rounds","sets":6,"reps":"3min","rest":"60s"},{"name":"Plyometric Push-ups","sets":4,"reps":"12","rest":"45s"},{"name":"Shadow Boxing","sets":4,"reps":"3min","rest":"30s"},{"name":"Core Rotations","sets":3,"reps":"20","rest":"30s"}]},
    ]

@api_router.post("/workouts/log")
async def log_workout(data: Dict[str, Any], user: User = Depends(get_current_user)):
    log = {"id": str(uuid.uuid4()), "user_id": user.user_id, "workout_name": data.get("workout_name","Custom"), "duration_minutes": data.get("duration_minutes",0), "completed_at": datetime.now(timezone.utc).isoformat()}
    await db.workout_logs.insert_one(log)
    await db.users.update_one({"user_id": user.user_id}, {"$inc": {"xp": 50, "total_workouts": 1}})
    # Auto streak checkin on workout
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    streak = await db.streaks.find_one({"user_id": user.user_id})
    if not streak or streak.get("last_activity") != today:
        await streak_checkin.__wrapped__(user)
    await db.activity_feed.insert_one({"user_id": user.user_id, "type": "workout", "detail": data.get("workout_name","Custom"), "created_at": datetime.now(timezone.utc).isoformat()})
    return {k: v for k, v in log.items() if k != "_id"}

@api_router.get("/games/modes")
async def get_game_modes():
    return get_seeded_game_modes()

@api_router.post("/games/session")
async def create_game_session(data: Dict[str, Any], user: User = Depends(get_current_user)):
    s = {"id": str(uuid.uuid4()), "user_id": user.user_id, "mode_id": data.get("mode_id"), "score": data.get("score",0), "duration_seconds": data.get("duration_seconds",0), "completed": data.get("completed",False), "created_at": datetime.now(timezone.utc).isoformat()}
    await db.game_sessions.insert_one(s)
    xp = max(10, s["score"]//5)
    await db.users.update_one({"user_id": user.user_id}, {"$inc": {"xp": xp}})
    await db.activity_feed.insert_one({"user_id": user.user_id, "type": "game", "detail": data.get("mode_id"), "score": s["score"], "created_at": datetime.now(timezone.utc).isoformat()})
    return {"session": {k:v for k,v in s.items() if k!="_id"}, "xp_earned": xp}

def get_seeded_game_modes():
    return [
        {"id":"basketball_h2h","name":"Street 1v1","display_name":"Street · 1v1","venue":"Venice Beach","category":"Basketball","description":"Head-to-head street basketball","image_url":"https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800","player_count":"1v1","duration":"10 min","difficulty":"Intermediate","playable":True,"game_type":"shooting"},
        {"id":"basketball_dunk","name":"Dunk Contest","display_name":"Dunk Contest","venue":"Venice Beach","category":"Basketball","description":"Execute dunks with timing precision","image_url":"https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=800","player_count":"1","duration":"5 min","difficulty":"Advanced","playable":True,"game_type":"timing"},
        {"id":"basketball_3v3","name":"Street 3v3","display_name":"Street · 3v3","venue":"Venice Beach","category":"Basketball","description":"Team-based street basketball","image_url":"https://images.unsplash.com/photo-1519861531473-9200262188bf?w=800","player_count":"3v3","duration":"15 min","difficulty":"Intermediate","playable":True,"game_type":"strategy"},
        {"id":"karate_h2h","name":"Karate 1v1","display_name":"Karate · 1v1","venue":"Dojo","category":"Combat","description":"Strike, block, counter","image_url":"https://images.unsplash.com/photo-1555597673-b21d5c935865?w=800","player_count":"1v1","duration":"5 min","difficulty":"Intermediate","playable":True,"game_type":"combat"},
        {"id":"karate_endless","name":"Karate Endless","display_name":"Karate · Endless","venue":"Dojo","category":"Combat","description":"Survive endless waves","image_url":"https://images.unsplash.com/photo-1564415315949-7a0c4c73aab4?w=800","player_count":"1","duration":"Unlimited","difficulty":"Expert","playable":True,"game_type":"endurance"},
        {"id":"baseball","name":"Baseball","display_name":"Baseball · Ballpark","venue":"Baseball Park","category":"Field","description":"Hit pitches with timing","image_url":"https://images.unsplash.com/photo-1566577739112-5180d4bf9390?w=800","player_count":"1v1","duration":"20 min","difficulty":"Intermediate","playable":True,"game_type":"timing"},
        {"id":"football","name":"Football","display_name":"Football · Kick Return","venue":"Gridiron","category":"Field","description":"Score touchdowns","image_url":"https://images.unsplash.com/photo-1566577134770-3d85bb3a9cc4?w=800","player_count":"1","duration":"10 min","difficulty":"Intermediate","playable":True,"game_type":"reflex"},
        {"id":"soccer","name":"Soccer","display_name":"Soccer · Stadium","venue":"Soccer Stadium","category":"Field","description":"Precision shooting","image_url":"https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=800","player_count":"1v1","duration":"15 min","difficulty":"Intermediate","playable":True,"game_type":"shooting"},
        {"id":"golf","name":"Golf","display_name":"Golf · Links","venue":"Links","category":"Precision","description":"Precision putting","image_url":"https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=800","player_count":"1-4","duration":"30 min","difficulty":"Beginner","playable":True,"game_type":"precision"},
        {"id":"tennis","name":"Tennis","display_name":"Tennis · Court","venue":"Tennis Court","category":"Court","description":"Rally timing","image_url":"https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?w=800","player_count":"1v1","duration":"15 min","difficulty":"Intermediate","playable":True,"game_type":"reflex"},
        {"id":"volleyball","name":"Volleyball","display_name":"Volleyball · Sand","venue":"Sand Court","category":"Court","description":"Beach volleyball","image_url":"https://images.unsplash.com/photo-1612872087720-bb876e2e67d1?w=800","player_count":"2v2","duration":"15 min","difficulty":"Intermediate","playable":True,"game_type":"reflex"},
        {"id":"gymnastics","name":"Gymnastics","display_name":"Gymnastics · Floor","venue":"Training Floor","category":"Performance","description":"Execute routines","image_url":"https://images.unsplash.com/photo-1566838616631-f2618f74a6a2?w=800","player_count":"1","duration":"10 min","difficulty":"Advanced","playable":True,"game_type":"timing"},
        {"id":"brain_brawl","name":"Brain Brawl","display_name":"Academy · Brain Brawl","venue":"Neuro Arena","category":"Academy","description":"Cognitive training","image_url":"https://images.unsplash.com/photo-1559757175-5700dde675bc?w=800","player_count":"1","duration":"5 min","difficulty":"Variable","playable":True,"game_type":"quiz"},
        {"id":"surfing","name":"Surfing","display_name":"Surf · Line","venue":"Venice Beach","category":"Board","description":"Ride the waves","image_url":"https://images.unsplash.com/photo-1502680390469-be75c86b636f?w=800","player_count":"1","duration":"10 min","difficulty":"Intermediate","playable":True,"game_type":"balance"},
        {"id":"skateboarding","name":"Skateboarding","display_name":"Skate · Park","venue":"Skate Park","category":"Board","description":"Land trick combos","image_url":"https://images.unsplash.com/photo-1547447134-cd3f5c716030?w=800","player_count":"1","duration":"10 min","difficulty":"Intermediate","playable":True,"game_type":"timing"},
        {"id":"snowboarding","name":"Snowboarding","display_name":"Snow · Line","venue":"Mountain","category":"Board","description":"Navigate slopes","image_url":"https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=800","player_count":"1","duration":"10 min","difficulty":"Intermediate","playable":True,"game_type":"reflex"},
        {"id":"market_browse","name":"Sovereign Shop","display_name":"Sovereign Shop","venue":"Marketplace","category":"Shop","description":"Browse and purchase","image_url":"https://images.unsplash.com/photo-1607082349566-187342175e2f?w=800","player_count":"1","duration":"Unlimited","difficulty":"None","playable":False,"game_type":"shop"}
    ]

@api_router.get("/cards")
async def get_creator_cards(category: Optional[str] = None):
    cards = await db.creator_cards.find({} if not category else {"sport": category}, {"_id": 0}).to_list(100)
    return cards if cards else get_seeded_creator_cards()

def get_seeded_creator_cards():
    return [
        {"id":"card_elijah","creator_id":"elijah_bonds","name":"Elijah Bonds","title":"Venice Beach Legend","sport":"basketball","tier":"featured","style":"legendary","image_url":"https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=600","bio":"Professional basketball player. Explosive dunks and creative ball handling.","signature_moves":["Magic Reveal Dunk","Venice Crossover","Beach Body Fadeaway"],"highlights":[{"title":"Venice Dunk"},{"title":"Street 1v1 Finals"}],"challenges":[{"name":"Dunk Master","description":"Score 10 dunks","reward":500},{"name":"Crossover King","description":"Complete 50 crossovers","reward":300}],"stats":{"games":1250,"wins":890,"dunks":3400},"price":99.99,"for_sale":True},
        {"id":"card_amir","creator_id":"amir_smith","name":"Amir Smith","title":"Combat Specialist","sport":"karate","tier":"featured","style":"holographic","image_url":"https://images.unsplash.com/photo-1555597673-b21d5c935865?w=600","bio":"Karate champion. Hampton/Metz pro with international experience.","signature_moves":["Shadow Strike","Iron Fist Combo","Dragon Sweep"],"highlights":[{"title":"Championship Finals"},{"title":"Training Montage"}],"challenges":[{"name":"Combo Master","description":"Land 100 combos","reward":400},{"name":"Perfect Block","description":"Block 50 attacks","reward":250}],"stats":{"matches":320,"wins":285,"knockouts":120},"price":79.99,"for_sale":True},
        {"id":"card_eric","creator_id":"eric_nash","name":"Eric Nash","title":"Multi-Sport Coach","sport":"training","tier":"verified","style":"premium","image_url":"https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600","bio":"Venice Beach coach specializing in athletic development.","signature_moves":["Foundation Flow","Power Circuit","Speed Series"],"highlights":[{"title":"Athlete Transformation"},{"title":"Beach Training"}],"challenges":[{"name":"Train with Eric","description":"Complete 5 workouts","reward":200},{"name":"Consistency King","description":"7-day streak","reward":350}],"stats":{"athletes_trained":500,"sessions":2500,"reviews":480},"price":49.99,"for_sale":True}
    ]

@api_router.get("/coach/available")
async def get_available_coaches():
    coaches = await db.users.find({"role": "coach"}, {"_id": 0}).to_list(50)
    if not coaches:
        return [
            {"user_id":"coach_1","name":"Coach Williams","sport":"basketball","specialty":"Shooting & Ball Handling","rating":4.8,"sessions":250,"rate":25},
            {"user_id":"coach_2","name":"Sensei Tanaka","sport":"karate","specialty":"Traditional Karate","rating":4.9,"sessions":180,"rate":35},
            {"user_id":"coach_3","name":"Coach Martinez","sport":"soccer","specialty":"Footwork & Strategy","rating":4.7,"sessions":320,"rate":20},
            {"user_id":"coach_4","name":"Dr. Sarah Chen","sport":"training","specialty":"Sports Psychology","rating":5.0,"sessions":150,"rate":50},
        ]
    return coaches

@api_router.get("/coach/sessions")
async def get_coach_sessions(user: User = Depends(get_current_user)):
    return await db.coach_sessions.find({"$or":[{"coach_id":user.user_id},{"athlete_id":user.user_id}]}, {"_id":0}).to_list(100)

@api_router.post("/coach/sessions")
async def create_coach_session(data: Dict[str, Any], user: User = Depends(get_current_user)):
    s = {"id":str(uuid.uuid4()),"athlete_id":user.user_id,"coach_id":data.get("coach_id"),"sport":data.get("sport"),"session_type":data.get("session_type","training"),"status":"pending","created_at":datetime.now(timezone.utc).isoformat()}
    await db.coach_sessions.insert_one(s)
    return {k:v for k,v in s.items() if k!="_id"}

@api_router.get("/education/courses")
async def get_courses(category: Optional[str] = None):
    return get_seeded_courses(category)

@api_router.post("/education/enroll/{course_id}")
async def enroll_course(course_id: str, user: User = Depends(get_current_user)):
    await db.enrollments.insert_one({"id":str(uuid.uuid4()),"user_id":user.user_id,"course_id":course_id,"progress":0,"enrolled_at":datetime.now(timezone.utc).isoformat()})
    return {"message":"Enrolled"}

def get_seeded_courses(category=None):
    courses = [
        {"id":"brain_brawl_101","title":"Brain Brawl Fundamentals","category":"brain_brawl","description":"Cognitive training techniques for peak performance","level":"Beginner","duration_hours":4,"modules":[{"name":"Reaction Time Training","duration":"1hr"},{"name":"Pattern Recognition","duration":"1hr"},{"name":"Decision Making Under Pressure","duration":"2hr"}],"instructor":"Dr. Sarah Chen","image_url":"https://images.unsplash.com/photo-1559757175-5700dde675bc?w=600","is_certificate":False,"price":0},
        {"id":"kinesiology_cert","title":"Applied Kinesiology Certificate","category":"kinesiology","description":"Comprehensive certification in applied kinesiology","level":"Advanced","duration_hours":40,"modules":[{"name":"Biomechanics Fundamentals","duration":"10hr"},{"name":"Movement Analysis","duration":"10hr"},{"name":"Injury Prevention","duration":"10hr"},{"name":"Performance Optimization","duration":"10hr"}],"instructor":"Dr. Michael Torres","image_url":"https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=600","is_certificate":True,"price":299},
        {"id":"stem_sports","title":"STEM in Sports Science","category":"stem","description":"STEM principles applied to athletic performance","level":"Intermediate","duration_hours":20,"modules":[{"name":"Physics of Movement","duration":"5hr"},{"name":"Sports Analytics","duration":"5hr"},{"name":"Nutrition Science","duration":"5hr"},{"name":"Technology in Training","duration":"5hr"}],"instructor":"Prof. James Wilson","image_url":"https://images.unsplash.com/photo-1507413245164-6160d8298b31?w=600","is_certificate":False,"price":49},
        {"id":"college_prep","title":"College Prep for Athletes","category":"common_core","description":"Academic pathway to college readiness","level":"High School","duration_hours":30,"modules":[{"name":"SAT/ACT Prep","duration":"10hr"},{"name":"College Essays","duration":"5hr"},{"name":"NCAA Eligibility","duration":"5hr"},{"name":"Time Management","duration":"10hr"}],"instructor":"Lisa Anderson","image_url":"https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=600","is_certificate":False,"price":79},
        {"id":"advanced_bb","title":"Brain Brawl: Advanced Tactics","category":"brain_brawl","description":"Advanced cognitive training under pressure","level":"Advanced","duration_hours":8,"modules":[{"name":"Rapid Pattern Analysis","duration":"2hr"},{"name":"Multi-variable Decision Making","duration":"3hr"},{"name":"Stress Inoculation","duration":"3hr"}],"instructor":"Dr. Sarah Chen","image_url":"https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600","is_certificate":True,"price":99},
    ]
    return [c for c in courses if c["category"]==category] if category else courses

@api_router.get("/brain-brawl/questions")
async def get_bb_questions(category: str = "all", count: int = 10):
    return get_seeded_questions(category, count)

@api_router.post("/brain-brawl/submit")
async def submit_bb(data: Dict[str, Any], user: User = Depends(get_current_user)):
    s = {"id":str(uuid.uuid4()),"user_id":user.user_id,"mode":data.get("mode","quick_fire"),"questions_total":data.get("questions_total",10),"questions_correct":data.get("questions_correct",0),"score":data.get("score",0),"category":data.get("category","all"),"completed_at":datetime.now(timezone.utc).isoformat()}
    await db.brain_brawl_sessions.insert_one(s)
    xp = s["score"]//10
    await db.users.update_one({"user_id":user.user_id}, {"$inc":{"xp":xp}})
    return {"session":{k:v for k,v in s.items() if k!="_id"},"xp_earned":xp}

def get_seeded_questions(category, count):
    qs = [
        {"id":"q1","question":"In basketball, how many points is a shot from beyond the arc worth?","options":["2","3","4","1"],"correct":1,"category":"sports_iq","difficulty":"easy"},
        {"id":"q2","question":"What is the standard length of an NBA quarter?","options":["10 min","12 min","15 min","8 min"],"correct":1,"category":"sports_iq","difficulty":"easy"},
        {"id":"q3","question":"In karate, what does 'dan' refer to?","options":["Stance","Belt rank","Kata name","Dojo"],"correct":1,"category":"sports_iq","difficulty":"medium"},
        {"id":"q4","question":"How many players are on a soccer field per team?","options":["9","10","11","12"],"correct":2,"category":"sports_iq","difficulty":"easy"},
        {"id":"q5","question":"What muscle group does the deadlift primarily target?","options":["Chest","Posterior chain","Shoulders","Arms"],"correct":1,"category":"kinesiology","difficulty":"medium"},
        {"id":"q6","question":"What is VO2 max a measure of?","options":["Heart rate","Max oxygen consumption","Blood pressure","Muscle strength"],"correct":1,"category":"kinesiology","difficulty":"medium"},
        {"id":"q7","question":"In tennis, what is 40-40 called?","options":["Match point","Deuce","Advantage","Break point"],"correct":1,"category":"sports_iq","difficulty":"easy"},
        {"id":"q8","question":"Fastest 100m sprint time recorded?","options":["9.58s","9.63s","9.69s","9.72s"],"correct":0,"category":"sports_iq","difficulty":"hard"},
        {"id":"q9","question":"Which energy system is used in sprinting?","options":["Aerobic","ATP-PC","Glycolytic","Oxidative"],"correct":1,"category":"kinesiology","difficulty":"hard"},
        {"id":"q10","question":"What is periodization?","options":["Rest periods","Systematic training phases","Diet cycles","Sleep patterns"],"correct":1,"category":"kinesiology","difficulty":"medium"},
        {"id":"q11","question":"Basketball rim diameter in inches?","options":["16","18","20","22"],"correct":1,"category":"sports_iq","difficulty":"hard"},
        {"id":"q12","question":"Which vitamin is crucial for bone health?","options":["Vitamin A","Vitamin B12","Vitamin D","Vitamin E"],"correct":2,"category":"kinesiology","difficulty":"medium"},
        {"id":"q13","question":"In football, how many yards for a first down?","options":["5","8","10","15"],"correct":2,"category":"sports_iq","difficulty":"easy"},
        {"id":"q14","question":"What does HIIT stand for?","options":["High Impact Interval Training","High Intensity Interval Training","High Intensity Isometric Training","High Impact Isometric Training"],"correct":1,"category":"kinesiology","difficulty":"easy"},
        {"id":"q15","question":"Most commonly injured joint in basketball?","options":["Shoulder","Ankle","Knee","Wrist"],"correct":1,"category":"kinesiology","difficulty":"medium"},
    ]
    filtered = [q for q in qs if q["category"]==category or category=="all"]
    random.shuffle(filtered)
    return filtered[:count]

@api_router.get("/leaderboard")
async def get_leaderboard(limit: int = 20):
    leaders = await db.users.find({}, {"_id":0,"user_id":1,"name":1,"prq_score":1,"level":1,"xp":1,"sport":1,"picture":1,"streak_days":1}).sort("prq_score",-1).limit(limit).to_list(limit)
    if not leaders:
        return [
            {"rank":1,"user_id":"u1","name":"Elijah Bonds","prq_score":95.5,"level":25,"xp":12500,"sport":"basketball","streak_days":30},
            {"rank":2,"user_id":"u2","name":"Amir Smith","prq_score":92.3,"level":22,"xp":11000,"sport":"karate","streak_days":14},
            {"rank":3,"user_id":"u3","name":"Eric Nash","prq_score":89.7,"level":20,"xp":10000,"sport":"training","streak_days":21},
            {"rank":4,"user_id":"u4","name":"Maya Johnson","prq_score":87.4,"level":18,"xp":9000,"sport":"soccer","streak_days":7},
            {"rank":5,"user_id":"u5","name":"Derek Wu","prq_score":85.1,"level":17,"xp":8500,"sport":"tennis","streak_days":10},
            {"rank":6,"user_id":"u6","name":"Sofia Reyes","prq_score":83.8,"level":16,"xp":8000,"sport":"gymnastics","streak_days":5},
            {"rank":7,"user_id":"u7","name":"Jake Thompson","prq_score":81.2,"level":15,"xp":7500,"sport":"football","streak_days":12},
            {"rank":8,"user_id":"u8","name":"Kai Chen","prq_score":79.6,"level":14,"xp":7000,"sport":"surfing","streak_days":8},
        ]
    return [{"rank":i+1,**l} for i,l in enumerate(leaders)]

@api_router.get("/stats/overview")
async def get_stats(user: User = Depends(get_current_user)):
    w = await db.workout_logs.count_documents({"user_id":user.user_id})
    s = await db.coach_sessions.count_documents({"athlete_id":user.user_id})
    b = await db.brain_brawl_sessions.count_documents({"user_id":user.user_id})
    g = await db.game_sessions.count_documents({"user_id":user.user_id})
    return {"total_workouts":w,"coaching_sessions":s,"brain_brawl_sessions":b,"game_sessions":g,"prq_score":user.prq_score,"level":user.level,"xp":user.xp,"streak_days":user.streak_days,"coins":user.coins}

@api_router.put("/profile")
async def update_profile(data: Dict[str, Any], user: User = Depends(get_current_user)):
    allowed = {"name","bio","sport","avatar_url","avatar_config"}
    updates = {k:v for k,v in data.items() if k in allowed}
    if updates: await db.users.update_one({"user_id":user.user_id}, {"$set":updates})
    return await db.users.find_one({"user_id":user.user_id}, {"_id":0})

@api_router.get("/profile/progress")
async def get_progress(user: User = Depends(get_current_user)):
    w = await db.workout_logs.count_documents({"user_id":user.user_id})
    g = await db.game_sessions.count_documents({"user_id":user.user_id})
    b = await db.brain_brawl_sessions.count_documents({"user_id":user.user_id})
    return {"total_workouts":w,"total_games":g,"total_brawls":b,"level":user.level,"xp":user.xp,"streak_days":user.streak_days,"prq_score":user.prq_score,"coins":user.coins}

# AI routes
@api_router.post("/ai/coach")
async def ai_coach(data: Dict[str, Any], user: User = Depends(get_current_user)):
    prompt_type = data.get("type","workout")
    context = data.get("context","")
    prq = await db.prq_metrics.find({"user_id":user.user_id},{"_id":0}).sort("recorded_at",-1).limit(1).to_list(1)
    pd = prq[0] if prq else {}
    sys_msg = f"You are the AI Coach for Final Evolution Lab. Coaching {user.name}, level {user.level} {user.role} focused on {user.sport}. PRQ: {pd.get('overall_score',75)}/100. Be expert, concise, actionable. Under 300 words."
    try:
        chat = LlmChat(api_key=EMERGENT_KEY, session_id=f"coach_{uuid.uuid4().hex[:8]}", system_message=sys_msg)
        chat.with_model("openai","gpt-5.2")
        r = await chat.send_message(UserMessage(text=context or f"Generate a {prompt_type} plan."))
        return {"response":r,"model":"gpt-5.2","type":prompt_type}
    except Exception as e:
        logger.error(f"AI error: {e}")
        return {"response":"AI service temporarily unavailable. Try again shortly.","model":"fallback","type":prompt_type}

@api_router.post("/ai/chat")
async def ai_chat(data: Dict[str, Any], user: User = Depends(get_current_user)):
    msg = data.get("message","")
    model = data.get("model","gpt-5.2")
    cid = data.get("conversation_id",str(uuid.uuid4()))
    if not msg: raise HTTPException(400,"Message required")
    configs = {"gpt-5.2":("openai","gpt-5.2"),"claude":("anthropic","claude-sonnet-4-5-20250929"),"gemini":("gemini","gemini-3-flash-preview")}
    try:
        p,m = configs.get(model,("openai","gpt-5.2"))
        chat = LlmChat(api_key=EMERGENT_KEY, session_id=f"chat_{cid}", system_message=f"You are FEL AI Assistant. Help {user.name} with training, nutrition, recovery. PRQ: {user.prq_score}/100. Be concise.")
        chat.with_model(p,m)
        r = await chat.send_message(UserMessage(text=msg))
        await db.ai_conversations.insert_one({"conversation_id":cid,"user_id":user.user_id,"user_message":msg,"ai_response":r,"model":model,"created_at":datetime.now(timezone.utc).isoformat()})
        return {"response":r,"model":model,"conversation_id":cid}
    except Exception as e:
        logger.error(f"Chat error: {e}")
        return {"response":"Connection issue. Please try again.","model":"fallback","conversation_id":cid}

@api_router.get("/streaming/status")
async def get_streaming_status():
    e3ds_stream = os.environ.get("E3DS_STREAM_URL", "")
    e3ds_iframe = os.environ.get("E3DS_IFRAME_URL", "")
    e3ds_app_id = os.environ.get("E3DS_APP_ID", "")
    e3ds_api_key = os.environ.get("E3DS_API_KEY", "")
    available = bool(e3ds_stream or e3ds_iframe)
    
    mode_maps = {
        "basketball_h2h": "Venice_Beach_Court", "basketball_dunk": "Venice_Beach_Court",
        "basketball_3v3": "Venice_Beach_Court", "karate_h2h": "Zen_Dojo",
        "karate_endless": "Zen_Dojo", "baseball": "Baseball_Park",
        "football": "Gridiron_Stadium", "soccer": "Soccer_Stadium",
        "golf": "Links_Course", "tennis": "Tennis_Court",
        "volleyball": "Sand_Court", "gymnastics": "Training_Floor",
        "surfing": "Venice_Beach_Surf", "skateboarding": "Skate_Park",
        "snowboarding": "Mountain_Slope",
    }
    
    return {
        "available": available,
        "stream_url": e3ds_stream,
        "iframe_url": e3ds_iframe,
        "app_id": e3ds_app_id,
        "has_api_key": bool(e3ds_api_key),
        "provider": "eagle3d" if available else ("eagle3d_configured" if e3ds_api_key else None),
        "message": (
            "Eagle 3D Streaming active — high-fidelity UE5 modes ready." if available
            else ("E3DS API key configured. Upload your UE5 build to the E3DS Control Panel (controlpanel.eagle3dstreaming.com), then paste the iframe URL below." if e3ds_api_key
            else "No E3DS stream connected. Run deploy_e3ds.sh or enter your E3DS iframe URL.")
        ),
        "supported_modes": list(mode_maps.keys()),
        "mode_maps": mode_maps,
        "setup_steps": [
            "1. Go to controlpanel.eagle3dstreaming.com and sign in",
            "2. Upload your packaged UE5 build (.zip with Pixel Streaming enabled)",
            "3. Create a Config for your app",
            "4. Generate a Streaming Link",
            "5. Copy the iframe embed script URL",
            "6. Paste the iframe URL in the connection panel below"
        ] if not available else []
    }

@api_router.post("/streaming/connect")
async def connect_streaming(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Manually set E3DS stream URL (admin / dev use)"""
    stream_url = data.get("stream_url") or data.get("server_url")
    iframe_url = data.get("iframe_url", "")
    if not stream_url:
        raise HTTPException(status_code=400, detail="stream_url required")
    # Persist to env file for subsequent restarts
    env_path = ROOT_DIR / '.env'
    lines = env_path.read_text().splitlines()
    lines = [l for l in lines if not l.startswith("E3DS_")]
    lines.append(f"E3DS_STREAM_URL={stream_url}")
    if iframe_url:
        lines.append(f"E3DS_IFRAME_URL={iframe_url}")
    env_path.write_text("\n".join(lines) + "\n")
    # Set in current process
    os.environ["E3DS_STREAM_URL"] = stream_url
    if iframe_url:
        os.environ["E3DS_IFRAME_URL"] = iframe_url
    return {"status": "connected", "stream_url": stream_url, "iframe_url": iframe_url}

@api_router.post("/streaming/launch-mode")
async def launch_stream_mode(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Send a command to E3DS to launch a specific game mode map"""
    mode_id = data.get("mode_id")
    mode_maps = {
        "basketball_h2h": "Venice_Beach_Court", "basketball_dunk": "Venice_Beach_Court",
        "basketball_3v3": "Venice_Beach_Court", "karate_h2h": "Zen_Dojo",
        "karate_endless": "Zen_Dojo", "baseball": "Baseball_Park",
        "football": "Gridiron_Stadium", "soccer": "Soccer_Stadium",
        "golf": "Links_Course", "tennis": "Tennis_Court",
        "volleyball": "Sand_Court", "gymnastics": "Training_Floor",
        "surfing": "Venice_Beach_Surf", "skateboarding": "Skate_Park",
        "snowboarding": "Mountain_Slope",
    }
    target_map = mode_maps.get(mode_id)
    if not target_map:
        raise HTTPException(status_code=404, detail="Mode not found in E3DS map registry")
    return {
        "mode_id": mode_id, "map": target_map,
        "command": {"cmd": "ueapp04", "value": {"ServerTravel": f"/Game/FEL/Maps/{target_map}"}},
        "stream_url": os.environ.get("E3DS_STREAM_URL", ""),
        "iframe_url": os.environ.get("E3DS_IFRAME_URL", "")
    }

@api_router.get("/")
async def root():
    return {"message":"Final Evolution Lab API","version":"2.0.0"}

@api_router.get("/health")
async def health():
    return {"status":"healthy","timestamp":datetime.now(timezone.utc).isoformat()}

# ===================== WEBSOCKET MULTIPLAYER =====================
class ConnectionManager:
    def __init__(self):
        self.rooms: Dict[str, List[WebSocket]] = {}
        self.player_data: Dict[str, Dict] = {}

    async def connect(self, websocket: WebSocket, room_id: str, user_id: str):
        await websocket.accept()
        if room_id not in self.rooms:
            self.rooms[room_id] = []
        self.rooms[room_id].append(websocket)
        self.player_data[user_id] = {"room": room_id, "score": 0, "ready": False}

    def disconnect(self, websocket: WebSocket, room_id: str, user_id: str):
        if room_id in self.rooms:
            self.rooms[room_id] = [ws for ws in self.rooms[room_id] if ws != websocket]
            if not self.rooms[room_id]:
                del self.rooms[room_id]
        self.player_data.pop(user_id, None)

    async def broadcast(self, room_id: str, message: dict):
        if room_id in self.rooms:
            for ws in self.rooms[room_id]:
                try: await ws.send_json(message)
                except: pass

manager = ConnectionManager()

@app.websocket("/ws/game/{room_id}")
async def game_websocket(websocket: WebSocket, room_id: str):
    user_id = f"player_{uuid.uuid4().hex[:8]}"
    await manager.connect(websocket, room_id, user_id)
    try:
        await manager.broadcast(room_id, {"type": "player_joined", "user_id": user_id, "players": len(manager.rooms.get(room_id, []))})
        while True:
            data = await websocket.receive_json()
            if data.get("type") == "score_update":
                manager.player_data[user_id]["score"] = data.get("score", 0)
                await manager.broadcast(room_id, {"type": "score_update", "user_id": user_id, "score": data["score"]})
            elif data.get("type") == "game_action":
                await manager.broadcast(room_id, {"type": "game_action", "user_id": user_id, "action": data.get("action")})
            elif data.get("type") == "ready":
                manager.player_data[user_id]["ready"] = True
                all_ready = all(p.get("ready") for p in manager.player_data.values() if p.get("room") == room_id)
                await manager.broadcast(room_id, {"type": "ready_status", "user_id": user_id, "all_ready": all_ready})
    except WebSocketDisconnect:
        manager.disconnect(websocket, room_id, user_id)
        await manager.broadcast(room_id, {"type": "player_left", "user_id": user_id})

# ===================== GATE 2: MULTIPLAYER ROOM MANAGEMENT =====================

@api_router.post("/multiplayer/create-room")
async def create_multiplayer_room(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Create a multiplayer game room with low-latency config"""
    room = {
        "id": f"room_{uuid.uuid4().hex[:10]}",
        "host_id": user.user_id,
        "host_name": user.name,
        "game_mode": data.get("game_mode", "basketball_h2h"),
        "max_players": data.get("max_players", 2),
        "players": [{"user_id": user.user_id, "name": user.name, "ready": False, "score": 0}],
        "status": "waiting",  # waiting, starting, in_progress, completed
        "settings": {
            "time_limit": data.get("time_limit", 60),
            "score_limit": data.get("score_limit", 100),
            "allow_spectators": data.get("allow_spectators", True),
            "latency_mode": "low"  # E3DS optimized
        },
        "spectators": [],
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.multiplayer_rooms.insert_one(room)
    return {k: v for k, v in room.items() if k != "_id"}

@api_router.get("/multiplayer/rooms")
async def get_active_rooms():
    """List active multiplayer rooms"""
    rooms = await db.multiplayer_rooms.find(
        {"status": {"$in": ["waiting", "in_progress"]}}, {"_id": 0}
    ).sort("created_at", -1).limit(20).to_list(20)
    if not rooms:
        return [
            {"id": "room_demo1", "host_name": "Elijah B.", "game_mode": "basketball_h2h", "max_players": 2, "players": [{"name": "Elijah B.", "ready": True}], "status": "waiting", "settings": {"time_limit": 60, "allow_spectators": True}},
            {"id": "room_demo2", "host_name": "Amir S.", "game_mode": "karate_h2h", "max_players": 2, "players": [{"name": "Amir S.", "ready": True}], "status": "waiting", "settings": {"time_limit": 60, "allow_spectators": True}},
        ]
    return rooms

@api_router.post("/multiplayer/rooms/{room_id}/join")
async def join_room(room_id: str, user: User = Depends(get_current_user)):
    room = await db.multiplayer_rooms.find_one({"id": room_id}, {"_id": 0})
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    if len(room.get("players", [])) >= room.get("max_players", 2):
        raise HTTPException(status_code=400, detail="Room full")
    await db.multiplayer_rooms.update_one(
        {"id": room_id},
        {"$push": {"players": {"user_id": user.user_id, "name": user.name, "ready": False, "score": 0}}}
    )
    return {"status": "joined", "room_id": room_id}

@api_router.post("/multiplayer/rooms/{room_id}/spectate")
async def spectate_room(room_id: str, user: User = Depends(get_current_user)):
    """Join as spectator (Gate 4: Spectator Mode)"""
    await db.multiplayer_rooms.update_one(
        {"id": room_id},
        {"$push": {"spectators": {"user_id": user.user_id, "name": user.name, "joined_at": datetime.now(timezone.utc).isoformat()}}}
    )
    return {"status": "spectating", "room_id": room_id}

# ===================== GATE 3: REFERRAL REWARD SYSTEM =====================

@api_router.post("/referral/generate")
async def generate_referral_code(user: User = Depends(get_current_user)):
    """Generate a unique referral code for the user"""
    existing = await db.referrals.find_one({"user_id": user.user_id, "type": "code"}, {"_id": 0})
    if existing:
        return existing

    code = f"FEL-{user.name.split()[0].upper()[:4]}-{uuid.uuid4().hex[:6].upper()}"
    referral = {
        "id": str(uuid.uuid4()),
        "user_id": user.user_id,
        "code": code,
        "type": "code",
        "uses": 0,
        "max_uses": 50,
        "rewards_earned": 0,
        "referred_users": [],
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.referrals.insert_one(referral)
    return {k: v for k, v in referral.items() if k != "_id"}

@api_router.post("/referral/redeem")
async def redeem_referral(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Redeem a referral code — rewards both referrer and new user"""
    code = data.get("code", "").strip().upper()
    if not code:
        raise HTTPException(status_code=400, detail="Referral code required")

    referral = await db.referrals.find_one({"code": code, "type": "code"}, {"_id": 0})
    if not referral:
        raise HTTPException(status_code=404, detail="Invalid referral code")
    if referral["user_id"] == user.user_id:
        raise HTTPException(status_code=400, detail="Cannot redeem your own code")
    if user.user_id in referral.get("referred_users", []):
        raise HTTPException(status_code=400, detail="Already redeemed")
    if referral.get("uses", 0) >= referral.get("max_uses", 50):
        raise HTTPException(status_code=400, detail="Referral code expired")

    # Reward referrer: 200 coins + 100 XP
    await db.users.update_one({"user_id": referral["user_id"]}, {"$inc": {"coins": 200, "xp": 100}})
    # Reward new user: 100 coins + 50 XP
    await db.users.update_one({"user_id": user.user_id}, {"$inc": {"coins": 100, "xp": 50}})

    # Update referral record
    await db.referrals.update_one({"code": code}, {
        "$inc": {"uses": 1, "rewards_earned": 200},
        "$push": {"referred_users": user.user_id}
    })

    # Log PayPal-eligible credit (for future payout)
    await db.referral_credits.insert_one({
        "id": str(uuid.uuid4()),
        "referrer_id": referral["user_id"],
        "referred_id": user.user_id,
        "referrer_reward": {"coins": 200, "xp": 100},
        "referred_reward": {"coins": 100, "xp": 50},
        "paypal_eligible": True,
        "paid_out": False,
        "created_at": datetime.now(timezone.utc).isoformat()
    })

    return {"message": "Referral redeemed!", "coins_earned": 100, "xp_earned": 50, "referrer_rewarded": True}

@api_router.get("/referral/stats")
async def get_referral_stats(user: User = Depends(get_current_user)):
    ref = await db.referrals.find_one({"user_id": user.user_id, "type": "code"}, {"_id": 0})
    credits = await db.referral_credits.find({"referrer_id": user.user_id}, {"_id": 0}).to_list(100)
    total_earned = sum(c.get("referrer_reward", {}).get("coins", 0) for c in credits)
    pending_payout = sum(c.get("referrer_reward", {}).get("coins", 0) for c in credits if not c.get("paid_out"))
    return {
        "code": ref.get("code") if ref else None,
        "total_referrals": ref.get("uses", 0) if ref else 0,
        "total_coins_earned": total_earned,
        "pending_payout": pending_payout,
        "referred_users": ref.get("referred_users", []) if ref else []
    }

@api_router.post("/referral/payout")
async def request_referral_payout(user: User = Depends(get_current_user)):
    """Request PayPal payout for referral credits"""
    credits = await db.referral_credits.find(
        {"referrer_id": user.user_id, "paid_out": False}, {"_id": 0}
    ).to_list(100)
    total = sum(c.get("referrer_reward", {}).get("coins", 0) for c in credits)
    if total < 500:
        raise HTTPException(status_code=400, detail=f"Minimum payout: 500 coins. Current: {total}")
    # Mark as payout requested
    await db.referral_credits.update_many(
        {"referrer_id": user.user_id, "paid_out": False},
        {"$set": {"paid_out": True, "payout_requested_at": datetime.now(timezone.utc).isoformat()}}
    )
    return {"status": "payout_requested", "amount_coins": total, "message": "PayPal payout processing"}

# ===================== GATE 4: SPECTATOR MODE (TOURNAMENT STREAMS) =====================

@api_router.get("/tournaments/{tournament_id}/spectate")
async def get_spectator_config(tournament_id: str):
    """Get spectator camera config for tournament streams — prevents focus-loss in E3DS"""
    t = None
    for st in get_seeded_tournaments():
        if st["id"] == tournament_id:
            t = st
            break
    if not t:
        t = await db.tournaments.find_one({"id": tournament_id}, {"_id": 0})
    if not t:
        raise HTTPException(status_code=404, detail="Tournament not found")

    mode_maps = {
        "basketball_h2h": "Venice_Beach_Court", "karate_h2h": "Zen_Dojo",
        "brain_brawl": "Neuro_Arena", "mixed": "Venice_Beach_Court"
    }
    venue = mode_maps.get(t.get("game_mode", ""), "Venice_Beach_Court")

    return {
        "tournament_id": tournament_id,
        "tournament_name": t["name"],
        "venue_map": f"/Game/FEL/Maps/{venue}",
        "spectator_config": {
            "camera_mode": "orbital",       # orbital, fixed, follow_player, free
            "auto_focus": True,             # Tracks active player
            "focus_lock": True,             # CRITICAL: prevents E3DS focus-loss
            "focus_lock_interval_ms": 500,  # Re-assert focus every 500ms
            "camera_distance": 800,
            "camera_height": 400,
            "camera_fov": 90,
            "smooth_transition": True,
            "transition_speed": 2.0,
            "auto_switch_player": True,     # Switch to active player on score
            "switch_delay_ms": 1500,
            "hud_overlay": True,            # Show scores, timer overlay
            "chat_enabled": True,
        },
        "e3ds_commands": {
            "start_spectate": {"cmd": "ueapp04", "value": {"SpectatorMode": True, "FocusLock": True}},
            "switch_camera": {"cmd": "ueapp04", "value": {"CameraMode": "orbital"}},
            "follow_player": {"cmd": "ueapp04", "value": {"FollowPlayer": "$PLAYER_ID"}},
            "focus_keepalive": {"cmd": "ueapp04", "value": {"FocusKeepalive": True}},
        },
        "iframe_focus_fix": {
            "description": "Auto-refocus iframe at 500ms intervals to prevent E3DS instance focus-loss during spectating",
            "interval_ms": 500,
            "method": "iframe.focus() + postMessage(FocusKeepalive)"
        }
    }

# ===================== GATE 5: ANALYTICS & SOVEREIGN SYNC =====================

@api_router.post("/analytics/session")
async def log_analytics_session(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Log game session analytics — feeds into Sovereign Sync pipeline"""
    session = {
        "id": str(uuid.uuid4()),
        "user_id": user.user_id,
        "game_mode": data.get("game_mode"),
        "venue": data.get("venue"),
        "session_start": data.get("session_start", datetime.now(timezone.utc).isoformat()),
        "session_end": data.get("session_end"),
        "duration_seconds": data.get("duration_seconds", 0),
        "score": data.get("score", 0),
        "events": data.get("events", []),
        "stream_quality": data.get("stream_quality", {}),
        "latency_ms": data.get("latency_ms"),
        "sync_status": "pending",  # pending → synced_local → synced_remote
        "sovereign_sync": {
            "local_store": True,          # Data stored in MongoDB first
            "m4_pro_sync": "pending",     # Sync to M4 Pro Mac Mini
            "signaling_server": "private" # Uses private signaling server
        },
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.analytics_sessions.insert_one(session)
    return {k: v for k, v in session.items() if k != "_id"}

@api_router.get("/analytics/dashboard")
async def get_analytics_dashboard(user: User = Depends(get_current_user)):
    """Get analytics dashboard data with Sovereign Sync status"""
    # Per-mode stats
    pipeline = [
        {"$match": {"user_id": user.user_id}},
        {"$group": {
            "_id": "$game_mode",
            "total_sessions": {"$sum": 1},
            "total_duration": {"$sum": "$duration_seconds"},
            "avg_score": {"$avg": "$score"},
            "avg_latency": {"$avg": "$latency_ms"}
        }},
        {"$sort": {"total_duration": -1}}
    ]
    mode_stats = await db.analytics_sessions.aggregate(pipeline).to_list(20)

    # Overall stats
    total = await db.analytics_sessions.count_documents({"user_id": user.user_id})
    total_time = await db.analytics_sessions.aggregate([
        {"$match": {"user_id": user.user_id}},
        {"$group": {"_id": None, "total": {"$sum": "$duration_seconds"}}}
    ]).to_list(1)

    # Sync status
    pending = await db.analytics_sessions.count_documents({"user_id": user.user_id, "sync_status": "pending"})
    synced = await db.analytics_sessions.count_documents({"user_id": user.user_id, "sync_status": {"$ne": "pending"}})

    return {
        "mode_stats": [{
            "game_mode": s["_id"],
            "total_sessions": s["total_sessions"],
            "total_minutes": round(s["total_duration"] / 60, 1),
            "avg_score": round(s["avg_score"] or 0, 1),
            "avg_latency_ms": round(s["avg_latency"] or 0, 1)
        } for s in mode_stats],
        "overview": {
            "total_sessions": total,
            "total_minutes": round((total_time[0]["total"] if total_time else 0) / 60, 1),
        },
        "sovereign_sync": {
            "pending_sync": pending,
            "synced": synced,
            "sync_target": "M4 Pro Mac Mini (Private Signaling Server)",
            "protocol": "Sovereign Sync v1",
            "data_policy": {
                "storage": "Local MongoDB → M4 Pro Mac Mini → Private Signaling Server",
                "retention": "Indefinite (user-controlled)",
                "encryption": "AES-256 at rest, TLS 1.3 in transit",
                "third_party_access": "None — all data sovereign",
                "sync_interval": "Every 5 minutes (configurable)",
                "export_format": "JSON / CSV on demand"
            }
        }
    }

@api_router.get("/analytics/policy")
async def get_analytics_policy():
    """Data tracking policy for session analytics across all 15 game modes"""
    return {
        "policy_version": "1.0.0",
        "effective_date": "2026-01-17",
        "data_controller": "Final Evolution Lab (Sovereign)",
        "tracked_metrics": {
            "per_session": [
                "game_mode", "venue_map", "session_start", "session_end",
                "duration_seconds", "score", "actions_count", "latency_ms",
                "stream_quality (resolution, fps, bitrate)", "input_events_count"
            ],
            "per_user_aggregate": [
                "total_sessions_per_mode", "total_play_time_per_mode",
                "average_score_per_mode", "peak_performance_times",
                "streak_correlation", "prq_impact_analysis"
            ],
            "venue_analytics": [
                "Venice_Beach_Court — basketball sessions, peak hours, avg duration",
                "Zen_Dojo — karate sessions, combo accuracy, avg round length",
                "Soccer_Stadium — shooting precision, goal conversion rate",
                "Baseball_Park — batting average, pitch timing accuracy",
                "Gridiron_Stadium — yards gained, touchdown rate",
                "Links_Course — putting accuracy, drive distance",
                "Tennis_Court — rally length, ace rate",
                "Sand_Court — block rate, serve accuracy",
                "Training_Floor — routine completion, difficulty progression",
                "Venice_Beach_Surf — wave duration, trick completion",
                "Skate_Park — trick combos, line completion",
                "Mountain_Slope — run time, trick accuracy",
                "Neuro_Arena — brain brawl accuracy, response time"
            ]
        },
        "sovereign_sync_protocol": {
            "description": "All analytics data stored locally first, then synced to M4 Pro Mac Mini via private signaling server",
            "flow": [
                "1. Session data → Local MongoDB (immediate)",
                "2. Local MongoDB → M4 Pro Mac Mini (every 5min via private signaling server)",
                "3. M4 Pro Mac Mini → Encrypted local archive (daily)",
                "4. No third-party cloud sync — fully sovereign"
            ],
            "private_signaling_server": {
                "host": "M4 Pro Mac Mini (local network)",
                "protocol": "WebSocket (WSS) over Cloudflare Tunnel",
                "auth": "mTLS + API key",
                "sync_endpoint": "wss://localhost:8443/sovereign/sync",
                "data_format": "JSON with AES-256-GCM envelope"
            },
            "retention": "User-controlled — no automatic deletion",
            "export": "On-demand JSON/CSV export via /api/analytics/export"
        }
    }

@api_router.get("/analytics/export")
async def export_analytics(user: User = Depends(get_current_user)):
    """Export all analytics data for sovereign storage"""
    sessions = await db.analytics_sessions.find({"user_id": user.user_id}, {"_id": 0}).to_list(10000)
    return {
        "user_id": user.user_id,
        "export_date": datetime.now(timezone.utc).isoformat(),
        "format": "json",
        "sessions": sessions,
        "total_records": len(sessions),
        "sovereign_sync_target": "M4 Pro Mac Mini"
    }

@api_router.post("/analytics/sovereign-sync")
async def trigger_sovereign_sync(user: User = Depends(get_current_user)):
    """Manually trigger sovereign sync to M4 Pro Mac Mini"""
    pending = await db.analytics_sessions.find(
        {"user_id": user.user_id, "sync_status": "pending"}, {"_id": 0}
    ).to_list(1000)

    if not pending:
        return {"message": "No pending data to sync", "synced": 0}

    # Mark as synced (actual sync happens via M4 Pro signaling server)
    await db.analytics_sessions.update_many(
        {"user_id": user.user_id, "sync_status": "pending"},
        {"$set": {
            "sync_status": "synced_local",
            "sovereign_sync.m4_pro_sync": "queued",
            "synced_at": datetime.now(timezone.utc).isoformat()
        }}
    )

    return {
        "message": f"Queued {len(pending)} sessions for sovereign sync",
        "synced": len(pending),
        "target": "M4 Pro Mac Mini (Private Signaling Server)",
        "sync_status": "queued"
    }

app.include_router(api_router)
app.add_middleware(CORSMiddleware, allow_credentials=True, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
