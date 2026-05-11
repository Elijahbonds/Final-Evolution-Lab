"""Shared core dependencies (DB, auth, models) used across server.py and routers/."""
from fastapi import HTTPException, Request, Depends
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic import BaseModel, ConfigDict
from typing import List, Optional, Dict
from datetime import datetime, timezone
import os
from dotenv import load_dotenv
from pathlib import Path

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]
EMERGENT_KEY = os.environ.get('EMERGENT_LLM_KEY', '')


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
    # Lab-verified competitive PRQ (measured assessment). Prefer for certification gates vs generic prq_score.
    verified_performance_prq: Optional[float] = None
    weight_kg: Optional[float] = None
    allergies: Optional[List[str]] = None
    dietary_restrictions: Optional[List[str]] = None
    # ISO YYYY-MM-DD for minors policy (optional)
    date_of_birth: Optional[str] = None
    parental_consent_acknowledged: bool = False
    # Explicit opt-in for authenticated athlete discovery list (SOCIAL-02 / PRIVACY-09). Absent/false = not discoverable.
    discovery_opt_in: Optional[bool] = None
    level: int = 1
    xp: int = 0
    streak_days: int = 0
    total_workouts: int = 0
    avatar_config: Optional[Dict] = None
    followers: List[str] = []
    following: List[str] = []
    coins: int = 100


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
