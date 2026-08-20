"""Shell mechanics coverage for coaching, critiques, food scanning, and game modes."""
from __future__ import annotations

import json
from pathlib import Path

from fastapi.testclient import TestClient

from app.main import app

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_game_modes_and_ai_coach_are_available() -> None:
    client = TestClient(app)

    modes = client.get("/api/games/modes")
    chat = client.post("/api/ai/chat", json={"message": "Build a training day", "model": "gpt-5.2"})
    registry = json.loads((REPO_ROOT / "FEL_ModeManager.production.json").read_text())["mode_manager"][
        "mode_registry"
    ]
    mode_payload = modes.json()
    mode_ids = {mode["id"] for mode in mode_payload}

    assert modes.status_code == 200
    assert mode_ids == set(registry)
    assert len(mode_payload) == len(registry) == 22
    assert "karate" not in mode_ids
    assert "trivia_arena" not in mode_ids
    assert any(mode["id"] == "basketball_dunk_irl" and mode["render_mode"] == "IRL" for mode in mode_payload)
    assert any(mode["id"] == "movement_lab" and mode["status"] == "preview" for mode in mode_payload)
    assert any(mode["id"] == "market_browse" and mode["playable"] is False for mode in mode_payload)
    assert chat.status_code == 200
    assert "FEL Coach" in chat.json()["response"]


def test_nexus_status_reports_canonical_mode_counts() -> None:
    client = TestClient(app)

    status = client.get("/api/nexus/status")

    assert status.status_code == 200
    registry = status.json()["mode_registry"]
    assert registry["total_modes"] == 22
    assert registry["production_modes"] == 20
    assert registry["preview_modes"] == 1
    assert registry["non_game_modules"] == 1
    assert len(registry["modes"]) == 22


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

