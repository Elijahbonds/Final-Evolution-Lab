"""Connection tracking for FEL WebSocket channels."""
from __future__ import annotations

from collections import defaultdict, deque
from typing import Any

from fastapi import WebSocket


class ConnectionManager:
    """Per-user WebSocket connection tracking."""

    def __init__(self, channel_name: str, max_connections_per_user: int = 3) -> None:
        self.channel = channel_name
        self.max_connections_per_user = max_connections_per_user
        self.active_connections: dict[str, deque[WebSocket]] = defaultdict(deque)

    async def connect(self, websocket: WebSocket, user_id: str) -> None:
        """Accept and track a WebSocket for a user."""

        await websocket.accept()
        connections = self.active_connections[user_id]
        while len(connections) >= self.max_connections_per_user:
            oldest = connections.popleft()
            try:
                await oldest.close(code=4000, reason="Connection limit exceeded")
            except Exception:
                pass
        connections.append(websocket)

    async def disconnect(self, websocket: WebSocket, user_id: str, *, close: bool = False) -> None:
        """Remove a WebSocket from tracking."""

        connections = self.active_connections.get(user_id)
        if connections is not None:
            try:
                connections.remove(websocket)
            except ValueError:
                pass
            if not connections:
                self.active_connections.pop(user_id, None)
        if close:
            try:
                await websocket.close()
            except Exception:
                pass

    async def send_to_user(self, user_id: str, message: dict[str, Any]) -> int:
        """Send JSON to all connections for a user. Returns delivery count."""

        delivered = 0
        dead: list[WebSocket] = []
        for websocket in list(self.active_connections.get(user_id, ())):
            try:
                await websocket.send_json(message)
                delivered += 1
            except Exception:
                dead.append(websocket)
        for websocket in dead:
            await self.disconnect(websocket, user_id)
        return delivered

    async def broadcast(self, message: dict[str, Any]) -> int:
        """Send JSON to every connected WebSocket."""

        delivered = 0
        for user_id in list(self.active_connections):
            delivered += await self.send_to_user(user_id, message)
        return delivered

    def get_connected_count(self) -> int:
        """Return total open connections."""

        return sum(len(connections) for connections in self.active_connections.values())

    def get_user_count(self) -> int:
        """Return users with at least one connection."""

        return len(self.active_connections)

