"""Game session receipt schemas."""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


Outcome = Literal["win", "draw", "loss"]


class SessionReceiptIn(BaseModel):
    """Client-submitted gameplay receipt.

    Economy fields are recomputed server-side; the client never supplies rewards.
    """

    mode_id: str = Field(default="basketball_h2h", description="Arena mode id from ArenaSettings")
    score: int = Field(ge=0, description="Authoritative score or score proxy")
    outcome: Outcome = Field(default="loss", description="Session outcome")
    duration_seconds: int = Field(default=60, ge=0, description="Session duration")
    completed: bool = Field(default=True, description="Whether the session reached a valid ending")
    combo_count: int = Field(default=0, ge=0, description="Max or total combo count")
    critical_count: int = Field(default=0, ge=0, description="Critical performance events")
    pacing_score: float = Field(default=0, ge=0, le=100, description="0-100 pacing quality")
    arv: float = Field(default=50, ge=0, le=100, description="Adaptive recovery value")
    esi: float = Field(default=50, ge=0, le=100, description="Emotional stability index")
    telemetry: dict = Field(default_factory=dict, description="Raw client telemetry envelope")


class SessionEconomyOut(BaseModel):
    """Computed rewards for a session."""

    xp: int = Field(description="XP awarded")
    shards: int = Field(description="Shards awarded")
    prq_delta: float = Field(description="PRQ delta awarded")
    mri: float = Field(description="Mental Resiliency Index")
    pacing_bonus_applied: bool = Field(description="Whether shard pacing bonus applied")


class SessionReceiptOut(BaseModel):
    """API response for a processed session."""

    session_id: str = Field(description="Server receipt id")
    user_id: str = Field(description="Authenticated user id")
    mode_id: str = Field(description="Arena mode id")
    economy: SessionEconomyOut = Field(description="Computed economy result")
    xp_earned: int = Field(default=0, description="Legacy flat XP alias")
    shards_earned: int = Field(default=0, description="Legacy flat Shards alias")
    prq_delta: float = Field(default=0, description="Legacy flat PRQ delta alias")
    mri: float = Field(default=0, description="Legacy flat MRI alias")
    score: int = Field(default=0, description="Echoed score for legacy shells")
    persisted: bool = Field(default=True, description="Whether the receipt was committed to Postgres/SQLite")

