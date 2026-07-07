"""
Who Scene It — buzz-in risk scoring engine.

Formula:
  drained_score = max(0, INITIAL_SCORE - floor(buzz_time_ms / 1000) * SCORE_DRAIN_RATE)
  awarded       = drained_score  if is_correct  else 0
  penalty       = WRONG_BUZZ_PENALTY  if not is_correct  else 0

The penalty is NOT applied here — it is returned in BuzzinResult.penalty
so the router can subtract it from the session total.
"""
import math
from typing import Optional

from .interfaces import IBuzzinScoringModule
from .schemas import BuzzinResult

INITIAL_SCORE: int = 500
SCORE_DRAIN_RATE: int = 50        # points lost per second elapsed before buzz
WRONG_BUZZ_PENALTY: int = 200     # deducted from session total on wrong buzz
ANSWER_TIME_LIMIT_MS: int = 4_000  # player has 4 s to answer after buzzing


def compute_buzz_score(buzz_time_ms: int, is_correct: bool) -> int:
    """Return raw points for this round (penalty not included)."""
    elapsed_s = buzz_time_ms / 1000.0
    drained = max(0, INITIAL_SCORE - math.floor(elapsed_s) * SCORE_DRAIN_RATE)
    return drained if is_correct else 0


class DefaultBuzzinScoringModule(IBuzzinScoringModule):
    """
    Concrete IBuzzinScoringModule.
    content_id and did_you_know are placeholders; caller overwrites them.
    """

    def compute_score(self, buzz_time_ms: int, is_correct: bool) -> BuzzinResult:
        score = compute_buzz_score(buzz_time_ms, is_correct)
        penalty = WRONG_BUZZ_PENALTY if not is_correct else 0
        return BuzzinResult(
            content_id="",           # filled by router
            score_awarded=score,
            buzz_time_ms=buzz_time_ms,
            answer_time_ms=0,        # filled by router
            is_correct=is_correct,
            penalty=penalty,
        )

    def timed_out_score(self) -> int:
        return 0
