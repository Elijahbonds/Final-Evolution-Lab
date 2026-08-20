"""Server-authoritative FEL economy constants."""
from __future__ import annotations

XP_MIN_PER_SESSION = 10
XP_CAP_PER_SESSION = 500
XP_SCORE_DIVISOR = 5

SHARD_BASE_BY_OUTCOME = {
    "win": 50,
    "draw": 25,
    "loss": 15,
}
SHARD_COMBO_THRESHOLD = 3
SHARD_COMBO_MULTIPLIER = 5
SHARD_CRITICAL_BONUS = 10
SHARD_PACING_BONUS_RATE = 0.05
SHARD_PACING_THRESHOLD = 75

PRQ_MODE_WEIGHTS = {
    "basketball_h2h": 1.2,
    "basketball_dunk": 1.0,
    "basketball_dunk_3d": 1.0,
    "basketball_dunk_irl": 1.5,
    "basketball_3v3": 1.3,
    "karate_h2h": 1.4,
    "karate_endless": 1.4,
    "baseball": 1.0,
    "football": 1.5,
    "soccer": 1.1,
    "golf": 0.9,
    "tennis": 1.1,
    "volleyball": 1.2,
    "gymnastics": 1.0,
    "brain_brawl": 1.0,
    "who_scene_it": 1.1,
    "court_carnival": 1.0,
    "surfing": 1.05,
    "skateboarding": 0.9,
    "snowboarding": 0.9,
    "market_browse": 0.0,
}
# PRQ v2.0 outcome bases (Architecture §6.1 — mirrors server.py)
PRQ_OUTCOME_BASE = {
    "win": 2.0,
    "draw": 0.5,
    "loss": 0.2,
}
PRQ_COMBO_BONUS_RATE = 0.05
PRQ_COMBO_BONUS_CAP = 1.0
PRQ_CRITICAL_BONUS_RATE = 0.1
PRQ_CRITICAL_BONUS_CAP = 0.5
PRQ_DOMINANCE_BONUS_RATE = 0.05
PRQ_DOMINANCE_BONUS_CAP = 0.5
PRQ_MRI_BONUS_SCALE = 0.5
PRQ_DELTA_CAP = 100.0

MRI_ARV_WEIGHT = 0.30
MRI_ESI_WEIGHT = 0.45
MRI_PACING_WEIGHT = 0.25

