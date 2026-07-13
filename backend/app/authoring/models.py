"""SQLAlchemy models for the Nexus authoring pipeline.

All tables are namespaced ``nexus_*`` so they can coexist with the Phase 1
schema and be dropped as a unit. Course content (modules -> lessons) is
stored as a JSON document per version so every review/publish decision is
made against an immutable snapshot.
"""
from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JsonDict, TimestampMixin
from app.models.types import PortableJSON


class AuthorProfile(TimestampMixin, Base):
    """Authoring identity layered on a platform user.

    ``role`` is one of ``first_party | coach | creator`` (policy.AUTHOR_ROLES).
    ``payout_account_ref`` is an opaque reference for a *future* payout
    provider — accrual bookkeeping only, no real-money integration here.
    """

    __tablename__ = "nexus_author_profiles"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"), unique=True, index=True, nullable=False
    )
    role: Mapped[str] = mapped_column(String(32), default="creator", nullable=False)
    display_name: Mapped[str] = mapped_column(String(160), nullable=False)
    bio: Mapped[str] = mapped_column(String(4000), default="", nullable=False)
    rating: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    payout_account_ref: Mapped[str | None] = mapped_column(String(160))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Curriculum(TimestampMixin, Base):
    """Long-horizon path spanning multiple courses (spec: Curriculum)."""

    __tablename__ = "nexus_curricula"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    author_id: Mapped[str] = mapped_column(
        ForeignKey("nexus_author_profiles.id", ondelete="CASCADE"), index=True, nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str] = mapped_column(String(4000), default="", nullable=False)
    sport: Mapped[str] = mapped_column(String(64), default="basketball", nullable=False)
    course_ids: Mapped[list] = mapped_column(PortableJSON, default=list, nullable=False)
    target_prq_profile: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class Course(TimestampMixin, Base):
    """Authored, versioned, reviewable course (spec: Course)."""

    __tablename__ = "nexus_courses"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    author_id: Mapped[str] = mapped_column(
        ForeignKey("nexus_author_profiles.id", ondelete="CASCADE"), index=True, nullable=False
    )
    curriculum_id: Mapped[str | None] = mapped_column(
        ForeignKey("nexus_curricula.id", ondelete="SET NULL"), index=True
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    slug: Mapped[str] = mapped_column(String(160), unique=True, index=True, nullable=False)
    description: Mapped[str] = mapped_column(String(4000), default="", nullable=False)
    sport: Mapped[str] = mapped_column(String(64), default="basketball", nullable=False)
    license: Mapped[str] = mapped_column(String(64), default="standard", nullable=False)
    #: Soft-currency price. Real-money pricing is a marketplace/payout lane concern.
    price_credits: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    head_version_id: Mapped[str | None] = mapped_column(String(36))
    published_version_id: Mapped[str | None] = mapped_column(String(36))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)


class CourseVersion(TimestampMixin, Base):
    """Immutable-once-submitted content snapshot with review state."""

    __tablename__ = "nexus_course_versions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    course_id: Mapped[str] = mapped_column(
        ForeignKey("nexus_courses.id", ondelete="CASCADE"), index=True, nullable=False
    )
    version_number: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    state: Mapped[str] = mapped_column(String(32), default="draft", index=True, nullable=False)
    #: Modules -> lessons document (see schemas.CourseContent).
    content: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    #: Summed prqDelta per attribute, computed on submit.
    prq_totals: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    #: Last automated review report (checks.run_review_checks output).
    review_report: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    rejection_reason: Mapped[str | None] = mapped_column(String(2000))
    reviewer_user_id: Mapped[str | None] = mapped_column(String(36))
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ReviewEvent(TimestampMixin, Base):
    """Audit trail entry for every state transition."""

    __tablename__ = "nexus_review_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    version_id: Mapped[str] = mapped_column(
        ForeignKey("nexus_course_versions.id", ondelete="CASCADE"), index=True, nullable=False
    )
    actor_user_id: Mapped[str] = mapped_column(String(36), nullable=False)
    from_state: Mapped[str] = mapped_column(String(32), nullable=False)
    to_state: Mapped[str] = mapped_column(String(32), nullable=False)
    note: Mapped[str] = mapped_column(String(2000), default="", nullable=False)


class CatalogEntry(TimestampMixin, Base):
    """Publish -> catalog visibility projection (one row per course)."""

    __tablename__ = "nexus_catalog_entries"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    course_id: Mapped[str] = mapped_column(
        ForeignKey("nexus_courses.id", ondelete="CASCADE"), unique=True, index=True, nullable=False
    )
    version_id: Mapped[str] = mapped_column(
        ForeignKey("nexus_course_versions.id", ondelete="CASCADE"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    sport: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    summary: Mapped[str] = mapped_column(String(4000), default="", nullable=False)
    author_id: Mapped[str] = mapped_column(String(36), nullable=False)
    author_role: Mapped[str] = mapped_column(String(32), nullable=False)
    price_credits: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    visibility: Mapped[str] = mapped_column(String(32), default="public", index=True, nullable=False)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
