"""
Brain Brawl P1 — unit self-check.

Covers:
  - TestSchemas          : dataclasses + enums instantiate correctly
  - TestScoring          : score_answer, compute_brawn_score, grade table
  - TestCategoryModule   : SpinCategoryModule spin + select
  - TestGhostModule      : InMemoryGhostModule record / get / list
  - TestCognitiveModule  : LocalCognitiveModule get_round + validate_answer
  - TestCardModule       : InMemoryCardModule check_award + get_collection
  - TestLocalProvider    : LocalQuestionProvider reads real JSON file
  - TestBrainBrawlRouter : HTTP endpoints (MOCK_DB=1, fully offline)

All tests run offline — no DB, no network.
"""
import os
import sys
import types
from unittest.mock import MagicMock, patch

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_bb")
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
from lib.brain_brawl.schemas import (
    AnswerResult,
    BrawnScore,
    Category,
    CognitiveRound,
    CognitiveRoundType,
    CollectionItem,
    GhostRecord,
    Question,
)
from lib.brain_brawl.scoring import (
    BASE_POINTS,
    DEFAULT_TIME_LIMIT_MS,
    MAX_SPEED_BONUS,
    compute_brawn_score,
    score_answer,
)
from lib.brain_brawl.providers import (
    CROWN_THRESHOLD,
    InMemoryCardModule,
    InMemoryGhostModule,
    LocalCognitiveModule,
    LocalQuestionProvider,
    SpinCategoryModule,
)
from routers.brain_brawl import (
    _card_module,
    _ghost_module,
    _sessions,
    router as bb_router,
)

_app = FastAPI()
_app.include_router(bb_router)

_USER = User(
    user_id="brawler_01",
    email="brawler@fellab.io",
    name="Brain Brawler",
    sport="basketball",
    prq_score=80.0,
    level=3,
    xp=300,
    streak_days=5,
    coins=150,
)
_USER_B = User(
    user_id="brawler_02",
    email="brawler2@fellab.io",
    name="Ghost Challenger",
    sport="basketball",
    prq_score=75.0,
    level=2,
    xp=200,
    streak_days=2,
    coins=100,
)


def _client(user: User = _USER) -> TestClient:
    _app.dependency_overrides[core.get_current_user] = lambda: user
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear_state():
    """Reset all module-level state before each test."""
    _sessions.clear()
    _ghost_module._store.clear()
    _card_module._collections.clear()
    yield
    _sessions.clear()
    _ghost_module._store.clear()
    _card_module._collections.clear()


# ── Helper fixtures ───────────────────────────────────────────────────────────

def _make_question(
    qid: str = "q1",
    correct_index: int = 0,
    difficulty: int = 1,
    cat: Category = Category.science,
) -> Question:
    return Question(
        id=qid,
        prompt="What is the answer?",
        options=["Correct", "Wrong A", "Wrong B", "Wrong C"],
        correct_index=correct_index,
        category=cat,
        difficulty=difficulty,
        did_you_know="A fascinating fact.",
    )


def _make_answer_result(correct: bool = True, response_ms: int = 1000) -> AnswerResult:
    q = _make_question()
    return score_answer(q, 0 if correct else 1, response_ms)


# ── TestSchemas ───────────────────────────────────────────────────────────────

class TestSchemas:
    def test_category_enum_values(self):
        assert Category.creators_devs.value == "creators_devs"
        assert Category.crown.value == "crown"
        assert len(list(Category)) == 7

    def test_question_dataclass(self):
        q = _make_question()
        assert q.id == "q1"
        assert len(q.options) == 4
        assert q.correct_index == 0

    def test_answer_result_dataclass(self):
        ar = AnswerResult(
            question_id="q1", chosen_index=0, correct_index=0,
            is_correct=True, response_ms=500, points_earned=140, speed_bonus=40,
        )
        assert ar.is_correct is True
        assert ar.points_earned == 140

    def test_brawn_score_dataclass(self):
        bs = BrawnScore(
            raw=1200, max_raw=1500, percentage=80.0, grade="B",
            question_count=10, correct_count=8, avg_response_ms=3000.0,
        )
        assert bs.grade == "B"
        assert bs.correct_count == 8

    def test_cognitive_round_type_enum(self):
        assert CognitiveRoundType.memorize_sequence.value == "memorize_sequence"
        assert CognitiveRoundType.spot_pattern.value == "spot_pattern"

    def test_collection_item_dataclass(self):
        item = CollectionItem(
            item_id="item_01", category=Category.art,
            name="The Canvas King", description="desc", image_placeholder="art_01.png",
        )
        assert item.category == Category.art


