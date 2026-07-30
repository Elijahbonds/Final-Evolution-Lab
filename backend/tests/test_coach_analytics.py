"""
Coach Analytics tests (Nexus AAA) — MOCK_DB=1, fully offline.

Covers:
  - per-play breakdown from the real replay event stream
  - success-rate math (overall / by_type / by_player)
  - heatmap bucketing correctness (cell indexing, success/attempt counts)
  - determinism across repeated calls
  - empty-match handling
  - single-play export slice (reuses replay shape)
  - pure-function unit tests for the analytics lib
"""
import os
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
from routers.matches import router as match_router, get_match_user, _matches, _events
from routers.dunk import router as dunk_router
from routers.analytics import router as analytics_router
from lib.coach_analytics import (
    build_heatmap,
    build_play_breakdown,
    compute_success_rates,
    slice_play_events,
    _cell_index,
    _extract_position,
    _is_success,
)

_app = FastAPI()
_app.include_router(match_router)
_app.include_router(dunk_router)
_app.include_router(analytics_router)

_USER_A = User(user_id="coach_a", email="ca@fellab.io", name="Coach A")
_USER_B = User(user_id="coach_b", email="cb@fellab.io", name="Coach B")


def _client_as(user: User) -> TestClient:
    _app.dependency_overrides[get_match_user] = lambda: user
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear_stores():
    _matches.clear()
    _events.clear()
    yield
    _matches.clear()
    _events.clear()


def _make_active_match(mode_id="basketball_dunk_3d") -> str:
    mid = _client_as(_USER_A).post(
        "/api/matches/create", json={"mode_id": mode_id}
    ).json()["match_id"]
    _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
    return mid


def _score(client, mid, player_id, points, position=None):
    payload = {"points": points}
    if position is not None:
        payload["position"] = position
    return client.post(
        f"/api/matches/{mid}/events",
        json={"type": "score_event", "player_id": player_id, "payload": payload},
    )


# ── Pure-function unit tests ──────────────────────────────────────────────

class TestPureHelpers:
    def test_cell_index_basic(self):
        assert _cell_index(0.0, 6) == 0
        assert _cell_index(0.99, 6) == 5
        assert _cell_index(1.0, 6) == 5  # boundary clamps into last cell
        assert _cell_index(0.5, 4) == 2

    def test_cell_index_clamps_out_of_range(self):
        assert _cell_index(-0.3, 6) == 0
        assert _cell_index(2.0, 6) == 5

    def test_extract_position_dict(self):
        assert _extract_position({"position": {"x": 0.2, "y": 0.8}}) == (0.2, 0.8)

    def test_extract_position_payload_pos_list(self):
        assert _extract_position({"payload": {"pos": [0.4, 0.6]}}) == (0.4, 0.6)

    def test_extract_position_clamps(self):
        assert _extract_position({"position": {"x": 1.5, "y": -0.2}}) == (1.0, 0.0)

    def test_extract_position_absent(self):
        assert _extract_position({"payload": {"points": 3}}) is None

    def test_is_success_score_event(self):
        assert _is_success({"type": "score_event", "points": 2}) is True
        assert _is_success({"type": "score_event", "points": 0}) is False

    def test_is_success_dunk(self):
        assert _is_success({"type": "dunk_result", "is_perfect": True, "total": 48}) is True
        assert _is_success({"type": "dunk_result", "is_perfect": False, "total": 30}) is True
        assert _is_success({"type": "dunk_result", "is_perfect": False, "total": 18}) is False

    def test_is_success_answer(self):
        assert _is_success({"type": "answer_event", "payload": {"correct": True}}) is True
        assert _is_success({"type": "answer_event", "payload": {"correct": False}}) is False


