"""
Unit tests for /api/music/* — Music Creation foundation.

CRUD + export round-trip + deterministic render-preview + creator-card apply
+ seed persistence. Runs fully offline: MOCK_DB=1 set before import so
lib/creative_store.py and routers/matches.py use in-memory stores.
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
from routers.music import router as music_router
from routers.creator_cards import router as cards_router

_app = FastAPI()
_app.include_router(music_router)
_app.include_router(cards_router)

_USER = User(user_id="musician_a", email="ma@fellab.io", name="Musician A")


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


_TRACKS = [
    {
        "type": "instrument",
        "clips": [{"start": 0, "length": 4}, {"start": 8, "length": 4}],
        "volume": 0.8,
        "pan": -0.25,
        "effects": [{"type": "reverb", "wet": 0.3}],
    },
    {"type": "sample", "clips": [{"start": 4, "length": 2}]},
]


def _create(seed=None, **overrides):
    body = {"name": "Test Beat", "bpm": 92, "key": "F#m", "tracks": _TRACKS, **overrides}
    if seed is not None:
        body["seed"] = seed
    resp = _client().post("/api/music/projects", json=body)
    assert resp.status_code == 200, resp.text
    return resp.json()


# ── CRUD ───────────────────────────────────────────────────────────────────

class TestMusicCreate:
    def test_create_returns_project_with_id_and_seed(self):
        data = _create()
        assert data["project_id"].startswith("mus_")
        assert isinstance(data["seed"], int)
        assert data["owner_id"] == "musician_a"
        assert data["bpm"] == 92
        assert data["key"] == "F#m"

    def test_tracks_get_ids_and_defaults(self):
        data = _create()
        assert len(data["tracks"]) == 2
        for t in data["tracks"]:
            assert t["track_id"]
            assert t["type"] in ("instrument", "sample")
            for c in t["clips"]:
                assert c["clip_id"]
        assert data["tracks"][1]["volume"] == 1.0  # default
        assert data["tracks"][1]["pan"] == 0.0

    def test_stored_in_memory_store(self):
        data = _create()
        assert data["project_id"] in creative_store._memory["music_projects"]

    def test_invalid_track_type_rejected(self):
        resp = _client().post("/api/music/projects", json={"tracks": [{"type": "vocoder"}]})
        assert resp.status_code == 422

    def test_invalid_bpm_rejected(self):
        resp = _client().post("/api/music/projects", json={"bpm": 5})
        assert resp.status_code == 422

    def test_create_records_replay_event(self):
        data = _create()
        events = _events.get(data["project_id"], [])
        assert any(e["type"] == "project_created" for e in events)


class TestMusicGet:
    def test_get_round_trip(self):
        created = _create()
        got = _client().get(f"/api/music/projects/{created['project_id']}").json()
        assert got == created

    def test_get_missing_returns_404(self):
        assert _client().get("/api/music/projects/mus_nope").status_code == 404


# ── Seed persistence ───────────────────────────────────────────────────────

class TestSeedPersistence:
    def test_supplied_seed_is_persisted(self):
        data = _create(seed=1234567890123456789)
        assert data["seed"] == 1234567890123456789
        got = _client().get(f"/api/music/projects/{data['project_id']}").json()
        assert got["seed"] == 1234567890123456789

    def test_generated_seed_is_stable_across_reads(self):
        pid = _create()["project_id"]
        s1 = _client().get(f"/api/music/projects/{pid}").json()["seed"]
        s2 = _client().get(f"/api/music/projects/{pid}").json()["seed"]
        assert s1 == s2


# ── Export round-trip ──────────────────────────────────────────────────────

class TestMusicExport:
    def test_export_structure(self):
        created = _create(seed=42)
        exp = _client().post(f"/api/music/projects/{created['project_id']}/export").json()
        assert exp["export_version"] == "1.0"
        assert exp["project_type"] == "music"
        assert exp["project"]["project_id"] == created["project_id"]
        assert exp["project"]["seed"] == 42
        assert exp["project"]["tracks"] == created["tracks"]
        assert exp["audio"]["status"] == "placeholder"
        assert exp["replay"]["replay_id"] == created["project_id"]
        assert exp["replay"]["event_count"] >= 1  # project_created

    def test_export_missing_returns_404(self):
        assert _client().post("/api/music/projects/mus_nope/export").status_code == 404

    def test_export_is_idempotent(self):
        pid = _create()["project_id"]
        e1 = _client().post(f"/api/music/projects/{pid}/export").json()
        e2 = _client().post(f"/api/music/projects/{pid}/export").json()
        assert e1 == e2


# ── Deterministic render preview ───────────────────────────────────────────

class TestRenderPreview:
    def test_render_preview_deterministic_for_same_project(self):
        pid = _create(seed=99)["project_id"]
        r1 = _client().post(f"/api/music/projects/{pid}/render-preview").json()
        r2 = _client().post(f"/api/music/projects/{pid}/render-preview").json()
        assert r1 == r2
        assert r1["status"] == "mock_rendered"
        assert r1["deterministic"] is True
        assert len(r1["sections"]) == 4

    def test_render_preview_same_seed_same_manifest_across_projects(self):
        p1 = _create(seed=777)["project_id"]
        p2 = _create(seed=777)["project_id"]
        r1 = _client().post(f"/api/music/projects/{p1}/render-preview").json()
        r2 = _client().post(f"/api/music/projects/{p2}/render-preview").json()
        assert r1["render_id"] == r2["render_id"]
        assert r1["sections"] == r2["sections"]
        assert r1["waveform_checksum"] == r2["waveform_checksum"]

    def test_render_preview_missing_returns_404(self):
        assert _client().post("/api/music/projects/mus_nope/render-preview").status_code == 404


# ── Creator Card apply ─────────────────────────────────────────────────────

class TestCreatorCardApply:
    def test_apply_music_card(self):
        pid = _create()["project_id"]
        resp = _client().post("/api/creator-cards/apply", json={
            "card_id": "card_maestro_01", "project_type": "music", "project_id": pid,
        })
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["ok"] is True
        assert data["pack"]["pack_id"] == "pack_music_theory_101"
        # ref persisted
        assert data["ref_id"] in creative_store._memory["creator_card_refs"]
        # pack attached to project
        got = _client().get(f"/api/music/projects/{pid}").json()
        assert got["applied_card_packs"][0]["card_id"] == "card_maestro_01"

    def test_apply_wrong_mode_card_rejected(self):
        pid = _create()["project_id"]
        resp = _client().post("/api/creator-cards/apply", json={
            "card_id": "card_groove_01", "project_type": "music", "project_id": pid,
        })
        assert resp.status_code == 422

    def test_apply_unknown_card_404(self):
        pid = _create()["project_id"]
        resp = _client().post("/api/creator-cards/apply", json={
            "card_id": "card_nope_99", "project_type": "music", "project_id": pid,
        })
        assert resp.status_code == 404

    def test_apply_twice_conflicts(self):
        pid = _create()["project_id"]
        body = {"card_id": "card_sampler_01", "project_type": "music", "project_id": pid}
        assert _client().post("/api/creator-cards/apply", json=body).status_code == 200
        assert _client().post("/api/creator-cards/apply", json=body).status_code == 409

    def test_packs_registry_exposed(self):
        packs = _client().get("/api/creator-cards/packs").json()["packs"]
        assert "card_maestro_01" in packs
        assert packs["card_maestro_01"]["mode"] == "music"


# ── Generic replay export reuses match event store ─────────────────────────

class TestGenericReplayExport:
    def test_replay_export_for_music_project(self):
        pid = _create(seed=555)["project_id"]
        _client().post("/api/creator-cards/apply", json={
            "card_id": "card_maestro_01", "project_type": "music", "project_id": pid,
        })
        exp = _client().get(f"/api/replays/{pid}/export").json()
        meta = exp["metadata"]
        assert meta["replay_id"] == pid
        assert meta["project_type"] == "music"
        assert meta["seed"] == 555
        types_seen = [e["type"] for e in exp["events"]]
        assert "project_created" in types_seen
        assert "card_applied" in types_seen
        # events ordered by seq
        seqs = [e.get("seq", 0) for e in exp["events"]]
        assert seqs == sorted(seqs)

    def test_replay_export_unknown_id_404(self):
        assert _client().get("/api/replays/nope/export").status_code == 404
