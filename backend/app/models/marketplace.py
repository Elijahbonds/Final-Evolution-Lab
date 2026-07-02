"""Creator card marketplace models."""
from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JsonDict, TimestampMixin
from app.models.types import PortableJSON


class CreatorCard(TimestampMixin, Base):
    """Cosmetic creator card definition."""

    __tablename__ = "creator_cards"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    creator_id: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    name: Mapped[str] = mapped_column(String(160), nullable=False)
    title: Mapped[str] = mapped_column(String(200), default="", nullable=False)
    sport: Mapped[str] = mapped_column(String(80), default="training", nullable=False)
    tier: Mapped[str] = mapped_column(String(40), default="verified", nullable=False)
    style: Mapped[str] = mapped_column(String(40), default="premium", nullable=False)
    rarity: Mapped[str] = mapped_column(String(32), default="common", nullable=False)
    price_shards: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    price_usd: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    image_url: Mapped[str | None] = mapped_column(String(1024))
    bio: Mapped[str] = mapped_column(String(4000), default="", nullable=False)
    traits: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    total_sold: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class InventoryItem(TimestampMixin, Base):
    """Owned card instance."""

    __tablename__ = "inventory"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    card_id: Mapped[str] = mapped_column(ForeignKey("creator_cards.id", ondelete="CASCADE"), index=True)
    acquired_via: Mapped[str] = mapped_column(String(40), default="purchase_shards", nullable=False)
    is_equipped: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)


class Purchase(TimestampMixin, Base):
    """External payment or shard purchase receipt."""

    __tablename__ = "purchases"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    item_type: Mapped[str] = mapped_column(String(40), default="creator_card", nullable=False)
    item_id: Mapped[str] = mapped_column(String(80), nullable=False)
    provider: Mapped[str] = mapped_column(String(40), nullable=False)
    provider_reference: Mapped[str | None] = mapped_column(String(160), index=True)
    amount_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    amount_shards: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    currency: Mapped[str] = mapped_column(String(8), default="USD", nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="pending", nullable=False)
    metadata_json: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)

