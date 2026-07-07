"""
Unit tests for backend/lib/av_cues.py and the av_cues event hooks.

Asserts that audio/VFX/haptic cue hints attach to the right event types:
  match_start -> buzzer
  score_event -> score_sting
  dunk_result -> rim_clank + particle_burst + heavy haptic
  match_end   -> buzzer

Runs fully offline (MOCK_DB=1, in-memory stores, stubbed third-party deps),
mirroring backend/tests/test_matches.py.
"""
import os, sys

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_fel")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")
os.environ["MOCK_DB"] = "1"

# Stub third-party modules before any FEL import
import types
from unittest.mock import MagicMock, AsyncMock, patch

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
import asyncio
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from core import User
from lib.av_cues import AV_CUE_TABLE, VALID_HAPTIC_LEVELS, attach_av_cues, av_cues_for
import routers.matches as matches_mod
from routers.matches import (
    router as match_router,
    get_current_user,
    _matches,
    _events,
    _simulate_scoring,
)
from routers.games import router as games_router

_app = FastAPI()
_app.include_router(match_router)
_app.include_router(games_router)

_USER_A = User(user_id="player_a", email="a@fellab.io", name="Player A",
               sport="basketball", prq_score=80.0, level=2, xp=200, streak_days=3, coins=100)
_USER_B = User(user_id="player_b", email="b@fellab.io", name="Player B",
               sport="basketball", prq_score=75.0, level=1, xp=100, streak_days=1, coins=50)


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


# ── Cue table unit tests ───────────────────────────────────────────────────

class TestAvCueTable:
    def test_match_start_maps_to_buzzer(self):
        cues = av_cues_for("match_start")
        assert cues == {"audio": "buzzer", "vfx": None, "haptic": None}

    def test_score_event_maps_to_score_sting(self):
        cues = av_cues_for("score_event")
        assert cues["audio"] == "score_sting"

    def test_dunk_result_maps_to_rim_clank_particle_burst_heavy(self):
        cues = av_cues_for("dunk_result")
        assert cues == {"audio": "rim_clank", "vfx": "particle_burst", "haptic": "heavy"}

    def test_match_end_maps_to_buzzer(self):
        assert av_cues_for("match_end")["audio"] == "buzzer"

    def test_unmapped_event_type_returns_none(self):
        assert av_cues_for("countdown_tick_unknown") is None

    def test_haptic_levels_are_valid(self):
        for etype, cues in AV_CUE_TABLE.items():
            haptic = cues.get("haptic")
            assert haptic is None or haptic in VALID_HAPTIC_LEVELS, etype

    def test_av_cues_for_returns_copy_not_table_reference(self):
        cues = av_cues_for("dunk_result")
        cues["audio"] = "mutated"
        assert AV_CUE_TABLE["dunk_result"]["audio"] == "rim_clank"


class TestAttachAvCues:
    def test_attach_adds_field_and_preserves_payload(self):
        event = {"type": "score_event", "player_id": "p1", "points": 3}
        out = attach_av_cues(event)
        assert out is event
        assert out["av_cues"]["audio"] == "score_sting"
        assert out["player_id"] == "p1" and out["points"] == 3

    def test_attach_noop_for_unknown_event_type(self):
        event = {"type": "ping"}
        attach_av_cues(event)
        assert "av_cues" not in event

    def test_attach_does_not_clobber_explicit_cues(self):
        event = {"type": "dunk_result", "av_cues": {"audio": "custom"}}
        attach_av_cues(event)
        assert event["av_cues"] == {"audio": "custom"}

    def test_attach_handles_missing_type_key(self):
        event = {"seq": 1}
        attach_av_cues(event)
        assert "av_cues" not in event


# ── Server hook: match lifecycle events carry cues ────────────────────────

class TestMatchEventHooks:
    def test_match_start_event_carries_buzzer_cue(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        start_events = [e for e in _events.get(mid, []) if e["type"] == "match_start"]
        assert len(start_events) == 1
        assert start_events[0]["av_cues"] == {"audio": "buzzer", "vfx": None, "haptic": None}

    def test_score_and_match_end_events_carry_cues(self, monkeypatch):
        async def _no_sleep(_):
            return None
        monkeypatch.setattr(matches_mod.asyncio, "sleep", _no_sleep)

        mid = "test_match_av"
        _matches[mid] = {"match_id": mid, "status": "active", "score": {}}
        asyncio.run(_simulate_scoring(mid, ["player_a", "player_b"], {}, n_events=3))

        score_events = [e for e in _events[mid] if e["type"] == "score_event"]
        assert len(score_events) == 3
        for ev in score_events:
            assert ev["av_cues"]["audio"] == "score_sting"

        end_events = [e for e in _events[mid] if e["type"] == "match_end"]
        assert len(end_events) == 1
        assert end_events[0]["av_cues"]["audio"] == "buzzer"

    def test_cues_visible_in_debug_match_payload(self, monkeypatch):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        payload = _client_as(_USER_A).get(f"/api/debug/match/{mid}/payload").json()
        typed = {e["type"]: e for e in payload["events"]}
        assert "match_start" in typed
        assert typed["match_start"]["av_cues"]["audio"] == "buzzer"


# ── Server hook: dunk_result cue on the dunk score endpoint ───────────────

class TestDunkResultHook:
    def test_dunk_score_response_includes_dunk_result_cues(self):
        resp = _client_as(_USER_A).post("/api/arena/dunk/score", json={
            "height_inches": 30, "style_key": "windmill",
            "approach": "running", "clean_finish": True, "crowd_reaction": 8,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert data["av_cues"] == {"audio": "rim_clank", "vfx": "particle_burst", "haptic": "heavy"}

    def test_dunk_score_rejects_bad_style_before_cues(self):
        resp = _client_as(_USER_A).post("/api/arena/dunk/score", json={
            "height_inches": 30, "style_key": "not_a_style",
        })
        assert resp.status_code == 400
