"""Match lifecycle models (port of legacy MOCK_DB matches router)."""
from __future__ import annotations

from uuid import uuid4

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JsonDict, TimestampMixin
from app.models.types import PortableJSON


class Match(TimestampMixin, Base):
    """One head-to-head match record."""

    __tablename__ = "matches"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    mode_id: Mapped[str] = mapped_column(String(80), default="basketball_h2h", nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="waiting", index=True, nullable=False)
    players: Mapped[list] = mapped_column(PortableJSON, default=list, nullable=False)
    score: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    loadouts: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
    started_at: Mapped[str | None] = mapped_column(String(64))
    finished_at: Mapped[str | None] = mapped_column(String(64))


class MatchEvent(TimestampMixin, Base):
    """Append-only per-match event stream (score_event, match_start, match_end)."""

    __tablename__ = "match_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    match_id: Mapped[str] = mapped_column(ForeignKey("matches.id", ondelete="CASCADE"), index=True)
    seq: Mapped[int] = mapped_column(Integer, default=0, index=True, nullable=False)
    event_type: Mapped[str] = mapped_column(String(40), nullable=False)
    payload_json: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
