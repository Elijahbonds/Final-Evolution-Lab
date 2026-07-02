"""Shell mechanics coverage for coaching, critiques, food scanning, and game modes."""
from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


def test_game_modes_and_ai_coach_are_available() -> None:
    client = TestClient(app)

    modes = client.get("/api/games/modes")
    chat = client.post("/api/ai/chat", json={"message": "Build a training day", "model": "gpt-5.2"})

    assert modes.status_code == 200
    mode_ids = {mode["id"] for mode in modes.json()}
    assert len(mode_ids) == 22
    assert {"basketball_dunk_3d", "basketball_dunk_irl", "who_scene_it", "court_carnival", "movement_lab"} <= mode_ids
    assert "trivia_arena" not in mode_ids
    assert chat.status_code == 200
    assert "FEL Coach" in chat.json()["response"]


def test_biofuel_scan_confirm_logs_nutri_shards() -> None:
    client = TestClient(app)

    scan = client.post(
        "/api/biofuel/scan",
        json={"model": "gemini-2.5-flash", "image_base64": "abc123", "hint": "post workout bowl"},
    )
    assert scan.status_code == 200
    assert scan.json()["pending_confirmation"] is True

    confirm = client.post("/api/biofuel/scan/confirm", json={"scan_id": scan.json()["scan_id"]})
    today = client.get("/api/biofuel/today")

    assert confirm.status_code == 200
    assert confirm.json()["nutri_shards_awarded"] == 12
    assert today.status_code == 200
    assert today.json()["nutri_shards_today"] >= 12


def test_biofuel_recipes_delivery_and_manual_log() -> None:
    client = TestClient(app)

    recipes = client.get("/api/biofuel/recipes")
    detail = client.get(f"/api/biofuel/recipes/{recipes.json()['recipes'][0]['id']}")
    delivery = client.post("/api/biofuel/doordash-search", json={"intent": "post_dunk_recovery"})
    log = client.post(
        "/api/biofuel/log",
        json={
            "label": "Recovery bowl",
            "calories": 620,
            "protein_g": 46,
            "carbs_g": 68,
            "fats_g": 16,
            "source": "doordash",
        },
    )

    assert recipes.status_code == 200
    assert detail.status_code == 200
    assert delivery.status_code == 200
    assert delivery.json()["matches"]
    assert log.status_code == 200
    assert log.json()["economy"]["currency"] == "nutri_shards"


def test_coaching_and_critique_economy_are_available() -> None:
    client = TestClient(app)

    coaches = client.get("/api/coach/available")
    upload = client.post("/api/uploads/video", files={"file": ("form.mp4", b"fake-video", "video/mp4")})
    critique = client.post(
        "/api/coach/critique",
        json={
            "coach_id": coaches.json()[0]["id"],
            "video_id": upload.json()["id"],
            "sport": "basketball",
            "notes": "Review my landing mechanics",
        },
    )
    critiques = client.get("/api/coach/critiques")

    assert coaches.status_code == 200
    assert upload.status_code == 200
    assert upload.json()["size"] == len(b"fake-video")
    assert critique.status_code == 200
    assert critique.json()["economy"]["shards_spent"] == 75
    assert critiques.status_code == 200
    assert critiques.json()[0]["id"] == critique.json()["id"]

