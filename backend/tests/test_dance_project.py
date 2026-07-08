"""
Unit tests for /api/dance/* — Dance Game foundation.

CRUD + export round-trip + creator-card apply + deterministic seed
persistence. Runs fully offline under MOCK_DB=1 (in-memory stores).
"""
import os, sys

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_fel")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")
os.environ["MOCK_DB"] = "1"

# Stub third-party modules before any FEL import
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

# ── Now import app code ────────────────────────────────────────────────────
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from core import User
from lib import creative_store
from lib.creative_store import get_creative_user
from routers.matches import _events, _matches
from routers.dance import router as dance_router
from routers.creator_cards import router as cards_router

_app = FastAPI()
_app.include_router(dance_router)
_app.include_router(cards_router)

_USER = User(user_id="dancer_a", email="da@fellab.io", name="Dancer A")


def _client() -> TestClient:
    _app.dependency_overrides[get_creative_user] = lambda: _USER
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear_stores():
    for store in creative_store._memory.values():
        store.clear()
    _matches.clear()
    _events.clear()
    yield
    for store in creative_store._memory.values():
        store.clear()
    _matches.clear()
    _events.clear()


_ANIMATIONS = [
    {"name": "wave_intro", "duration": 3.5, "source": "mocap"},
    {"name": "spin_combo", "duration": 2.0, "source": "library"},
]

_TIMELINE = {"entries": [
    {"animation": "wave_intro", "start_beat": 0},
    {"animation": "spin_combo", "start_beat": 8},
]}


def _create(seed=None, **overrides):
    body = {
        "name": "Test Routine",
        "skeleton": "humanoid_v1",
        "animations": _ANIMATIONS,
        "timeline": _TIMELINE,
        "bpm": 128,
        **overrides,
    }
    if seed is not None:
        body["seed"] = seed
    resp = _client().post("/api/dance/projects", json=body)
    assert resp.status_code == 200, resp.text
    return resp.json()


# ── CRUD ───────────────────────────────────────────────────────────────────

class TestDanceCreate:
    def test_create_returns_project_with_id_and_seed(self):
        data = _create()
        assert data["project_id"].startswith("dan_")
        assert isinstance(data["seed"], int)
        assert data["owner_id"] == "dancer_a"
        assert data["skeleton"] == "humanoid_v1"
        assert data["bpm"] == 128

    def test_animations_get_ids(self):
        data = _create()
        assert len(data["animations"]) == 2
        for a in data["animations"]:
            assert a["id"]
            assert a["duration"] >= 0
        assert data["animations"][0]["source"] == "mocap"

    def test_timeline_round_trip(self):
        data = _create()
        assert data["timeline"] == _TIMELINE

    def test_stored_in_memory_store(self):
        data = _create()
        assert data["project_id"] in creative_store._memory["dance_projects"]

    def test_negative_duration_rejected(self):
        resp = _client().post("/api/dance/projects", json={
            "animations": [{"name": "bad", "duration": -1}],
        })
        assert resp.status_code == 422

    def test_create_records_replay_event(self):
        data = _create()
        events = _events.get(data["project_id"], [])
        assert any(e["type"] == "project_created" for e in events)


class TestDanceGet:
    def test_get_round_trip(self):
        created = _create()
        got = _client().get(f"/api/dance/projects/{created['project_id']}").json()
        assert got == created

    def test_get_missing_returns_404(self):
        assert _client().get("/api/dance/projects/dan_nope").status_code == 404


# ── Seed persistence ───────────────────────────────────────────────────────

class TestSeedPersistence:
    def test_supplied_seed_is_persisted(self):
        data = _create(seed=9876543210)
        assert data["seed"] == 9876543210
        got = _client().get(f"/api/dance/projects/{data['project_id']}").json()
        assert got["seed"] == 9876543210

    def test_generated_seed_is_stable_across_reads(self):
        pid = _create()["project_id"]
        s1 = _client().get(f"/api/dance/projects/{pid}").json()["seed"]
        s2 = _client().get(f"/api/dance/projects/{pid}").json()["seed"]
        assert s1 == s2


# ── Export round-trip ──────────────────────────────────────────────────────

class TestDanceExport:
    def test_export_structure(self):
        created = _create(seed=13)
        exp = _client().post(f"/api/dance/projects/{created['project_id']}/export").json()
        assert exp["export_version"] == "1.0"
        assert exp["project_type"] == "dance"
        assert exp["project"]["project_id"] == created["project_id"]
        assert exp["project"]["seed"] == 13
        assert exp["project"]["skeleton"] == "humanoid_v1"
        assert exp["project"]["animations"] == created["animations"]
        assert exp["project"]["timeline"] == _TIMELINE
        assert exp["replay"]["replay_id"] == created["project_id"]
        assert exp["replay"]["event_count"] >= 1

    def test_export_missing_returns_404(self):
        assert _client().post("/api/dance/projects/dan_nope/export").status_code == 404

    def test_export_is_idempotent(self):
        pid = _create()["project_id"]
        e1 = _client().post(f"/api/dance/projects/{pid}/export").json()
        e2 = _client().post(f"/api/dance/projects/{pid}/export").json()
        assert e1 == e2


# ── Creator Card apply ─────────────────────────────────────────────────────

class TestCreatorCardApply:
    def test_apply_dance_card(self):
        pid = _create()["project_id"]
        resp = _client().post("/api/creator-cards/apply", json={
            "card_id": "card_groove_01", "project_type": "dance", "project_id": pid,
        })
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["pack"]["pack_id"] == "pack_dance_footwork_101"
        got = _client().get(f"/api/dance/projects/{pid}").json()
        assert got["applied_card_packs"][0]["card_id"] == "card_groove_01"

    def test_apply_music_card_to_dance_rejected(self):
        pid = _create()["project_id"]
        resp = _client().post("/api/creator-cards/apply", json={
            "card_id": "card_maestro_01", "project_type": "dance", "project_id": pid,
        })
        assert resp.status_code == 422

    def test_apply_to_missing_project_404(self):
        resp = _client().post("/api/creator-cards/apply", json={
            "card_id": "card_groove_01", "project_type": "dance", "project_id": "dan_nope",
        })
        assert resp.status_code == 404


# ── Generic replay export ──────────────────────────────────────────────────

class TestGenericReplayExport:
    def test_replay_export_for_dance_project(self):
        pid = _create(seed=321)["project_id"]
        exp = _client().get(f"/api/replays/{pid}/export").json()
        assert exp["metadata"]["project_type"] == "dance"
        assert exp["metadata"]["seed"] == 321
        assert any(e["type"] == "project_created" for e in exp["events"])
