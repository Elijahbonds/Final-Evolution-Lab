"""
Who Scene It P1 — unit self-check.

Covers:
  - TestSchemas               : dataclasses + enums instantiate correctly
  - TestScoring               : compute_buzz_score, DefaultBuzzinScoringModule
  - TestRoundTypeModule       : SequentialRoundTypeModule
  - TestCardModule            : InMemoryCardModule check_award + collection
  - TestLocalSceneContentModule : reads real JSON file
  - TestRouter                : HTTP endpoints (MOCK_DB=1, fully offline)

All tests run offline — no DB, no network.
"""
import os
import sys
import types
from unittest.mock import MagicMock, patch

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_si")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")
os.environ["MOCK_DB"] = "1"

# ── Stub third-party modules before any FEL import ────────────────────────────

def _stub(name: str):
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

# ── Now safe to import FEL modules ────────────────────────────────────────────

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

import core
from core import User
from lib.who_scene_it.schemas import (
    BuzzinResult,
    BuzzinSession,
    CreatorCard,
    RoundType,
    SceneContent,
)
from lib.who_scene_it.scoring import (
    ANSWER_TIME_LIMIT_MS,
    DefaultBuzzinScoringModule,
    INITIAL_SCORE,
    SCORE_DRAIN_RATE,
    WRONG_BUZZ_PENALTY,
    compute_buzz_score,
)
from lib.who_scene_it.providers import (
    CARD_THRESHOLD,
    InMemoryCardModule,
    LocalSceneContentModule,
    SequentialRoundTypeModule,
)
from routers.who_scene_it import (
    _si_card_module,
    _si_sessions,
    router as si_router,
)

_app = FastAPI()
_app.include_router(si_router)

_USER = User(
    user_id="scene_player_01",
    email="scene@fellab.io",
    name="Scene Spotter",
    sport="basketball",
    prq_score=85.0,
    level=4,
    xp=400,
    streak_days=7,
    coins=200,
)


def _client(user: User = _USER) -> TestClient:
    _app.dependency_overrides[core.get_current_user] = lambda: user
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear_state():
    _si_sessions.clear()
    _si_card_module._collections.clear()
    yield
    _si_sessions.clear()
    _si_card_module._collections.clear()


# ── TestSchemas ───────────────────────────────────────────────────────────────

class TestSchemas:
    def test_round_type_enum_values(self):
        assert RoundType.image_reveal.value == "image_reveal"
        assert RoundType.audio_clip.value == "audio_clip"
        assert RoundType.text_clue.value == "text_clue"
        assert RoundType.silhouette.value == "silhouette"
        assert len(list(RoundType)) == 4

    def test_scene_content_dataclass(self):
        sc = SceneContent(
            content_id="sc_01",
            title="The Iron Sentinel",
            description="A guardian.",
            image_path="assets/test.png",
            round_type=RoundType.image_reveal,
            difficulty=2,
            license="FEL Studios Original",
            source="FEL Studios art team",
            content_provider_id="fel_internal_v1",
        )
        assert sc.content_id == "sc_01"
        assert sc.round_type == RoundType.image_reveal
        assert sc.tags == []

    def test_buzzin_result_dataclass(self):
        br = BuzzinResult(
            content_id="sc_01",
            score_awarded=400,
            buzz_time_ms=2000,
            answer_time_ms=1500,
            is_correct=True,
            penalty=0,
        )
        assert br.is_correct is True
        assert br.score_awarded == 400

    def test_buzzin_session_defaults(self):
        session = BuzzinSession(
            session_id="s1",
            user_id="u1",
            round_type=RoundType.text_clue,
        )
        assert session.rounds_played == 0
        assert session.total_score == 0
        assert session.status == "active"

    def test_creator_card_dataclass(self):
        card = CreatorCard(
            card_id="si_card_01",
            name="The Visionary",
            description="desc",
            image_placeholder="card_01.png",
            round_type=RoundType.image_reveal,
        )
        assert card.round_type == RoundType.image_reveal


