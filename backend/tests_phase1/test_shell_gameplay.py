"""Coverage for shell-safe gameplay endpoints that power the React PWA.

These endpoints back the Dashboard, System Scan, Brain Brawl, Trivia Arena,
native-launch handshake, and the Final Evolution Hub command center.
"""
from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


def test_prq_metrics_and_stats_overview() -> None:
    client = TestClient(app)

    prq = client.get("/api/prq/metrics")
    stats = client.get("/api/stats/overview")

    assert prq.status_code == 200
    assert prq.json()["overall_score"] == 75.0
    assert prq.json()["strength"] >= 0
    assert stats.status_code == 200
    assert "game_sessions" in stats.json()


def test_workouts_recommended_and_log() -> None:
    client = TestClient(app)

    recommended = client.get("/api/workouts/recommended")
    log = client.post("/api/workouts/log", json={"workout_id": "shell-explosive-primer", "duration_minutes": 14})

    assert recommended.status_code == 200
    assert len(recommended.json()) >= 1
    assert recommended.json()[0]["exercises"]
    assert log.status_code == 200
    assert log.json()["status"] == "logged"


def test_brain_brawl_session_is_server_graded() -> None:
    client = TestClient(app)

    start = client.post("/api/brain-brawl/session/start", json={"category": "all", "count": 5})
    assert start.status_code == 200
    body = start.json()
    session_id = body["session_id"]
    questions = body["questions"]
    assert len(questions) == 5
    # Public questions must NOT leak the answer key.
    assert all("answer" not in q for q in questions)

    # All answers index 0 (bank is authored with answer index 0 throughout).
    submit = client.post(
        "/api/brain-brawl/session/submit",
        json={"session_id": session_id, "answers": [0, 0, 0, 0, 0]},
    )
    assert submit.status_code == 200
    result = submit.json()
    assert result["verified"] is True
    assert result["questions_total"] == 5
    assert result["questions_correct"] == 5
    assert result["xp_earned"] == 250


def test_brain_brawl_category_filter() -> None:
    client = TestClient(app)
    start = client.post("/api/brain-brawl/session/start", json={"category": "kinesiology", "count": 3})
    assert start.status_code == 200
    assert all(q["category"] == "kinesiology" for q in start.json()["questions"])


def test_trivia_questions_by_category_and_random() -> None:
    client = TestClient(app)

    science = client.get("/api/trivia/questions", params={"category": "science", "count": 1})
    mixed = client.get("/api/trivia/questions", params={"count": 5})

    assert science.status_code == 200
    assert len(science.json()) == 1
    q = science.json()[0]
    assert q["category"] == "science"
    assert "correct" in q and "difficulty" in q and len(q["options"]) == 4
    assert mixed.status_code == 200
    assert len(mixed.json()) == 5


def test_native_launch_returns_no_deeplink_on_web() -> None:
    client = TestClient(app)

    hub = client.post("/api/hub/launch-mode", json={"mode_id": "karate_h2h"})
    vault = client.post("/api/vault/launch-mode", json={"mode_id": "soccer"})
    state = client.post("/api/session/state", json={"session_id": "hub_x", "state": "completed", "score": 900})

    assert hub.status_code == 200
    assert hub.json()["deep_link"] is None
    assert hub.json()["mode_id"] == "karate_h2h"
    assert vault.status_code == 200
    assert state.status_code == 200
    assert state.json()["state"] == "completed"


def test_hub_command_center_status_renders() -> None:
    client = TestClient(app)

    status = client.get("/api/hub/status")
    health = client.get("/api/production/health")
    handshake = client.get("/api/production/handshake-log")
    telemetry = client.get("/api/telemetry/live")

    assert status.status_code == 200
    assert status.json()["database"]["status"] == "ready"
    assert len(status.json()["database"]["venues"]) == 12
    assert health.status_code == 200
    assert health.json()["checks"]["mode_manager"]["production_modes"] == 19
    assert handshake.status_code == 200
    assert handshake.json()["log"]
    assert telemetry.status_code == 200


def test_profile_update_echoes_payload() -> None:
    client = TestClient(app)
    res = client.put("/api/profile", json={"bio": "Venice runner", "sport": "basketball"})
    assert res.status_code == 200
    assert res.json()["status"] == "saved"
    assert res.json()["sport"] == "basketball"
