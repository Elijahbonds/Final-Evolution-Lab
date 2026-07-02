"""User account model."""
from __future__ import annotations

from uuid import uuid4

from sqlalchemy import Boolean, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class User(TimestampMixin, Base):
    """Firebase-backed athlete/user identity."""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    firebase_uid: Mapped[str] = mapped_column(String(128), unique=True, index=True, nullable=False)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True, nullable=False)
    display_name: Mapped[str] = mapped_column(String(160), nullable=False)
    avatar_url: Mapped[str | None] = mapped_column(String(1024))
    role: Mapped[str] = mapped_column(String(32), default="athlete", nullable=False)
    sport: Mapped[str] = mapped_column(String(64), default="basketball", nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_minor: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

