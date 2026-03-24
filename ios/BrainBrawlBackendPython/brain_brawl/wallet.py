from __future__ import annotations

from dataclasses import dataclass

from .types import PlayerId


@dataclass(slots=True)
class Hold:
    id: str
    player_id: PlayerId
    amount: int


class InMemoryShardWallet:
    def __init__(self) -> None:
        self._balances: dict[PlayerId, int] = {}
        self._holds: dict[str, Hold] = {}
        self._hold_counter = 1

    def set_balance(self, player_id: PlayerId, amount: int) -> None:
        self._balances[player_id] = max(0, int(amount))

    def get_balance(self, player_id: PlayerId) -> int:
        return self._balances.get(player_id, 0)

    def reserve(self, player_id: PlayerId, amount: int) -> str:
        normalized = int(amount)
        if normalized <= 0:
            raise ValueError("Reserve amount must be greater than zero.")

        if self._get_available_balance(player_id) < normalized:
            raise ValueError("Insufficient shards to reserve.")

        hold_id = f"hold_{self._hold_counter}"
        self._hold_counter += 1
        self._holds[hold_id] = Hold(id=hold_id, player_id=player_id, amount=normalized)
        return hold_id

    def release(self, hold_id: str) -> None:
        self._holds.pop(hold_id, None)

    def capture(self, hold_id: str) -> int:
        hold = self._holds.get(hold_id)
        if hold is None:
            raise ValueError("Hold not found.")

        self.debit(hold.player_id, hold.amount)
        self._holds.pop(hold_id, None)
        return hold.amount

    def debit(self, player_id: PlayerId, amount: int) -> None:
        normalized = int(amount)
        if normalized <= 0:
            raise ValueError("Debit amount must be greater than zero.")

        current = self.get_balance(player_id)
        if current < normalized:
            raise ValueError("Insufficient shard balance.")

        self._balances[player_id] = current - normalized

    def credit(self, player_id: PlayerId, amount: int) -> None:
        normalized = int(amount)
        if normalized <= 0:
            return

        self._balances[player_id] = self.get_balance(player_id) + normalized

    def _get_reserved_total(self, player_id: PlayerId) -> int:
        return sum(hold.amount for hold in self._holds.values() if hold.player_id == player_id)

    def _get_available_balance(self, player_id: PlayerId) -> int:
        return self.get_balance(player_id) - self._get_reserved_total(player_id)
