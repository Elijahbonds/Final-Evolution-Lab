"""
Tests for dunk scoring determinism, edge cases, and match integration.
Runs fully offline with MOCK_DB=1.
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
_chat.LlmChat = MagicMock; _chat.UserMessage = MagicMock; _chat.ImageContent = MagicMock

_motor_patcher = patch("motor.motor_asyncio.AsyncIOMotorClient")
_mock_motor = _motor_patcher.start()
_mock_motor.return_value.__getitem__ = lambda self, n: MagicMock()

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

import core
from core import User
from lib.match_utils import generate_seed, derive_judge_offsets
from lib.dunk_scoring import DunkEngine3DInput, score_dunk, score_engine3d_dunk
from lib.card_effects import compute_loadout_modifiers, CARD_EFFECT_MAP
from routers.matches import router as match_router, get_match_user, _matches, _events
from routers.dunk import router as dunk_router

_app = FastAPI()
_app.include_router(match_router)
_app.include_router(dunk_router)

_USER_A = User(user_id="player_a", email="a@fellab.io", name="Player A",
               sport="basketball", prq_score=80.0, level=2, xp=200, streak_days=3, coins=100)
_USER_B = User(user_id="player_b", email="b@fellab.io", name="Player B",
               sport="basketball", prq_score=75.0, level=1, xp=100, streak_days=1, coins=50)

def _client_as(user: User) -> TestClient:
    _app.dependency_overrides[get_match_user] = lambda: user
    return TestClient(_app, raise_server_exceptions=True)

@pytest.fixture(autouse=True)
def _clear_stores():
    _matches.clear(); _events.clear()
    yield
    _matches.clear(); _events.clear()


class TestSeedAndJudgeOffsets:
    def test_seed_is_positive_int(self):
        seed = generate_seed()
        assert isinstance(seed, int) and seed > 0

    def test_judge_offsets_are_deterministic(self):
        seed = 12345678
        a = derive_judge_offsets(seed)
        b = derive_judge_offsets(seed)
        assert a == b

    def test_judge_offsets_count(self):
        assert len(derive_judge_offsets(42)) == 3

    def test_judge_offsets_in_range(self):
        for _ in range(50):
            seed = generate_seed()
            for offset in derive_judge_offsets(seed, lo=-5, hi=5):
                assert -5 <= offset <= 5

    def test_different_seeds_produce_different_offsets(self):
        o1 = derive_judge_offsets(111)
        o2 = derive_judge_offsets(222)
        assert o1 != o2  # astronomically likely

    def test_match_create_includes_seed_and_offsets(self):
        resp = _client_as(_USER_A).post("/api/matches/create", json={"mode_id": "basketball_dunk"})
        mid = resp.json()["match_id"]
        match = _matches[mid]
        assert "seed" in match and isinstance(match["seed"], int)
        assert "judge_offsets" in match and len(match["judge_offsets"]) == 3

    def test_match_start_event_includes_seed(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        events = _events.get(mid, [])
        start = next((e for e in events if e["type"] == "match_start"), None)
        assert start is not None
        assert "seed" in start
        assert "judge_offsets" in start


class TestServerDunkScoring:
    FIXED_SEED = 999_999_999
    FIXED_OFFSETS = derive_judge_offsets(FIXED_SEED)  # deterministic for tests

    def test_perfect_dunk_at_max_inputs(self):
        result = score_dunk(1.0, 1.0, 1.0, [5, 5, 5])
        assert result.total == 30
        assert result.j1 == 10 and result.j2 == 10 and result.j3 == 10
        assert result.is_perfect

    def test_min_inputs_returns_low_score(self):
        result = score_dunk(0.0, 0.0, 0.0, [0, 0, 0])
        assert result.total <= 12  # all 3 judges at minimum (3 each)
        assert result.j1 >= 3 and result.j2 >= 3 and result.j3 >= 3  # floor enforced

    def test_deterministic_for_fixed_seed(self):
        offsets = self.FIXED_OFFSETS
        r1 = score_dunk(0.75, 0.80, 0.70, offsets)
        r2 = score_dunk(0.75, 0.80, 0.70, offsets)
        assert (r1.j1, r1.j2, r1.j3, r1.total) == (r2.j1, r2.j2, r2.j3, r2.total)

    def test_score_dunk_endpoint_returns_judges(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={"mode_id": "basketball_dunk"}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        resp = _client_as(_USER_A).post(f"/api/matches/{mid}/score_dunk",
                                        json={"approach_quality": 0.8, "execution_quality": 0.85,
                                              "style_difficulty": 0.7})
        assert resp.status_code == 200
        data = resp.json()
        for key in ("j1", "j2", "j3", "total", "message"):
            assert key in data
        assert 0 <= data["j1"] <= 10
        assert 3 <= data["total"] <= 30

    def test_score_dunk_persists_event(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        _client_as(_USER_A).post(f"/api/matches/{mid}/score_dunk",
                                  json={"approach_quality": 0.6, "execution_quality": 0.7, "style_difficulty": 0.5})
        events = _events.get(mid, [])
        dunk_events = [e for e in events if e["type"] == "dunk_result"]
        assert len(dunk_events) == 1

    def test_score_dunk_404_on_missing_match(self):
        resp = _client_as(_USER_A).post("/api/matches/nope/score_dunk",
                                        json={"approach_quality": 0.5, "execution_quality": 0.5})
        assert resp.status_code == 404

    def test_inputs_clamped(self):
        # out-of-range inputs should not crash; should be clamped
        resp = _client_as(_USER_A).post("/api/matches/create", json={}).json()
        mid = resp["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        resp2 = _client_as(_USER_A).post(f"/api/matches/{mid}/score_dunk",
                                          json={"approach_quality": 2.5, "execution_quality": -0.5})
        assert resp2.status_code == 200


class TestWDAEngine3DScoring:
    """Deterministic vectors for the Swift WDAScoringEngine port (Agent 2).

    Each vector pins exact (j1, j2, j3, total, message) so ANY change to the
    scoring math is caught. Same seed + same inputs -> identical result.
    """

    VECTORS = [
        # (input, judge_offsets, expected j1, j2, j3, total, message)
        (
            DunkEngine3DInput(
                jump_height=0.9, launch_quality=0.85, landing_quality=0.8,
                completed_rotation=1.0, trick="three_sixty", freestyle_points=18,
                mid_air_branch_count=2, style_landing_success=True,
                modifier_score_multiplier=1.35,
            ),
            [2, -1, 0],
            (30, 8, 10, 48, "PERFECT DUNK!"),
        ),
        (
            DunkEngine3DInput(
                jump_height=0.5, launch_quality=0.5, landing_quality=0.5,
                completed_rotation=0.5, trick="windmill",
            ),
            [0, 0, 0],
            (21, 5, 10, 36, "POWERFUL!"),
        ),
        (
            DunkEngine3DInput(
                jump_height=0.2, launch_quality=0.3, landing_quality=0.25,
                completed_rotation=0.1, trick="rim_grazer",
                attempts_count=3, time_spent_seconds=80.0,
            ),
            [-3, 4, 1],
            (10, 7, 5, 18, "NEEDS WORK"),
        ),
        (
            DunkEngine3DInput(
                jump_height=1.0, launch_quality=1.0, landing_quality=1.0,
                completed_rotation=1.0, trick="seven_twenty", freestyle_points=30,
                mid_air_branch_count=4, style_landing_success=True,
                modifier_score_multiplier=1.8, signature_difficulty_bonus=2.0,
            ),
            [5, 5, 5],
            (30, 10, 10, 50, "PERFECT DUNK!"),
        ),
    ]

    def test_deterministic_vectors(self):
        for inp, offsets, (j1, j2, j3, total, message) in self.VECTORS:
            r = score_engine3d_dunk(inp, offsets)
            assert (r.j1, r.j2, r.j3, r.total, r.message) == (j1, j2, j3, total, message), \
                f"Vector mismatch for trick={inp.trick}: got {r}"

    def test_repeatable_with_seeded_offsets(self):
        seed = 777000111222333
        offsets = derive_judge_offsets(seed)
        assert offsets == [3, 4, 3]  # pinned: random.Random(seed).randint(-5, 5) x3
        inp = self.VECTORS[0][0]
        results = {(r.j1, r.j2, r.j3, r.total) for r in
                   (score_engine3d_dunk(inp, offsets) for _ in range(25))}
        assert len(results) == 1

    def test_judges_stay_within_rubric_bounds(self):
        for inp, _, _ in self.VECTORS:
            for offsets in ([-5, -5, -5], [5, 5, 5], [0, 0, 0]):
                r = score_engine3d_dunk(inp, offsets)
                assert 10 <= r.j1 <= 30
                assert 1 <= r.j2 <= 10
                assert 1 <= r.j3 <= 10
                assert 0 <= r.total <= 50

    def test_unknown_trick_raises(self):
        import pytest as _pytest
        with _pytest.raises(ValueError):
            score_engine3d_dunk(
                DunkEngine3DInput(jump_height=0.5, launch_quality=0.5,
                                  landing_quality=0.5, completed_rotation=0.5,
                                  trick="not_a_trick"),
                [0, 0, 0],
            )

    def test_engine3d_endpoint_scores_and_persists(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={"mode_id": "basketball_dunk_3d"}).json()["match_id"]
        _matches[mid]["judge_offsets"] = [2, -1, 0]  # pin offsets for exact assertion
        payload = {"engine3d": {
            "jump_height": 0.9, "launch_quality": 0.85, "landing_quality": 0.8,
            "completed_rotation": 1.0, "trick": "three_sixty", "freestyle_points": 18,
            "mid_air_branch_count": 2, "style_landing_success": True,
            "modifier_score_multiplier": 1.35,
        }}
        resp = _client_as(_USER_A).post(f"/api/matches/{mid}/score_dunk", json=payload)
        assert resp.status_code == 200
        data = resp.json()
        assert (data["j1"], data["j2"], data["j3"], data["total"]) == (30, 8, 10, 48)
        assert data["message"] == "PERFECT DUNK!"
        assert data["scoring_model"] == "wda_engine3d"
        dunk_events = [e for e in _events.get(mid, []) if e["type"] == "dunk_result"]
        assert len(dunk_events) == 1
        assert dunk_events[0]["inputs"]["engine3d"]["trick"] == "three_sixty"

    def test_endpoint_422_when_no_payload(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        resp = _client_as(_USER_A).post(f"/api/matches/{mid}/score_dunk", json={})
        assert resp.status_code == 422


class TestCardEffects:
    def test_default_modifiers_are_ones(self):
        mods = compute_loadout_modifiers([])
        assert mods["jump_multiplier"] == 1.0
        assert mods["speed_multiplier"] == 1.0
        assert mods["execution_bonus"] == 0.0

    def test_speed_demon_card_boosts_speed(self):
        mods = compute_loadout_modifiers([{"id": "speed_demon"}])
        assert mods["speed_multiplier"] > 1.0

    def test_multiple_cards_stack(self):
        mods_none = compute_loadout_modifiers([])
        mods_two = compute_loadout_modifiers([{"id": "iron_grip"}, {"id": "clutch_gene"}])
        assert mods_two["execution_bonus"] > mods_none["execution_bonus"]

    def test_modifiers_capped(self):
        many = [{"id": "speed_demon"}] * 20
        mods = compute_loadout_modifiers(many)
        assert mods["speed_multiplier"] <= 2.0

    def test_match_start_includes_computed_modifiers(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        events = _events.get(mid, [])
        start = next((e for e in events if e["type"] == "match_start"), None)
        assert start is not None
        for p in start["players"]:
            assert "computed_modifiers" in p


class TestReplayExport:
    def test_export_replay_includes_metadata(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        resp = _client_as(_USER_A).get(f"/api/matches/{mid}/export-replay")
        assert resp.status_code == 200
        data = resp.json()
        for key in ("match_id", "seed", "judge_offsets", "players", "events", "metadata"):
            assert key in data

    def test_export_replay_contains_match_start_event(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        data = _client_as(_USER_A).get(f"/api/matches/{mid}/export-replay").json()
        types_in_events = [e["type"] for e in data["events"]]
        assert "match_start" in types_in_events

    def test_export_replay_includes_dunk_events(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={"mode_id": "basketball_dunk"}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        _client_as(_USER_A).post(f"/api/matches/{mid}/score_dunk",
                                  json={"approach_quality": 0.9, "execution_quality": 0.85, "style_difficulty": 0.8})
        data = _client_as(_USER_A).get(f"/api/matches/{mid}/export-replay").json()
        types_in_events = [e["type"] for e in data["events"]]
        assert "dunk_result" in types_in_events

    def test_export_replay_404_on_missing(self):
        resp = _client_as(_USER_A).get("/api/matches/nope/export-replay")
        assert resp.status_code == 404

    def test_get_match_includes_seed_and_offsets(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        data = _client_as(_USER_A).get(f"/api/matches/{mid}").json()
        assert "seed" in data
        assert "judge_offsets" in data
