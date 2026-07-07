from pydantic import BaseModel
from typing import Dict, List, Optional


class MatchResponse(BaseModel):
    match_id: str
    state: str
    mode_id: str
    players: List[str]
    loadouts: Dict[str, dict]
    created_at: str


class MatchEventResponse(BaseModel):
    type: str
    seq: int
    player: str
    points: int
    timestamp: str
