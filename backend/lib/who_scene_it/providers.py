"""
Who Scene It — concrete provider implementations.

LocalSceneContentModule    — reads backend/data/who_scene_it_content.json
SequentialRoundTypeModule  — cycles through round types deterministically
DefaultBuzzinScoringModule — re-exported from scoring.py
InMemoryCardModule         — awards one CreatorCard per RoundType at CARD_THRESHOLD streaks
"""
import json
import random
from pathlib import Path
from typing import Dict, List, Optional, Set

from .interfaces import ICardModule, IRoundTypeModule, ISceneContentModule
from .schemas import CreatorCard, RoundType, SceneContent
from .scoring import DefaultBuzzinScoringModule  # re-export for convenience

__all__ = [
    "LocalSceneContentModule",
    "SequentialRoundTypeModule",
    "DefaultBuzzinScoringModule",
    "InMemoryCardModule",
    "CARD_THRESHOLD",
]

CARD_THRESHOLD: int = 3  # correct buzz-in streak needed for a CreatorCard

_ROUND_ORDER = [
    RoundType.text_clue,
    RoundType.silhouette,
    RoundType.image_reveal,
    RoundType.audio_clip,
]

_CARD_CATALOG: Dict[RoundType, CreatorCard] = {
    RoundType.image_reveal: CreatorCard(
        card_id="si_card_image_01",
        name="The Visionary",
        description="One glance was all it took to see what others missed.",
        image_placeholder="si_card_image_01.png",
        round_type=RoundType.image_reveal,
    ),
    RoundType.audio_clip: CreatorCard(
        card_id="si_card_audio_01",
        name="The Ear Catcher",
        description="They heard the signal buried beneath the noise.",
        image_placeholder="si_card_audio_01.png",
        round_type=RoundType.audio_clip,
    ),
    RoundType.text_clue: CreatorCard(
        card_id="si_card_text_01",
        name="The Word Weaver",
        description="Between the lines, the answer was always there.",
        image_placeholder="si_card_text_01.png",
        round_type=RoundType.text_clue,
    ),
    RoundType.silhouette: CreatorCard(
        card_id="si_card_shadow_01",
        name="The Shadow Reader",
        description="Shape and shadow held the truth the world tried to hide.",
        image_placeholder="si_card_shadow_01.png",
        round_type=RoundType.silhouette,
    ),
}


# ── LocalSceneContentModule ─────────────────────────────────────────────────

class LocalSceneContentModule(ISceneContentModule):
    """Reads content from backend/data/who_scene_it_content.json at init time."""

    def __init__(self, data_path: Optional[str] = None):
        if data_path is None:
            data_path = str(
                Path(__file__).parent.parent.parent / "data" / "who_scene_it_content.json"
            )
        with open(data_path, encoding="utf-8") as fh:
            raw = json.load(fh)
        self._by_type: Dict[str, List[SceneContent]] = {}
        self._by_id: Dict[str, SceneContent] = {}
        for item in raw["content"]:
            sc = SceneContent(
                content_id=item["content_id"],
                title=item["title"],
                description=item["description"],
                image_path=item["image_path"],
                round_type=RoundType(item["round_type"]),
                difficulty=item["difficulty"],
                license=item["license"],
                source=item["source"],
                content_provider_id=item["content_provider_id"],
                tags=item.get("tags", []),
                did_you_know=item.get("did_you_know", ""),
            )
            self._by_type.setdefault(item["round_type"], []).append(sc)
            self._by_id[sc.content_id] = sc

    def get_content(
        self,
        round_type: RoundType,
        difficulty: int,
        exclude_ids: Optional[Set[str]] = None,
    ) -> Optional[SceneContent]:
        pool = self._by_type.get(round_type.value, [])
        exclude_ids = exclude_ids or set()
        candidates = [
            c for c in pool
            if c.content_id not in exclude_ids and abs(c.difficulty - difficulty) <= 1
        ]
        if not candidates:
            candidates = [c for c in pool if c.content_id not in exclude_ids]
        return random.choice(candidates) if candidates else None

    def get_content_by_id(self, content_id: str) -> Optional[SceneContent]:
        return self._by_id.get(content_id)

    def list_content(self, round_type: Optional[RoundType] = None) -> List[SceneContent]:
        if round_type is None:
            return list(self._by_id.values())
        return list(self._by_type.get(round_type.value, []))


# ── SequentialRoundTypeModule ───────────────────────────────────────────────

class SequentialRoundTypeModule(IRoundTypeModule):
    """Cycles through round types in a fixed order, wrapping at the end."""

    def next_round_type(
        self, seed: int, used: Optional[List[RoundType]] = None
    ) -> RoundType:
        used = used or []
        available = [r for r in _ROUND_ORDER if r not in used]
        if not available:
            available = list(_ROUND_ORDER)
        rng = random.Random(seed)
        return rng.choice(available)


# ── InMemoryCardModule ────────────────────────────────────────────────────────

class InMemoryCardModule(ICardModule):

    def __init__(self):
        self._collections: Dict[str, List[CreatorCard]] = {}

    def check_award(self, round_type: RoundType, streak: int) -> Optional[CreatorCard]:
        if streak >= CARD_THRESHOLD and round_type in _CARD_CATALOG:
            return _CARD_CATALOG[round_type]
        return None

    def award(self, user_id: str, card: CreatorCard) -> None:
        coll = self._collections.setdefault(user_id, [])
        existing = {c.card_id for c in coll}
        if card.card_id not in existing:
            coll.append(card)

    def get_collection(self, user_id: str) -> List[CreatorCard]:
        return list(self._collections.get(user_id, []))
