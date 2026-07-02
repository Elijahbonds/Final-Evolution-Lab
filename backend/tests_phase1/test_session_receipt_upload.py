"""Session receipt upload E2E (Phase 5)."""
from __future__ import annotations

import jwt
from fastapi.testclient import TestClient

from app.main import app


def _nexus_receipt(mode_id: str = "basketball_dunk", score: int = 42) -> dict:
    return {
        "mode_id": mode_id,
        "score": score,
        "outcome": "win",
        "duration_seconds": 90,
        "completed": True,
        "combo_count": 3,
        "critical_count": 1,
        "pacing_score": 72.0,
        "arv": 78.0,
        "esi": 65.0,
        "telemetry": {
            "session_id": "nexus-ios-test-session",
            "user_id": "ios_player",
            "device": {"engine": "NEXUS 1.0"},
        },
    }


def test_session_receipt_post_without_auth_uses_dev_athlete() -> None:
    client = TestClient(app)
    response = client.post("/api/games/session", json=_nexus_receipt())
    assert response.status_code == 200
    body = response.json()
    assert body["user_id"] == "dev-athlete"
    assert body["mode_id"] == "basketball_dunk"
    assert body["score"] == 42
    assert body["persisted"] is True
    assert body["economy"]["xp"] >= 0


def test_session_receipt_post_rejects_impossible_score() -> None:
    client = TestClient(app)
    payload = _nexus_receipt(score=99_999)
    response = client.post("/api/games/session", json=payload)
    assert response.status_code == 422
    body = response.json()
    assert "detail" in body
    assert "score_out_of_bounds" in str(body["detail"])


def test_session_receipt_post_with_firebase_bearer() -> None:
    token = jwt.encode({"sub": "test-user", "uid": "test-user"}, "unused", algorithm="HS256")
    client = TestClient(app)
    response = client.post(
        "/api/games/session",
        json=_nexus_receipt(mode_id="karate_endless", score=15),
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["user_id"] == "test-user"
    assert body["mode_id"] == "karate_endless"
