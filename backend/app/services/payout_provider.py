"""Payout provider abstraction.

Real-money disbursement is explicitly OUT of scope for Nexus platform-core.
The marketplace accrues creator balances in the ledger; when a settlement is
recorded it is handed to a ``PayoutProvider``. The only shipped implementation
is ``NullPayoutProvider``, which acknowledges the settlement without moving
funds. A real provider (Stripe Connect, etc.) plugs in behind this interface.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from uuid import uuid4

from app.config import get_settings


class PayoutProvider(ABC):
    """Interface a real disbursement rail must implement."""

    name: str = "abstract"

    @abstractmethod
    async def submit_settlement(self, *, creator_id: str, amount_cents: int, settlement_id: str) -> str:
        """Submit a settlement for disbursement; return a provider reference."""


class NullPayoutProvider(PayoutProvider):
    """No-op provider: records an acknowledgement reference, moves no money."""

    name = "null"

    async def submit_settlement(self, *, creator_id: str, amount_cents: int, settlement_id: str) -> str:
        """Acknowledge without disbursing (accrual-ledger-only mode)."""

        return f"null_payout_{settlement_id[:8]}_{uuid4().hex[:8]}"


_PROVIDERS: dict[str, PayoutProvider] = {"null": NullPayoutProvider()}


def get_payout_provider() -> PayoutProvider:
    """Return the configured provider; unknown names fall back to the null stub."""

    return _PROVIDERS.get(get_settings().payout_provider, _PROVIDERS["null"])
