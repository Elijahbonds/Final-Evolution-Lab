"""Creator payout accrual service.

Implements the spec's marketplace payout math as an accrual ledger:

    gross -> store fee (config pct, Apple-style, off the top)
          -> net = gross - store_fee
          -> creator share = net * creator_share_pct   (default 70%)
          -> platform share = net - creator share      (default 30%)

Creator shares accrue on a ``PayoutAccount``. When the accrued balance
reaches the configured threshold, ``settle`` records a ``PayoutSettlement``
and hands it to the configured ``PayoutProvider`` (NullProvider by default —
no real money ever moves in this codebase).
"""
from __future__ import annotations

from dataclasses import dataclass

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.models.payout import PayoutAccount, PayoutSettlement
from app.services.payout_provider import get_payout_provider


@dataclass(frozen=True)
class OrderSplit:
    """Deterministic cents split for one hard-currency order."""

    gross_cents: int
    store_fee_cents: int
    net_cents: int
    creator_share_cents: int
    platform_share_cents: int


def compute_order_split(gross_cents: int) -> OrderSplit:
    """Split gross cents per config: store fee off the top, then creator/platform."""

    if gross_cents < 0:
        raise ValueError("gross_cents must be non-negative")
    settings = get_settings()
    store_fee = round(gross_cents * settings.marketplace_store_fee_pct)
    net = gross_cents - store_fee
    creator = round(net * settings.marketplace_creator_share_pct)
    platform = net - creator
    return OrderSplit(
        gross_cents=gross_cents,
        store_fee_cents=store_fee,
        net_cents=net,
        creator_share_cents=creator,
        platform_share_cents=platform,
    )


class PayoutService:
    """Accrue creator shares and record threshold-gated settlements."""

    async def get_or_create_account(self, *, db: AsyncSession, creator_id: str) -> PayoutAccount:
        """Return the creator's payout account, creating an empty one on first touch."""

        result = await db.execute(select(PayoutAccount).where(PayoutAccount.creator_id == creator_id))
        account = result.scalar_one_or_none()
        if account is None:
            account = PayoutAccount(creator_id=creator_id, provider=get_settings().payout_provider)
            db.add(account)
            await db.flush()
        return account

    async def accrue(self, *, db: AsyncSession, creator_id: str, amount_cents: int) -> PayoutAccount:
        """Add a creator share to the accrual balance (no commit — caller owns the txn)."""

        if amount_cents <= 0:
            return await self.get_or_create_account(db=db, creator_id=creator_id)
        account = await self.get_or_create_account(db=db, creator_id=creator_id)
        account.accrued_cents += amount_cents
        return account

    def threshold_cents(self, account: PayoutAccount) -> int:
        """Effective settlement threshold for an account."""

        if account.threshold_cents_override is not None:
            return account.threshold_cents_override
        return get_settings().payout_threshold_cents

    async def settle(self, *, db: AsyncSession, creator_id: str) -> PayoutSettlement:
        """Record a settlement for the full accrued balance if it meets the threshold.

        The settlement is handed to the configured PayoutProvider stub; the
        accrued balance moves to ``paid_out_cents`` in the same transaction.
        """

        account = await self.get_or_create_account(db=db, creator_id=creator_id)
        threshold = self.threshold_cents(account)
        if account.accrued_cents < threshold:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    f"Accrued balance {account.accrued_cents}c is below the "
                    f"settlement threshold {threshold}c"
                ),
            )

        amount = account.accrued_cents
        provider = get_payout_provider()
        settlement = PayoutSettlement(
            creator_id=creator_id,
            account_id=account.id,
            amount_cents=amount,
            status="recorded",
            provider=provider.name,
            metadata_json={"threshold_cents": threshold},
        )
        db.add(settlement)
        await db.flush()

        settlement.provider_reference = await provider.submit_settlement(
            creator_id=creator_id, amount_cents=amount, settlement_id=settlement.id
        )
        settlement.status = "submitted"
        account.accrued_cents = 0
        account.paid_out_cents += amount
        await db.commit()
        return settlement


payout_service = PayoutService()
