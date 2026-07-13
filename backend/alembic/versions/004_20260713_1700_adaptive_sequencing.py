"""adaptive sequencing tables (mastery_states + recommendations)

Revision ID: 004_20260713_1700
Revises: 003_20260713_1600
Create Date: 2026-07-13 17:00:00.000000
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "004_20260713_1700"
down_revision = "003_20260713_1600"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "mastery_states",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("skill_id", sa.String(80), nullable=False),
        sa.Column("strength", sa.Float(), nullable=False, server_default="0"),
        sa.Column("reps", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("decay_rate", sa.Float(), nullable=False, server_default="0.07"),
        sa.Column("last_seen", sa.DateTime(timezone=True)),
        sa.Column("next_due", sa.DateTime(timezone=True)),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "skill_id", name="uq_mastery_states_user_skill"),
    )
    op.create_index("ix_mastery_states_user_id", "mastery_states", ["user_id"])
    op.create_index("ix_mastery_states_skill_id", "mastery_states", ["skill_id"])

    op.create_table(
        "recommendations",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("computed_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("readiness", sa.Float(), nullable=False, server_default="70"),
        sa.Column("queue", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'[]'::jsonb")),
        sa.Column("inputs_snapshot", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_recommendations_user_id", "recommendations", ["user_id"])


def downgrade() -> None:
    for table in ("recommendations", "mastery_states"):
        op.drop_table(table)
