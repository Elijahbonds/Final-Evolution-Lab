from fastapi import FastAPI, APIRouter, HTTPException, Depends, Request, Response
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Optional, Dict, Any
import uuid
import random
from datetime import datetime, timezone, timedelta
import httpx
from emergentintegrations.llm.chat import LlmChat, UserMessage

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

EMERGENT_KEY = os.environ.get('EMERGENT_LLM_KEY', '')

app = FastAPI(title="Final Evolution Lab API")
api_router = APIRouter(prefix="/api")

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# ===================== MODELS =====================

class User(BaseModel):
    model_config = ConfigDict(extra="ignore")
    user_id: str
    email: str
    name: str
    picture: Optional[str] = None
    created_at: Optional[str] = None
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    role: str = "athlete"
    sport: str = "basketball"
    prq_score: float = 75.0
    level: int = 1
    xp: int = 0
    streak_days: int = 0
    total_workouts: int = 0

# ===================== AUTH HELPERS =====================

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

# ===================== AUTH ROUTES =====================

@api_router.post("/auth/session")
async def create_session(request: Request, response: Response):
    data = await request.json()
    session_id = data.get("session_id")
    if not session_id:
        raise HTTPException(status_code=400, detail="session_id required")
    async with httpx.AsyncClient() as http_client:
        resp = await http_client.get(
            "https://demobackend.emergentagent.com/auth/v1/env/oauth/session-data",
            headers={"X-Session-ID": session_id}
        )
        if resp.status_code != 200:
            raise HTTPException(status_code=401, detail="Invalid session_id")
        session_data = resp.json()
    user_id = f"user_{uuid.uuid4().hex[:12]}"
    existing_user = await db.users.find_one({"email": session_data["email"]}, {"_id": 0})
    if existing_user:
        user_id = existing_user["user_id"]
        await db.users.update_one(
            {"user_id": user_id},
            {"$set": {"name": session_data["name"], "picture": session_data.get("picture")}}
        )
    else:
        user_doc = {
            "user_id": user_id, "email": session_data["email"], "name": session_data["name"],
            "picture": session_data.get("picture"), "created_at": datetime.now(timezone.utc).isoformat(),
            "role": "athlete", "sport": "basketball", "prq_score": 75.0, "level": 1, "xp": 0,
            "streak_days": 0, "total_workouts": 0
        }
        await db.users.insert_one(user_doc)
        prq_doc = {
            "id": str(uuid.uuid4()), "user_id": user_id, "overall_score": 75.0,
            "strength": 70.0, "speed": 75.0, "endurance": 80.0, "agility": 72.0,
            "power": 68.0, "flexibility": 78.0, "recovery": 82.0, "mental": 76.0,
            "recorded_at": datetime.now(timezone.utc).isoformat()
        }
        await db.prq_metrics.insert_one(prq_doc)
    session_token = session_data.get("session_token", f"sess_{uuid.uuid4().hex}")
    expires_at = datetime.now(timezone.utc) + timedelta(days=7)
    await db.user_sessions.insert_one({
        "user_id": user_id, "session_token": session_token,
        "expires_at": expires_at.isoformat(), "created_at": datetime.now(timezone.utc).isoformat()
    })
    response.set_cookie(key="session_token", value=session_token, httponly=True, secure=True, samesite="none", path="/", max_age=7*24*60*60)
    user = await db.users.find_one({"user_id": user_id}, {"_id": 0})
    return user

@api_router.get("/auth/me")
async def get_me(user: User = Depends(get_current_user)):
    return user.model_dump()

@api_router.post("/auth/logout")
async def logout(request: Request, response: Response):
    session_token = request.cookies.get("session_token")
    if session_token:
        await db.user_sessions.delete_one({"session_token": session_token})
    response.delete_cookie(key="session_token", path="/")
    return {"message": "Logged out"}

# ===================== PROFILE ROUTES =====================

@api_router.put("/profile")
async def update_profile(data: Dict[str, Any], user: User = Depends(get_current_user)):
    allowed = {"name", "bio", "sport", "avatar_url"}
    updates = {k: v for k, v in data.items() if k in allowed}
    if updates:
        await db.users.update_one({"user_id": user.user_id}, {"$set": updates})
    updated = await db.users.find_one({"user_id": user.user_id}, {"_id": 0})
    return updated

@api_router.get("/profile/progress")
async def get_progress(user: User = Depends(get_current_user)):
    workouts = await db.workout_logs.count_documents({"user_id": user.user_id})
    games = await db.game_sessions.count_documents({"user_id": user.user_id})
    brawls = await db.brain_brawl_sessions.count_documents({"user_id": user.user_id})
    coaching = await db.coach_sessions.count_documents({"athlete_id": user.user_id})
    recent_workouts = await db.workout_logs.find({"user_id": user.user_id}, {"_id": 0}).sort("completed_at", -1).limit(7).to_list(7)
    return {
        "total_workouts": workouts, "total_games": games, "total_brawls": brawls,
        "total_coaching": coaching, "level": user.level, "xp": user.xp,
        "streak_days": user.streak_days, "prq_score": user.prq_score,
        "recent_workouts": recent_workouts
    }

# ===================== PRQ & SYSTEM SCAN =====================

