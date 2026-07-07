"""
Brain Brawl stub providers — concrete implementations of every module interface.

These ship in the initial build:
  LocalQuestionProvider   — reads backend/data/brain_brawl_questions.json
  SpinCategoryModule      — deterministic random spin; tracks used categories
  InMemoryGhostModule     — in-memory ghost store (no DB required)
  LocalCognitiveModule    — hard-coded memorize-sequence + spot-pattern rounds
  InMemoryCardModule      — awards one CollectionItem per category at CROWN_THRESHOLD

AI / OpenTDB / Firebase providers are future plug-ins; swap via IQuestionProvider etc.
"""
import json
import random
import time
import uuid
from pathlib import Path
from typing import Dict, List, Optional, Set

from .interfaces import (
    ICardModule,
    ICategoryModule,
    ICognitiveModule,
    IGhostModule,
    IQuestionProvider,
)
from .schemas import (
    AnswerResult,
    BrawnScore,
    Category,
    CognitiveRound,
    CognitiveRoundType,
    CollectionItem,
    GhostRecord,
    Question,
)

_TRIVIA_CATEGORIES = [c for c in Category if c != Category.crown]


# ── LocalQuestionProvider ─────────────────────────────────────────────

class LocalQuestionProvider(IQuestionProvider):
    """Reads questions from backend/data/brain_brawl_questions.json at init time."""

    def __init__(self, data_path: Optional[str] = None):
        if data_path is None:
            data_path = str(
                Path(__file__).parent.parent.parent / "data" / "brain_brawl_questions.json"
            )
        with open(data_path, encoding="utf-8") as fh:
            raw = json.load(fh)
        self._by_category: Dict[str, List[Question]] = {}
        for item in raw["questions"]:
            cat = item["category"]
            q = Question(
                id=item["id"],
                prompt=item["prompt"],
                options=item["options"],
                correct_index=item["correct_index"],
                category=Category(cat),
                difficulty=item["difficulty"],
                did_you_know=item.get("did_you_know", ""),
            )
            self._by_category.setdefault(cat, []).append(q)

    def get_question(
        self,
        category: Category,
        difficulty: int,
        exclude_ids: Optional[Set[str]] = None,
    ) -> Optional[Question]:
        pool = self._by_category.get(category.value, [])
        exclude_ids = exclude_ids or set()
        candidates = [
            q for q in pool
            if q.id not in exclude_ids and abs(q.difficulty - difficulty) <= 1
        ]
        if not candidates:
            candidates = [q for q in pool if q.id not in exclude_ids]
        return random.choice(candidates) if candidates else None

    def get_categories(self) -> List[Category]:
        return [Category(c) for c in self._by_category]

    def get_question_count(self, category: Category) -> int:
        return len(self._by_category.get(category.value, []))


# ── SpinCategoryModule ────────────────────────────────────────────────

class SpinCategoryModule(ICategoryModule):
    """Deterministically picks from unused categories; resets when all are used."""

    def __init__(self):
        self._used: Set[Category] = set()

    def spin(self, seed: int) -> Category:
        rng = random.Random(seed)
        available = [c for c in _TRIVIA_CATEGORIES if c not in self._used]
        if not available:
            available = list(_TRIVIA_CATEGORIES)
        return rng.choice(available)

    def select(self, category: Category) -> bool:
        if category in self._used:
            return False
        self._used.add(category)
        return True


# ── InMemoryGhostModule ───────────────────────────────────────────────

class InMemoryGhostModule(IGhostModule):

    def __init__(self):
        self._store: Dict[str, GhostRecord] = {}

    def record_run(
        self,
        user_id: str,
        match_id: str,
        category_sequence: List[str],
        answers: List[AnswerResult],
        brawn_score: BrawnScore,
    ) -> GhostRecord:
        ghost_id = str(uuid.uuid4())
        record = GhostRecord(
            ghost_id=ghost_id,
            user_id=user_id,
            match_id=match_id,
            category_sequence=category_sequence,
            answers=answers,
            brawn_score=brawn_score,
            recorded_at=time.time(),
        )
        self._store[ghost_id] = record
        return record

    def get_ghost(self, ghost_id: str) -> Optional[GhostRecord]:
        return self._store.get(ghost_id)

    def list_ghosts(self, user_id: Optional[str] = None) -> List[GhostRecord]:
        ghosts = list(self._store.values())
        if user_id:
            ghosts = [g for g in ghosts if g.user_id == user_id]
        return ghosts


# ── LocalCognitiveModule ───────────────────────────────────────────────

