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

mongo_url = os.environ.get('MONGO_URL', 'mongodb://localhost:27017')
db_name = os.environ.get('DB_NAME', 'final_evolution_lab')
mongo_timeout_ms = int(os.environ.get('MONGO_SERVER_SELECTION_TIMEOUT_MS', '2000'))
client = AsyncIOMotorClient(mongo_url, serverSelectionTimeoutMS=mongo_timeout_ms)
db = client[db_name]
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
    weight_kg: Optional[float] = 75.0
    prq_score: float = 75.0
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
