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
from datetime import datetime, timezone, timedelta
import httpx

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# Create the main app
app = FastAPI(title="Final Evolution Lab API")

# Create router with /api prefix
api_router = APIRouter(prefix="/api")

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# ===================== MODELS =====================

class User(BaseModel):
    model_config = ConfigDict(extra="ignore")
    user_id: str
    email: str
    name: str
    picture: Optional[str] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    # Profile data
    avatar_url: Optional[str] = None
    bio: Optional[str] = None
    role: str = "athlete"  # athlete, coach, admin
    prq_score: float = 75.0
    level: int = 1
    xp: int = 0

class UserSession(BaseModel):
    user_id: str
    session_token: str
    expires_at: datetime
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class PRQMetrics(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    overall_score: float = 75.0
    strength: float = 70.0
    speed: float = 75.0
    endurance: float = 80.0
    agility: float = 72.0
    power: float = 68.0
    flexibility: float = 78.0
    recovery: float = 82.0
    mental: float = 76.0
    recorded_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class HealthMetrics(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    heart_rate: Optional[int] = None
    sleep_hours: Optional[float] = None
    calories_burned: Optional[int] = None
    steps: Optional[int] = None
    hydration_ml: Optional[int] = None
    stress_level: Optional[int] = None
    readiness_score: Optional[float] = None
    recorded_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class WorkoutPlan(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    name: str
    description: Optional[str] = None
    sport: str
    difficulty: str = "intermediate"
    duration_minutes: int = 45
    exercises: List[Dict[str, Any]] = []
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))
    is_active: bool = True

class CreatorCard(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    creator_id: str
    name: str
    title: str
    sport: str
    tier: str = "community"  # featured, verified, community
    style: str = "premium"  # legendary, holographic, premium
    image_url: str
    bio: Optional[str] = None
    signature_moves: List[str] = []
    highlights: List[Dict[str, str]] = []
    challenges: List[Dict[str, Any]] = []
    stats: Dict[str, int] = {}
    price: float = 0.0
    for_sale: bool = False
    owner_id: Optional[str] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class GameMode(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str
    name: str
    display_name: str
    venue: str
    category: str
    description: str
    image_url: str
    player_count: str
    duration: str
    difficulty: str
    is_active: bool = True

class CoachSession(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    coach_id: str
    athlete_id: str
    sport: str
    session_type: str  # training, review, critique
    notes: Optional[str] = None
    rating: Optional[int] = None
    credits_earned: float = 0.0
    status: str = "pending"  # pending, completed, cancelled
    scheduled_at: Optional[datetime] = None
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class Course(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    title: str
    category: str  # brain_brawl, common_core, stem, kinesiology
    description: str
    level: str
    duration_hours: int
    modules: List[Dict[str, Any]] = []
    instructor: str
    image_url: str
    is_certificate: bool = False
    price: float = 0.0
    created_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

class BrainBrawlSession(BaseModel):
    model_config = ConfigDict(extra="ignore")
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    user_id: str
    mode: str  # quick_fire, endurance, challenge
    questions_total: int = 10
    questions_correct: int = 0
    time_taken_seconds: int = 0
    category: str = "sports_iq"
    score: int = 0
    completed_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))

# ===================== AUTH HELPERS =====================

async def get_current_user(request: Request) -> User:
    """Get current user from session token"""
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
    """Exchange session_id for session_token"""
    data = await request.json()
    session_id = data.get("session_id")
    
    if not session_id:
        raise HTTPException(status_code=400, detail="session_id required")
    
    async with httpx.AsyncClient() as client:
        resp = await client.get(
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
            {"$set": {
                "name": session_data["name"],
                "picture": session_data.get("picture")
            }}
        )
    else:
        user_doc = {
            "user_id": user_id,
            "email": session_data["email"],
            "name": session_data["name"],
            "picture": session_data.get("picture"),
            "created_at": datetime.now(timezone.utc).isoformat(),
            "role": "athlete",
            "prq_score": 75.0,
            "level": 1,
            "xp": 0
        }
        await db.users.insert_one(user_doc)
        # Initialize PRQ metrics for new user
        prq = PRQMetrics(user_id=user_id)
        prq_doc = prq.model_dump()
        prq_doc['recorded_at'] = prq_doc['recorded_at'].isoformat()
        await db.prq_metrics.insert_one(prq_doc)
    
    session_token = session_data.get("session_token", f"sess_{uuid.uuid4().hex}")
    expires_at = datetime.now(timezone.utc) + timedelta(days=7)
    
    await db.user_sessions.insert_one({
        "user_id": user_id,
        "session_token": session_token,
        "expires_at": expires_at.isoformat(),
        "created_at": datetime.now(timezone.utc).isoformat()
    })
    
    response.set_cookie(
        key="session_token",
        value=session_token,
        httponly=True,
        secure=True,
        samesite="none",
        path="/",
        max_age=7 * 24 * 60 * 60
    )
    
    user = await db.users.find_one({"user_id": user_id}, {"_id": 0})
    return user

@api_router.get("/auth/me")
async def get_me(user: User = Depends(get_current_user)):
    """Get current user"""
    return user.model_dump()

@api_router.post("/auth/logout")
async def logout(request: Request, response: Response):
    """Logout user"""
    session_token = request.cookies.get("session_token")
    if session_token:
        await db.user_sessions.delete_one({"session_token": session_token})
    response.delete_cookie(key="session_token", path="/")
    return {"message": "Logged out"}

# ===================== PRQ & SYSTEM SCAN ROUTES =====================

@api_router.get("/prq/metrics")
async def get_prq_metrics(user: User = Depends(get_current_user)):
    """Get user's PRQ metrics"""
    metrics = await db.prq_metrics.find(
        {"user_id": user.user_id}, {"_id": 0}
    ).sort("recorded_at", -1).limit(1).to_list(1)
    
    if not metrics:
        prq = PRQMetrics(user_id=user.user_id)
        prq_doc = prq.model_dump()
        prq_doc['recorded_at'] = prq_doc['recorded_at'].isoformat()
        await db.prq_metrics.insert_one(prq_doc)
        return prq.model_dump()
    
    return metrics[0]

@api_router.post("/prq/metrics")
async def update_prq_metrics(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Update PRQ metrics"""
    prq = PRQMetrics(user_id=user.user_id, **data)
    prq_doc = prq.model_dump()
    prq_doc['recorded_at'] = prq_doc['recorded_at'].isoformat()
    await db.prq_metrics.insert_one(prq_doc)
    
    # Update user's overall PRQ score
    await db.users.update_one(
        {"user_id": user.user_id},
        {"$set": {"prq_score": prq.overall_score}}
    )
    return prq.model_dump()

@api_router.get("/health/metrics")
async def get_health_metrics(user: User = Depends(get_current_user)):
    """Get user's health metrics"""
    metrics = await db.health_metrics.find(
        {"user_id": user.user_id}, {"_id": 0}
    ).sort("recorded_at", -1).limit(7).to_list(7)
    return metrics

@api_router.post("/health/metrics")
async def add_health_metrics(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Add health metrics"""
    health = HealthMetrics(user_id=user.user_id, **data)
    health_doc = health.model_dump()
    health_doc['recorded_at'] = health_doc['recorded_at'].isoformat()
    await db.health_metrics.insert_one(health_doc)
    return health.model_dump()

# ===================== WORKOUT ROUTES =====================

@api_router.get("/workouts")
async def get_workouts(user: User = Depends(get_current_user)):
    """Get user's workout plans"""
    workouts = await db.workouts.find(
        {"user_id": user.user_id, "is_active": True}, {"_id": 0}
    ).to_list(100)
    return workouts

@api_router.post("/workouts")
async def create_workout(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Create workout plan"""
    workout = WorkoutPlan(user_id=user.user_id, **data)
    workout_doc = workout.model_dump()
    workout_doc['created_at'] = workout_doc['created_at'].isoformat()
    await db.workouts.insert_one(workout_doc)
    return workout.model_dump()

@api_router.get("/workouts/recommended")
async def get_recommended_workouts(user: User = Depends(get_current_user)):
    """Get AI-recommended workouts based on PRQ"""
    # Fetch user's PRQ to customize recommendations
    prq = await db.prq_metrics.find_one({"user_id": user.user_id}, {"_id": 0})
    
    # Return pre-defined recommended workouts
    recommendations = [
        {
            "id": "rec_1",
            "name": "Power Development",
            "sport": "basketball",
            "difficulty": "intermediate",
            "duration_minutes": 45,
            "focus": "strength",
            "exercises": [
                {"name": "Box Jumps", "sets": 4, "reps": 8},
                {"name": "Medicine Ball Slams", "sets": 3, "reps": 12},
                {"name": "Squat Jumps", "sets": 4, "reps": 10}
            ]
        },
        {
            "id": "rec_2",
            "name": "Speed & Agility",
            "sport": "soccer",
            "difficulty": "advanced",
            "duration_minutes": 30,
            "focus": "agility",
            "exercises": [
                {"name": "Ladder Drills", "sets": 3, "reps": "30s"},
                {"name": "Cone Sprints", "sets": 5, "reps": "20m"},
                {"name": "Defensive Slides", "sets": 4, "reps": "15s"}
            ]
        },
        {
            "id": "rec_3",
            "name": "Recovery Flow",
            "sport": "general",
            "difficulty": "beginner",
            "duration_minutes": 20,
            "focus": "recovery",
            "exercises": [
                {"name": "Foam Rolling", "sets": 1, "reps": "10min"},
                {"name": "Dynamic Stretching", "sets": 2, "reps": "5min"},
                {"name": "Breathing Exercises", "sets": 1, "reps": "5min"}
            ]
        }
    ]
    return recommendations

# ===================== CREATOR CARDS ROUTES =====================

@api_router.get("/cards")
async def get_creator_cards(category: Optional[str] = None):
    """Get all creator cards"""
    query = {}
    if category:
        query["sport"] = category
    cards = await db.creator_cards.find(query, {"_id": 0}).to_list(100)
    
    if not cards:
        # Return seeded cards
        return get_seeded_creator_cards()
    return cards

@api_router.get("/cards/{card_id}")
async def get_card(card_id: str):
    """Get single creator card"""
    card = await db.creator_cards.find_one({"id": card_id}, {"_id": 0})
    if not card:
        # Check seeded cards
        seeded = get_seeded_creator_cards()
        for c in seeded:
            if c["id"] == card_id:
                return c
        raise HTTPException(status_code=404, detail="Card not found")
    return card

@api_router.get("/cards/market")
async def get_marketplace_cards():
    """Get cards available for sale"""
    cards = await db.creator_cards.find({"for_sale": True}, {"_id": 0}).to_list(100)
    return cards

@api_router.post("/cards/purchase/{card_id}")
async def purchase_card(card_id: str, user: User = Depends(get_current_user)):
    """Purchase a creator card"""
    card = await db.creator_cards.find_one({"id": card_id, "for_sale": True}, {"_id": 0})
    if not card:
        raise HTTPException(status_code=404, detail="Card not available")
    
    await db.creator_cards.update_one(
        {"id": card_id},
        {"$set": {"owner_id": user.user_id, "for_sale": False}}
    )
    return {"message": "Card purchased", "card_id": card_id}

def get_seeded_creator_cards():
    """Return pre-seeded creator cards"""
    return [
        {
            "id": "card_elijah",
            "creator_id": "elijah_bonds",
            "name": "Elijah Bonds",
            "title": "Venice Beach Legend",
            "sport": "basketball",
            "tier": "featured",
            "style": "legendary",
            "image_url": "https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=600",
            "bio": "Professional basketball player and trainer from Venice Beach. Known for explosive dunks and creative ball handling.",
            "signature_moves": ["Magic Reveal Dunk", "Venice Crossover", "Beach Body Fadeaway"],
            "highlights": [
                {"title": "Venice Dunk", "video_url": "#"},
                {"title": "Street 1v1 Finals", "video_url": "#"}
            ],
            "challenges": [
                {"name": "Dunk Master", "description": "Score 10 dunks", "reward": 500},
                {"name": "Crossover King", "description": "Complete 50 crossovers", "reward": 300}
            ],
            "stats": {"games": 1250, "wins": 890, "dunks": 3400},
            "price": 99.99,
            "for_sale": True
        },
        {
            "id": "card_amir",
            "creator_id": "amir_smith",
            "name": "Amir Smith",
            "title": "Combat Specialist",
            "sport": "karate",
            "tier": "featured",
            "style": "holographic",
            "image_url": "https://images.unsplash.com/photo-1555597673-b21d5c935865?w=600",
            "bio": "Mixed martial artist and karate champion. Hampton/Metz pro with international tournament experience.",
            "signature_moves": ["Shadow Strike", "Iron Fist Combo", "Dragon Sweep"],
            "highlights": [
                {"title": "Championship Finals", "video_url": "#"},
                {"title": "Training Montage", "video_url": "#"}
            ],
            "challenges": [
                {"name": "Combo Master", "description": "Land 100 combos", "reward": 400},
                {"name": "Perfect Block", "description": "Block 50 attacks", "reward": 250}
            ],
            "stats": {"matches": 320, "wins": 285, "knockouts": 120},
            "price": 79.99,
            "for_sale": True
        },
        {
            "id": "card_eric",
            "creator_id": "eric_nash",
            "name": "Eric Nash",
            "title": "Multi-Sport Coach",
            "sport": "training",
            "tier": "verified",
            "style": "premium",
            "image_url": "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=600",
            "bio": "Venice Beach coach specializing in athletic development across multiple sports.",
            "signature_moves": ["Foundation Flow", "Power Circuit", "Speed Series"],
            "highlights": [
                {"title": "Athlete Transformation", "video_url": "#"},
                {"title": "Beach Training", "video_url": "#"}
            ],
            "challenges": [
                {"name": "Train with Eric", "description": "Complete 5 workouts", "reward": 200},
                {"name": "Consistency King", "description": "7-day streak", "reward": 350}
            ],
            "stats": {"athletes_trained": 500, "sessions": 2500, "reviews": 480},
            "price": 49.99,
            "for_sale": True
        }
    ]

# ===================== GAME MODES ROUTES =====================

@api_router.get("/games/modes")
async def get_game_modes():
    """Get all game modes"""
    return get_seeded_game_modes()

@api_router.get("/games/modes/{mode_id}")
async def get_game_mode(mode_id: str):
    """Get single game mode"""
    modes = get_seeded_game_modes()
    for mode in modes:
        if mode["id"] == mode_id:
            return mode
    raise HTTPException(status_code=404, detail="Game mode not found")

def get_seeded_game_modes():
    """Return all 17 game modes"""
    return [
        {"id": "basketball_h2h", "name": "Street 1v1", "display_name": "Street · 1v1", "venue": "Venice Beach", "category": "Basketball", "description": "Head-to-head street basketball action", "image_url": "https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800", "player_count": "1v1", "duration": "10 min", "difficulty": "Intermediate"},
        {"id": "basketball_dunk", "name": "Dunk Contest", "display_name": "Dunk Contest", "venue": "Venice Beach", "category": "Basketball", "description": "Show off your best dunks and aerial moves", "image_url": "https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800", "player_count": "1", "duration": "5 min", "difficulty": "Advanced"},
        {"id": "basketball_3v3", "name": "Street 3v3", "display_name": "Street · 3v3", "venue": "Venice Beach", "category": "Basketball", "description": "Team-based street basketball", "image_url": "https://images.unsplash.com/photo-1519861531473-9200262188bf?w=800", "player_count": "3v3", "duration": "15 min", "difficulty": "Intermediate"},
        {"id": "karate_h2h", "name": "Karate 1v1", "display_name": "Karate · 1v1", "venue": "Dojo", "category": "Combat", "description": "Traditional karate combat", "image_url": "https://images.unsplash.com/photo-1555597673-b21d5c935865?w=800", "player_count": "1v1", "duration": "5 min", "difficulty": "Intermediate"},
        {"id": "karate_endless", "name": "Karate Endless", "display_name": "Karate · Endless", "venue": "Dojo", "category": "Combat", "description": "Survive endless waves of opponents", "image_url": "https://images.unsplash.com/photo-1564415315949-7a0c4c73aab4?w=800", "player_count": "1", "duration": "∞", "difficulty": "Expert"},
        {"id": "baseball", "name": "Baseball", "display_name": "Baseball · Ballpark", "venue": "Baseball Park", "category": "Field", "description": "Classic baseball gameplay", "image_url": "https://images.unsplash.com/photo-1566577739112-5180d4bf9390?w=800", "player_count": "1v1", "duration": "20 min", "difficulty": "Intermediate"},
        {"id": "football", "name": "Football", "display_name": "Football · Kick Return", "venue": "Gridiron", "category": "Field", "description": "Return kicks and score touchdowns", "image_url": "https://images.unsplash.com/photo-1566577134770-3d85bb3a9cc4?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Intermediate"},
        {"id": "soccer", "name": "Soccer", "display_name": "Soccer · Stadium", "venue": "Soccer Stadium", "category": "Field", "description": "Stadium soccer matches", "image_url": "https://images.unsplash.com/photo-1579952363873-27f3bade9f55?w=800", "player_count": "1v1", "duration": "15 min", "difficulty": "Intermediate"},
        {"id": "golf", "name": "Golf", "display_name": "Golf · Links", "venue": "Links", "category": "Precision", "description": "Precision golf on beautiful courses", "image_url": "https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=800", "player_count": "1-4", "duration": "30 min", "difficulty": "Beginner"},
        {"id": "tennis", "name": "Tennis", "display_name": "Tennis · Court", "venue": "Tennis Court", "category": "Court", "description": "Fast-paced tennis matches", "image_url": "https://images.unsplash.com/photo-1595435934249-5df7ed86e1c0?w=800", "player_count": "1v1", "duration": "15 min", "difficulty": "Intermediate"},
        {"id": "volleyball", "name": "Volleyball", "display_name": "Volleyball · Sand", "venue": "Sand Court", "category": "Court", "description": "Beach volleyball action", "image_url": "https://images.unsplash.com/photo-1612872087720-bb876e2e67d1?w=800", "player_count": "2v2", "duration": "15 min", "difficulty": "Intermediate"},
        {"id": "gymnastics", "name": "Gymnastics", "display_name": "Gymnastics · Floor", "venue": "Training Floor", "category": "Performance", "description": "Artistic gymnastics routines", "image_url": "https://images.unsplash.com/photo-1566838616631-f2618f74a6a2?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Advanced"},
        {"id": "brain_brawl", "name": "Brain Brawl", "display_name": "Academy · Brain Brawl", "venue": "Neuro Arena", "category": "Academy", "description": "Cognitive training and sports IQ challenges", "image_url": "https://images.unsplash.com/photo-1559757175-5700dde675bc?w=800", "player_count": "1", "duration": "5 min", "difficulty": "Variable"},
        {"id": "surfing", "name": "Surfing", "display_name": "Surf · Line", "venue": "Venice Beach", "category": "Board", "description": "Ride the waves at Venice Beach", "image_url": "https://images.unsplash.com/photo-1502680390469-be75c86b636f?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Intermediate"},
        {"id": "skateboarding", "name": "Skateboarding", "display_name": "Skate · Park", "venue": "Skate Park", "category": "Board", "description": "Tricks and combos at the skate park", "image_url": "https://images.unsplash.com/photo-1547447134-cd3f5c716030?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Intermediate"},
        {"id": "snowboarding", "name": "Snowboarding", "display_name": "Snow · Line", "venue": "Training Floor", "category": "Board", "description": "Snowboarding down the slopes", "image_url": "https://images.unsplash.com/photo-1551698618-1dfe5d97d256?w=800", "player_count": "1", "duration": "10 min", "difficulty": "Intermediate"},
        {"id": "market_browse", "name": "Sovereign Shop", "display_name": "Sovereign Shop", "venue": "Marketplace", "category": "Shop", "description": "Browse and purchase creator cards", "image_url": "https://images.unsplash.com/photo-1607082349566-187342175e2f?w=800", "player_count": "1", "duration": "∞", "difficulty": "None"}
    ]

# ===================== COACH ECONOMY ROUTES =====================

@api_router.get("/coach/sessions")
async def get_coach_sessions(user: User = Depends(get_current_user)):
    """Get user's coaching sessions"""
    sessions = await db.coach_sessions.find(
        {"$or": [{"coach_id": user.user_id}, {"athlete_id": user.user_id}]},
        {"_id": 0}
    ).to_list(100)
    return sessions

@api_router.post("/coach/sessions")
async def create_coach_session(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Create coaching session"""
    session = CoachSession(athlete_id=user.user_id, **data)
    session_doc = session.model_dump()
    session_doc['created_at'] = session_doc['created_at'].isoformat()
    if session_doc.get('scheduled_at'):
        session_doc['scheduled_at'] = session_doc['scheduled_at'].isoformat()
    await db.coach_sessions.insert_one(session_doc)
    return session.model_dump()

@api_router.get("/coach/available")
async def get_available_coaches():
    """Get available coaches"""
    coaches = await db.users.find({"role": "coach"}, {"_id": 0}).to_list(50)
    if not coaches:
        return [
            {"user_id": "coach_1", "name": "Coach Williams", "sport": "basketball", "rating": 4.8, "sessions": 250},
            {"user_id": "coach_2", "name": "Sensei Tanaka", "sport": "karate", "rating": 4.9, "sessions": 180},
            {"user_id": "coach_3", "name": "Coach Martinez", "sport": "soccer", "rating": 4.7, "sessions": 320}
        ]
    return coaches

# ===================== EDUCATION ROUTES =====================

@api_router.get("/education/courses")
async def get_courses(category: Optional[str] = None):
    """Get available courses"""
    return get_seeded_courses(category)

@api_router.get("/education/courses/{course_id}")
async def get_course(course_id: str):
    """Get single course"""
    courses = get_seeded_courses()
    for course in courses:
        if course["id"] == course_id:
            return course
    raise HTTPException(status_code=404, detail="Course not found")

@api_router.post("/education/enroll/{course_id}")
async def enroll_course(course_id: str, user: User = Depends(get_current_user)):
    """Enroll in a course"""
    enrollment = {
        "id": str(uuid.uuid4()),
        "user_id": user.user_id,
        "course_id": course_id,
        "progress": 0,
        "enrolled_at": datetime.now(timezone.utc).isoformat()
    }
    await db.enrollments.insert_one(enrollment)
    return {"message": "Enrolled successfully", "enrollment_id": enrollment["id"]}

def get_seeded_courses(category: Optional[str] = None):
    """Return seeded courses"""
    courses = [
        {
            "id": "brain_brawl_101",
            "title": "Brain Brawl Fundamentals",
            "category": "brain_brawl",
            "description": "Master cognitive training techniques for peak athletic performance",
            "level": "Beginner",
            "duration_hours": 4,
            "modules": [
                {"name": "Reaction Time Training", "duration": "1hr"},
                {"name": "Pattern Recognition", "duration": "1hr"},
                {"name": "Decision Making Under Pressure", "duration": "2hr"}
            ],
            "instructor": "Dr. Sarah Chen",
            "image_url": "https://images.unsplash.com/photo-1559757175-5700dde675bc?w=600",
            "is_certificate": False,
            "price": 0
        },
        {
            "id": "kinesiology_cert",
            "title": "Applied Kinesiology Certificate",
            "category": "kinesiology",
            "description": "Comprehensive certification in applied kinesiology for athletes and coaches",
            "level": "Advanced",
            "duration_hours": 40,
            "modules": [
                {"name": "Biomechanics Fundamentals", "duration": "10hr"},
                {"name": "Movement Analysis", "duration": "10hr"},
                {"name": "Injury Prevention", "duration": "10hr"},
                {"name": "Performance Optimization", "duration": "10hr"}
            ],
            "instructor": "Dr. Michael Torres",
            "image_url": "https://images.unsplash.com/photo-1576091160550-2173dba999ef?w=600",
            "is_certificate": True,
            "price": 299
        },
        {
            "id": "stem_sports_science",
            "title": "STEM in Sports Science",
            "category": "stem",
            "description": "Apply STEM principles to athletic performance and training",
            "level": "Intermediate",
            "duration_hours": 20,
            "modules": [
                {"name": "Physics of Movement", "duration": "5hr"},
                {"name": "Sports Analytics", "duration": "5hr"},
                {"name": "Nutrition Science", "duration": "5hr"},
                {"name": "Technology in Training", "duration": "5hr"}
            ],
            "instructor": "Prof. James Wilson",
            "image_url": "https://images.unsplash.com/photo-1507413245164-6160d8298b31?w=600",
            "is_certificate": False,
            "price": 49
        },
        {
            "id": "college_prep",
            "title": "College Prep for Athletes",
            "category": "common_core",
            "description": "Academic preparation pathway from Common Core to college readiness",
            "level": "High School",
            "duration_hours": 30,
            "modules": [
                {"name": "SAT/ACT Prep", "duration": "10hr"},
                {"name": "College Essays", "duration": "5hr"},
                {"name": "NCAA Eligibility", "duration": "5hr"},
                {"name": "Time Management", "duration": "10hr"}
            ],
            "instructor": "Lisa Anderson",
            "image_url": "https://images.unsplash.com/photo-1523050854058-8df90110c9f1?w=600",
            "is_certificate": False,
            "price": 79
        }
    ]
    
    if category:
        return [c for c in courses if c["category"] == category]
    return courses

# ===================== BRAIN BRAWL ROUTES =====================

@api_router.get("/brain-brawl/questions")
async def get_brain_brawl_questions(category: str = "sports_iq", count: int = 10):
    """Get Brain Brawl questions"""
    return get_seeded_questions(category, count)

@api_router.post("/brain-brawl/submit")
async def submit_brain_brawl(data: Dict[str, Any], user: User = Depends(get_current_user)):
    """Submit Brain Brawl results"""
    session = BrainBrawlSession(
        user_id=user.user_id,
        mode=data.get("mode", "quick_fire"),
        questions_total=data.get("questions_total", 10),
        questions_correct=data.get("questions_correct", 0),
        time_taken_seconds=data.get("time_taken_seconds", 0),
        category=data.get("category", "sports_iq"),
        score=data.get("score", 0)
    )
    session_doc = session.model_dump()
    session_doc['completed_at'] = session_doc['completed_at'].isoformat()
    await db.brain_brawl_sessions.insert_one(session_doc)
    
    # Award XP
    xp_earned = session.score // 10
    await db.users.update_one(
        {"user_id": user.user_id},
        {"$inc": {"xp": xp_earned}}
    )
    
    return {"session": session.model_dump(), "xp_earned": xp_earned}

def get_seeded_questions(category: str, count: int):
    """Return seeded Brain Brawl questions"""
    questions = [
        {"id": "q1", "question": "In basketball, how many points is a shot from beyond the arc worth?", "options": ["2", "3", "4", "1"], "correct": 1, "category": "sports_iq"},
        {"id": "q2", "question": "What is the standard length of an NBA quarter?", "options": ["10 min", "12 min", "15 min", "8 min"], "correct": 1, "category": "sports_iq"},
        {"id": "q3", "question": "In karate, what does 'dan' refer to?", "options": ["Stance", "Belt rank", "Kata name", "Dojo"], "correct": 1, "category": "sports_iq"},
        {"id": "q4", "question": "How many players are on a soccer field per team?", "options": ["9", "10", "11", "12"], "correct": 2, "category": "sports_iq"},
        {"id": "q5", "question": "What muscle group does the deadlift primarily target?", "options": ["Chest", "Posterior chain", "Shoulders", "Arms"], "correct": 1, "category": "kinesiology"},
        {"id": "q6", "question": "What is VO2 max?", "options": ["Heart rate", "Oxygen consumption", "Blood pressure", "Muscle strength"], "correct": 1, "category": "kinesiology"},
        {"id": "q7", "question": "In tennis, what is a score of 40-40 called?", "options": ["Match point", "Deuce", "Advantage", "Break point"], "correct": 1, "category": "sports_iq"},
        {"id": "q8", "question": "What is the Olympic record for 100m sprint?", "options": ["9.58s", "9.63s", "9.69s", "9.72s"], "correct": 1, "category": "sports_iq"},
        {"id": "q9", "question": "Which energy system is primarily used in sprinting?", "options": ["Aerobic", "ATP-PC", "Glycolytic", "Oxidative"], "correct": 1, "category": "kinesiology"},
        {"id": "q10", "question": "What is periodization in training?", "options": ["Rest periods", "Systematic planning", "Diet cycles", "Sleep patterns"], "correct": 1, "category": "kinesiology"}
    ]
    
    filtered = [q for q in questions if q["category"] == category or category == "all"]
    return filtered[:count]

# ===================== LEADERBOARD & STATS =====================

@api_router.get("/leaderboard")
async def get_leaderboard(game_mode: Optional[str] = None, limit: int = 10):
    """Get leaderboard"""
    pipeline = [
        {"$sort": {"prq_score": -1}},
        {"$limit": limit},
        {"$project": {"_id": 0, "user_id": 1, "name": 1, "prq_score": 1, "level": 1}}
    ]
    leaders = await db.users.aggregate(pipeline).to_list(limit)
    
    if not leaders:
        return [
            {"rank": 1, "user_id": "user_1", "name": "Elijah B.", "prq_score": 95.5, "level": 25},
            {"rank": 2, "user_id": "user_2", "name": "Amir S.", "prq_score": 92.3, "level": 22},
            {"rank": 3, "user_id": "user_3", "name": "Eric N.", "prq_score": 89.7, "level": 20}
        ]
    
    return [{"rank": i+1, **leader} for i, leader in enumerate(leaders)]

@api_router.get("/stats/overview")
async def get_stats_overview(user: User = Depends(get_current_user)):
    """Get user's overall stats"""
    workouts = await db.workouts.count_documents({"user_id": user.user_id})
    sessions = await db.coach_sessions.count_documents({"athlete_id": user.user_id})
    brain_brawls = await db.brain_brawl_sessions.count_documents({"user_id": user.user_id})
    
    return {
        "total_workouts": workouts,
        "coaching_sessions": sessions,
        "brain_brawl_sessions": brain_brawls,
        "prq_score": user.prq_score,
        "level": user.level,
        "xp": user.xp
    }

# ===================== ROOT & HEALTH =====================

@api_router.get("/")
async def root():
    return {"message": "Final Evolution Lab API", "version": "1.0.0"}

@api_router.get("/health")
async def health():
    return {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}

# Include router
app.include_router(api_router)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()
