"""Regression coverage for legacy server game routes used by Docker/web clients."""

from __future__ import annotations

import os
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
    server.app.dependency_overrides[matches_router.get_current_user] = lambda: _USER
    return TestClient(server.app)


def test_registry_venues_returns_mapped_modes() -> None:
    body = _client().get("/api/registry/venues").json()

    assert body["total_modes"] >= 20
    modes = {mode["mode_id"]: mode for mode in body["modes"]}
    assert modes["basketball_h2h"]["unreal_map"] == "Venice_Beach_Court"
    assert modes["basketball_dunk_irl"]["map_path"] is None
    assert modes["basketball_dunk_irl"]["venue_token"] == "regulation_court_irl"


def test_production_modes_returns_registry_payload_without_database() -> None:
    server._count_live_sessions = AsyncMock(return_value=0)

    body = _client().get("/api/production/modes").json()

    assert body["total_modes"] >= 20
    assert body["production_modes"] == 20
    modes = {mode["mode_id"]: mode for mode in body["modes"]}
    assert modes["brain_brawl"]["status"] == "production"
    assert modes["basketball_h2h"]["map_path"] == "/Game/FEL/Maps/Venice_Beach_Court"


def test_matches_router_is_mounted_on_server_app() -> None:
    matches_router._matches.clear()
    matches_router._events.clear()

    response = _client().post("/api/matches/create", json={"mode_id": "basketball_h2h"})

    assert response.status_code == 200
    assert response.json()["mode_id"] == "basketball_h2h"
    assert response.json()["status"] == "waiting"