@api_router.get("/prq/metrics")
async def get_prq_metrics(user: User = Depends(get_current_user)):
    metrics = await db.prq_metrics.find({"user_id": user.user_id}, {"_id": 0}).sort("recorded_at", -1).limit(1).to_list(1)
    if not metrics:
        prq = {"id": str(uuid.uuid4()), "user_id": user.user_id, "overall_score": 75.0,
               "strength": 70.0, "speed": 75.0, "endurance": 80.0, "agility": 72.0,
               "power": 68.0, "flexibility": 78.0, "recovery": 82.0, "mental": 76.0,
               "recorded_at": datetime.now(timezone.utc).isoformat()}
        await db.prq_metrics.insert_one(prq)
        return {k: v for k, v in prq.items() if k != "_id"}
    return metrics[0]

@api_router.get("/prq/history")
async def get_prq_history(user: User = Depends(get_current_user)):
    history = await db.prq_metrics.find({"user_id": user.user_id}, {"_id": 0}).sort("recorded_at", -1).limit(30).to_list(30)
    return history

@api_router.post("/prq/metrics")
async def update_prq_metrics(data: Dict[str, Any], user: User = Depends(get_current_user)):
    prq = {"id": str(uuid.uuid4()), "user_id": user.user_id, "recorded_at": datetime.now(timezone.utc).isoformat()}
    for k in ["overall_score", "strength", "speed", "endurance", "agility", "power", "flexibility", "recovery", "mental"]:
        prq[k] = data.get(k, 75.0)
    await db.prq_metrics.insert_one(prq)
    await db.users.update_one({"user_id": user.user_id}, {"$set": {"prq_score": prq["overall_score"]}})
    return {k: v for k, v in prq.items() if k != "_id"}

@api_router.get("/health/metrics")
async def get_health_metrics(user: User = Depends(get_current_user)):
    metrics = await db.health_metrics.find({"user_id": user.user_id}, {"_id": 0}).sort("recorded_at", -1).limit(7).to_list(7)
    return metrics

@api_router.post("/health/metrics")
async def add_health_metrics(data: Dict[str, Any], user: User = Depends(get_current_user)):
    health = {"id": str(uuid.uuid4()), "user_id": user.user_id, "recorded_at": datetime.now(timezone.utc).isoformat()}
    for k in ["heart_rate", "sleep_hours", "calories_burned", "steps", "hydration_ml", "stress_level", "readiness_score"]:
        health[k] = data.get(k)
    await db.health_metrics.insert_one(health)
    return {k: v for k, v in health.items() if k != "_id"}

# ===================== WORKOUTS =====================

@api_router.get("/workouts/recommended")
async def get_recommended_workouts(user: User = Depends(get_current_user)):
    return [
        {"id": "rec_1", "name": "Power Development", "sport": "basketball", "difficulty": "intermediate", "duration_minutes": 45, "focus": "strength",
         "exercises": [{"name": "Box Jumps", "sets": 4, "reps": "8", "rest": "60s"}, {"name": "Medicine Ball Slams", "sets": 3, "reps": "12", "rest": "45s"}, {"name": "Squat Jumps", "sets": 4, "reps": "10", "rest": "60s"}, {"name": "Resistance Band Sprints", "sets": 3, "reps": "30s", "rest": "90s"}]},
        {"id": "rec_2", "name": "Speed & Agility", "sport": "soccer", "difficulty": "advanced", "duration_minutes": 30, "focus": "agility",
         "exercises": [{"name": "Ladder Drills", "sets": 3, "reps": "30s", "rest": "30s"}, {"name": "Cone Sprints", "sets": 5, "reps": "20m", "rest": "60s"}, {"name": "Defensive Slides", "sets": 4, "reps": "15s", "rest": "30s"}, {"name": "T-Drill", "sets": 4, "reps": "1", "rest": "90s"}]},
        {"id": "rec_3", "name": "Recovery Flow", "sport": "general", "difficulty": "beginner", "duration_minutes": 20, "focus": "recovery",
         "exercises": [{"name": "Foam Rolling", "sets": 1, "reps": "10min", "rest": "-"}, {"name": "Dynamic Stretching", "sets": 2, "reps": "5min", "rest": "-"}, {"name": "Breathing Exercises", "sets": 1, "reps": "5min", "rest": "-"}]},
        {"id": "rec_4", "name": "Combat Conditioning", "sport": "karate", "difficulty": "advanced", "duration_minutes": 40, "focus": "power",
         "exercises": [{"name": "Heavy Bag Rounds", "sets": 6, "reps": "3min", "rest": "60s"}, {"name": "Plyometric Push-ups", "sets": 4, "reps": "12", "rest": "45s"}, {"name": "Shadow Boxing", "sets": 4, "reps": "3min", "rest": "30s"}, {"name": "Core Rotations", "sets": 3, "reps": "20", "rest": "30s"}]},
    ]

@api_router.post("/workouts/log")
async def log_workout(data: Dict[str, Any], user: User = Depends(get_current_user)):
    log = {"id": str(uuid.uuid4()), "user_id": user.user_id, "workout_id": data.get("workout_id"),
           "workout_name": data.get("workout_name", "Custom Workout"), "duration_minutes": data.get("duration_minutes", 0),
           "calories_burned": data.get("calories_burned", 0), "exercises_completed": data.get("exercises_completed", []),
           "completed_at": datetime.now(timezone.utc).isoformat()}
    await db.workout_logs.insert_one(log)
    await db.users.update_one({"user_id": user.user_id}, {"$inc": {"xp": 50, "total_workouts": 1}})
    return {k: v for k, v in log.items() if k != "_id"}