_MEMORIZE_ROUNDS = [
    {
        "payload": {"sequence": [3, 1, 4, 1, 5], "display_ms": 500},
        "expected_answer": [3, 1, 4, 1, 5],
        "time_limit_ms": 8_000,
        "did_you_know": "The average human working memory holds 7 ± 2 items.",
    },
    {
        "payload": {"sequence": [7, 2, 8, 1, 8], "display_ms": 500},
        "expected_answer": [7, 2, 8, 1, 8],
        "time_limit_ms": 8_000,
        "did_you_know": "Chunking turns 10 random digits into 3–4 memorable groups.",
    },
    {
        "payload": {"sequence": [1, 6, 1, 8, 0], "display_ms": 400},
        "expected_answer": [1, 6, 1, 8, 0],
        "time_limit_ms": 7_000,
        "did_you_know": "Short-term memory fades in about 20 seconds without rehearsal.",
    },
]

_PATTERN_ROUNDS = [
    {
        "payload": {"sequence": [2, 4, 8, 16, "?"], "rule": "double"},
        "expected_answer": 32,
        "time_limit_ms": 10_000,
        "did_you_know": "Exponential growth doubles each step — 1 becomes 1,024 in just 10 steps.",
    },
    {
        "payload": {"sequence": [1, 1, 2, 3, 5, "?"], "rule": "fibonacci"},
        "expected_answer": 8,
        "time_limit_ms": 12_000,
        "did_you_know": "Fibonacci numbers appear in sunflower seeds, pinecones, and nautilus shells.",
    },
    {
        "payload": {"sequence": [3, 6, 9, 12, "?"], "rule": "add_3"},
        "expected_answer": 15,
        "time_limit_ms": 8_000,
        "did_you_know": "Arithmetic sequences have equal differences between consecutive terms.",
    },
]

_ALL_COGNITIVE = _MEMORIZE_ROUNDS + _PATTERN_ROUNDS


class LocalCognitiveModule(ICognitiveModule):

    def get_round(self, seed: int) -> CognitiveRound:
        rng = random.Random(seed)
        chosen = rng.choice(_ALL_COGNITIVE)
        is_memorize = "display_ms" in chosen["payload"]
        round_type = (
            CognitiveRoundType.memorize_sequence
            if is_memorize
            else CognitiveRoundType.spot_pattern
        )
        return CognitiveRound(
            id=f"cog_{seed & 0xFFFF:04x}",
            round_type=round_type,
            payload=dict(chosen["payload"]),
            expected_answer=chosen["expected_answer"],
            time_limit_ms=chosen["time_limit_ms"],
            did_you_know=chosen["did_you_know"],
        )

    def validate_answer(self, round: CognitiveRound, answer: object) -> bool:
        return answer == round.expected_answer


# ── InMemoryCardModule ───────────────────────────────────────────────

CROWN_THRESHOLD = 5

_CROWN_CATALOG: Dict[Category, CollectionItem] = {
    Category.creators_devs: CollectionItem(
        item_id="card_creators_01",
        category=Category.creators_devs,
        name="The Code Weaver",
        description="A legendary creator who built worlds from pure logic.",
        image_placeholder="creators_01.png",
    ),
    Category.pop_culture: CollectionItem(
        item_id="card_pop_01",
        category=Category.pop_culture,
        name="The Trend Setter",
        description="A visionary who shaped the culture of a generation.",
        image_placeholder="pop_culture_01.png",
    ),
    Category.science: CollectionItem(
        item_id="card_science_01",
        category=Category.science,
        name="The Discovery Maker",
        description="A brilliant mind whose eureka moment changed everything.",
        image_placeholder="science_01.png",
    ),
    Category.history: CollectionItem(
        item_id="card_history_01",
        category=Category.history,
        name="The Time Keeper",
        description="A guardian of the past who ensured the future was never forgotten.",
        image_placeholder="history_01.png",
    ),
    Category.art: CollectionItem(
        item_id="card_art_01",
        category=Category.art,
        name="The Canvas King",
        description="An artist whose strokes redefined the meaning of beauty.",
        image_placeholder="art_01.png",
    ),
    Category.sport: CollectionItem(
        item_id="card_sport_01",
        category=Category.sport,
        name="The Champion's Spirit",
        description="An athlete who proved that will can overcome any obstacle.",
        image_placeholder="sport_01.png",
    ),
}


class InMemoryCardModule(ICardModule):

    def __init__(self):
        self._collections: Dict[str, List[CollectionItem]] = {}

    def check_award(
        self,
        category: Category,
        crown_meter: int,
    ) -> Optional[CollectionItem]:
        if crown_meter >= CROWN_THRESHOLD and category in _CROWN_CATALOG:
            return _CROWN_CATALOG[category]
        return None

    def get_collection(self, user_id: str) -> List[CollectionItem]:
        return list(self._collections.get(user_id, []))

    def award(self, user_id: str, item: CollectionItem) -> None:
        """Add item to user's collection; silently deduplicates."""
        coll = self._collections.setdefault(user_id, [])
        existing = {i.item_id for i in coll}
        if item.item_id not in existing:
            coll.append(item)
