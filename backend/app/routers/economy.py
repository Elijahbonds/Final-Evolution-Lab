"""Economy routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.permissions import CurrentSubject
from app.dependencies import get_db
from app.models.economy_transaction import EconomyTransaction
from app.schemas.economy_schemas import LedgerEntryOut, WalletOut
from app.schemas.marketplace_schemas import PayoutAccountOut, PayoutSettlementOut
from app.services.payout_service import payout_service
from app.services.wallet_service import wallet_service

router = APIRouter(prefix="/economy", tags=["economy"])


@router.get("/wallet", response_model=WalletOut)
async def get_wallet(
    user_id: CurrentSubject,
    db: AsyncSession = Depends(get_db),
) -> WalletOut:
    """Return authenticated user's wallet."""

    return await wallet_service.get_wallet(db=db, user_id=user_id)


@router.get("/ledger", response_model=list[LedgerEntryOut])
async def get_ledger(
    user_id: CurrentSubject,
    limit: int = Query(default=50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
) -> list[LedgerEntryOut]:
    """Return the caller's append-only economy transactions, newest first."""

    result = await db.execute(
        select(EconomyTransaction)
        .where(EconomyTransaction.user_id == user_id)
        .order_by(EconomyTransaction.created_at.desc())
        .limit(limit)
    )
    return [
        LedgerEntryOut(
            id=tx.id,
            transaction_type=tx.transaction_type,
            currency=tx.currency,
            amount=tx.amount,
            metadata=tx.metadata_json or {},
            created_at=tx.created_at.isoformat() if tx.created_at else None,
        )
        for tx in result.scalars().all()
    ]


@router.get("/payouts/account", response_model=PayoutAccountOut)
async def get_payout_account(
    user_id: CurrentSubject,
    db: AsyncSession = Depends(get_db),
) -> PayoutAccountOut:
    """Return the caller's creator payout accrual balance (accrual ledger only)."""

    account = await payout_service.get_or_create_account(db=db, creator_id=user_id)
    threshold = payout_service.threshold_cents(account)
    await db.commit()
    return PayoutAccountOut(
        creator_id=account.creator_id,
        accrued_cents=account.accrued_cents,
        paid_out_cents=account.paid_out_cents,
        threshold_cents=threshold,
        eligible_for_settlement=account.accrued_cents >= threshold,
        provider=account.provider,
    )


@router.post("/payouts/settle", response_model=PayoutSettlementOut)
async def settle_payout(
    user_id: CurrentSubject,
    db: AsyncSession = Depends(get_db),
) -> PayoutSettlementOut:
    """Record a threshold-gated settlement via the stubbed PayoutProvider.

    409 when the accrued balance is below the configured threshold. No real
    money moves: the NullProvider only acknowledges the settlement record.
    """

    settlement = await payout_service.settle(db=db, creator_id=user_id)
    return PayoutSettlementOut(
        settlement_id=settlement.id,
        creator_id=settlement.creator_id,
        amount_cents=settlement.amount_cents,
        status=settlement.status,
        provider=settlement.provider,
        provider_reference=settlement.provider_reference,
    )
