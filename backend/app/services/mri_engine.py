"""Mental Resiliency Index service."""
from __future__ import annotations

from app.utils.formulas import calculate_mri, grade_mri


class MRIEngine:
    """Calculate and grade MRI values."""

    def calculate(self, *, arv: float, esi: float, pacing: float) -> float:
        """Return bounded MRI value."""

        return calculate_mri(arv=arv, esi=esi, pacing=pacing)

    def grade(self, score: float) -> str:
        """Return grade threshold label."""

        return grade_mri(score)


mri_engine = MRIEngine()

