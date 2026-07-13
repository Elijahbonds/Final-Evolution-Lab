"""Economy schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field


class WalletOut(BaseModel):
    """Current wallet balances."""

    user_id: str = Field(description="User id")
    xp: int = Field(description="Total XP")
    shards: int = Field(description="Shard balance")
    prq_delta: float = Field(description="Accumulated PRQ delta")


class LedgerEntryOut(BaseModel):
    """One append-only economy transaction."""

    id: str = Field(description="Transaction id")
    transaction_type: str = Field(description="Movement type (earn/purchase/...)")
    currency: str = Field(description="Currency (shards/xp/usd_cents)")
    amount: int = Field(description="Signed amount")
    metadata: dict = Field(default_factory=dict, description="Context metadata")
    created_at: str | None = Field(default=None, description="ISO timestamp")

