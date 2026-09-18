"""Regression coverage for legacy server game routes used by Docker/web clients."""

from __future__ import annotations

import os
from types import SimpleNamespace
from unittest.mock import AsyncMock

from fastapi.testclient import TestClient

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_fel")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")
os.environ["MOCK_DB"] = "1"

import server  # noqa: E402
from core import User  # noqa: E402
from routers import matches as matches_router  # noqa: E402


_USER = User(
    user_id="route_tester",
    email="route-tester@fellab.io",
    name="Route Tester",
    sport="basketball",
    prq_score=80.0,
    level=2,
    xp=200,
    streak_days=3,
    coins=100,
)


def _client() -> TestClient:
    server.app.dependency_overrides[server.get_current_user] = lambda: _USER
    server.app.dependency_overrides[matches_router.get_current_user] = lambda: _USER
    return TestClient(server.app)


class _FakeCollection:
    def __init__(self) -> None:
        self.inserted = []

    async def insert_one(self, document):
        self.inserted.append(document)
        return document

    async def find_one(self, *args, **kwargs):
        return None


def test_registry_venues_returns_mapped_modes() -> None:
    body = _client().get("/api/registry/venues").json()

    assert body["total_modes"] >= 20
    modes = {mode["mode_id"]: mode for mode in body["modes"]}
    assert modes["basketball_h2h"]["unreal_map"] == "Venice_Beach_Court"
    assert modes["basketball_dunk_irl"]["map_path"] is None
    assert modes["basketball_dunk_irl"]["venue_token"] == "regulation_court_irl"
    assert modes["movement_lab"]["status"] == "preview"
    assert modes["movement_lab"]["venue_token"] == "movement_lab"


def test_production_modes_returns_registry_payload_without_database() -> None:
    server._count_live_sessions = AsyncMock(return_value=0)

    body = _client().get("/api/production/modes").json()

    assert body["total_modes"] >= 20
    assert body["production_modes"] == 20
    modes = {mode["mode_id"]: mode for mode in body["modes"]}
    assert modes["brain_brawl"]["status"] == "production"
    assert modes["basketball_h2h"]["map_path"] == "/Game/FEL/Maps/Venice_Beach_Court"
    assert modes["movement_lab"]["status"] == "preview"
    assert modes["movement_lab"]["map_path"] == "/Game/FEL/Venues/MovementLab/MovementLab"


def test_streaming_status_uses_registry_mode_maps(monkeypatch) -> None:
    fake_db = SimpleNamespace(streaming_connections=_FakeCollection())
    monkeypatch.setattr(server, "db", fake_db)

    body = _client().get("/api/streaming/status").json()

    assert body["mode_maps"]["basketball_dunk_irl"] == "regulation_court_irl"
    assert body["mode_maps"]["basketball_dunk_3d"] == "Venice_Beach_Court"
    assert "market_browse" not in body["mode_maps"]
    assert "movement_lab" not in body["mode_maps"]


def test_irl_dunk_launch_uses_camera_venue_without_unreal_map(monkeypatch) -> None:
    live_sessions = _FakeCollection()
    fake_db = SimpleNamespace(live_sessions=live_sessions)
    fake_bridge = SimpleNamespace(broadcast=AsyncMock())
    monkeypatch.setattr(server, "db", fake_db)
    monkeypatch.setattr(server, "vault_bridge", fake_bridge)

    response = _client().post("/api/hub/launch-mode", json={"mode_id": "basketball_dunk_irl"})

    assert response.status_code == 200
    body = response.json()
    assert body["mode_id"] == "basketball_dunk_irl"
    assert body["venue"] == "regulation_court_irl"
    assert body["map"] == "regulation_court_irl"
    assert body["map_path"] is None
    assert body["render_mode"] == "IRL"
    assert body["command"]["cmd"] == "fel.irl.launch"
    assert body["command"]["value"]["VenueToken"] == "regulation_court_irl"
    assert live_sessions.inserted[0]["map_path"] is None
    fake_bridge.broadcast.assert_awaited_once()


def test_preview_movement_lab_is_not_launchable() -> None:
    response = _client().post("/api/hub/launch-mode", json={"mode_id": "movement_lab"})

    assert response.status_code == 403
    assert "not in production or staging" in response.json()["detail"]


def test_prq_weights_are_loaded_from_mode_manager_registry() -> None:
    registry = server.MODE_MANAGER["mode_manager"]["mode_registry"]

    for mode_id, config in registry.items():
        assert server.PRQ_MODE_WEIGHTS[mode_id] == config["prq_weight"]


def test_matches_router_is_mounted_on_server_app() -> None:
    matches_router._matches.clear()
    matches_router._events.clear()

    response = _client().post("/api/matches/create", json={"mode_id": "basketball_h2h"})

    assert response.status_code == 200
    assert response.json()["mode_id"] == "basketball_h2h"
    assert response.json()["status"] == "waiting"