class TestBucketingCorrectness:
    def test_heatmap_buckets_positions(self):
        plays = [
            {"type": "score_event", "success": True, "points": 2, "position": {"x": 0.1, "y": 0.1}},
            {"type": "score_event", "success": False, "points": 0, "position": {"x": 0.1, "y": 0.1}},
            {"type": "score_event", "success": True, "points": 3, "position": {"x": 0.9, "y": 0.9}},
        ]
        hm = build_heatmap(plays, grid=2)
        # (0.1,0.1) -> row0,col0 ; (0.9,0.9) -> row1,col1
        c00 = hm["cells"][0][0]
        c11 = hm["cells"][1][1]
        assert c00["attempts"] == 2 and c00["successes"] == 1
        assert c00["success_rate"] == 0.5
        assert c11["attempts"] == 1 and c11["successes"] == 1
        assert c11["success_rate"] == 1.0
        # empty cells stay zero
        assert hm["cells"][0][1]["attempts"] == 0
        assert hm["max_cell_attempts"] == 2

    def test_heatmap_unpositioned_counted_separately(self):
        plays = [
            {"type": "score_event", "success": True, "points": 2, "position": None},
            {"type": "score_event", "success": False, "points": 0, "position": None},
            {"type": "score_event", "success": True, "points": 1, "position": {"x": 0.5, "y": 0.5}},
        ]
        hm = build_heatmap(plays, grid=3)
        assert hm["unpositioned"]["attempts"] == 2
        assert hm["unpositioned"]["successes"] == 1
        assert hm["positioned_plays"] == 1
        assert hm["total_plays"] == 3

    def test_heatmap_is_dense_grid(self):
        hm = build_heatmap([], grid=5)
        assert hm["grid"] == 5
        assert len(hm["cells"]) == 5
        assert all(len(row) == 5 for row in hm["cells"])
        assert hm["max_cell_attempts"] == 0

    def test_boundary_positions_land_in_last_cell(self):
        plays = [{"type": "score_event", "success": True, "points": 2, "position": {"x": 1.0, "y": 1.0}}]
        hm = build_heatmap(plays, grid=4)
        assert hm["cells"][3][3]["attempts"] == 1


class TestSuccessRateMath:
    def test_overall_and_by_type_and_by_player(self):
        plays = [
            {"type": "score_event", "player_id": "a", "success": True, "points": 2},
            {"type": "score_event", "player_id": "a", "success": False, "points": 0},
            {"type": "dunk_result", "player_id": "b", "success": True, "points": 40},
            {"type": "dunk_result", "player_id": "b", "success": False, "points": 12},
        ]
        rates = compute_success_rates(plays)
        assert rates["overall"]["attempts"] == 4
        assert rates["overall"]["successes"] == 2
        assert rates["overall"]["success_rate"] == 0.5
        assert rates["overall"]["points"] == 54
        assert rates["by_type"]["score_event"]["success_rate"] == 0.5
        assert rates["by_type"]["dunk_result"]["success_rate"] == 0.5
        assert rates["by_player"]["a"]["attempts"] == 2
        assert rates["by_player"]["b"]["successes"] == 1

    def test_empty_rates_are_zero(self):
        rates = compute_success_rates([])
        assert rates["overall"]["attempts"] == 0
        assert rates["overall"]["success_rate"] == 0.0
        assert rates["by_type"] == {}
        assert rates["by_player"] == {}


# ── Endpoint / integration tests ──────────────────────────────────────────

