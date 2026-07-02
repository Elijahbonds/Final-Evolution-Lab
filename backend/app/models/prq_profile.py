"""Physical Readiness Quotient profile model."""
from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Float, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class PRQProfile(TimestampMixin, Base):
    """Latest server-authoritative readiness attributes for a user."""

    __tablename__ = "prq_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    overall_score: Mapped[float] = mapped_column(Float, default=75.0, nullable=False)
    vertical_power: Mapped[float] = mapped_column(Float, default=50.0, nullable=False)
    reaction_time: Mapped[float] = mapped_column(Float, default=50.0, nullable=False)
    mobility: Mapped[float] = mapped_column(Float, default=50.0, nullable=False)
    balance: Mapped[float] = mapped_column(Float, default=50.0, nullable=False)
    stamina: Mapped[float] = mapped_column(Float, default=50.0, nullable=False)
    grade: Mapped[str] = mapped_column(String(32), default="PRIMED", nullable=False)