# ── TestScoring ───────────────────────────────────────────────────────────────

class TestScoring:
    def test_instant_correct_buzz_earns_initial_score(self):
        score = compute_buzz_score(0, is_correct=True)
        assert score == INITIAL_SCORE

    def test_wrong_buzz_earns_zero(self):
        score = compute_buzz_score(500, is_correct=False)
        assert score == 0

    def test_score_drains_per_second(self):
        score_0s = compute_buzz_score(0, is_correct=True)
        score_1s = compute_buzz_score(1000, is_correct=True)
        assert score_0s - score_1s == SCORE_DRAIN_RATE

    def test_score_floors_at_zero(self):
        very_late = 999_000
        score = compute_buzz_score(very_late, is_correct=True)
        assert score == 0

    def test_score_uses_floor_seconds(self):
        score_999ms = compute_buzz_score(999, is_correct=True)
        score_0ms = compute_buzz_score(0, is_correct=True)
        assert score_999ms == score_0ms  # still 0 full seconds elapsed

    def test_scoring_module_correct(self):
        sm = DefaultBuzzinScoringModule()
        result = sm.compute_score(buzz_time_ms=2000, is_correct=True)
        assert result.is_correct is True
        assert result.score_awarded == INITIAL_SCORE - 2 * SCORE_DRAIN_RATE
        assert result.penalty == 0

    def test_scoring_module_wrong_returns_penalty(self):
        sm = DefaultBuzzinScoringModule()
        result = sm.compute_score(buzz_time_ms=1000, is_correct=False)
        assert result.is_correct is False
        assert result.score_awarded == 0
        assert result.penalty == WRONG_BUZZ_PENALTY

    def test_timed_out_score_is_zero(self):
        sm = DefaultBuzzinScoringModule()
        assert sm.timed_out_score() == 0

    def test_scoring_constants_sane(self):
        assert INITIAL_SCORE > 0
        assert SCORE_DRAIN_RATE > 0
        assert WRONG_BUZZ_PENALTY > 0
        assert ANSWER_TIME_LIMIT_MS >= 4_000


# ── TestRoundTypeModule ───────────────────────────────────────────────────────

class TestRoundTypeModule:
    def test_next_round_type_returns_valid_type(self):
        rm = SequentialRoundTypeModule()
        rt = rm.next_round_type(seed=42)
        assert rt in list(RoundType)

    def test_next_round_type_deterministic(self):
        rm1 = SequentialRoundTypeModule()
        rm2 = SequentialRoundTypeModule()
        assert rm1.next_round_type(seed=123) == rm2.next_round_type(seed=123)

    def test_avoids_used_types_when_possible(self):
        rm = SequentialRoundTypeModule()
        used = [RoundType.text_clue, RoundType.silhouette, RoundType.image_reveal]
        rt = rm.next_round_type(seed=1, used=used)
        assert rt == RoundType.audio_clip

    def test_resets_when_all_used(self):
        rm = SequentialRoundTypeModule()
        all_types = list(RoundType)
        rt = rm.next_round_type(seed=77, used=all_types)
        assert rt in list(RoundType)


# ── TestCardModule ────────────────────────────────────────────────────────────

class TestCardModule:
    def test_no_award_below_threshold(self):
        cm = InMemoryCardModule()
        assert cm.check_award(RoundType.image_reveal, CARD_THRESHOLD - 1) is None

    def test_award_at_threshold(self):
        cm = InMemoryCardModule()
        card = cm.check_award(RoundType.image_reveal, CARD_THRESHOLD)
        assert card is not None
        assert card.round_type == RoundType.image_reveal

    def test_award_above_threshold(self):
        cm = InMemoryCardModule()
        card = cm.check_award(RoundType.audio_clip, CARD_THRESHOLD + 2)
        assert card is not None

    def test_collection_empty_initially(self):
        cm = InMemoryCardModule()
        assert cm.get_collection("user_x") == []

    def test_award_adds_to_collection(self):
        cm = InMemoryCardModule()
        card = cm.check_award(RoundType.text_clue, CARD_THRESHOLD)
        cm.award("user_x", card)
        coll = cm.get_collection("user_x")
        assert len(coll) == 1
        assert coll[0].round_type == RoundType.text_clue

    def test_award_deduplicates(self):
        cm = InMemoryCardModule()
        card = cm.check_award(RoundType.silhouette, CARD_THRESHOLD)
        cm.award("user_x", card)
        cm.award("user_x", card)
        assert len(cm.get_collection("user_x")) == 1

    def test_multiple_users_isolated(self):
        cm = InMemoryCardModule()
        card = cm.check_award(RoundType.image_reveal, CARD_THRESHOLD)
        cm.award("user_a", card)
        assert cm.get_collection("user_b") == []


