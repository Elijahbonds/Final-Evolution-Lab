"""
Who Scene It — module interfaces (ABCs).

All game behaviour is injected via these contracts so providers can be
swapped without touching the router (Nexus module philosophy).
"""
from abc import ABC, abstractmethod
from typing import List, Optional, Set

from .schemas import BuzzinResult, CreatorCard, RoundType, SceneContent


class ISceneContentModule(ABC):
    """Provides SceneContent items to rounds."""

    @abstractmethod
    def get_content(
        self,
        round_type: RoundType,
        difficulty: int,
        exclude_ids: Optional[Set[str]] = None,
    ) -> Optional[SceneContent]:
        """Return one content item matching round_type/difficulty, or None."""

    @abstractmethod
    def get_content_by_id(self, content_id: str) -> Optional[SceneContent]:
        """Fetch a specific content item by ID."""

    @abstractmethod
    def list_content(
        self, round_type: Optional[RoundType] = None
    ) -> List[SceneContent]:
        """List all content, optionally filtered by round_type."""


class IRoundTypeModule(ABC):
    """Determines which RoundType to use next."""

    @abstractmethod
    def next_round_type(self, seed: int, used: Optional[List[RoundType]] = None) -> RoundType:
        """Pick the next round type given a seed and already-used list."""


class IBuzzinScoringModule(ABC):
    """
    Scores a buzz-in attempt.

    Scoring rules:
      - Score drains from INITIAL_SCORE at SCORE_DRAIN_RATE pts/sec from round start.
      - Player buzzes at buzz_time_ms → countdown stops.
      - Player has 4 s to answer after buzz.
      - Correct answer → drained score is awarded.
      - Wrong answer   → 0 pts this round + WRONG_BUZZ_PENALTY subtracted from total.
    """

    @abstractmethod
    def compute_score(
        self,
        buzz_time_ms: int,
        is_correct: bool,
    ) -> BuzzinResult:
        """Return a partial BuzzinResult (content_id / did_you_know filled by caller)."""

    @abstractmethod
    def timed_out_score(self) -> int:
        """Score awarded when the player does not buzz before time runs out (always 0)."""


class ICardModule(ABC):
    """Awards CreatorCards to users."""

    @abstractmethod
    def check_award(self, round_type: RoundType, streak: int) -> Optional[CreatorCard]:
        """Return a card if the streak qualifies, else None."""

    @abstractmethod
    def award(self, user_id: str, card: CreatorCard) -> None:
        """Persist the card to the user's collection."""

    @abstractmethod
    def get_collection(self, user_id: str) -> List[CreatorCard]:
        """Return the user's full card collection."""
