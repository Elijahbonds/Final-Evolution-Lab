"""Economy routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.permissions import CurrentSubject
from app.dependencies import get_db
from app.schemas.economy_schemas import WalletOut
from app.services.wallet_service import wallet_service

router = APIRouter(prefix="/economy", tags=["economy"])


@router.get("/wallet", response_model=WalletOut)
async def get_wallet(
    user_id: CurrentSubject,
    db: AsyncSession = Depends(get_db),
) -> WalletOut:
    """Return authenticated user's wallet."""

    return await wallet_service.get_wallet(db=db, user_id=user_id)

