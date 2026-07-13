"""Education track progress models (port of legacy MOCK_DB education_tracks)."""
from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JsonDict, TimestampMixin
from app.models.types import PortableJSON


class EducationProgress(TimestampMixin, Base):
    """Per-user per-track progression state."""

    __tablename__ = "education_progress"
    __table_args__ = (UniqueConstraint("user_id", "track_id", name="uq_education_progress_user_track"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    track_id: Mapped[str] = mapped_column(String(80), index=True, nullable=False)
    completed_lessons: Mapped[list] = mapped_column(PortableJSON, default=list, nullable=False)
    xp_awarded_lessons: Mapped[list] = mapped_column(PortableJSON, default=list, nullable=False)
    quiz_scores: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    final_passed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    final_score_pct: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    final_verified_receipt: Mapped[str | None] = mapped_column(String(160))
    certificate_issued: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    certificate_id: Mapped[str | None] = mapped_column(String(80))
    issued_at: Mapped[str | None] = mapped_column(String(64))
    extra_json: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)


class EducationAttempt(TimestampMixin, Base):
    """Short-lived server-issued attempt/receipt tokens.

    ``kind`` is one of:
      - ``kin_final``    — shuffled kinesiology final-assessment session
      - ``bio_digital``  — bio-digital module completion receipt
      - ``lesson_open``  — lesson first-open marker for minimum-study gating
    """

    __tablename__ = "education_attempts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    token: Mapped[str] = mapped_column(String(160), unique=True, index=True, nullable=False)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    kind: Mapped[str] = mapped_column(String(32), index=True, nullable=False)
    subject_id: Mapped[str] = mapped_column(String(120), default="", nullable=False)
    payload_json: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
