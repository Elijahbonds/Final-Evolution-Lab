"""initial phase 1 schema

Revision ID: 001_20260618_0100
Revises:
Create Date: 2026-06-18 01:00:00.000000
"""
from __future__ import annotations

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision = "001_20260618_0100"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("firebase_uid", sa.String(128), nullable=False),
        sa.Column("email", sa.String(320), nullable=False),
        sa.Column("display_name", sa.String(160), nullable=False),
        sa.Column("avatar_url", sa.String(1024)),
        sa.Column("role", sa.String(32), nullable=False, server_default="athlete"),
        sa.Column("sport", sa.String(64), nullable=False, server_default="basketball"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("is_minor", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_users_firebase_uid", "users", ["firebase_uid"], unique=True)
    op.create_index("ix_users_email", "users", ["email"], unique=True)

    op.create_table(
        "prq_profiles",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), unique=True),
        sa.Column("overall_score", sa.Float(), nullable=False, server_default="75"),
        sa.Column("vertical_power", sa.Float(), nullable=False, server_default="50"),
        sa.Column("reaction_time", sa.Float(), nullable=False, server_default="50"),
        sa.Column("mobility", sa.Float(), nullable=False, server_default="50"),
        sa.Column("balance", sa.Float(), nullable=False, server_default="50"),
        sa.Column("stamina", sa.Float(), nullable=False, server_default="50"),
        sa.Column("grade", sa.String(32), nullable=False, server_default="PRIMED"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "wallets",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), unique=True),
        sa.Column("xp", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("shards", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("prq_delta_cents", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "creator_cards",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("creator_id", sa.String(120), nullable=False),
        sa.Column("name", sa.String(160), nullable=False),
        sa.Column("title", sa.String(200), nullable=False, server_default=""),
        sa.Column("sport", sa.String(80), nullable=False, server_default="training"),
        sa.Column("tier", sa.String(40), nullable=False, server_default="verified"),
        sa.Column("style", sa.String(40), nullable=False, server_default="premium"),
        sa.Column("rarity", sa.String(32), nullable=False, server_default="common"),
        sa.Column("price_shards", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("price_usd", sa.Float(), nullable=False, server_default="0"),
        sa.Column("image_url", sa.String(1024)),
        sa.Column("bio", sa.String(4000), nullable=False, server_default=""),
        sa.Column("traits", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("total_sold", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_creator_cards_creator_id", "creator_cards", ["creator_id"])

    op.create_table(
        "game_sessions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("mode_id", sa.String(80), nullable=False),
        sa.Column("outcome", sa.String(16), nullable=False),
        sa.Column("score", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("duration_seconds", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("completed", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("combo_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("critical_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("pacing_score", sa.Float(), nullable=False, server_default="0"),
        sa.Column("mri_score", sa.Float(), nullable=False, server_default="0"),
        sa.Column("xp_earned", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("shards_earned", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("prq_delta", sa.Float(), nullable=False, server_default="0"),
        sa.Column("telemetry", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_game_sessions_user_id", "game_sessions", ["user_id"])
    op.create_index("ix_game_sessions_mode_id", "game_sessions", ["mode_id"])

    op.create_table(
        "economy_transactions",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("session_id", sa.String(36), sa.ForeignKey("game_sessions.id", ondelete="SET NULL")),
        sa.Column("transaction_type", sa.String(40), nullable=False),
        sa.Column("currency", sa.String(32), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_economy_transactions_user_id", "economy_transactions", ["user_id"])

    op.create_table(
        "inventory",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("card_id", sa.String(36), sa.ForeignKey("creator_cards.id", ondelete="CASCADE"), nullable=False),
        sa.Column("acquired_via", sa.String(40), nullable=False, server_default="purchase_shards"),
        sa.Column("is_equipped", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_inventory_user_id", "inventory", ["user_id"])

    op.create_table(
        "purchases",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("item_type", sa.String(40), nullable=False, server_default="creator_card"),
        sa.Column("item_id", sa.String(80), nullable=False),
        sa.Column("provider", sa.String(40), nullable=False),
        sa.Column("provider_reference", sa.String(160)),
        sa.Column("amount_cents", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("amount_shards", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("currency", sa.String(8), nullable=False, server_default="USD"),
        sa.Column("status", sa.String(32), nullable=False, server_default="pending"),
        sa.Column("metadata_json", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "leaderboards",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("mode_id", sa.String(80), nullable=False),
        sa.Column("window", sa.String(32), nullable=False, server_default="all_time"),
        sa.Column("score", sa.Integer(), nullable=False),
        sa.Column("rank_score", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_leaderboards_mode_id", "leaderboards", ["mode_id"])

    op.create_table(
        "education_courses",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("slug", sa.String(120), nullable=False, unique=True),
        sa.Column("title", sa.String(200), nullable=False),
        sa.Column("description", sa.String(2000), nullable=False, server_default=""),
        sa.Column("required_prq", sa.Float(), nullable=False, server_default="0"),
        sa.Column("modules", postgresql.JSONB(astext_type=sa.Text()), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )

    op.create_table(
        "referrals",
        sa.Column("id", sa.String(36), primary_key=True),
        sa.Column("referrer_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("referred_user_id", sa.String(36), sa.ForeignKey("users.id", ondelete="SET NULL")),
        sa.Column("referral_code", sa.String(80), nullable=False, unique=True),
        sa.Column("status", sa.String(32), nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )


def downgrade() -> None:
    for table in (
        "referrals",
        "education_courses",
        "leaderboards",
        "purchases",
        "inventory",
        "economy_transactions",
        "game_sessions",
        "creator_cards",
        "wallets",
        "prq_profiles",
        "users",
    ):
        op.drop_table(table)