@api_router.get("/workouts/history")
async def get_workout_history(user: User = Depends(get_current_user)):
    logs = await db.workout_logs.find({"user_id": user.user_id}, {"_id": 0}).sort("completed_at", -1).limit(20).to_list(20)
    return logs

# ===================== AI COACHING =====================

@api_router.post("/ai/coach")
async def ai_coach(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """AI-powered coaching - generates personalized workout plans and feedback"""
    prompt_type = data.get("type", "workout")  # workout, feedback, nutrition, recovery
    context = data.get("context", "")
    
    prq = await db.prq_metrics.find({"user_id": user.user_id}, {"_id": 0}).sort("recorded_at", -1).limit(1).to_list(1)
    prq_data = prq[0] if prq else {}
    
    system_msg = f"""You are the AI Coach for Final Evolution Lab, an elite athlete training platform. 
You are coaching {user.name}, a level {user.level} {user.role} focused on {user.sport}.

Their PRQ (Performance Readiness Quotient) metrics:
- Overall: {prq_data.get('overall_score', 75)}/100
- Strength: {prq_data.get('strength', 70)}/100
- Speed: {prq_data.get('speed', 75)}/100  
- Endurance: {prq_data.get('endurance', 80)}/100
- Agility: {prq_data.get('agility', 72)}/100
- Power: {prq_data.get('power', 68)}/100
- Flexibility: {prq_data.get('flexibility', 78)}/100
- Recovery: {prq_data.get('recovery', 82)}/100
- Mental: {prq_data.get('mental', 76)}/100

Provide expert, concise coaching advice. Be direct and actionable. Use performance data to personalize recommendations.
Format responses with clear sections using markdown. Keep responses focused and under 300 words."""

    try:
        chat = LlmChat(api_key=EMERGENT_KEY, session_id=f"coach_{user.user_id}_{uuid.uuid4().hex[:8]}", system_message=system_msg)
        chat.with_model("openai", "gpt-5.2")
        
        user_prompt = context if context else f"Generate a personalized {prompt_type} plan for me."
        response = await chat.send_message(UserMessage(text=user_prompt))
        
        # Save to chat history
        await db.ai_chat_history.insert_one({
            "user_id": user.user_id, "type": "coach", "prompt": user_prompt,
            "response": response, "model": "gpt-5.2",
            "created_at": datetime.now(timezone.utc).isoformat()
        })
        
        return {"response": response, "model": "gpt-5.2", "type": prompt_type}
    except Exception as e:
        logger.error(f"AI Coach error: {e}")
        return {"response": get_fallback_coaching(prompt_type, user.sport), "model": "fallback", "type": prompt_type}

@api_router.post("/ai/chat")
async def ai_chat(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Multi-model AI chat assistant"""
    message = data.get("message", "")
    model_choice = data.get("model", "gpt-5.2")
    conversation_id = data.get("conversation_id", str(uuid.uuid4()))
    
    if not message:
        raise HTTPException(status_code=400, detail="Message required")
    
    # Get conversation history
    history = await db.ai_conversations.find(
        {"conversation_id": conversation_id, "user_id": user.user_id}, {"_id": 0}
    ).sort("created_at", 1).limit(20).to_list(20)
    
    system_msg = f"""You are the FEL AI Assistant for Final Evolution Lab - the athlete operating system.
You help {user.name} with training, nutrition, recovery, sports science, game strategy, and athletic development.
Be knowledgeable, supportive, and data-driven. Reference their PRQ score of {user.prq_score}/100 and level {user.level} when relevant.
Keep responses concise and actionable."""

    try:
        provider, model_name = get_model_config(model_choice)
        chat = LlmChat(api_key=EMERGENT_KEY, session_id=f"chat_{conversation_id}", system_message=system_msg)
        chat.with_model(provider, model_name)
        
        # Send previous messages for context
        for h in history[-10:]:
            await chat.send_message(UserMessage(text=h["user_message"]))
        
        response = await chat.send_message(UserMessage(text=message))
        
        await db.ai_conversations.insert_one({
            "conversation_id": conversation_id, "user_id": user.user_id,
            "user_message": message, "ai_response": response, "model": model_choice,
            "created_at": datetime.now(timezone.utc).isoformat()
        })
        
        return {"response": response, "model": model_choice, "conversation_id": conversation_id}
    except Exception as e:
        logger.error(f"AI Chat error: {e}")
        return {"response": "I'm having trouble connecting right now. Please try again in a moment.", "model": "fallback", "conversation_id": conversation_id}

def get_model_config(model_choice):
    configs = {
        "gpt-5.2": ("openai", "gpt-5.2"),
        "claude": ("anthropic", "claude-sonnet-4-5-20250929"),
        "gemini": ("gemini", "gemini-3-flash-preview"),
    }
    return configs.get(model_choice, ("openai", "gpt-5.2"))

def get_fallback_coaching(prompt_type, sport):
    fallbacks = {
        "workout": f"**Today's {sport.title()} Workout**\n\n1. **Warm-Up** (10 min): Dynamic stretching, light jog\n2. **Main Set** (25 min): Sport-specific drills\n3. **Strength** (10 min): Core and compound movements\n4. **Cool Down** (5 min): Static stretching\n\n*Focus on form over intensity today.*",
        "feedback": "**Performance Review**\n\nYour consistency is building a strong foundation. Focus areas:\n- Increase flexibility training\n- Add more sport-specific agility work\n- Recovery between sessions is good\n\n*Keep pushing, you're on track.*",
        "nutrition": "**Nutrition Guide**\n\n- **Pre-workout**: Complex carbs + protein (2hrs before)\n- **During**: Hydration with electrolytes\n- **Post-workout**: Protein shake within 30min\n- **Daily**: 1.6-2.2g protein per kg bodyweight\n\n*Stay hydrated throughout the day.*",
        "recovery": "**Recovery Protocol**\n\n1. **Foam Rolling**: 10 minutes targeting worked muscles\n2. **Cold/Hot Contrast**: 3 cycles of 1min cold / 3min warm\n3. **Sleep**: Target 8+ hours tonight\n4. **Nutrition**: Anti-inflammatory foods\n\n*Recovery is where gains happen.*"
    }
    return fallbacks.get(prompt_type, fallbacks["workout"])

# ===================== GAME MODES =====================

@api_router.get("/games/modes")
async def get_game_modes():
    return get_seeded_game_modes()

@api_router.get("/games/modes/{mode_id}")
async def get_game_mode(mode_id: str):
    for mode in get_seeded_game_modes():
        if mode["id"] == mode_id:
            return mode
    raise HTTPException(status_code=404, detail="Game mode not found")

@api_router.post("/games/session")
async def create_game_session(data: Dict[str, Any], user: User = Depends(get_current_user)):
    session = {
        "id": str(uuid.uuid4()), "user_id": user.user_id, "mode_id": data.get("mode_id"),
        "score": data.get("score", 0), "duration_seconds": data.get("duration_seconds", 0),
        "stats": data.get("stats", {}), "completed": data.get("completed", False),
        "created_at": datetime.now(timezone.utc).isoformat()
    }
    await db.game_sessions.insert_one(session)
    xp = max(10, session["score"] // 5)
    await db.users.update_one({"user_id": user.user_id}, {"$inc": {"xp": xp}})
    return {"session": {k: v for k, v in session.items() if k != "_id"}, "xp_earned": xp}

@api_router.get("/games/history")
async def get_game_history(user: User = Depends(get_current_user)):
    sessions = await db.game_sessions.find({"user_id": user.user_id}, {"_id": 0}).sort("created_at", -1).limit(20).to_list(20)
    return sessions

def get_seeded_game_modes():
    return [
        {"id": "basketball_h2h", "name": "Street 1v1", "display_name": "Street · 1v1", "venue": "Venice Beach", "category": "Basketball", "description": "Head-to-head street basketball — timed scoring challenge", "image_url": "https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800", "player_count": "1v1", "duration": "10 min", "difficulty": "Intermediate", "playable": True, "game_type": "shooting"},
        {"id": "basketball_dunk", "name": "Dunk Contest", "display_name": "Dunk Contest", "venue": "Venice Beach", "category": "Basketball", "description": "Execute dunks with timing precision for maximum style points", "image_url": "https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=800", "player_count": "1", "duration": "5 min", "difficulty": "Advanced", "playable": True, "game_type": "timing"},
        {"id": "basketball_3v3", "name": "Street 3v3", "display_name": "Street · 3v3", "venue": "Venice Beach", "category": "Basketball", "description": "Team-based street basketball strategy", "image_url": "https://images.unsplash.com/photo-1519861531473-9200262188bf?w=800", "player_count": "3v3", "duration": "15 min", "difficulty": "Intermediate", "playable": True, "game_type": "strategy"},
        {"id": "karate_h2h", "name": "Karate 1v1", "display_name": "Karate · 1v1", "venue": "Dojo", "category": "Combat", "description": "Traditional karate combat — strike, block, counter", "image_url": "https://images.unsplash.com/photo-1555597673-b21d5c935865?w=800", "player_count": "1v1", "duration": "5 min", "difficulty": "Intermediate", "playable": True, "game_type": "combat"},
        {"id": "karate_endless", "name": "Karate Endless", "display_name": "Karate · Endless", "venue": "Dojo", "category": "Combat", "description": "Survive endless waves — test your stamina", "image_url": "https://images.unsplash.com/photo-1564415315949-7a0c4c73aab4?w=800", "player_count": "1", "duration": "Unlimited", "difficulty": "Expert", "playable": True, "game_type": "endurance"},
        {"id": "baseball", "name": "Baseball", "display_name": "Baseball · Ballpark", "venue": "Baseball Park", "category": "Field", "description": "Hit pitches with perfect timing and aim", "image_url": "https://images.unsplash.com/photo-1566577739112-5180d4bf9390?w=800", "player_count": "1v1", "duration": "20 min", "difficulty": "Intermediate", "playable": True, "game_type": "timing"},
        {"id": "football", "name": "Football", "display_name": "Football · Kick Return", "venue": "Gridiron", "category": "Field", "description": "Navigate the field and score touchdowns", "image_url": "https://images.unsplash.com/photo-1566577134770-3d85bb3a9cc4?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Intermediate", "playable": True, "game_type": "reflex"},
        {"id": "soccer", "name": "Soccer", "display_name": "Soccer · Stadium", "venue": "Soccer Stadium", "category": "Field", "description": "Precision shooting and penalty kicks", "image_url": "https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=800", "player_count": "1v1", "duration": "15 min", "difficulty": "Intermediate", "playable": True, "game_type": "shooting"},
        {"id": "golf", "name": "Golf", "display_name": "Golf · Links", "venue": "Links", "category": "Precision", "description": "Precision putting and driving challenges", "image_url": "https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=800", "player_count": "1-4", "duration": "30 min", "difficulty": "Beginner", "playable": True, "game_type": "precision"},
        {"id": "tennis", "name": "Tennis", "display_name": "Tennis · Court", "venue": "Tennis Court", "category": "Court", "description": "Rally timing and shot placement", "image_url": "https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?w=800", "player_count": "1v1", "duration": "15 min", "difficulty": "Intermediate", "playable": True, "game_type": "reflex"},
        {"id": "volleyball", "name": "Volleyball", "display_name": "Volleyball · Sand", "venue": "Sand Court", "category": "Court", "description": "Beach volleyball timing and reactions", "image_url": "https://images.unsplash.com/photo-1612872087720-bb876e2e67d1?w=800", "player_count": "2v2", "duration": "15 min", "difficulty": "Intermediate", "playable": True, "game_type": "reflex"},
        {"id": "gymnastics", "name": "Gymnastics", "display_name": "Gymnastics · Floor", "venue": "Training Floor", "category": "Performance", "description": "Execute routines with perfect timing", "image_url": "https://images.unsplash.com/photo-1566838616631-f2618f74a6a2?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Advanced", "playable": True, "game_type": "timing"},
        {"id": "brain_brawl", "name": "Brain Brawl", "display_name": "Academy · Brain Brawl", "venue": "Neuro Arena", "category": "Academy", "description": "Cognitive training for peak decision-making", "image_url": "https://images.unsplash.com/photo-1559757175-5700dde675bc?w=800", "player_count": "1", "duration": "5 min", "difficulty": "Variable", "playable": True, "game_type": "quiz"},
        {"id": "surfing", "name": "Surfing", "display_name": "Surf · Line", "venue": "Venice Beach", "category": "Board", "description": "Ride waves with balance and timing", "image_url": "https://images.unsplash.com/photo-1502680390469-be75c86b636f?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Intermediate", "playable": True, "game_type": "balance"},
        {"id": "skateboarding", "name": "Skateboarding", "display_name": "Skate · Park", "venue": "Skate Park", "category": "Board", "description": "Land tricks with precise timing combos", "image_url": "https://images.unsplash.com/photo-1547447134-cd3f5c716030?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Intermediate", "playable": True, "game_type": "timing"},
        {"id": "snowboarding", "name": "Snowboarding", "display_name": "Snow · Line", "venue": "Mountain", "category": "Board", "description": "Navigate slopes and land aerial tricks", "image_url": "https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Intermediate", "playable": True, "game_type": "reflex"},
        {"id": "market_browse", "name": "Sovereign Shop", "display_name": "Sovereign Shop", "venue": "Marketplace", "category": "Shop", "description": "Browse and purchase creator cards and gear", "image_url": "https://images.unsplash.com/photo-1607082349566-187342175e2f?w=800", "player_count": "1", "duration": "Unlimited", "difficulty": "None", "playable": False, "game_type": "shop"}
    ]

# ===================== CREATOR CARDS =====================

@api_router.get("/cards")
async def get_creator_cards(category: Optional[str] = None):
    cards = await db.creator_cards.find({} if not category else {"sport": category}, {"_id": 0}).to_list(100)
    if not cards:
        return get_seeded_creator_cards()
    return cards

@api_router.get("/cards/{card_id}")
async def get_card(card_id: str):
    card = await db.creator_cards.find_one({"id": card_id}, {"_id": 0})
    if not card:
        for c in get_seeded_creator_cards():
            if c["id"] == card_id:
                return c
        raise HTTPException(status_code=404, detail="Card not found")
    return card

@api_router.post("/cards/purchase/{card_id}")
async def purchase_card(card_id: str, user: User = Depends(get_current_user)):
    return {"message": "Card purchased", "card_id": card_id}

def get_seeded_creator_cards():
    return [
        {"id": "card_elijah", "creator_id": "elijah_bonds", "name": "Elijah Bonds", "title": "Venice Beach Legend", "sport": "basketball", "tier": "featured", "style": "legendary", "image_url": "https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=600", "bio": "Professional basketball player and trainer from Venice Beach. Known for explosive dunks and creative ball handling.", "signature_moves": ["Magic Reveal Dunk", "Venice Crossover", "Beach Body Fadeaway"], "highlights": [{"title": "Venice Dunk", "video_url": "#"}, {"title": "Street 1v1 Finals", "video_url": "#"}], "challenges": [{"name": "Dunk Master", "description": "Score 10 dunks", "reward": 500}, {"name": "Crossover King", "description": "Complete 50 crossovers", "reward": 300}], "stats": {"games": 1250, "wins": 890, "dunks": 3400}, "price": 99.99, "for_sale": True},
        {"id": "card_amir", "creator_id": "amir_smith", "name": "Amir Smith", "title": "Combat Specialist", "sport": "karate", "tier": "featured", "style": "holographic", "image_url": "https://images.unsplash.com/photo-1555597673-b21d5c935865?w=600", "bio": "Mixed martial artist and karate champion. Hampton/Metz pro with international tournament experience.", "signature_moves": ["Shadow Strike", "Iron Fist Combo", "Dragon Sweep"], "highlights": [{"title": "Championship Finals", "video_url": "#"}, {"title": "Training Montage", "video_url": "#"}], "challenges": [{"name": "Combo Master", "description": "Land 100 combos", "reward": 400}, {"name": "Perfect Block", "description": "Block 50 attacks", "reward": 250}], "stats": {"matches": 320, "wins": 285, "knockouts": 120}, "price": 79.99, "for_sale": True},
        {"id": "card_eric", "creator_id": "eric_nash", "name": "Eric Nash", "title": "Multi-Sport Coach", "sport": "training", "tier": "verified", "style": "premium", "image_url": "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600", "bio": "Venice Beach coach specializing in athletic development across multiple sports.", "signature_moves": ["Foundation Flow", "Power Circuit", "Speed Series"], "highlights": [{"title": "Athlete Transformation", "video_url": "#"}, {"title": "Beach Training", "video_url": "#"}], "challenges": [{"name": "Train with Eric", "description": "Complete 5 workouts", "reward": 200}, {"name": "Consistency King", "description": "7-day streak", "reward": 350}], "stats": {"athletes_trained": 500, "sessions": 2500, "reviews": 480}, "price": 49.99, "for_sale": True}
    ]

# ===================== COACH ECONOMY =====================

@api_router.get("/coach/available")
async def get_available_coaches():
    coaches = await db.users.find({"role": "coach"}, {"_id": 0}).to_list(50)
    if not coaches:
        return [
            {"user_id": "coach_1", "name": "Coach Williams", "sport": "basketball", "specialty": "Shooting & Ball Handling", "rating": 4.8, "sessions": 250, "rate": 25},
            {"user_id": "coach_2", "name": "Sensei Tanaka", "sport": "karate", "specialty": "Traditional Karate & Self-Defense", "rating": 4.9, "sessions": 180, "rate": 35},
            {"user_id": "coach_3", "name": "Coach Martinez", "sport": "soccer", "specialty": "Footwork & Strategy", "rating": 4.7, "sessions": 320, "rate": 20},
            {"user_id": "coach_4", "name": "Dr. Sarah Chen", "sport": "training", "specialty": "Sports Psychology & Mental Training", "rating": 5.0, "sessions": 150, "rate": 50},
        ]
    return coaches

@api_router.get("/coach/sessions")
async def get_coach_sessions(user: User = Depends(get_current_user)):
    sessions = await db.coach_sessions.find({"$or": [{"coach_id": user.user_id}, {"athlete_id": user.user_id}]}, {"_id": 0}).to_list(100)
    return sessions

@api_router.post("/coach/sessions")
async def create_coach_session(data: Dict[str, Any], user: User = Depends(get_current_user)):
    session = {"id": str(uuid.uuid4()), "athlete_id": user.user_id, "coach_id": data.get("coach_id"), "sport": data.get("sport"), "session_type": data.get("session_type", "training"), "notes": data.get("notes"), "status": "pending", "created_at": datetime.now(timezone.utc).isoformat()}
    await db.coach_sessions.insert_one(session)
    return {k: v for k, v in session.items() if k != "_id"}

@api_router.post("/coach/review")
async def submit_review(data: Dict[str, Any], user: User = Depends(get_current_user)):
    review = {"id": str(uuid.uuid4()), "reviewer_id": user.user_id, "coach_id": data.get("coach_id"), "session_id": data.get("session_id"), "rating": data.get("rating", 5), "feedback": data.get("feedback", ""), "created_at": datetime.now(timezone.utc).isoformat()}
    await db.coach_reviews.insert_one(review)
    return {k: v for k, v in review.items() if k != "_id"}

# ===================== EDUCATION =====================

@api_router.get("/education/courses")
async def get_courses(category: Optional[str] = None):
    return get_seeded_courses(category)

@api_router.post("/education/enroll/{course_id}")
async def enroll_course(course_id: str, user: User = Depends(get_current_user)):
    enrollment = {"id": str(uuid.uuid4()), "user_id": user.user_id, "course_id": course_id, "progress": 0, "enrolled_at": datetime.now(timezone.utc).isoformat()}
    await db.enrollments.insert_one(enrollment)
    return {"message": "Enrolled successfully", "enrollment_id": enrollment["id"]}

@api_router.get("/education/enrolled")
async def get_enrolled(user: User = Depends(get_current_user)):
    enrolled = await db.enrollments.find({"user_id": user.user_id}, {"_id": 0}).to_list(50)
    return enrolled

def get_seeded_courses(category=None):
    courses = [
        {"id": "brain_brawl_101", "title": "Brain Brawl Fundamentals", "category": "brain_brawl", "description": "Master cognitive training techniques for peak athletic performance", "level": "Beginner", "duration_hours": 4, "modules": [{"name": "Reaction Time Training", "duration": "1hr"}, {"name": "Pattern Recognition", "duration": "1hr"}, {"name": "Decision Making Under Pressure", "duration": "2hr"}], "instructor": "Dr. Sarah Chen", "image_url": "https://images.unsplash.com/photo-1559757175-5700dde675bc?w=600", "is_certificate": False, "price": 0},
        {"id": "kinesiology_cert", "title": "Applied Kinesiology Certificate", "category": "kinesiology", "description": "Comprehensive certification in applied kinesiology for athletes and coaches", "level": "Advanced", "duration_hours": 40, "modules": [{"name": "Biomechanics Fundamentals", "duration": "10hr"}, {"name": "Movement Analysis", "duration": "10hr"}, {"name": "Injury Prevention", "duration": "10hr"}, {"name": "Performance Optimization", "duration": "10hr"}], "instructor": "Dr. Michael Torres", "image_url": "https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=600", "is_certificate": True, "price": 299},
        {"id": "stem_sports", "title": "STEM in Sports Science", "category": "stem", "description": "Apply STEM principles to athletic performance and training", "level": "Intermediate", "duration_hours": 20, "modules": [{"name": "Physics of Movement", "duration": "5hr"}, {"name": "Sports Analytics", "duration": "5hr"}, {"name": "Nutrition Science", "duration": "5hr"}, {"name": "Technology in Training", "duration": "5hr"}], "instructor": "Prof. James Wilson", "image_url": "https://images.unsplash.com/photo-1507413245164-6160d8298b31?w=600", "is_certificate": False, "price": 49},
        {"id": "college_prep", "title": "College Prep for Athletes", "category": "common_core", "description": "Academic pathway from Common Core to college readiness", "level": "High School", "duration_hours": 30, "modules": [{"name": "SAT/ACT Prep", "duration": "10hr"}, {"name": "College Essays", "duration": "5hr"}, {"name": "NCAA Eligibility", "duration": "5hr"}, {"name": "Time Management", "duration": "10hr"}], "instructor": "Lisa Anderson", "image_url": "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=600", "is_certificate": False, "price": 79},
        {"id": "advanced_bb", "title": "Brain Brawl: Advanced Tactics", "category": "brain_brawl", "description": "Advanced cognitive training with real-time decision making under pressure scenarios", "level": "Advanced", "duration_hours": 8, "modules": [{"name": "Rapid Pattern Analysis", "duration": "2hr"}, {"name": "Multi-variable Decision Making", "duration": "3hr"}, {"name": "Stress Inoculation Training", "duration": "3hr"}], "instructor": "Dr. Sarah Chen", "image_url": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600", "is_certificate": True, "price": 99},
    ]
    if category:
        return [c for c in courses if c["category"] == category]
    return courses

# ===================== BRAIN BRAWL =====================

@api_router.get("/brain-brawl/questions")
async def get_brain_brawl_questions(category: str = "all", count: int = 10):
    return get_seeded_questions(category, count)

@api_router.post("/brain-brawl/submit")
async def submit_brain_brawl(data: Dict[str, Any], user: User = Depends(get_current_user)):
    session = {"id": str(uuid.uuid4()), "user_id": user.user_id, "mode": data.get("mode", "quick_fire"), "questions_total": data.get("questions_total", 10), "questions_correct": data.get("questions_correct", 0), "time_taken_seconds": data.get("time_taken_seconds", 0), "category": data.get("category", "sports_iq"), "score": data.get("score", 0), "completed_at": datetime.now(timezone.utc).isoformat()}
    await db.brain_brawl_sessions.insert_one(session)
    xp = session["score"] // 10
    await db.users.update_one({"user_id": user.user_id}, {"$inc": {"xp": xp}})
    return {"session": {k: v for k, v in session.items() if k != "_id"}, "xp_earned": xp}

def get_seeded_questions(category, count):
    all_questions = [
        {"id": "q1", "question": "In basketball, how many points is a shot from beyond the arc worth?", "options": ["2", "3", "4", "1"], "correct": 1, "category": "sports_iq", "difficulty": "easy"},
        {"id": "q2", "question": "What is the standard length of an NBA quarter?", "options": ["10 min", "12 min", "15 min", "8 min"], "correct": 1, "category": "sports_iq", "difficulty": "easy"},
        {"id": "q3", "question": "In karate, what does 'dan' refer to?", "options": ["Stance", "Belt rank", "Kata name", "Dojo"], "correct": 1, "category": "sports_iq", "difficulty": "medium"},
        {"id": "q4", "question": "How many players are on a soccer field per team?", "options": ["9", "10", "11", "12"], "correct": 2, "category": "sports_iq", "difficulty": "easy"},
        {"id": "q5", "question": "What muscle group does the deadlift primarily target?", "options": ["Chest", "Posterior chain", "Shoulders", "Arms"], "correct": 1, "category": "kinesiology", "difficulty": "medium"},
        {"id": "q6", "question": "What is VO2 max a measure of?", "options": ["Heart rate", "Max oxygen consumption", "Blood pressure", "Muscle strength"], "correct": 1, "category": "kinesiology", "difficulty": "medium"},
        {"id": "q7", "question": "In tennis, what is a score of 40-40 called?", "options": ["Match point", "Deuce", "Advantage", "Break point"], "correct": 1, "category": "sports_iq", "difficulty": "easy"},
        {"id": "q8", "question": "What is the fastest 100m sprint time ever recorded?", "options": ["9.58s", "9.63s", "9.69s", "9.72s"], "correct": 0, "category": "sports_iq", "difficulty": "hard"},
        {"id": "q9", "question": "Which energy system is primarily used in sprinting?", "options": ["Aerobic", "ATP-PC (Phosphagen)", "Glycolytic", "Oxidative"], "correct": 1, "category": "kinesiology", "difficulty": "hard"},
        {"id": "q10", "question": "What is periodization in training?", "options": ["Rest periods", "Systematic planning of training phases", "Diet cycles", "Sleep patterns"], "correct": 1, "category": "kinesiology", "difficulty": "medium"},
        {"id": "q11", "question": "What's the diameter of a basketball rim in inches?", "options": ["16", "18", "20", "22"], "correct": 1, "category": "sports_iq", "difficulty": "hard"},
        {"id": "q12", "question": "Which vitamin is crucial for bone health in athletes?", "options": ["Vitamin A", "Vitamin B12", "Vitamin D", "Vitamin E"], "correct": 2, "category": "kinesiology", "difficulty": "medium"},
        {"id": "q13", "question": "In football, how many yards is a first down?", "options": ["5", "8", "10", "15"], "correct": 2, "category": "sports_iq", "difficulty": "easy"},
        {"id": "q14", "question": "What does HIIT stand for?", "options": ["High Impact Interval Training", "High Intensity Interval Training", "High Intensity Isometric Training", "High Impact Isometric Training"], "correct": 1, "category": "kinesiology", "difficulty": "easy"},
        {"id": "q15", "question": "Which joint is most commonly injured in basketball?", "options": ["Shoulder", "Ankle", "Knee", "Wrist"], "correct": 1, "category": "kinesiology", "difficulty": "medium"},
    ]
    filtered = [q for q in all_questions if q["category"] == category or category == "all"]
    random.shuffle(filtered)
    return filtered[:count]

# ===================== LEADERBOARD =====================

@api_router.get("/leaderboard")
async def get_leaderboard(game_mode: Optional[str] = None, limit: int = 20):
    leaders = await db.users.find({}, {"_id": 0, "user_id": 1, "name": 1, "prq_score": 1, "level": 1, "xp": 1, "sport": 1, "picture": 1}).sort("prq_score", -1).limit(limit).to_list(limit)
    if not leaders:
        return [
            {"rank": 1, "user_id": "u1", "name": "Elijah Bonds", "prq_score": 95.5, "level": 25, "xp": 12500, "sport": "basketball"},
            {"rank": 2, "user_id": "u2", "name": "Amir Smith", "prq_score": 92.3, "level": 22, "xp": 11000, "sport": "karate"},
            {"rank": 3, "user_id": "u3", "name": "Eric Nash", "prq_score": 89.7, "level": 20, "xp": 10000, "sport": "training"},
            {"rank": 4, "user_id": "u4", "name": "Maya Johnson", "prq_score": 87.4, "level": 18, "xp": 9000, "sport": "soccer"},
            {"rank": 5, "user_id": "u5", "name": "Derek Wu", "prq_score": 85.1, "level": 17, "xp": 8500, "sport": "tennis"},
            {"rank": 6, "user_id": "u6", "name": "Sofia Reyes", "prq_score": 83.8, "level": 16, "xp": 8000, "sport": "gymnastics"},
            {"rank": 7, "user_id": "u7", "name": "Jake Thompson", "prq_score": 81.2, "level": 15, "xp": 7500, "sport": "football"},
            {"rank": 8, "user_id": "u8", "name": "Kai Chen", "prq_score": 79.6, "level": 14, "xp": 7000, "sport": "surfing"},
        ]
    return [{"rank": i+1, **l} for i, l in enumerate(leaders)]

@api_router.get("/stats/overview")
async def get_stats_overview(user: User = Depends(get_current_user)):
    workouts = await db.workout_logs.count_documents({"user_id": user.user_id})
    sessions = await db.coach_sessions.count_documents({"athlete_id": user.user_id})
    brawls = await db.brain_brawl_sessions.count_documents({"user_id": user.user_id})
    games = await db.game_sessions.count_documents({"user_id": user.user_id})
    return {"total_workouts": workouts, "coaching_sessions": sessions, "brain_brawl_sessions": brawls, "game_sessions": games, "prq_score": user.prq_score, "level": user.level, "xp": user.xp, "streak_days": user.streak_days}

# ===================== PIXEL STREAMING =====================

@api_router.get("/streaming/status")
async def get_streaming_status():
    return {"available": False, "server_url": None, "message": "Pixel Streaming server not connected. Connect your UE5 server to enable live game streaming.", "supported_modes": ["basketball_h2h", "basketball_dunk", "karate_h2h", "soccer"]}

@api_router.post("/streaming/connect")
async def connect_streaming(data: Dict[str, Any], user: User = Depends(get_current_user)):
    server_url = data.get("server_url")
    if not server_url:
        raise HTTPException(status_code=400, detail="server_url required")
    return {"status": "connecting", "server_url": server_url, "session_id": str(uuid.uuid4())}

# ===================== ROOT =====================

@api_router.get("/")
async def root():
    return {"message": "Final Evolution Lab API", "version": "1.0.0"}

@api_router.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}

app.include_router(api_router)
app.add_middleware(CORSMiddleware, allow_credentials=True, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
