"""Marketplace routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Header, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import decode_access_token
from app.dependencies import get_db
from app.schemas.marketplace_schemas import CreatorCardOut, PurchaseOut, PurchaseRequest
from app.services.marketplace_service import marketplace_service

router = APIRouter(tags=["marketplace"])


def shell_subject(authorization: str | None = Header(default=None)) -> str:
    """Return authenticated user id, falling back to the local shell athlete."""

    if authorization and authorization.startswith("Bearer "):
        try:
            claims = decode_access_token(authorization.removeprefix("Bearer ").strip())
            subject = claims.get("sub")
            if isinstance(subject, str) and subject:
                return subject
        except Exception:
            pass
    return "dev-athlete"


@router.get("/marketplace/cards", response_model=list[CreatorCardOut])
async def list_marketplace_cards(
    category: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
) -> list[CreatorCardOut]:
    """List active Creator Cards."""

    return await marketplace_service.list_cards(db=db, category=category)


@router.get("/marketplace/cards/{card_id}", response_model=CreatorCardOut)
async def get_marketplace_card(
    card_id: str,
    db: AsyncSession = Depends(get_db),
) -> CreatorCardOut:
    """Return one Creator Card."""

    return await marketplace_service.get_card(db=db, card_id=card_id)


@router.post("/marketplace/purchase", response_model=PurchaseOut)
async def purchase_marketplace_item(
    request: PurchaseRequest,
    user_id: str = Depends(shell_subject),
    db: AsyncSession = Depends(get_db),
) -> PurchaseOut:
    """Purchase a marketplace item via shards or Stripe."""

    if request.payment_method == "stripe":
        return await marketplace_service.purchase_with_stripe(
            db=db,
            user_id=user_id,
            item_id=request.item_id,
            return_url=request.return_url,
            cancel_url=request.cancel_url,
        )
    return await marketplace_service.purchase_with_shards(db=db, user_id=user_id, item_id=request.item_id)


# Compatibility paths used by the legacy React shell.
@router.get("/cards", response_model=list[CreatorCardOut])
async def list_cards_compat(
    category: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
) -> list[CreatorCardOut]:
    """Compatibility alias for legacy `/api/cards`."""

    return await marketplace_service.list_cards(db=db, category=category)


@router.get("/cards/{card_id}", response_model=CreatorCardOut)
async def get_card_compat(card_id: str, db: AsyncSession = Depends(get_db)) -> CreatorCardOut:
    """Compatibility alias for legacy `/api/cards/{card_id}`."""

    return await marketplace_service.get_card(db=db, card_id=card_id)

