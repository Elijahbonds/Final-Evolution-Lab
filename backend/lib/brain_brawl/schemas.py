"""
Brain Brawl data schemas — wire-format and internal representations.

All fields are required unless Optional. Dataclasses are used (not Pydantic)
so the lib stays framework-agnostic; the router converts to dicts for JSON.
"""
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional


class Category(str, Enum):
    creators_devs = "creators_devs"
    pop_culture   = "pop_culture"
    science       = "science"
    history       = "history"
    art           = "art"
    sport         = "sport"
    crown         = "crown"  # special finals category


@dataclass
class Question:
    id: str
    prompt: str
    options: List[str]       # exactly 4 choices
    correct_index: int       # 0-based index into options
    category: Category
    difficulty: int          # 1 (easy) – 6 (hardest)
    did_you_know: str = ""


@dataclass
class AnswerResult:
    question_id: str
    chosen_index: int
    correct_index: int
    is_correct: bool
    response_ms: int
    points_earned: int
    speed_bonus: int
    did_you_know: str = ""


@dataclass
class BrawnScore:
    raw: int
    max_raw: int
    percentage: float        # 0.0 – 100.0
    grade: str               # A+, A, B, C, D, F
    question_count: int
    correct_count: int
    avg_response_ms: float


@dataclass
class GhostRecord:
    ghost_id: str
    user_id: str
    match_id: str
    category_sequence: List[str]
    answers: List[AnswerResult]
    brawn_score: BrawnScore
    recorded_at: float = field(default_factory=time.time)


class CognitiveRoundType(str, Enum):
    memorize_sequence = "memorize_sequence"
    spot_pattern      = "spot_pattern"


@dataclass
class CognitiveRound:
    id: str
    round_type: CognitiveRoundType
    payload: Dict[str, Any]    # mode-specific display data
    expected_answer: Any
    time_limit_ms: int
    did_you_know: str = ""


@dataclass
class CollectionItem:
    item_id: str
    category: Category
    name: str
    description: str
    image_placeholder: str     # relative asset path, e.g. "art_01.png"
