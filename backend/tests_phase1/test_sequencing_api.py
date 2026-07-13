"""API coverage for /api/sequencing (in-memory SQLite via tests_phase1 conftest)."""
from __future__ import annotations

from datetime import datetime

from fastapi.testclient import TestClient

from app.main import app


def _client() -> TestClient:
    return TestClient(app)


def test_mastery_post_creates_state() -> None:
    client = _client()
    res = client.post(
        "/api/sequencing/mastery",
        json={"skill_id": "jump_mechanics", "quality": 0.9, "lesson_id": "drill_box_jump_ladder"},
    )
    assert res.status_code == 200
    body = res.json()
    assert body["skill_id"] == "jump_mechanics"
    assert 0 < body["strength"] <= 1
    assert body["reps"] == 1
    assert body["decay_rate"] == 0.06  # seeded from the catalog lesson
    assert body["last_seen"] is not None
    assert datetime.fromisoformat(body["next_due"]) > datetime.fromisoformat(body["last_seen"])


def test_mastery_post_updates_existing_state() -> None:
    client = _client()
    first = client.post("/api/sequencing/mastery", json={"skill_id": "aerobic_pacing", "quality": 0.8})
    second = client.post("/api/sequencing/mastery", json={"skill_id": "aerobic_pacing", "quality": 0.9})
    assert first.status_code == 200 and second.status_code == 200
    assert second.json()["reps"] == first.json()["reps"] + 1
    assert second.json()["strength"] > first.json()["strength"]


def test_mastery_post_rejects_out_of_range_quality() -> None:
    client = _client()
    assert client.post("/api/sequencing/mastery", json={"skill_id": "s", "quality": 1.5}).status_code == 422
    assert client.post("/api/sequencing/mastery", json={"skill_id": "s", "quality": -0.1}).status_code == 422
    assert client.post("/api/sequencing/mastery", json={"skill_id": "", "quality": 0.5}).status_code == 422


def test_mastery_list_returns_states_sorted_by_skill() -> None:
    client = _client()
    client.post("/api/sequencing/mastery", json={"skill_id": "visual_reaction", "quality": 0.7})
    res = client.get("/api/sequencing/mastery")
    assert res.status_code == 200
    skills = [state["skill_id"] for state in res.json()]
    assert "visual_reaction" in skills
    assert skills == sorted(skills)


def test_queue_returns_ordered_items_and_persists_recommendation() -> None:
    client = _client()
    res = client.get("/api/sequencing/queue", params={"readiness": 70, "limit": 6})
    assert res.status_code == 200
    body = res.json()

    assert body["recommendation_id"]
    assert body["user_id"] == "dev-athlete"
    assert body["readiness"] == 70
    assert len(body["items"]) == 6
    priorities = [item["priority"] for item in body["items"]]
    assert priorities == sorted(priorities, reverse=True)
    for item in body["items"]:
        assert item["lesson_id"] and item["skill_id"] and item["reasons"]

    # Recomputed per request: a second call persists a new Recommendation row.
    res2 = client.get("/api/sequencing/queue", params={"readiness": 70, "limit": 6})
    assert res2.status_code == 200
    assert res2.json()["recommendation_id"] != body["recommendation_id"]


def test_queue_readiness_gating_prefers_low_impact_when_fatigued() -> None:
    client = _client()
    res = client.get("/api/sequencing/queue", params={"readiness": 20, "limit": 12})
    assert res.status_code == 200
    items = res.json()["items"]
    assert items[0]["load"] != "high"
    assert items[0]["kind"] in ("cognitive", "technique")
    for item in items:
        if item["load"] == "high":
            assert item["readiness_multiplier"] < 1.0


def test_queue_reflects_mastery_history() -> None:
    client = _client()
    # Train foot_speed to a strong pass: it should stop being "new skill".
    client.post("/api/sequencing/mastery", json={"skill_id": "foot_speed", "quality": 1.0})
    res = client.get("/api/sequencing/queue", params={"limit": 12})
    assert res.status_code == 200
    trained = [i for i in res.json()["items"] if i["skill_id"] == "foot_speed"]
    assert trained, "foot_speed lessons should still be in the full queue"
    for item in trained:
        assert item["due_score"] < 0.5  # freshly reinforced, not due
        assert all("new skill" not in reason for reason in item["reasons"])


def test_queue_validates_params() -> None:
    client = _client()
    assert client.get("/api/sequencing/queue", params={"readiness": 200}).status_code == 422
    assert client.get("/api/sequencing/queue", params={"limit": 0}).status_code == 422
