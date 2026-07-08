"""
Unit tests for Art Showcase Mode — /api/art/* micro-games + sample content.

Covers:
  - exhibit CRUD + publish flow (mode-level smoke, distinct from
    test_art_exhibit.py foundation tests)
  - sample exhibit content shape (3 images + 1 glTF model, alt/license)
  - guess-the-technique determinism + server-side answer hiding
  - timed-sketch save (derivative item, tiny)
  - critique-card save

Runs fully offline under MOCK_DB=1 (in-memory stores).
"""
import os, sys

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
from lib import creative_store
from lib.creative_store import get_creative_user
from routers.matches import _events, _matches
from routers.art import router as art_router

_app = FastAPI()
_app.include_router(art_router)

_USER = User(user_id="artist_m", email="am@fellab.io", name="Artist M")


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


def _create_exhibit():
    resp = _client().post("/api/art/exhibits", json={
        "title": "Mode Exhibit",
        "items": [{"type": "image", "path": "/x.svg", "meta": {"alt": "x"}}],
    })
    assert resp.status_code == 200, resp.text
    return resp.json()["exhibit_id"]


# ── Sample content ─────────────────────────────────────────────────────────

class TestSampleExhibit:
    def test_sample_has_three_images_and_one_model(self):
        data = _client().get("/api/art/sample-exhibit").json()
        items = data["items"]
        images = [i for i in items if i["type"] == "image"]
        models = [i for i in items if i["type"] == "model"]
        assert len(images) == 3
        assert len(models) == 1

    def test_every_item_has_alt_and_license(self):
        items = _client().get("/api/art/sample-exhibit").json()["items"]
        for i in items:
            assert i["meta"].get("alt"), f"missing alt: {i}"
            assert i["meta"].get("license"), f"missing license: {i}"
            assert i["meta"].get("source"), f"missing source: {i}"

    def test_items_link_creator_cards(self):
        items = _client().get("/api/art/sample-exhibit").json()["items"]
        card_ids = {i["meta"].get("card_id") for i in items}
        # Uses only the contract-stable art card ids.
        assert card_ids <= {"card_visionary_01", "card_curator_01"}
        assert "card_visionary_01" in card_ids


# ── Guess-the-technique determinism + answer hiding ────────────────────────

class TestGuessTechnique:
    def test_round_is_deterministic_for_seed(self):
        a = _client().get("/api/art/guess-technique/round?seed=42&count=4").json()
        b = _client().get("/api/art/guess-technique/round?seed=42&count=4").json()
        assert a == b

    def test_different_seed_changes_order(self):
        a = _client().get("/api/art/guess-technique/round?seed=1&count=5").json()
        b = _client().get("/api/art/guess-technique/round?seed=2&count=5").json()
        assert [q["id"] for q in a["questions"]] != [q["id"] for q in b["questions"]] \
            or any(qa["options"] != qb["options"]
                   for qa, qb in zip(a["questions"], b["questions"]))

    def test_round_never_ships_correct_answer(self):
        data = _client().get("/api/art/guess-technique/round?seed=7").json()
        for q in data["questions"]:
            assert "correct" not in q
            assert "lesson" not in q
            assert "answer_token" in q  # opaque, not the answer
            assert isinstance(q["options"], list) and len(q["options"]) >= 2

    def test_count_zero_rejected(self):
        assert _client().get("/api/art/guess-technique/round?seed=1&count=0").status_code == 422

    def test_answer_reveals_correctness_and_lesson(self):
        resp = _client().post("/api/art/guess-technique/answer", json={
            "seed": 1, "question_id": "gt_lowpoly", "selected": "Low-poly",
        })
        assert resp.status_code == 200, resp.text
        data = resp.json()
        assert data["is_correct"] is True
        assert data["correct"] == "Low-poly"
        assert data["lesson"]

    def test_wrong_answer_marked_incorrect(self):
        data = _client().post("/api/art/guess-technique/answer", json={
            "seed": 1, "question_id": "gt_lowpoly", "selected": "Watercolor",
        }).json()
        assert data["is_correct"] is False
        assert data["correct"] == "Low-poly"

    def test_unknown_question_404(self):
        assert _client().post("/api/art/guess-technique/answer", json={
            "seed": 1, "question_id": "gt_nope", "selected": "x",
        }).status_code == 404

    def test_answer_records_replay_event_when_attached(self):
        eid = _create_exhibit()
        _client().post("/api/art/guess-technique/answer", json={
            "seed": 3, "question_id": "gt_gradient",
            "selected": "Gradient blending", "exhibit_id": eid,
        })
        exp = _client().get(f"/api/art/exhibits/{eid}")
        assert exp.status_code == 200
        assert eid in _events
        assert any(e["type"] == "guess_technique_answered" for e in _events[eid])


