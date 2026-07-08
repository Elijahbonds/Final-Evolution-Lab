"""
scoring.py — ScoringModule seam + BuzzRiskScoring (THE core mechanic).

Rules (Scene It!-inspired buzz-in risk loop):
  - Answer options stay HIDDEN until a player buzzes.
  - While nobody has buzzed, the potential score COUNTS DOWN (linear decay
    from `max_points` to `floor_points` over `countdown_ms`).
  - Buzzing LOCKS the potential at the buzz instant and starts a
    `lock_in_ms` answer window (~4s).
  - Correct answer inside the window: +locked potential.
  - Wrong answer, or window expiry: LOSE round(potential * wrong_buzz_penalty_ratio).

Everything here is a pure function of (config, elapsed times) so replays are
deterministic: given the same seed, buzz timestamps, and answers, the exact
same scores are recomputed by backend/tools/sceneit_replay_validator.py.
"""
from abc import ABC, abstractmethod
from dataclasses import dataclass, asdict
from typing import Optional


@dataclass(frozen=True)
class ScoringConfig:
    max_points: int = 1000
    floor_points: int = 100
    countdown_ms: int = 20_000   # linear decay window per question
    lock_in_ms: int = 4_000      # answer window after buzz (~4s)
    wrong_buzz_penalty_ratio: float = 0.5

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass(frozen=True)
class BuzzResolution:
    potential: int        # points locked at buzz time
    delta: int            # signed score change applied to the buzzer
    correct: bool
    timed_out: bool       # answered after (or never inside) the lock-in window


class ScoringModule(ABC):
    """Swappable scoring seam. The match engine only calls these two methods."""

    scoring_id: str = "abstract"
    config: ScoringConfig

    @abstractmethod
    def potential_at(self, elapsed_ms: int) -> int:
        """Points a player would lock in by buzzing `elapsed_ms` after reveal."""

    @abstractmethod
    def resolve(self, buzz_elapsed_ms: int, answer_elapsed_ms, correct: bool) -> BuzzResolution:
        """Resolve a buzz given the answer instant (None = never answered)."""


class BuzzRiskScoring(ScoringModule):
    scoring_id = "buzz_risk_v1"

    def __init__(self, config: Optional[ScoringConfig] = None):
        self.config = config or ScoringConfig()

    def potential_at(self, elapsed_ms: int) -> int:
        cfg = self.config
        elapsed_ms = max(0, int(elapsed_ms))
        if elapsed_ms >= cfg.countdown_ms:
            return cfg.floor_points
        span = cfg.max_points - cfg.floor_points
        # Linear decay; integer math keeps this exactly reproducible.
        decayed = (span * elapsed_ms) // cfg.countdown_ms
        return cfg.max_points - decayed

    def resolve(self, buzz_elapsed_ms: int, answer_elapsed_ms, correct: bool) -> BuzzResolution:
        cfg = self.config
        potential = self.potential_at(buzz_elapsed_ms)
        timed_out = (
            answer_elapsed_ms is None
            or int(answer_elapsed_ms) - int(buzz_elapsed_ms) > cfg.lock_in_ms
        )
        if timed_out:
            correct = False
        if correct:
            delta = potential
        else:
            delta = -round(potential * cfg.wrong_buzz_penalty_ratio)
        return BuzzResolution(potential=potential, delta=delta, correct=correct, timed_out=timed_out)
