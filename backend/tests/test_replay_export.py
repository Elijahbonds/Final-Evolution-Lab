"""
Agent 3 — Match events + replay export tests.

Verifies:
  - match_start, input, score_event, dunk_result, match_end all land in the
    in-memory `_events` store under MOCK_DB=1
  - GET /api/matches/{id}/export-replay returns
    {metadata: {match_id, mode_id, seed, judge_offsets, players, start_time}, events: [...]}
  - events carry monotonically ordered `seq` values for deterministic replay
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
from routers.matches import router as match_router, get_current_user, _matches, _events
from routers.dunk import router as dunk_router

_app = FastAPI()
_app.include_router(match_router)
_app.include_router(dunk_router)

_USER_A = User(user_id="replay_a", email="ra@fellab.io", name="Replay A")
_USER_B = User(user_id="replay_b", email="rb@fellab.io", name="Replay B")


def _client_as(user: User) -> TestClient:
    _app.dependency_overrides[get_current_user] = lambda: user
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear_stores():
    _matches.clear()
    _events.clear()
    yield
    _matches.clear()
    _events.clear()


def _make_active_match(mode_id="basketball_dunk_3d") -> str:
    mid = _client_as(_USER_A).post("/api/matches/create", json={"mode_id": mode_id}).json()["match_id"]
    _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
    return mid


class TestEventAppend:
    def test_match_start_recorded_on_activation(self):
        mid = _make_active_match()
        assert any(e["type"] == "match_start" for e in _events[mid])

    def test_input_event_appended(self):
        mid = _make_active_match()
        resp = _client_as(_USER_A).post(
            f"/api/matches/{mid}/events",
            json={"type": "input", "player_id": "replay_a",
                  "payload": {"seq": 1, "input": {"action": "jump"}, "ts": 123.45}},
        )
        assert resp.status_code == 200
        inputs = [e for e in _events[mid] if e["type"] == "input"]
        assert len(inputs) == 1
        assert inputs[0]["payload"]["input"]["action"] == "jump"

    def test_score_event_appended_and_updates_score(self):
        mid = _make_active_match()
        _client_as(_USER_A).post(
            f"/api/matches/{mid}/events",
            json={"type": "score_event", "player_id": "replay_a", "payload": {"points": 3}},
        )
        score_events = [e for e in _events[mid] if e["type"] == "score_event"]
        assert score_events and score_events[-1]["points"] == 3
        assert _matches[mid]["score"]["replay_a"] >= 3

    def test_dunk_result_appended(self):
        mid = _make_active_match()
        _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={"approach_quality": 0.8, "execution_quality": 0.9, "style_difficulty": 0.6},
        )
        assert any(e["type"] == "dunk_result" for e in _events[mid])

    def test_match_end_appended_and_status_finished(self):
        mid = _make_active_match()
        resp = _client_as(_USER_A).post(f"/api/matches/{mid}/end", json={"reason": "test_done"})
        assert resp.status_code == 200
        assert _matches[mid]["status"] == "finished"
        ends = [e for e in _events[mid] if e["type"] == "match_end"]
        assert len(ends) == 1 and ends[0]["reason"] == "test_done"

    def test_append_after_end_rejected(self):
        mid = _make_active_match()
        _client_as(_USER_A).post(f"/api/matches/{mid}/end", json={})
        resp = _client_as(_USER_A).post(
            f"/api/matches/{mid}/events", json={"type": "input", "payload": {}})
        assert resp.status_code == 409

    def test_unknown_event_type_rejected(self):
        mid = _make_active_match()
        resp = _client_as(_USER_A).post(
            f"/api/matches/{mid}/events", json={"type": "hack_the_planet", "payload": {}})
        assert resp.status_code == 422

    def test_seq_is_monotonic(self):
        mid = _make_active_match()
        c = _client_as(_USER_A)
        for i in range(5):
            c.post(f"/api/matches/{mid}/events",
                   json={"type": "input", "payload": {"seq": i, "input": {}, "ts": i * 0.1}})
        seqs = [e["seq"] for e in _events[mid]]
        assert seqs == sorted(seqs)
        assert len(set(seqs)) == len(seqs)


class TestReplayExport:
    REQUIRED_METADATA_KEYS = ("match_id", "mode_id", "seed", "judge_offsets", "players", "start_time")

    def test_export_shape_matches_contract(self):
        mid = _make_active_match()
        data = _client_as(_USER_A).get(f"/api/matches/{mid}/export-replay").json()
        assert "metadata" in data and "events" in data
        for key in self.REQUIRED_METADATA_KEYS:
            assert key in data["metadata"], f"missing metadata.{key}"
        assert data["metadata"]["match_id"] == mid
        assert isinstance(data["metadata"]["seed"], int)
        assert len(data["metadata"]["judge_offsets"]) == 3
        assert data["metadata"]["players"] == ["replay_a", "replay_b"]
        assert data["metadata"]["start_time"] is not None

    def test_export_contains_full_lifecycle_events(self):
        mid = _make_active_match()
        c = _client_as(_USER_A)
        c.post(f"/api/matches/{mid}/events",
               json={"type": "input", "payload": {"seq": 1, "input": {"action": "sprint"}, "ts": 0.5}})
        c.post(f"/api/matches/{mid}/events",
               json={"type": "score_event", "player_id": "replay_a", "payload": {"points": 2}})
        c.post(f"/api/matches/{mid}/score_dunk",
               json={"approach_quality": 0.9, "execution_quality": 0.8, "style_difficulty": 0.7})
        c.post(f"/api/matches/{mid}/end", json={})
        data = c.get(f"/api/matches/{mid}/export-replay").json()
        types_present = {e["type"] for e in data["events"]}
        for expected in ("match_start", "input", "score_event", "dunk_result", "match_end"):
            assert expected in types_present, f"missing event type {expected}"

    def test_export_replay_is_stable_across_calls(self):
        mid = _make_active_match()
        c = _client_as(_USER_A)
        c.post(f"/api/matches/{mid}/score_dunk",
               json={"approach_quality": 0.7, "execution_quality": 0.7, "style_difficulty": 0.5})
        c.post(f"/api/matches/{mid}/end", json={})
        d1 = c.get(f"/api/matches/{mid}/export-replay").json()
        d2 = c.get(f"/api/matches/{mid}/export-replay").json()
        assert d1 == d2

    def test_export_404_on_missing_match(self):
        resp = _client_as(_USER_A).get("/api/matches/nope/export-replay")
        assert resp.status_code == 404

    def test_dunk_result_event_echoes_inputs_for_revalidation(self):
        mid = _make_active_match()
        c = _client_as(_USER_A)
        c.post(f"/api/matches/{mid}/score_dunk",
               json={"engine3d": {"jump_height": 0.8, "launch_quality": 0.75,
                                  "landing_quality": 0.7, "completed_rotation": 1.0,
                                  "trick": "windmill"}})
        data = c.get(f"/api/matches/{mid}/export-replay").json()
        dunk = next(e for e in data["events"] if e["type"] == "dunk_result")
        assert dunk["scoring_model"] == "wda_engine3d"
        assert dunk["inputs"]["engine3d"]["trick"] == "windmill"
        assert dunk["judge_offsets"] == data["metadata"]["judge_offsets"]
