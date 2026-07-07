"""
Brain Brawl module interfaces — swappable seams that keep the router thin.

Every concrete provider must subclass the matching ABC. The router depends
only on these interfaces, so implementations (local JSON, OpenTDB, AI-gen)
can be swapped without touching game logic.
"""
from abc import ABC, abstractmethod
from typing import List, Optional, Set

from .schemas import (
    AnswerResult,
    BrawnScore,
    Category,
    CognitiveRound,
    CollectionItem,
    GhostRecord,
    Question,
)


class IQuestionProvider(ABC):
    @abstractmethod
    def get_question(
        self,
        category: Category,
        difficulty: int,
        exclude_ids: Optional[Set[str]] = None,
    ) -> Optional[Question]:
        """Return one question matching category + difficulty; None if pool exhausted."""

    @abstractmethod
    def get_categories(self) -> List[Category]:
        """Return all categories that have at least one question."""

    @abstractmethod
    def get_question_count(self, category: Category) -> int:
        """Return the number of available questions for category."""


class ICategoryModule(ABC):
    @abstractmethod
    def spin(self, seed: int) -> Category:
        """Deterministically pick a category from seed."""

    @abstractmethod
    def select(self, category: Category) -> bool:
        """Mark category as used; returns False if already selected."""


class IScoringModule(ABC):
    @abstractmethod
    def score_answer(
        self,
        question: Question,
        chosen_index: int,
        response_ms: int,
        time_limit_ms: int = 10_000,
    ) -> AnswerResult:
        """Score one answer and return the result."""

    @abstractmethod
    def compute_brawn_score(self, results: List[AnswerResult]) -> BrawnScore:
        """Aggregate a completed round into a final BrawnScore."""


class IGhostModule(ABC):
    @abstractmethod
    def record_run(
        self,
        user_id: str,
        match_id: str,
        category_sequence: List[str],
        answers: List[AnswerResult],
        brawn_score: BrawnScore,
    ) -> GhostRecord:
        """Persist a completed run as a ghost for future challengers."""

    @abstractmethod
    def get_ghost(self, ghost_id: str) -> Optional[GhostRecord]:
        """Fetch a ghost record by ID; None if not found."""

    @abstractmethod
    def list_ghosts(self, user_id: Optional[str] = None) -> List[GhostRecord]:
        """List all ghosts, optionally filtered by owner user_id."""


class ICognitiveModule(ABC):
    @abstractmethod
    def get_round(self, seed: int) -> CognitiveRound:
        """Generate a cognitive round deterministically from seed."""

    @abstractmethod
    def validate_answer(self, round: CognitiveRound, answer: object) -> bool:
        """Return True iff answer correctly solves the round."""


class ICardModule(ABC):
    @abstractmethod
    def check_award(
        self,
        category: Category,
        crown_meter: int,
    ) -> Optional[CollectionItem]:
        """Return a CollectionItem if crown_meter threshold is met; else None."""

    @abstractmethod
    def get_collection(self, user_id: str) -> List[CollectionItem]:
        """Return all CollectionItems earned by user_id."""
