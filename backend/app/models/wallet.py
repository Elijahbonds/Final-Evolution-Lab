"""Economy wallet model."""
from __future__ import annotations

from uuid import uuid4

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class Wallet(TimestampMixin, Base):
    """Server-owned balances for XP, shards, and future currencies."""

    __tablename__ = "wallets"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    xp: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    shards: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    prq_delta_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

