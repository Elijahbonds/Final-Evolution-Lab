"""In-process idempotency store for /nexus/v1/session-result.

Keyed by (user_id, idempotency_key). Per-process and TTL-bounded — good for
one API worker and for contract tests. Production multi-worker deployments
swap this for the Redis-backed implementation behind the same interface
(see docs/NEXUS_GATEWAY.md, Idempotency).
"""
from __future__ import annotations

import time
from collections import OrderedDict


class IdempotencyStore:
    """Bounded TTL cache of previously returned response payloads."""

    def __init__(self, *, ttl_seconds: float = 24 * 3600, max_entries: int = 10_000) -> None:
        self._ttl = ttl_seconds
        self._max_entries = max_entries
        self._entries: OrderedDict[tuple[str, str], tuple[float, dict]] = OrderedDict()

    def get(self, user_id: str, key: str) -> dict | None:
        """Return the stored response payload, or None if absent/expired."""

        entry = self._entries.get((user_id, key))
        if entry is None:
            return None
        stored_at, payload = entry
        if time.monotonic() - stored_at > self._ttl:
            del self._entries[(user_id, key)]
            return None
        return payload

    def put(self, user_id: str, key: str, payload: dict) -> None:
        """Record the first response for (user_id, key)."""

        self._entries[(user_id, key)] = (time.monotonic(), payload)
        self._entries.move_to_end((user_id, key))
        while len(self._entries) > self._max_entries:
            self._entries.popitem(last=False)

    def reset(self) -> None:
        """Clear all entries (test helper)."""

        self._entries.clear()


idempotency_store = IdempotencyStore()