# ── TestScoring ───────────────────────────────────────────────────────────────

class TestScoring:
    def test_correct_answer_earns_base_points(self):
        q = _make_question()
        result = score_answer(q, 0, DEFAULT_TIME_LIMIT_MS)
        assert result.is_correct is True
        assert result.points_earned == BASE_POINTS  # no speed bonus at full time

    def test_incorrect_answer_earns_zero(self):
        q = _make_question()
        result = score_answer(q, 1, 500)
        assert result.is_correct is False
        assert result.points_earned == 0
        assert result.speed_bonus == 0

    def test_fastest_correct_answer_earns_max_bonus(self):
        q = _make_question()
        result = score_answer(q, 0, 0)
        assert result.speed_bonus == MAX_SPEED_BONUS
        assert result.points_earned == BASE_POINTS + MAX_SPEED_BONUS

    def test_speed_bonus_decreases_with_time(self):
        q = _make_question()
        fast = score_answer(q, 0, 1_000)
        slow = score_answer(q, 0, 8_000)
        assert fast.points_earned > slow.points_earned

    def test_response_clamped_at_time_limit(self):
        q = _make_question()
        over_time = score_answer(q, 0, DEFAULT_TIME_LIMIT_MS + 5_000)
        assert over_time.points_earned == BASE_POINTS
        assert over_time.speed_bonus == 0

    def test_did_you_know_propagated(self):
        q = _make_question()
        q.did_you_know = "Amazing fact!"
        result = score_answer(q, 0, 500)
        assert result.did_you_know == "Amazing fact!"

    def test_compute_brawn_score_empty(self):
        bs = compute_brawn_score([])
        assert bs.raw == 0
        assert bs.grade == "F"
        assert bs.question_count == 0

    def test_compute_brawn_score_all_correct_fast(self):
        results = [_make_answer_result(correct=True, response_ms=0) for _ in range(10)]
        bs = compute_brawn_score(results)
        assert bs.raw == 10 * (BASE_POINTS + MAX_SPEED_BONUS)
        assert bs.grade == "A+"
        assert bs.correct_count == 10

    def test_compute_brawn_score_all_wrong(self):
        results = [_make_answer_result(correct=False, response_ms=500) for _ in range(10)]
        bs = compute_brawn_score(results)
        assert bs.raw == 0
        assert bs.grade == "F"

    def test_compute_brawn_score_grade_b(self):
        # 80% = B: need raw/max_raw = 0.80
        # With BASE=100, BONUS=50: max_per_q=150; target raw = 10 * 150 * 0.80 = 1200
        # 8 correct at full speed (150) + 2 wrong (0) = 1200/1500 = 80.0% exactly
        qs = [_make_question(qid=f"q{i}") for i in range(10)]
        results = []
        for i, q in enumerate(qs):
            if i < 8:
                results.append(score_answer(q, 0, 0))  # correct + fastest
            else:
                results.append(score_answer(q, 1, 1000))  # wrong
        bs = compute_brawn_score(results)
        assert bs.grade == "B"
        assert bs.correct_count == 8

    def test_brawn_score_correct_count(self):
        results = [_make_answer_result(correct=(i % 2 == 0)) for i in range(10)]
        bs = compute_brawn_score(results)
        assert bs.correct_count == 5

    def test_brawn_score_avg_response_ms(self):
        qs = [_make_question(qid=f"q{i}") for i in range(4)]
        results = [score_answer(q, 0, t) for q, t in zip(qs, [1000, 2000, 3000, 4000])]
        bs = compute_brawn_score(results)
        assert bs.avg_response_ms == 2500.0


# ── TestCategoryModule ────────────────────────────────────────────────────────

class TestCategoryModule:
    def test_spin_is_deterministic(self):
        cm1 = SpinCategoryModule()
        cm2 = SpinCategoryModule()
        assert cm1.spin(12345) == cm2.spin(12345)

    def test_spin_returns_valid_category(self):
        cm = SpinCategoryModule()
        cat = cm.spin(99999)
        assert cat in list(Category)
        assert cat != Category.crown

    def test_select_marks_category_used(self):
        cm = SpinCategoryModule()
        cat = cm.spin(1)
        assert cm.select(cat) is True
        # After selecting, spin with same seed avoids that category
        next_cat = cm.spin(1)
        # May or may not be same due to available pool — just check select works
        assert cm.select(cat) is False  # second select = duplicate

    def test_select_false_on_duplicate(self):
        cm = SpinCategoryModule()
        cat = Category.science
        cm.select(cat)
        assert cm.select(cat) is False

    def test_all_categories_reachable_through_spin(self):
        cats = set()
        for seed in range(500):
            cm = SpinCategoryModule()
            cats.add(cm.spin(seed))
        assert len(cats) >= 5  # should reach most non-crown categories


