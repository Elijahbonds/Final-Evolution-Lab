"""Creator payout accrual models.

Real money never moves here: these tables are an accrual ledger only.
Disbursement is delegated to a ``PayoutProvider`` implementation which is
explicitly stubbed (``NullPayoutProvider``) until a real provider is wired.
"""
from __future__ import annotations

from uuid import uuid4

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, JsonDict, TimestampMixin
from app.models.types import PortableJSON


class PayoutAccount(TimestampMixin, Base):
    """Per-creator accrual balance (spec: Payout entity)."""

    __tablename__ = "payout_accounts"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    creator_id: Mapped[str] = mapped_column(String(120), unique=True, index=True, nullable=False)
    accrued_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    paid_out_cents: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    threshold_cents_override: Mapped[int | None] = mapped_column(Integer)
    provider: Mapped[str] = mapped_column(String(40), default="null", nullable=False)
    provider_account_ref: Mapped[str | None] = mapped_column(String(160))


class PayoutSettlement(TimestampMixin, Base):
    """Threshold-gated settlement record; a provider stub acknowledges it."""

    __tablename__ = "payout_settlements"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid4()))
    creator_id: Mapped[str] = mapped_column(String(120), index=True, nullable=False)
    account_id: Mapped[str] = mapped_column(ForeignKey("payout_accounts.id", ondelete="CASCADE"), index=True)
    amount_cents: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(32), default="recorded", nullable=False)
    provider: Mapped[str] = mapped_column(String(40), default="null", nullable=False)
    provider_reference: Mapped[str | None] = mapped_column(String(160))
    metadata_json: Mapped[JsonDict] = mapped_column(PortableJSON, default=dict, nullable=False)
