"""Adaptive sequencing persistence models (MasteryState + Recommendation)."""
from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JsonDict, TimestampMixin
from app.models.types import PortableJSON


class MasteryState(TimestampMixin, Base):
    """Spaced-repetition state for one (user, skill) pair.

    ``strength`` is the modelled retention in [0, 1] at ``last_seen``;
    the sequencer decays it exponentially with ``decay_rate`` per day.
    ``next_due`` is when the skill should resurface for review.
    """

    __tablename__ = "mastery_states"
    __table_args__ = (UniqueConstraint("user_id", "skill_id", name="uq_mastery_states_user_skill"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    skill_id: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    strength: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    reps: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    decay_rate: Mapped[float] = mapped_column(Float, default=0.07, nullable=False)
    last_seen: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    next_due: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Recommendation(TimestampMixin, Base):
    """A computed, ordered lesson/drill queue for one user at one point in time."""

    __tablename__ = "recommendations"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    computed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    readiness: Mapped[float] = mapped_column(Float, default=70.0, nullable=False)
    queue: Mapped[list] = mapped_column(PortableJSON, default=list, nullable=False)
    inputs_snapshot: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
