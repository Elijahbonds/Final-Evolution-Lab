"""
Brain Brawl scoring engine — Big Brain Academy-inspired speed-weighted Brawn Score.

Formula per question:
  speed_factor  = 1.0 - clamp(response_ms, 0, time_limit_ms) / time_limit_ms
  speed_bonus   = round(speed_factor * MAX_SPEED_BONUS)  [0 if wrong]
  points_earned = BASE_POINTS + speed_bonus              [0 if wrong]

Brawn Score aggregation:
  raw      = sum(points_earned)
  max_raw  = question_count * (BASE_POINTS + MAX_SPEED_BONUS)
  pct      = raw / max_raw * 100
  grade    = letter from GRADE_TABLE
"""
from typing import List

from .interfaces import IScoringModule
from .schemas import AnswerResult, BrawnScore, Question

BASE_POINTS: int = 100
MAX_SPEED_BONUS: int = 50
DEFAULT_TIME_LIMIT_MS: int = 10_000

_GRADE_TABLE = [
    (97.0, "A+"),
    (90.0, "A"),
    (80.0, "B"),
    (70.0, "C"),
    (55.0, "D"),
    (0.0,  "F"),
]


def _grade(pct: float) -> str:
    for threshold, letter in _GRADE_TABLE:
        if pct >= threshold:
            return letter
    return "F"


def score_answer(
    question: Question,
    chosen_index: int,
    response_ms: int,
    time_limit_ms: int = DEFAULT_TIME_LIMIT_MS,
) -> AnswerResult:
    is_correct = chosen_index == question.correct_index
    clamped_ms = min(max(response_ms, 0), time_limit_ms)
    speed_factor = 1.0 - clamped_ms / time_limit_ms
    speed_bonus = round(speed_factor * MAX_SPEED_BONUS) if is_correct else 0
    points = (BASE_POINTS + speed_bonus) if is_correct else 0
    return AnswerResult(
        question_id=question.id,
        chosen_index=chosen_index,
        correct_index=question.correct_index,
        is_correct=is_correct,
        response_ms=response_ms,
        points_earned=points,
        speed_bonus=speed_bonus,
        did_you_know=question.did_you_know,
    )


def compute_brawn_score(results: List[AnswerResult]) -> BrawnScore:
    if not results:
        return BrawnScore(
            raw=0, max_raw=0, percentage=0.0, grade="F",
            question_count=0, correct_count=0, avg_response_ms=0.0,
        )
    raw = sum(r.points_earned for r in results)
    max_raw = len(results) * (BASE_POINTS + MAX_SPEED_BONUS)
    pct = (raw / max_raw * 100) if max_raw > 0 else 0.0
    correct_count = sum(1 for r in results if r.is_correct)
    avg_ms = sum(r.response_ms for r in results) / len(results)
    return BrawnScore(
        raw=raw,
        max_raw=max_raw,
        percentage=round(pct, 2),
        grade=_grade(pct),
        question_count=len(results),
        correct_count=correct_count,
        avg_response_ms=round(avg_ms, 1),
    )


class DefaultScoringModule(IScoringModule):
    """Concrete IScoringModule backed by the module-level scoring functions."""

    def score_answer(self, question, chosen_index, response_ms, time_limit_ms=DEFAULT_TIME_LIMIT_MS):
        return score_answer(question, chosen_index, response_ms, time_limit_ms)

    def compute_brawn_score(self, results):
        return compute_brawn_score(results)
