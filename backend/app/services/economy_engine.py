"""Server-authoritative economy engine."""
from __future__ import annotations

from dataclasses import dataclass

from app.schemas.session_receipt import SessionReceiptIn
from app.utils.formulas import calculate_mri, calculate_prq_delta, calculate_shards, calculate_xp


@dataclass(frozen=True)
class EconomyResult:
    """Computed session rewards."""

    xp: int
    shards: int
    prq_delta: float
    mri: float
    pacing_bonus_applied: bool


class EconomyEngine:
    """Compute rewards from verified gameplay receipts."""

    def compute_session(self, receipt: SessionReceiptIn) -> EconomyResult:
        """Compute XP, shards, PRQ delta, and MRI from a session receipt."""

        mri = calculate_mri(arv=receipt.arv, esi=receipt.esi, pacing=receipt.pacing_score)
        return EconomyResult(
            xp=calculate_xp(receipt.score),
            shards=calculate_shards(
                outcome=receipt.outcome,
                combo_count=receipt.combo_count,
                critical_count=receipt.critical_count,
                pacing_score=receipt.pacing_score,
            ),
            prq_delta=calculate_prq_delta(
                mode_id=receipt.mode_id,
                score=receipt.score,
                outcome=receipt.outcome,
                combo_count=receipt.combo_count,
                critical_count=receipt.critical_count,
                mri_score=mri,
                completed=receipt.completed,
                duration_seconds=receipt.duration_seconds,
            ),
            mri=mri,
            pacing_bonus_applied=receipt.pacing_score >= 75,
        )


economy_engine = EconomyEngine()

