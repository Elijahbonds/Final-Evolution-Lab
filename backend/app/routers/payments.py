"""Payment routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.permissions import CurrentSubject
from app.dependencies import get_db
from app.schemas.marketplace_schemas import PaymentIntentIn, PaymentIntentOut, PurchaseOut, PurchaseRequest
from app.services.marketplace_service import marketplace_service
from app.services.payment_service import payment_service

router = APIRouter(prefix="/payments", tags=["payments"])


@router.post("/payment-intent", response_model=PaymentIntentOut)
async def create_payment_intent(request: PaymentIntentIn) -> PaymentIntentOut:
    """Create a Stripe-compatible PaymentIntent."""

    return await payment_service.create_payment_intent(
        amount_cents=request.amount_cents,
        currency=request.currency,
        metadata=request.metadata,
    )


@router.post("/create-order", response_model=PurchaseOut)
async def create_order(
    request: PurchaseRequest,
    user_id: CurrentSubject,
    db: AsyncSession = Depends(get_db),
) -> PurchaseOut:
    """Legacy-compatible purchase order endpoint."""

    if request.payment_method == "shards":
        return await marketplace_service.purchase_with_shards(db=db, user_id=user_id, item_id=request.item_id)
    return await marketplace_service.purchase_with_stripe(
        db=db,
        user_id=user_id,
        item_id=request.item_id,
        return_url=request.return_url,
        cancel_url=request.cancel_url,
    )


@router.get("/history")
async def payment_history(user_id: CurrentSubject) -> list[dict]:
    """Placeholder history endpoint until DB-backed purchase listing is wired."""

    return [{"user_id": user_id, "status": "phase4-ready", "purchases": []}]