class TestAnalyticsEndpoint:
    def test_404_on_missing_match(self):
        resp = _client_as(_USER_A).get("/api/analytics/match/nope")
        assert resp.status_code == 404

    def test_empty_match_returns_zeroed_analytics(self):
        mid = _make_active_match()
        data = _client_as(_USER_A).get(f"/api/analytics/match/{mid}").json()
        assert data["match_id"] == mid
        assert data["play_count"] == 0
        assert data["plays"] == []
        assert data["success_rates"]["overall"]["attempts"] == 0
        assert data["heatmap"]["total_plays"] == 0
        # heatmap still a dense grid
        assert len(data["heatmap"]["cells"]) == data["heatmap"]["grid"]

    def test_plays_reflect_event_stream(self):
        mid = _make_active_match()
        c = _client_as(_USER_A)
        _score(c, mid, "coach_a", 2, position={"x": 0.2, "y": 0.3})
        _score(c, mid, "coach_a", 0, position={"x": 0.2, "y": 0.3})
        c.post(
            f"/api/matches/{mid}/score_dunk",
            json={"approach_quality": 0.9, "execution_quality": 0.9, "style_difficulty": 0.8},
        )
        data = c.get(f"/api/analytics/match/{mid}").json()
        # 2 score_events + 1 dunk_result = 3 plays; input/start excluded
        assert data["play_count"] == 3
        types = {p["type"] for p in data["plays"]}
        assert types == {"score_event", "dunk_result"}
        # score_event success math
        se = data["success_rates"]["by_type"]["score_event"]
        assert se["attempts"] == 2 and se["successes"] == 1

    def test_heatmap_endpoint_matches_full_endpoint(self):
        mid = _make_active_match()
        c = _client_as(_USER_A)
        _score(c, mid, "coach_a", 2, position={"x": 0.1, "y": 0.1})
        _score(c, mid, "coach_b", 3, position={"x": 0.9, "y": 0.8})
        full = c.get(f"/api/analytics/match/{mid}?grid=4").json()
        hm = c.get(f"/api/analytics/match/{mid}/heatmap?grid=4").json()
        assert hm["heatmap"] == full["heatmap"]
        assert hm["heatmap"]["grid"] == 4

    def test_grid_param_respected(self):
        mid = _make_active_match()
        data = _client_as(_USER_A).get(f"/api/analytics/match/{mid}?grid=8").json()
        assert data["heatmap"]["grid"] == 8

    def test_determinism_across_calls(self):
        mid = _make_active_match()
        c = _client_as(_USER_A)
        _score(c, mid, "coach_a", 2, position={"x": 0.3, "y": 0.4})
        c.post(
            f"/api/matches/{mid}/score_dunk",
            json={"approach_quality": 0.7, "execution_quality": 0.7, "style_difficulty": 0.5},
        )
        c.post(f"/api/matches/{mid}/end", json={})
        d1 = c.get(f"/api/analytics/match/{mid}").json()
        d2 = c.get(f"/api/analytics/match/{mid}").json()
        assert d1 == d2


class TestPlayExport:
    def test_export_single_play_slice(self):
        mid = _make_active_match()
        c = _client_as(_USER_A)
        _score(c, mid, "coach_a", 2, position={"x": 0.2, "y": 0.2})
        data = c.get(f"/api/analytics/match/{mid}").json()
        play_id = data["plays"][0]["play_id"]
        exp = c.get(f"/api/analytics/match/{mid}/play/{play_id}/export").json()
        assert "metadata" in exp and "events" in exp
        assert exp["metadata"]["play_id"] == play_id
        assert exp["metadata"]["match_id"] == mid
        # the slice ends on the target play event
        assert exp["events"][-1]["type"] == "score_event"
        assert exp["metadata"]["event_count"] == len(exp["events"])

    def test_export_slice_includes_preceding_inputs(self):
        mid = _make_active_match()
        c = _client_as(_USER_A)
        # inputs then a scoring play
        c.post(f"/api/matches/{mid}/events",
               json={"type": "input", "player_id": "coach_a",
                     "payload": {"seq": 1, "input": {"action": "drive"}}})
        _score(c, mid, "coach_a", 3, position={"x": 0.5, "y": 0.5})
        data = c.get(f"/api/analytics/match/{mid}").json()
        play_id = data["plays"][0]["play_id"]
        exp = c.get(f"/api/analytics/match/{mid}/play/{play_id}/export").json()
        types = [e["type"] for e in exp["events"]]
        assert "input" in types
        assert types[-1] == "score_event"

    def test_export_404_on_missing_play(self):
        mid = _make_active_match()
        resp = _client_as(_USER_A).get(f"/api/analytics/match/{mid}/play/play-999/export")
        assert resp.status_code == 404

    def test_export_404_on_missing_match(self):
        resp = _client_as(_USER_A).get("/api/analytics/match/nope/play/play-1/export")
        assert resp.status_code == 404

    def test_slice_helper_isolates_second_play(self):
        events = [
            {"type": "match_start", "seq": 0},
            {"type": "input", "seq": 1, "payload": {}},
            {"type": "score_event", "seq": 2, "points": 2},
            {"type": "input", "seq": 3, "payload": {}},
            {"type": "score_event", "seq": 4, "points": 3},
        ]
        plays = build_play_breakdown(events)
        second_id = plays[1]["play_id"]
        sl = slice_play_events(events, second_id)
        seqs = [e["seq"] for e in sl]
        # slice for 2nd play = input@3 + score@4, not the first play's events
        assert seqs == [3, 4]