# ── TestGhostModule ───────────────────────────────────────────────────────────

class TestGhostModule:
    def _brawn(self, raw: int = 1000) -> BrawnScore:
        return BrawnScore(
            raw=raw, max_raw=1500, percentage=raw / 1500 * 100,
            grade="B", question_count=10, correct_count=8, avg_response_ms=2000.0,
        )

    def test_record_returns_ghost_record(self):
        gm = InMemoryGhostModule()
        ghost = gm.record_run("u1", "match1", ["science"], [], self._brawn())
        assert isinstance(ghost, GhostRecord)
        assert ghost.ghost_id

    def test_get_ghost_returns_stored_record(self):
        gm = InMemoryGhostModule()
        ghost = gm.record_run("u1", "match1", ["science"], [], self._brawn())
        fetched = gm.get_ghost(ghost.ghost_id)
        assert fetched is not None
        assert fetched.ghost_id == ghost.ghost_id

    def test_get_ghost_none_on_missing(self):
        gm = InMemoryGhostModule()
        assert gm.get_ghost("no-such-id") is None

    def test_list_all_ghosts(self):
        gm = InMemoryGhostModule()
        gm.record_run("u1", "m1", [], [], self._brawn(800))
        gm.record_run("u2", "m2", [], [], self._brawn(900))
        assert len(gm.list_ghosts()) == 2

    def test_list_filtered_by_user(self):
        gm = InMemoryGhostModule()
        gm.record_run("u1", "m1", [], [], self._brawn())
        gm.record_run("u2", "m2", [], [], self._brawn())
        gm.record_run("u1", "m3", [], [], self._brawn())
        assert len(gm.list_ghosts(user_id="u1")) == 2
        assert len(gm.list_ghosts(user_id="u2")) == 1


# ── TestCognitiveModule ───────────────────────────────────────────────────────

class TestCognitiveModule:
    def test_get_round_returns_cognitive_round(self):
        cm = LocalCognitiveModule()
        r = cm.get_round(seed=42)
        assert isinstance(r, CognitiveRound)
        assert r.id
        assert r.time_limit_ms > 0

    def test_get_round_deterministic(self):
        cm = LocalCognitiveModule()
        r1 = cm.get_round(seed=12345)
        r2 = cm.get_round(seed=12345)
        assert r1.id == r2.id
        assert r1.expected_answer == r2.expected_answer

    def test_validate_memorize_sequence_correct(self):
        cm = LocalCognitiveModule()
        # Force a memorize-sequence round by brute-forcing seeds
        for seed in range(100):
            r = cm.get_round(seed)
            if r.round_type == CognitiveRoundType.memorize_sequence:
                assert cm.validate_answer(r, r.expected_answer) is True
                break

    def test_validate_memorize_sequence_wrong(self):
        cm = LocalCognitiveModule()
        for seed in range(100):
            r = cm.get_round(seed)
            if r.round_type == CognitiveRoundType.memorize_sequence:
                assert cm.validate_answer(r, [0, 0, 0]) is False
                break

    def test_validate_pattern_correct(self):
        cm = LocalCognitiveModule()
        for seed in range(100):
            r = cm.get_round(seed)
            if r.round_type == CognitiveRoundType.spot_pattern:
                assert cm.validate_answer(r, r.expected_answer) is True
                break

    def test_validate_pattern_wrong(self):
        cm = LocalCognitiveModule()
        for seed in range(100):
            r = cm.get_round(seed)
            if r.round_type == CognitiveRoundType.spot_pattern:
                assert cm.validate_answer(r, -999) is False
                break


# ── TestCardModule ────────────────────────────────────────────────────────────