# ── Timed sketch ───────────────────────────────────────────────────────────

class TestSketchSave:
    def test_sketch_saved_as_derivative_item(self):
        eid = _create_exhibit()
        resp = _client().post(f"/api/art/exhibits/{eid}/sketch", json={
            "strokes": [{"points": [[0, 0], [1, 1]], "color": "#00D4FF", "width": 3}],
            "thumbnail": "data:image/png;base64,AAAA",
            "duration_sec": 30.0,
            "prompt": "a cube",
        })
        assert resp.status_code == 200, resp.text
        item = resp.json()["item"]
        assert item["type"] == "image"
        assert item["meta"]["derivative"] is True
        assert item["meta"]["kind"] == "timed_sketch"
        assert item["meta"]["stroke_count"] == 1
        assert item["meta"]["alt"]

    def test_sketch_appended_to_exhibit(self):
        eid = _create_exhibit()
        _client().post(f"/api/art/exhibits/{eid}/sketch", json={"strokes": []})
        got = _client().get(f"/api/art/exhibits/{eid}").json()
        assert any(i["meta"].get("kind") == "timed_sketch" for i in got["items"])

    def test_sketch_stroke_cap_enforced(self):
        eid = _create_exhibit()
        big = [{"points": [[0, 0]]} for _ in range(2001)]
        assert _client().post(f"/api/art/exhibits/{eid}/sketch",
                              json={"strokes": big}).status_code == 422

    def test_sketch_missing_exhibit_404(self):
        assert _client().post("/api/art/exhibits/art_nope/sketch",
                              json={"strokes": []}).status_code == 404


# ── Critique cards ─────────────────────────────────────────────────────────

class TestCritiqueSave:
    def test_critique_saved(self):
        eid = _create_exhibit()
        resp = _client().post(f"/api/art/exhibits/{eid}/critique", json={
            "composition": "Strong diagonal", "color": "Warm/cool balance",
            "execution": "Clean edges", "rating": 4,
        })
        assert resp.status_code == 200, resp.text
        crit = resp.json()["critique"]
        assert crit["rating"] == 4
        assert crit["author_id"] == "artist_m"

    def test_critique_persisted_on_exhibit(self):
        eid = _create_exhibit()
        _client().post(f"/api/art/exhibits/{eid}/critique", json={"composition": "ok"})
        got = _client().get(f"/api/art/exhibits/{eid}").json()
        assert len(got["critiques"]) == 1

    def test_empty_critique_rejected(self):
        eid = _create_exhibit()
        assert _client().post(f"/api/art/exhibits/{eid}/critique",
                              json={}).status_code == 422

    def test_critique_rating_range_enforced(self):
        eid = _create_exhibit()
        assert _client().post(f"/api/art/exhibits/{eid}/critique",
                              json={"rating": 9}).status_code == 422

    def test_critique_missing_exhibit_404(self):
        assert _client().post("/api/art/exhibits/art_nope/critique",
                              json={"composition": "x"}).status_code == 404


# ── Publish flow (mode-level smoke) ────────────────────────────────────────

class TestPublishFlow:
    def test_publish_then_marketplace_listed(self):
        eid = _create_exhibit()
        pub = _client().post(f"/api/art/exhibits/{eid}/publish").json()
        assert pub["status"] == "published"
        assert pub["marketplace"]["stub"] is True
