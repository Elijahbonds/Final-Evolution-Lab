"""Webhook routes."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, Request

from app.services.payment_service import payment_service

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


@router.post("/stripe")
async def stripe_webhook(request: Request) -> dict:
    """Handle Stripe webhook events or offline test webhook envelopes."""

    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    try:
        event = await payment_service.handle_webhook(payload=payload, sig_header=sig_header)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return {"status": "ok", "event_type": event["type"], "offline": event.get("offline", False)}

