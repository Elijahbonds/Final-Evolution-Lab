"""
Agent 1 — Judge/Seed Authority determinism tests.

Verifies:
  - match creation persists a 64-bit `seed` and 3 `judge_offsets`
  - judge_offsets are derived via random.Random(seed).randint(lo, hi)
  - same seed -> same offsets, always
Runs fully offline with MOCK_DB=1 (in-memory match store).
"""
import os
import random
import sys

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_fel")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")
os.environ["MOCK_DB"] = "1"

import types
from unittest.mock import MagicMock, patch


def _stub(name):
    parts = name.split(".")
    for i in range(1, len(parts) + 1):
        pkg = ".".join(parts[:i])
        if pkg not in sys.modules:
            sys.modules[pkg] = types.ModuleType(pkg)
    return sys.modules[name]


_chat = _stub("emergentintegrations.llm.chat")
_chat.LlmChat = MagicMock
_chat.UserMessage = MagicMock
_chat.ImageContent = MagicMock

_motor_patcher = patch("motor.motor_asyncio.AsyncIOMotorClient")
_mock_motor = _motor_patcher.start()
_mock_motor.return_value.__getitem__ = lambda self, n: MagicMock()

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from core import User
from lib.match_utils import generate_seed, derive_judge_offsets
from routers.matches import router as match_router, get_current_user, _matches, _events

_app = FastAPI()
_app.include_router(match_router)

_USER = User(user_id="seed_tester", email="seed@fellab.io", name="Seed Tester")


def _client() -> TestClient:
    _app.dependency_overrides[get_current_user] = lambda: _USER
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear_stores():
    _matches.clear()
    _events.clear()
    yield
    _matches.clear()
    _events.clear()


class TestSeedGeneration:
    def test_seed_is_64_bit_int(self):
        for _ in range(100):
            seed = generate_seed()
            assert isinstance(seed, int)
            assert 0 <= seed < 2 ** 64

    def test_seeds_are_unique_across_calls(self):
        seeds = {generate_seed() for _ in range(200)}
        assert len(seeds) == 200


class TestJudgeOffsetDeterminism:
    def test_same_seed_same_offsets(self):
        for seed in (0, 1, 42, 2 ** 63, 2 ** 64 - 1, 987654321012345678):
            assert derive_judge_offsets(seed) == derive_judge_offsets(seed)

    def test_offsets_match_reference_rng(self):
        # Contract: offsets MUST equal random.Random(seed).randint(lo, hi) x3.
        seed = 1122334455667788
        rng = random.Random(seed)
        expected = [rng.randint(-5, 5) for _ in range(3)]
        assert derive_judge_offsets(seed, count=3, lo=-5, hi=5) == expected

    def test_offsets_are_three_ints_in_range(self):
        offsets = derive_judge_offsets(generate_seed())
        assert len(offsets) == 3
        assert all(isinstance(o, int) and -5 <= o <= 5 for o in offsets)

    def test_repeatable_across_many_derivations(self):
        seed = generate_seed()
        first = derive_judge_offsets(seed)
        for _ in range(50):
            assert derive_judge_offsets(seed) == first


class TestMatchRecordPersistence:
    def test_created_match_persists_seed_and_offsets(self):
        resp = _client().post("/api/matches/create", json={"mode_id": "basketball_dunk_3d"})
        assert resp.status_code == 200
        match = _matches[resp.json()["match_id"]]
        assert isinstance(match["seed"], int) and 0 <= match["seed"] < 2 ** 64
        assert match["judge_offsets"] == derive_judge_offsets(match["seed"])

    def test_create_response_returns_seed_state_and_offsets(self):
        """Contract: POST /api/matches/create -> {match_id, state, seed, judge_offsets}."""
        resp = _client().post("/api/matches/create", json={"mode_id": "basketball_dunk_3d"})
        assert resp.status_code == 200
        body = resp.json()
        assert body["state"] == "waiting"
        assert isinstance(body["seed"], int) and 0 <= body["seed"] < 2 ** 64
        assert body["judge_offsets"] == derive_judge_offsets(body["seed"])
        assert body["seed"] == _matches[body["match_id"]]["seed"]

    def test_two_matches_get_independent_seeds(self):
        c = _client()
        m1 = _matches[c.post("/api/matches/create", json={}).json()["match_id"]]
        m2 = _matches[c.post("/api/matches/create", json={}).json()["match_id"]]
        assert m1["seed"] != m2["seed"]

    def test_get_match_exposes_seed_and_offsets(self):
        c = _client()
        mid = c.post("/api/matches/create", json={}).json()["match_id"]
        body = c.get(f"/api/matches/{mid}").json()
        assert body["seed"] == _matches[mid]["seed"]
        assert body["judge_offsets"] == _matches[mid]["judge_offsets"]