# ── TestLocalSceneContentModule ───────────────────────────────────────────────

class TestLocalSceneContentModule:
    def test_loads_all_round_types(self):
        lc = LocalSceneContentModule()
        content = lc.list_content()
        types_found = {c.round_type for c in content}
        assert len(types_found) == 4

    def test_content_count(self):
        lc = LocalSceneContentModule()
        assert len(lc.list_content()) == 12

    def test_get_content_returns_item(self):
        lc = LocalSceneContentModule()
        c = lc.get_content(RoundType.text_clue, difficulty=1)
        assert isinstance(c, SceneContent)
        assert c.round_type == RoundType.text_clue

    def test_get_content_excludes_ids(self):
        lc = LocalSceneContentModule()
        first = lc.get_content(RoundType.silhouette, difficulty=1)
        second = lc.get_content(RoundType.silhouette, difficulty=1, exclude_ids={first.content_id})
        assert second is None or second.content_id != first.content_id

    def test_get_content_by_id(self):
        lc = LocalSceneContentModule()
        c = lc.get_content(RoundType.image_reveal, difficulty=1)
        fetched = lc.get_content_by_id(c.content_id)
        assert fetched is not None
        assert fetched.content_id == c.content_id

    def test_content_has_required_fields(self):
        lc = LocalSceneContentModule()
        for c in lc.list_content():
            assert c.license
            assert c.source
            assert c.content_provider_id

    def test_list_filtered_by_round_type(self):
        lc = LocalSceneContentModule()
        audio_items = lc.list_content(round_type=RoundType.audio_clip)
        assert all(c.round_type == RoundType.audio_clip for c in audio_items)
        assert len(audio_items) == 3

    def test_pool_exhaustion_returns_none(self):
        lc = LocalSceneContentModule()
        all_ids = {c.content_id for c in lc.list_content(round_type=RoundType.audio_clip)}
        result = lc.get_content(RoundType.audio_clip, difficulty=1, exclude_ids=all_ids)
        assert result is None


# ── TestRouter ────────────────────────────────────────────────────────────────

