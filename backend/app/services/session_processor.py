"""Session processing service."""
from __future__ import annotations

from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.economy_transaction import EconomyTransaction
from app.models.game_session import GameSession
from app.schemas.session_receipt import SessionEconomyOut, SessionReceiptIn, SessionReceiptOut
from app.services.anticheat_validator import anti_cheat_validator
from app.services.economy_engine import economy_engine


class SessionProcessor:
    """Validate, score, and persist session receipts."""

    async def process(
        self,
        *,
        db: AsyncSession,
        user_id: str,
        receipt: SessionReceiptIn,
    ) -> SessionReceiptOut:
        """Process and persist a session receipt."""

        validation = anti_cheat_validator.validate(receipt)
        if not validation.accepted:
            raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=validation.reason)

        economy = economy_engine.compute_session(receipt)
        session_id = str(uuid4())
        try:
            db.add(
                GameSession(
                    id=session_id,
                    user_id=user_id,
                    mode_id=receipt.mode_id,
                    outcome=receipt.outcome,
                    score=receipt.score,
                    duration_seconds=receipt.duration_seconds,
                    completed=receipt.completed,
                    combo_count=receipt.combo_count,
                    critical_count=receipt.critical_count,
                    pacing_score=receipt.pacing_score,
                    mri_score=economy.mri,
                    xp_earned=economy.xp,
                    shards_earned=economy.shards,
                    prq_delta=economy.prq_delta,
                    telemetry=receipt.telemetry,
                )
            )
            for currency, amount in (("xp", economy.xp), ("shards", economy.shards)):
                db.add(
                    EconomyTransaction(
                        user_id=user_id,
                        session_id=session_id,
                        transaction_type="session_reward",
                        currency=currency,
                        amount=amount,
                        metadata_json={"mode_id": receipt.mode_id, "outcome": receipt.outcome},
                    )
                )
            await db.commit()
        except Exception as exc:
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Session receipt persistence failed: {exc}",
            ) from exc

        return SessionReceiptOut(
            session_id=session_id,
            user_id=user_id,
            mode_id=receipt.mode_id,
            economy=SessionEconomyOut(
                xp=economy.xp,
                shards=economy.shards,
                prq_delta=economy.prq_delta,
                mri=economy.mri,
                pacing_bonus_applied=economy.pacing_bonus_applied,
            ),
            xp_earned=economy.xp,
            shards_earned=economy.shards,
            prq_delta=economy.prq_delta,
            mri=economy.mri,
            score=receipt.score,
            persisted=True,
        )


session_processor = SessionProcessor()
