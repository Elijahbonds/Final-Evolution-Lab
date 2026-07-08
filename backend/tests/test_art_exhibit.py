"""
Unit tests for /api/art/* — Art Showcase foundation.

CRUD + publish (marketplace stub) state change + creator-card apply.
Runs fully offline under MOCK_DB=1 (in-memory stores).
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
from routers.art import router as art_router
from routers.creator_cards import router as cards_router

_app = FastAPI()
_app.include_router(art_router)
_app.include_router(cards_router)

_USER = User(user_id="artist_a", email="aa@fellab.io", name="Artist A")


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


_ITEMS = [
    {"type": "image", "path": "assets/gallery/sunrise.png", "meta": {"w": 1920, "h": 1080}},
    {"type": "3d", "path": "assets/venues/sculpture_01.scn", "meta": {"polys": 12000}},
    {"type": "model", "path": "assets/models/statue.usdz"},
]


def _create(**overrides):
    body = {"title": "First Light", "items": _ITEMS, **overrides}
    resp = _client().post("/api/art/exhibits", json=body)
    assert resp.status_code == 200, resp.text
    return resp.json()


# ── CRUD ───────────────────────────────────────────────────────────────────

class TestArtCreate:
    def test_create_returns_exhibit(self):
        data = _create()
        assert data["exhibit_id"].startswith("art_")
        assert data["owner_id"] == "artist_a"
        assert data["title"] == "First Light"
        assert data["status"] == "draft"
        assert data["published_at"] is None
        assert data["marketplace"]["listed"] is False

    def test_items_get_ids_and_keep_meta(self):
        data = _create()
        assert len(data["items"]) == 3
        for item in data["items"]:
            assert item["id"]
            assert item["type"] in ("image", "3d", "model")
        assert data["items"][0]["meta"] == {"w": 1920, "h": 1080}
        assert data["items"][2]["meta"] == {}  # default

    def test_stored_in_memory_store(self):
        data = _create()
        assert data["exhibit_id"] in creative_store._memory["art_exhibits"]

    def test_invalid_item_type_rejected(self):
        resp = _client().post("/api/art/exhibits", json={
            "items": [{"type": "hologram", "path": "x"}],
        })
        assert resp.status_code == 422

    def test_item_requires_path(self):
        resp = _client().post("/api/art/exhibits", json={"items": [{"type": "image"}]})
        assert resp.status_code == 422


class TestArtGet:
    def test_get_round_trip(self):
        created = _create()
        got = _client().get(f"/api/art/exhibits/{created['exhibit_id']}").json()
        assert got == created

    def test_get_missing_returns_404(self):
        assert _client().get("/api/art/exhibits/art_nope").status_code == 404


# ── Publish (marketplace stub) ─────────────────────────────────────────────

class TestArtPublish:
    def test_publish_transitions_draft_to_published(self):
        eid = _create()["exhibit_id"]
        resp = _client().post(f"/api/art/exhibits/{eid}/publish")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "published"
        assert data["published_at"] is not None
        assert data["marketplace"]["listed"] is True
        assert data["marketplace"]["stub"] is True
        assert data["marketplace"]["listing_id"].startswith("list_")

    def test_publish_persists_state(self):
        eid = _create()["exhibit_id"]
        _client().post(f"/api/art/exhibits/{eid}/publish")
        got = _client().get(f"/api/art/exhibits/{eid}").json()
        assert got["status"] == "published"
        assert got["marketplace"]["listed"] is True

    def test_double_publish_conflicts(self):
        eid = _create()["exhibit_id"]
        assert _client().post(f"/api/art/exhibits/{eid}/publish").status_code == 200
        assert _client().post(f"/api/art/exhibits/{eid}/publish").status_code == 409

    def test_publish_missing_returns_404(self):
        assert _client().post("/api/art/exhibits/art_nope/publish").status_code == 404


# ── Creator Card apply ─────────────────────────────────────────────────────

class TestCreatorCardApply:
    def test_apply_art_card(self):
        eid = _create()["exhibit_id"]
        resp = _client().post("/api/creator-cards/apply", json={
            "card_id": "card_visionary_01", "project_type": "art", "project_id": eid,
        })
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["pack"]["pack_id"] == "pack_art_composition_101"
        got = _client().get(f"/api/art/exhibits/{eid}").json()
        assert got["applied_card_packs"][0]["card_id"] == "card_visionary_01"

    def test_apply_dance_card_to_art_rejected(self):
        eid = _create()["exhibit_id"]
        resp = _client().post("/api/creator-cards/apply", json={
            "card_id": "card_choreo_01", "project_type": "art", "project_id": eid,
        })
        assert resp.status_code == 422

    def test_card_ref_record_shape(self):
        eid = _create()["exhibit_id"]
        ref_id = _client().post("/api/creator-cards/apply", json={
            "card_id": "card_curator_01", "project_type": "art", "project_id": eid,
        }).json()["ref_id"]
        ref = creative_store._memory["creator_card_refs"][ref_id]
        assert ref["card_id"] == "card_curator_01"
        assert ref["pack_id"] == "pack_exhibit_curation_101"
        assert ref["project_type"] == "art"
        assert ref["project_id"] == eid
        assert ref["owner_id"] == "artist_a"


# ── Generic replay export (art exhibits are replayable containers too) ─────

class TestGenericReplayExport:
    def test_replay_export_for_art_exhibit(self):
        eid = _create()["exhibit_id"]
        _client().post("/api/creator-cards/apply", json={
            "card_id": "card_visionary_01", "project_type": "art", "project_id": eid,
        })
        exp = _client().get(f"/api/replays/{eid}/export").json()
        assert exp["metadata"]["project_type"] == "art"
        assert exp["metadata"]["replay_id"] == eid
        assert any(e["type"] == "card_applied" for e in exp["events"])
