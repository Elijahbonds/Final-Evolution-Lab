import asyncio
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from core import User
from routers import biofuel
import server


class _CountCollection:
    def __init__(self, count):
        self.count = count

    async def count_documents(self, _query):
        return self.count


class _ProgressDb:
    workout_logs = _CountCollection(2)
    game_sessions = _CountCollection(3)
    brain_brawl_sessions = _CountCollection(4)


def _user(**overrides):
    data = {
        "user_id": "user_test",
        "email": "athlete@example.com",
        "name": "Test Athlete",
        "sport": "basketball",
        "weight_kg": 82,
        "level": 5,
        "xp": 1200,
        "streak_days": 7,
        "prq_score": 88.5,
        "coins": 250,
    }
    data.update(overrides)
    return User(**data)


def test_profile_progress_returns_aggregated_stats(monkeypatch):
    monkeypatch.setattr(server, "db", _ProgressDb())

    progress = asyncio.run(server.get_progress(_user()))

    assert progress == {
        "total_workouts": 2,
        "total_games": 3,
        "total_brawls": 4,
        "level": 5,
        "xp": 1200,
        "streak_days": 7,
        "prq_score": 88.5,
        "coins": 250,
    }


def test_biofuel_uses_profile_weight_with_safe_default():
    assert biofuel._athlete_weight_kg(_user(weight_kg=82)) == 82.0
    assert biofuel._athlete_weight_kg(_user(weight_kg=None)) == 75.0
    assert biofuel._athlete_weight_kg(_user(weight_kg=500)) == 250.0


def test_scan_rejects_oversized_base64_before_provider_call():
    req = biofuel.ScanRequest(
        model="gemini-2.5-flash",
        image_base64="x" * (biofuel.MAX_SCAN_IMAGE_BASE64_BYTES + 1),
    )

    with pytest.raises(biofuel.HTTPException) as exc:
        asyncio.run(biofuel.scan_meal(req, _user()))

    assert exc.value.status_code == 413


def test_doordash_search_does_not_mutate_seed(monkeypatch):
    async def fake_today(_user):
        return {
            "intent": "post_dunk_recovery",
            "remaining": {"calories": 900, "protein_g": 20},
        }

    monkeypatch.setattr(biofuel, "get_today", fake_today)
    assert all("deep_link" not in meal for meal in biofuel.DOORDASH_SEED)

    result = asyncio.run(biofuel.doordash_search(biofuel.DoorDashRequest(), _user()))

    assert result["matches"]
    assert all("deep_link" in meal for meal in result["matches"])
    assert all("deep_link" not in meal for meal in biofuel.DOORDASH_SEED)
