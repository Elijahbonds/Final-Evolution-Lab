"""Game session receipt model."""
from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JsonDict, TimestampMixin
from app.models.types import PortableJSON


class GameSession(TimestampMixin, Base):
    """Immutable-ish receipt for one completed gameplay session."""

    __tablename__ = "game_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    mode_id: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    outcome: Mapped[str] = mapped_column(String(16), nullable=False)
    score: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    completed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    combo_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    critical_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    pacing_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    mri_score: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    xp_earned: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    shards_earned: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    prq_delta: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    telemetry: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)

