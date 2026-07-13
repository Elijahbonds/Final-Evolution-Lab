"""nexus authoring pipeline (Course Builder backend)

Revision ID: 003_20260713_1600
Revises: 001_20260618_0100
Create Date: 2026-07-13 16:00:00.000000

NOTE for the integrator: this lane found only 001 on disk. If another lane
lands a 002 revision, re-point ``down_revision`` here to that revision id to
keep the history linear (tables are namespaced nexus_* and independent).
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "003_20260713_1600"
down_revision = "001_20260618_0100"
branch_labels = None
depends_on = None

JSONB = postgresql.JSONB(astext_type=sa.Text())
EMPTY_OBJECT = sa.text("'{}'::jsonb")
EMPTY_ARRAY = sa.text("'[]'::jsonb")


def upgrade() -> None:
    op.create_table(
        "nexus_author_profiles",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "user_id",
            sa.String(36),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("role", sa.String(32), nullable=False, server_default="creator"),
        sa.Column("display_name", sa.String(160), nullable=False),
        sa.Column("bio", sa.String(4000), nullable=False, server_default=""),
        sa.Column("rating", sa.Float(), nullable=False, server_default="0"),
        sa.Column("payout_account_ref", sa.String(160)),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index(
        "ix_nexus_author_profiles_user_id", "nexus_author_profiles", ["user_id"], unique=True
    )

    op.create_table(
        "nexus_curricula",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "author_id",
            sa.String(36),
            sa.ForeignKey("nexus_author_profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.String(4000), nullable=False, server_default=""),
        sa.Column("sport", sa.String(64), nullable=False, server_default="basketball"),
        sa.Column("course_ids", JSONB, nullable=False, server_default=EMPTY_ARRAY),
        sa.Column("target_prq_profile", JSONB, nullable=False, server_default=EMPTY_OBJECT),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_nexus_curricula_author_id", "nexus_curricula", ["author_id"])

    op.create_table(
        "nexus_courses",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "author_id",
            sa.String(36),
            sa.ForeignKey("nexus_author_profiles.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "curriculum_id",
            sa.String(36),
            sa.ForeignKey("nexus_curricula.id", ondelete="SET NULL"),
        ),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("slug", sa.String(160), nullable=False),
        sa.Column("description", sa.String(4000), nullable=False, server_default=""),
        sa.Column("sport", sa.String(64), nullable=False, server_default="basketball"),
        sa.Column("license", sa.String(64), nullable=False, server_default="standard"),
        sa.Column("price_credits", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("head_version_id", sa.String(36)),
        sa.Column("published_version_id", sa.String(36)),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_nexus_courses_author_id", "nexus_courses", ["author_id"])
    op.create_index("ix_nexus_courses_curriculum_id", "nexus_courses", ["curriculum_id"])
    op.create_index("ix_nexus_courses_slug", "nexus_courses", ["slug"], unique=True)

    op.create_table(
        "nexus_course_versions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "course_id",
            sa.String(36),
            sa.ForeignKey("nexus_courses.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("version_number", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("state", sa.String(32), nullable=False, server_default="draft"),
        sa.Column("content", JSONB, nullable=False, server_default=EMPTY_OBJECT),
        sa.Column("prq_totals", JSONB, nullable=False, server_default=EMPTY_OBJECT),
        sa.Column("review_report", JSONB, nullable=False, server_default=EMPTY_OBJECT),
        sa.Column("rejection_reason", sa.String(2000)),
        sa.Column("reviewer_user_id", sa.String(36)),
        sa.Column("submitted_at", sa.DateTime(timezone=True)),
        sa.Column("reviewed_at", sa.DateTime(timezone=True)),
        sa.Column("published_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_nexus_course_versions_course_id", "nexus_course_versions", ["course_id"])
    op.create_index("ix_nexus_course_versions_state", "nexus_course_versions", ["state"])

    op.create_table(
        "nexus_review_events",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "version_id",
            sa.String(36),
            sa.ForeignKey("nexus_course_versions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("actor_user_id", sa.String(36), nullable=False),
        sa.Column("from_state", sa.String(32), nullable=False),
        sa.Column("to_state", sa.String(32), nullable=False),
        sa.Column("note", sa.String(2000), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_nexus_review_events_version_id", "nexus_review_events", ["version_id"])

    op.create_table(
        "nexus_catalog_entries",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column(
            "course_id",
            sa.String(36),
            sa.ForeignKey("nexus_courses.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "version_id",
            sa.String(36),
            sa.ForeignKey("nexus_course_versions.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("sport", sa.String(64), nullable=False),
        sa.Column("summary", sa.String(4000), nullable=False, server_default=""),
        sa.Column("author_id", sa.String(36), nullable=False),
        sa.Column("author_role", sa.String(32), nullable=False),
        sa.Column("price_credits", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("visibility", sa.String(32), nullable=False, server_default="public"),
        sa.Column("published_at", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index(
        "ix_nexus_catalog_entries_course_id", "nexus_catalog_entries", ["course_id"], unique=True
    )
    op.create_index("ix_nexus_catalog_entries_sport", "nexus_catalog_entries", ["sport"])
    op.create_index("ix_nexus_catalog_entries_visibility", "nexus_catalog_entries", ["visibility"])


def downgrade() -> None:
    op.drop_table("nexus_catalog_entries")
    op.drop_table("nexus_review_events")
    op.drop_table("nexus_course_versions")
    op.drop_table("nexus_courses")
    op.drop_table("nexus_curricula")
    op.drop_table("nexus_author_profiles")