class TestRouter:
    def _start(self, round_count: int = 4) -> dict:
        resp = _client().post("/api/who-scene-it/session", json={"round_count": round_count})
        assert resp.status_code == 200
        return resp.json()

    def _buzz(self, session_id: str, content_id: str, chosen_index: int, buzz_ms: int = 1000) -> dict:
        resp = _client().post(
            f"/api/who-scene-it/session/{session_id}/buzz",
            json={"content_id": content_id, "buzz_time_ms": buzz_ms, "chosen_index": chosen_index},
        )
        return resp

    def test_start_session_returns_session_id(self):
        data = self._start()
        assert "session_id" in data
        assert data["session_id"]

    def test_start_session_returns_first_round(self):
        data = self._start()
        assert data["round"] is not None
        r = data["round"]
        assert "content_id" in r
        assert "options" in r
        assert len(r["options"]) == 4

    def test_start_session_stores_in_state(self):
        data = self._start()
        assert data["session_id"] in _si_sessions

    def test_buzz_correct_answer_returns_score(self):
        data = self._start()
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        resp = self._buzz(sid, r["content_id"], correct_idx)
        assert resp.status_code == 200
        body = resp.json()
        assert body["is_correct"] is True
        assert body["score_awarded"] > 0
        assert body["penalty"] == 0

    def test_buzz_wrong_answer_returns_penalty(self):
        data = self._start()
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        wrong_idx = (correct_idx + 1) % 4
        resp = self._buzz(sid, r["content_id"], wrong_idx)
        assert resp.status_code == 200
        body = resp.json()
        assert body["is_correct"] is False
        assert body["score_awarded"] == 0
        assert body["penalty"] == WRONG_BUZZ_PENALTY

    def test_buzz_content_id_mismatch_returns_400(self):
        data = self._start()
        sid = data["session_id"]
        resp = self._buzz(sid, "wrong-id", 0)
        assert resp.status_code == 400

    def test_buzz_missing_session_returns_404(self):
        resp = self._buzz("no-such-session", "content_01", 0)
        assert resp.status_code == 404

    def test_correct_buzz_increments_streak(self):
        data = self._start()
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        body = self._buzz(sid, r["content_id"], correct_idx).json()
        assert body["buzz_streak"] == 1

    def test_wrong_buzz_resets_streak(self):
        data = self._start()
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        # First correct
        self._buzz(sid, r["content_id"], correct_idx)
        # Second wrong — read the NEW correct index for round 2
        r2 = _si_sessions[sid].get("current_content")
        correct_idx_2 = _si_sessions[sid]["current_correct_index"]
        wrong_idx = (correct_idx_2 + 1) % 4
        body = self._buzz(sid, r2.content_id, wrong_idx).json()
        assert body["buzz_streak"] == 0

    def test_total_score_tracked(self):
        data = self._start()
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        body = self._buzz(sid, r["content_id"], correct_idx, buzz_ms=0).json()
        assert body["total_score"] == INITIAL_SCORE

    def test_wrong_buzz_penalises_total_score(self):
        data = self._start()
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        wrong_idx = (correct_idx + 1) % 4
        body = self._buzz(sid, r["content_id"], wrong_idx).json()
        assert body["total_score"] == 0  # started at 0; penalty can't go below 0

    def test_buzz_returns_next_round(self):
        data = self._start(round_count=4)
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        body = self._buzz(sid, r["content_id"], correct_idx).json()
        assert body["next_round"] is not None
        assert "options" in body["next_round"]

    def test_session_complete_after_all_rounds(self):
        data = self._start(round_count=1)
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        body = self._buzz(sid, r["content_id"], correct_idx).json()
        assert body["session_complete"] is True
        assert _si_sessions[sid]["status"] == "complete"

    def test_result_endpoint_returns_score(self):
        data = self._start()
        sid = data["session_id"]
        result = _client().get(f"/api/who-scene-it/session/{sid}/result")
        assert result.status_code == 200
        body = result.json()
        assert "total_score" in body
        assert "correct_count" in body
        assert "collection" in body

    def test_result_404_on_missing_session(self):
        resp = _client().get("/api/who-scene-it/session/no-such/result")
        assert resp.status_code == 404

    def test_result_correct_count_accurate(self):
        data = self._start(round_count=1)
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        self._buzz(sid, r["content_id"], correct_idx)
        body = _client().get(f"/api/who-scene-it/session/{sid}/result").json()
        assert body["correct_count"] == 1

    def test_buzz_active_session_409_check(self):
        data = self._start(round_count=1)
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        self._buzz(sid, r["content_id"], correct_idx)  # completes session
        resp = _client().post(
            f"/api/who-scene-it/session/{sid}/buzz",
            json={"content_id": "any", "buzz_time_ms": 500, "chosen_index": 0},
        )
        assert resp.status_code == 409

    def test_did_you_know_in_buzz_response(self):
        data = self._start()
        sid = data["session_id"]
        r = data["round"]
        correct_idx = _si_sessions[sid]["current_correct_index"]
        body = self._buzz(sid, r["content_id"], correct_idx).json()
        assert "did_you_know" in body