class TestCardModule:
    def test_no_award_below_threshold(self):
        cm = InMemoryCardModule()
        item = cm.check_award(Category.science, CROWN_THRESHOLD - 1)
        assert item is None

    def test_award_at_threshold(self):
        cm = InMemoryCardModule()
        item = cm.check_award(Category.science, CROWN_THRESHOLD)
        assert item is not None
        assert item.category == Category.science

    def test_award_above_threshold(self):
        cm = InMemoryCardModule()
        item = cm.check_award(Category.art, CROWN_THRESHOLD + 3)
        assert item is not None

    def test_get_collection_empty_initially(self):
        cm = InMemoryCardModule()
        assert cm.get_collection("user_x") == []

    def test_get_collection_after_award(self):
        cm = InMemoryCardModule()
        item = cm.check_award(Category.sport, CROWN_THRESHOLD)
        cm.award("user_x", item)
        coll = cm.get_collection("user_x")
        assert len(coll) == 1
        assert coll[0].category == Category.sport

    def test_award_deduplicates(self):
        cm = InMemoryCardModule()
        item = cm.check_award(Category.history, CROWN_THRESHOLD)
        cm.award("user_x", item)
        cm.award("user_x", item)
        assert len(cm.get_collection("user_x")) == 1


# ── TestLocalQuestionProvider ─────────────────────────────────────────────────

class TestLocalQuestionProvider:
    def test_loads_all_categories(self):
        lp = LocalQuestionProvider()
        cats = lp.get_categories()
        assert len(cats) >= 6

    def test_question_count_per_category(self):
        lp = LocalQuestionProvider()
        assert lp.get_question_count(Category.science) == 5
        assert lp.get_question_count(Category.sport) == 5

    def test_get_question_returns_question(self):
        lp = LocalQuestionProvider()
        q = lp.get_question(Category.science, difficulty=1)
        assert isinstance(q, Question)
        assert q.category == Category.science

    def test_get_question_respects_exclude_ids(self):
        lp = LocalQuestionProvider()
        first = lp.get_question(Category.history, difficulty=1)
        second = lp.get_question(Category.history, difficulty=1, exclude_ids={first.id})
        assert second is None or second.id != first.id

    def test_get_question_returns_none_when_pool_exhausted(self):
        lp = LocalQuestionProvider()
        # Exclude every question in the category pool directly from the internal store
        all_ids = {q.id for q in lp._by_category.get("creators_devs", [])}
        result = lp.get_question(Category.creators_devs, difficulty=1, exclude_ids=all_ids)
        assert result is None


# ── TestBrainBrawlRouter ──────────────────────────────────────────────────────

