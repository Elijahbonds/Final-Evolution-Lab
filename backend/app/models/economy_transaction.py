"""Economy transaction ledger."""
from __future__ import annotations

from uuid import uuid4

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JsonDict, TimestampMixin
from app.models.types import PortableJSON


class EconomyTransaction(TimestampMixin, Base):
    """Append-only balance movement for auditability."""

    __tablename__ = "economy_transactions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    session_id: Mapped[str | None] = mapped_column(ForeignKey("game_sessions.id", ondelete="SET NULL"))
    transaction_type: Mapped[str] = mapped_column(String(40), index=True, nullable=False)
    currency: Mapped[str] = mapped_column(String(32), nullable=False)
    amount: Mapped[int] = mapped_column(Integer, nullable=False)
    metadata_json: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)

