from __future__ import annotations

import jwt
from fastapi.testclient import TestClient

import core
import server


class _FailingCollection:
    async def find_one(self, *args, **kwargs):
        raise RuntimeError("db unavailable")


def _dev_jwt() -> str:
    return jwt.encode(
        {
            "sub": "demo-athlete",
            "email": "demo@finalevolutionlab.local",
            "name": "Demo Athlete",
        },
        "local-dev-testing-key-1234567890",
        algorithm="HS256",
    )


def test_server_auth_session_falls_back_to_local_shell_when_db_is_unavailable(monkeypatch) -> None:
    monkeypatch.setenv("FEL_ENV", "development")
    monkeypatch.setattr(server.db, "users", _FailingCollection(), raising=False)

    client = TestClient(server.app)
    response = client.post("/api/auth/session", json={"session_id": _dev_jwt()})

    assert response.status_code == 200
    body = response.json()
    assert body["user_id"] == "demo-athlete"
    assert body["name"] == "Demo Athlete"
    assert body["session_token"].startswith("sess_dev_demo-athlete_")

    me = client.get("/api/auth/me", headers={"Authorization": f"Bearer {body['session_token']}"})
    assert me.status_code == 200
    assert me.json()["user_id"] == "demo-athlete"


def test_local_shell_session_tokens_are_disabled_in_production(monkeypatch) -> None:
    monkeypatch.setenv("FEL_ENV", "production")

    assert core.local_shell_user_from_session_token("sess_dev_demo-athlete_abc123") is None
