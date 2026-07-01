"""Stripe-compatible payment service with local offline fallback."""
from __future__ import annotations

import hashlib
import json
from uuid import uuid4

from app.config import get_settings
from app.schemas.marketplace_schemas import PaymentIntentOut

try:
    import stripe
except ModuleNotFoundError:  # pragma: no cover - dependency exists in repo requirements
    stripe = None  # type: ignore[assignment]


class PaymentService:
    """Payment rail abstraction.

    Live Stripe calls are used only when `STRIPE_SECRET_KEY` is configured and
    offline payments are disabled. Otherwise local development receives stable
    Stripe-shaped mock objects.
    """

    def _live_enabled(self) -> bool:
        settings = get_settings()
        return bool(stripe and settings.stripe_secret_key and not settings.marketplace_offline_payments)

    async def create_stripe_customer(self, *, user_id: str, email: str) -> str:
        """Create a Stripe customer or return an offline customer id."""

        if self._live_enabled():
            assert stripe is not None
            stripe.api_key = get_settings().stripe_secret_key
            customer = stripe.Customer.create(metadata={"fel_user_id": user_id}, email=email)
            return str(customer.id)
        return f"cus_offline_{self._stable_suffix(user_id, email)}"

    async def create_payment_intent(
        self,
        *,
        amount_cents: int,
        currency: str = "usd",
        customer_id: str | None = None,
        metadata: dict | None = None,
    ) -> PaymentIntentOut:
        """Create a PaymentIntent-shaped object."""

        metadata = metadata or {}
        if self._live_enabled():
            assert stripe is not None
            stripe.api_key = get_settings().stripe_secret_key
            intent = stripe.PaymentIntent.create(
                amount=amount_cents,
                currency=currency,
                customer=customer_id,
                metadata=metadata,
                automatic_payment_methods={"enabled": True},
            )
            return PaymentIntentOut(
                payment_intent_id=str(intent.id),
                client_secret=str(intent.client_secret),
                status=str(intent.status),
                offline=False,
            )

        suffix = self._stable_suffix(amount_cents, currency, metadata)
        return PaymentIntentOut(
            payment_intent_id=f"pi_offline_{suffix}",
            client_secret=f"pi_offline_{suffix}_secret_{uuid4().hex[:16]}",
            status="requires_payment_method",
            offline=True,
        )

    async def create_checkout_session(
        self,
        *,
        price_cents: int,
        item_name: str,
        success_url: str,
        cancel_url: str,
        customer_id: str | None = None,
        metadata: dict | None = None,
    ) -> dict:
        """Create a Checkout Session-shaped object."""

        metadata = metadata or {}
        if self._live_enabled():
            assert stripe is not None
            stripe.api_key = get_settings().stripe_secret_key
            session = stripe.checkout.Session.create(
                payment_method_types=["card"],
                line_items=[
                    {
                        "price_data": {
                            "currency": "usd",
                            "product_data": {"name": item_name},
                            "unit_amount": price_cents,
                        },
                        "quantity": 1,
                    }
                ],
                mode="payment",
                success_url=success_url,
                cancel_url=cancel_url,
                customer=customer_id,
                metadata=metadata,
            )
            return {"session_id": session.id, "url": session.url, "offline": False}

        suffix = self._stable_suffix(price_cents, item_name, metadata)
        return {
            "session_id": f"cs_offline_{suffix}",
            "url": f"{success_url or 'http://localhost:3000' }?checkout_session=cs_offline_{suffix}",
            "offline": True,
        }

    async def create_subscription(self, *, customer_id: str, price_id: str) -> dict:
        """Create a subscription-shaped object."""

        if self._live_enabled():
            assert stripe is not None
            stripe.api_key = get_settings().stripe_secret_key
            subscription = stripe.Subscription.create(customer=customer_id, items=[{"price": price_id}])
            return {
                "subscription_id": subscription.id,
                "status": subscription.status,
                "current_period_end": subscription.current_period_end,
                "offline": False,
            }
        suffix = self._stable_suffix(customer_id, price_id)
        return {
            "subscription_id": f"sub_offline_{suffix}",
            "status": "incomplete",
            "current_period_end": None,
            "offline": True,
        }

    async def handle_webhook(self, *, payload: bytes, sig_header: str | None) -> dict:
        """Parse a Stripe webhook or local test webhook."""

        settings = get_settings()
        if self._live_enabled() and settings.stripe_webhook_secret:
            assert stripe is not None
            event = stripe.Webhook.construct_event(payload, sig_header, settings.stripe_webhook_secret)
            return {"type": event["type"], "data": event["data"]["object"], "offline": False}
        try:
            data = json.loads(payload.decode("utf-8") or "{}")
        except json.JSONDecodeError:
            data = {}
        return {
            "type": data.get("type", "offline.test"),
            "data": data.get("data", {}).get("object", data),
            "offline": True,
        }

    @staticmethod
    def _stable_suffix(*parts: object) -> str:
        raw = json.dumps(parts, sort_keys=True, default=str)
        return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


payment_service = PaymentService()