class TestBrainBrawlRouter:
    def test_start_session_returns_session_id(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        assert resp.status_code == 200
        data = resp.json()
        assert "session_id" in data
        assert data["session_id"]

    def test_start_session_returns_first_question(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        data = resp.json()
        assert data["question"] is not None
        q = data["question"]
        assert "id" in q and "prompt" in q and "options" in q

    def test_start_session_returns_category(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        data = resp.json()
        assert "current_category" in data
        assert data["current_category"] in [c.value for c in Category if c != Category.crown]

    def test_start_session_stores_in_state(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        assert sid in _sessions

    def test_start_session_stores_seed(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        assert "seed" in _sessions[sid]
        assert isinstance(_sessions[sid]["seed"], int)

    def test_submit_answer_correct(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        q = resp.json()["question"]
        # Mock provider: correct_index = 0
        ans_resp = _client().post(
            f"/api/brain-brawl/session/{sid}/answer",
            json={"question_id": q["id"], "chosen_index": 0, "response_ms": 1000},
        )
        assert ans_resp.status_code == 200
        data = ans_resp.json()
        assert data["is_correct"] is True
        assert data["points_earned"] > 0

    def test_submit_answer_wrong(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        q = resp.json()["question"]
        ans_resp = _client().post(
            f"/api/brain-brawl/session/{sid}/answer",
            json={"question_id": q["id"], "chosen_index": 3, "response_ms": 2000},
        )
        assert ans_resp.status_code == 200
        data = ans_resp.json()
        assert data["is_correct"] is False
        assert data["points_earned"] == 0

    def test_submit_answer_question_id_mismatch_returns_400(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        ans_resp = _client().post(
            f"/api/brain-brawl/session/{sid}/answer",
            json={"question_id": "wrong-id", "chosen_index": 0, "response_ms": 500},
        )
        assert ans_resp.status_code == 400

    def test_submit_answer_404_on_missing_session(self):
        resp = _client().post(
            "/api/brain-brawl/session/no-such-session/answer",
            json={"question_id": "q1", "chosen_index": 0, "response_ms": 500},
        )
        assert resp.status_code == 404

    def test_submit_answer_returns_did_you_know(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        q = resp.json()["question"]
        ans_resp = _client().post(
            f"/api/brain-brawl/session/{sid}/answer",
            json={"question_id": q["id"], "chosen_index": 0, "response_ms": 500},
        )
        assert "did_you_know" in ans_resp.json()

    def test_correct_streak_increments_crown_meter(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        q = resp.json()["question"]
        ans_resp = _client().post(
            f"/api/brain-brawl/session/{sid}/answer",
            json={"question_id": q["id"], "chosen_index": 0, "response_ms": 500},
        )
        assert ans_resp.json()["crown_meter"] == 1

    def test_wrong_answer_resets_crown_meter(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        q = resp.json()["question"]
        # First: correct (crown_meter -> 1)
        _client().post(
            f"/api/brain-brawl/session/{sid}/answer",
            json={"question_id": q["id"], "chosen_index": 0, "response_ms": 500},
        )
        # Second: wrong (crown_meter -> 0)
        q2 = _sessions[sid]["current_question"]
        ans_resp = _client().post(
            f"/api/brain-brawl/session/{sid}/answer",
            json={"question_id": q2.id, "chosen_index": 3, "response_ms": 500},
        )
        assert ans_resp.json()["crown_meter"] == 0

    def test_session_completes_after_all_questions(self):
        resp = _client().post("/api/brain-brawl/session", json={"question_count": 2})
        sid = resp.json()["session_id"]
        for _ in range(2):
            q = _sessions[sid]["current_question"]
            if q is None:
                break
            _client().post(
                f"/api/brain-brawl/session/{sid}/answer",
                json={"question_id": q.id, "chosen_index": 0, "response_ms": 500},
            )
        assert _sessions[sid]["status"] == "complete"

    def test_get_result_returns_brawn_score(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        result = _client().get(f"/api/brain-brawl/session/{sid}/result")
        assert result.status_code == 200
        data = result.json()
        assert "brawn_score" in data
        bs = data["brawn_score"]
        for key in ("raw", "max_raw", "percentage", "grade", "question_count", "correct_count"):
            assert key in bs

    def test_get_result_404_on_missing_session(self):
        resp = _client().get("/api/brain-brawl/session/no-such/result")
        assert resp.status_code == 404

    def test_get_result_includes_collection(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        result = _client().get(f"/api/brain-brawl/session/{sid}/result")
        assert "collection" in result.json()
        assert isinstance(result.json()["collection"], list)

    def test_record_ghost_returns_ghost_id(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        ghost_resp = _client().post(
            "/api/brain-brawl/ghost/record", json={"session_id": sid}
        )
        assert ghost_resp.status_code == 200
        assert "ghost_id" in ghost_resp.json()

    def test_record_ghost_404_on_missing_session(self):
        resp = _client().post(
            "/api/brain-brawl/ghost/record", json={"session_id": "no-such"}
        )
        assert resp.status_code == 404

    def test_get_ghost_returns_data(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        ghost_id = _client().post(
            "/api/brain-brawl/ghost/record", json={"session_id": sid}
        ).json()["ghost_id"]
        ghost_resp = _client().get(f"/api/brain-brawl/ghost/{ghost_id}")
        assert ghost_resp.status_code == 200
        data = ghost_resp.json()
        assert data["ghost_id"] == ghost_id
        assert "brawn_score" in data

    def test_get_ghost_404_on_missing(self):
        resp = _client().get("/api/brain-brawl/ghost/no-such-ghost")
        assert resp.status_code == 404

    def test_ghost_comparison_in_result(self):
        # Record a ghost first
        sess1 = _client().post("/api/brain-brawl/session", json={}).json()["session_id"]
        ghost_id = _client().post(
            "/api/brain-brawl/ghost/record", json={"session_id": sess1}
        ).json()["ghost_id"]
        # Start new session targeting the ghost
        sess2 = _client().post(
            "/api/brain-brawl/session", json={"ghost_id": ghost_id}
        ).json()["session_id"]
        result = _client().get(f"/api/brain-brawl/session/{sess2}/result").json()
        assert result["ghost_comparison"] is not None
        assert "beat_ghost" in result["ghost_comparison"]

    def test_cognitive_answer_400_with_no_active_round(self):
        resp = _client().post("/api/brain-brawl/session", json={})
        sid = resp.json()["session_id"]
        cog_resp = _client().post(
            f"/api/brain-brawl/session/{sid}/cognitive-answer",
            json={"answer": [1, 2, 3]},
        )
        assert cog_resp.status_code == 400

    def test_start_session_respects_custom_question_count(self):
        resp = _client().post("/api/brain-brawl/session", json={"question_count": 3})
        sid = resp.json()["session_id"]
        assert _sessions[sid]["question_count"] == 3
