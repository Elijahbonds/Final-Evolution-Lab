"""Marketplace and payment schemas."""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


PaymentMethod = Literal["shards", "stripe"]
MarketplaceItemType = Literal["creator_card"]


class CreatorCardOut(BaseModel):
    """Creator card listing."""

    id: str = Field(description="Card id")
    creator_id: str = Field(description="Creator id")
    name: str = Field(description="Creator display name")
    title: str = Field(description="Card subtitle/title")
    sport: str = Field(description="Primary sport/category")
    tier: str = Field(description="Card tier")
    style: str = Field(description="Visual style token")
    rarity: str = Field(description="Marketplace rarity")
    image_url: str = Field(description="Card image")
    bio: str = Field(description="Creator/card bio")
    signature_moves: list[str] = Field(default_factory=list, description="Signature moves")
    challenges: list[dict] = Field(default_factory=list, description="Attached challenges")
    stats: dict = Field(default_factory=dict, description="Creator stats")
    price_shards: int = Field(description="Shard price")
    price_usd: float = Field(description="USD price")
    price: float = Field(description="Legacy USD price alias")
    for_sale: bool = Field(default=True, description="Availability")


class CardCreateIn(BaseModel):
    """Admin card create/update payload."""

    creator_id: str = Field(min_length=1, description="Creator id")
    name: str = Field(min_length=1, description="Card name")
    title: str = Field(default="", description="Card title")
    sport: str = Field(default="training", description="Sport/category")
    tier: str = Field(default="verified", description="Card tier")
    style: str = Field(default="premium", description="Visual style")
    rarity: str = Field(default="common", description="Marketplace rarity")
    image_url: str = Field(default="", description="Image URL")
    bio: str = Field(default="", description="Biography")
    signature_moves: list[str] = Field(default_factory=list, description="Signature moves")
    challenges: list[dict] = Field(default_factory=list, description="Challenges")
    stats: dict = Field(default_factory=dict, description="Stats")
    price_shards: int = Field(default=500, ge=0, description="Shard price")
    price_usd: float = Field(default=9.99, ge=0, description="USD price")
    for_sale: bool = Field(default=True, description="Availability")


class PurchaseRequest(BaseModel):
    """Purchase request for marketplace items."""

    item_type: MarketplaceItemType = Field(default="creator_card", description="Item type")
    item_id: str = Field(description="Item id")
    payment_method: PaymentMethod = Field(default="shards", description="Payment rail")
    return_url: str | None = Field(default=None, description="Checkout success URL")
    cancel_url: str | None = Field(default=None, description="Checkout cancel URL")


class PurchaseOut(BaseModel):
    """Purchase response."""

    purchase_id: str = Field(description="Purchase id")
    item_type: str = Field(description="Item type")
    item_id: str = Field(description="Item id")
    item_name: str = Field(description="Display name")
    payment_method: str = Field(description="Payment rail")
    status: str = Field(description="Purchase status")
    amount_shards: int | None = Field(default=None, description="Shard amount")
    amount_usd: float | None = Field(default=None, description="USD amount")
    wallet_after: dict | None = Field(default=None, description="Wallet snapshot")
    stripe_client_secret: str | None = Field(default=None, description="Stripe PaymentIntent client secret")
    checkout_url: str | None = Field(default=None, description="Stripe Checkout URL")


class PaymentIntentIn(BaseModel):
    """Direct payment intent request."""

    amount_cents: int = Field(gt=0, description="Amount in cents")
    currency: str = Field(default="usd", min_length=3, max_length=3, description="Currency")
    metadata: dict = Field(default_factory=dict, description="Provider metadata")


class PaymentIntentOut(BaseModel):
    """Stripe-compatible payment intent response."""

    payment_intent_id: str = Field(description="PaymentIntent id")
    client_secret: str = Field(description="Client secret")
    status: str = Field(description="Provider status")
    offline: bool = Field(default=False, description="True when generated without live provider")

