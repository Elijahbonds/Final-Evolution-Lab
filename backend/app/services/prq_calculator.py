"""PRQ calculator service."""
from __future__ import annotations

from app.utils.formulas import calculate_prq_delta, grade_prq


class PRQCalculator:
    """Calculate and grade PRQ values."""

    def delta(
        self,
        *,
        mode_id: str,
        score: int,
        outcome: str,
        combo_count: int = 0,
        critical_count: int = 0,
        mri_score: float = 50.0,
        completed: bool = True,
        duration_seconds: int = 0,
    ) -> float:
        """Return bounded PRQ delta."""

        return calculate_prq_delta(
            mode_id=mode_id,
            score=score,
            outcome=outcome,
            combo_count=combo_count,
            critical_count=critical_count,
            mri_score=mri_score,
            completed=completed,
            duration_seconds=duration_seconds,
        )

    def grade(self, score: float) -> str:
        """Return grade threshold label."""

        return grade_prq(score)


prq_calculator = PRQCalculator()

