"""Wallet service."""
from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.wallet import Wallet
from app.schemas.economy_schemas import WalletOut


class WalletService:
    """Read wallet balances."""

    async def get_wallet(self, *, db: AsyncSession, user_id: str) -> WalletOut:
        """Return existing or empty wallet balances."""

        result = await db.execute(select(Wallet).where(Wallet.user_id == user_id))
        wallet = result.scalar_one_or_none()
        if wallet is None:
            return WalletOut(user_id=user_id, xp=0, shards=0, prq_delta=0.0)
        return WalletOut(
            user_id=user_id,
            xp=wallet.xp,
            shards=wallet.shards,
            prq_delta=wallet.prq_delta_cents / 100.0,
        )


wallet_service = WalletService()

