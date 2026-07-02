"""Auth compatibility tests for the React shell."""
from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


def test_shell_can_exchange_opaque_session_id() -> None:
    client = TestClient(app)

    response = client.post("/api/auth/session", json={"session_id": "sess_local_shell"})

    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "sess_local_shell"
    assert data["session_token"]
    assert data["name"]


def test_shell_me_and_logout_are_available_without_full_firebase() -> None:
    client = TestClient(app)

    me = client.get("/api/auth/me")
    logout = client.post("/api/auth/logout")

    assert me.status_code == 200
    assert me.json()["user_id"] == "dev-athlete"
    assert logout.status_code == 200
    assert logout.json() == {"status": "ok"}

