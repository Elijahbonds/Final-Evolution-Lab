"""Production monolith session receipt route parity checks."""
from __future__ import annotations

from types import SimpleNamespace

from fastapi.testclient import TestClient

import server


class _FakeCollection:
    def __init__(self) -> None:
        self.inserted: list[dict] = []
        self.updates: list[tuple[dict, dict]] = []

    async def insert_one(self, document: dict) -> SimpleNamespace:
        self.inserted.append(dict(document))
        return SimpleNamespace(inserted_id=document.get("id", "fake-id"))

    async def update_one(self, query: dict, update: dict) -> SimpleNamespace:
        self.updates.append((dict(query), dict(update)))
        return SimpleNamespace(modified_count=1)


class _FakeMongo:
    def __init__(self) -> None:
        self.game_sessions = _FakeCollection()
        self.users = _FakeCollection()
        self.shard_ledger = _FakeCollection()
        self.shard_transactions = _FakeCollection()
        self.activity_feed = _FakeCollection()


def _nexus_receipt(score: int = 42) -> dict:
    return {
        "mode_id": "basketball_dunk",
        "score": score,
        "outcome": "win",
        "duration_seconds": 90,
        "completed": True,
        "combo_count": 3,
        "critical_count": 1,
        "pacing_score": 72.0,
        "arv": 78.0,
        "esi": 65.0,
        "telemetry": {"session_id": "nexus-monolith-test-session"},
    }


async def _test_user() -> server.User:
    return server.User(
        user_id="monolith-athlete",
        email="monolith-athlete@fel.local",
        name="Monolith Athlete",
        prq_score=75.0,
    )


def test_monolith_session_receipt_uses_shared_economy(monkeypatch) -> None:
    fake_db = _FakeMongo()
    monkeypatch.setattr(server, "db", fake_db)
    server.app.dependency_overrides[server.get_current_user] = _test_user

    try:
        response = TestClient(server.app).post("/api/games/session", json=_nexus_receipt())
    finally:
        server.app.dependency_overrides.pop(server.get_current_user, None)

    assert response.status_code == 200
    body = response.json()
    assert body["user_id"] == "monolith-athlete"
    assert body["mode_id"] == "basketball_dunk"
    assert body["score"] == 42
    assert body["persisted"] is True
    assert body["economy"]["xp"] == body["xp_earned"] == 10
    assert body["economy"]["shards"] == body["shards_earned"] == 60
    assert body["session"]["shards_earned"] == 60
    assert len(fake_db.game_sessions.inserted) == 1
    assert len(fake_db.users.updates) == 1


def test_monolith_session_receipt_rejects_impossible_score(monkeypatch) -> None:
    fake_db = _FakeMongo()
    monkeypatch.setattr(server, "db", fake_db)
    server.app.dependency_overrides[server.get_current_user] = _test_user

    try:
        response = TestClient(server.app).post("/api/games/session", json=_nexus_receipt(score=99_999))
    finally:
        server.app.dependency_overrides.pop(server.get_current_user, None)

    assert response.status_code == 422
    assert response.json()["detail"] == "score_out_of_bounds"
    assert fake_db.game_sessions.inserted == []
