"""Leaderboard and education models."""
from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Boolean, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JsonDict, TimestampMixin
from app.models.types import PortableJSON


class Leaderboard(TimestampMixin, Base):
    """Aggregated score row by mode and time window."""

    __tablename__ = "leaderboards"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    mode_id: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    window: Mapped[str] = mapped_column(String(32), default="all_time", index=True, nullable=False)
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    rank_score: Mapped[float] = mapped_column(Float, nullable=False)


class EducationCourse(TimestampMixin, Base):
    """Education course metadata."""

    __tablename__ = "education_courses"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    slug: Mapped[str] = mapped_column(String(120), unique=True, nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(String(2000), default="", nullable=False)
    required_prq: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    modules: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Referral(TimestampMixin, Base):
    """Referral attribution."""

    __tablename__ = "referrals"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    referrer_user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    referred_user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"))
    referral_code: Mapped[str] = mapped_column(String(80), unique=True, nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="pending", nullable=False)

