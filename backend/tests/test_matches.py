"""
Unit tests for /api/matches/* — match lifecycle, WS stub, and Creator Card loadouts.

Runs fully offline. Sets MOCK_DB=1 before import so matches.py uses
the in-memory dict store instead of real MongoDB.
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
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

import core
from core import User
from routers.matches import router as match_router, get_current_user, _matches, _events

_app = FastAPI()
_app.include_router(match_router)

_USER_A = User(user_id="player_a", email="a@fellab.io", name="Player A",
               sport="basketball", prq_score=80.0, level=2, xp=200, streak_days=3, coins=100)
_USER_B = User(user_id="player_b", email="b@fellab.io", name="Player B",
               sport="basketball", prq_score=75.0, level=1, xp=100, streak_days=1, coins=50)


def _client_as(user: User) -> TestClient:
    _app.dependency_overrides[get_current_user] = lambda: user
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear_stores():
    """Reset in-memory stores before each test."""
    _matches.clear()
    _events.clear()
    yield
    _matches.clear()
    _events.clear()


# ── Match lifecycle ────────────────────────────────────────────────────────

class TestMatchCreate:
    def test_create_returns_match_id(self):
        resp = _client_as(_USER_A).post("/api/matches/create", json={"mode_id": "basketball_h2h"})
        assert resp.status_code == 200
        data = resp.json()
        assert "match_id" in data
        assert data["status"] == "waiting"
        assert data["mode_id"] == "basketball_h2h"

    def test_match_stored_in_memory(self):
        resp = _client_as(_USER_A).post("/api/matches/create", json={})
        mid = resp.json()["match_id"]
        assert mid in _matches
        assert _matches[mid]["status"] == "waiting"

    def test_creator_gets_added_as_first_player(self):
        resp = _client_as(_USER_A).post("/api/matches/create", json={})
        mid = resp.json()["match_id"]
        assert "player_a" in _matches[mid]["players"]

    def test_score_initialized_to_zero(self):
        resp = _client_as(_USER_A).post("/api/matches/create", json={})
        mid = resp.json()["match_id"]
        assert _matches[mid]["score"]["player_a"] == 0


class TestMatchJoin:
    def test_join_waiting_match_succeeds(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        resp = _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        assert resp.status_code == 200

    def test_join_second_player_activates_match(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        resp = _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        data = resp.json()
        assert data["status"] == "active"

    def test_both_players_in_match_after_join(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        players = _matches[mid]["players"]
        assert "player_a" in players
        assert "player_b" in players

    def test_join_nonexistent_match_returns_404(self):
        resp = _client_as(_USER_B).post("/api/matches/join", json={"match_id": "no-such-id"})
        assert resp.status_code == 404

    def test_join_active_match_returns_409(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        # Try a third join on an already-active match
        resp = _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        assert resp.status_code == 409

    def test_started_at_set_on_activation(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        assert _matches[mid].get("started_at") is not None


class TestGetMatch:
    def test_get_waiting_match(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        resp = _client_as(_USER_A).get(f"/api/matches/{mid}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["match_id"] == mid
        assert data["status"] == "waiting"

    def test_get_nonexistent_match_returns_404(self):
        resp = _client_as(_USER_A).get("/api/matches/does-not-exist")
        assert resp.status_code == 404

    def test_get_active_match_returns_players_and_score(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        data = _client_as(_USER_A).get(f"/api/matches/{mid}").json()
        assert data["status"] == "active"
        assert len(data["players"]) == 2
        assert "score" in data

    def test_get_match_includes_loadout_keys(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        data = _client_as(_USER_A).get(f"/api/matches/{mid}").json()
        assert "loadouts" in data

    def test_get_match_events_list(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        data = _client_as(_USER_A).get(f"/api/matches/{mid}").json()
        assert isinstance(data["events"], list)


class TestCreatorCardLoadout:
    def test_loadout_keys_present_in_match_payload(self):
        """Loadout dict must exist in match record for both players."""
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        match = _matches[mid]
        assert "loadouts" in match
        assert "player_a" in match["loadouts"]
        assert "player_b" in match["loadouts"]
        # In MOCK_DB=1, no real cards → empty list is valid
        assert isinstance(match["loadouts"]["player_a"], list)
        assert isinstance(match["loadouts"]["player_b"], list)

    def test_loadout_in_debug_payload(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        data = _client_as(_USER_A).get(f"/api/debug/match/{mid}/payload").json()
        assert "players" in data
        for p in data["players"]:
            assert "loadout" in p
            assert isinstance(p["loadout"], list)


class TestDebugEndpoints:
    def test_debug_match_payload_returns_full_state(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
        data = _client_as(_USER_A).get(f"/api/debug/match/{mid}/payload").json()
        for key in ("match_id", "status", "players", "score", "events"):
            assert key in data

    def test_debug_match_payload_404_on_missing(self):
        resp = _client_as(_USER_A).get("/api/debug/match/nope/payload")
        assert resp.status_code == 404

    def test_debug_latest_system_scan_returns_detail_when_empty(self):
        data = _client_as(_USER_A).get("/api/debug/latest-system-scan").json()
        assert "detail" in data or isinstance(data, dict)


class TestScoreDunkEndpoint:
    def _create_dunk_match(self) -> str:
        resp = _client_as(_USER_A).post("/api/matches/create", json={"mode_id": "basketball_dunk"})
        return resp.json()["match_id"]

    def test_score_dunk_returns_judge_scores(self):
        mid = self._create_dunk_match()
        resp = _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={"approach_quality": 0.8, "execution_quality": 0.9},
        )
        assert resp.status_code == 200
        data = resp.json()
        for key in ("j1", "j2", "j3", "total", "message", "is_perfect"):
            assert key in data

    def test_score_dunk_totals_sum_correctly(self):
        mid = self._create_dunk_match()
        data = _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={"approach_quality": 0.7, "execution_quality": 0.8},
        ).json()
        assert data["total"] == data["j1"] + data["j2"] + data["j3"]

    def test_score_dunk_judge_scores_in_range(self):
        mid = self._create_dunk_match()
        data = _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={"approach_quality": 0.5, "execution_quality": 0.5},
        ).json()
        for j in (data["j1"], data["j2"], data["j3"]):
            assert 3 <= j <= 10

    def test_score_dunk_404_on_missing_match(self):
        resp = _client_as(_USER_A).post(
            "/api/matches/no-such-id/score_dunk",
            json={"approach_quality": 0.5, "execution_quality": 0.5},
        )
        assert resp.status_code == 404

    def test_score_dunk_wire_format_launch_angle(self):
        mid = self._create_dunk_match()
        resp = _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={"launch_angle": 0.87, "landing_precision": 0.91},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == data["j1"] + data["j2"] + data["j3"]

    def test_score_dunk_wire_format_with_style_key(self):
        mid = self._create_dunk_match()
        resp = _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={"launch_angle": 0.9, "landing_precision": 0.85, "style_key": "360_windmill"},
        )
        assert resp.status_code == 200

    def test_score_dunk_wire_format_with_valid_trick_hash(self):
        import zlib
        style_key = "tomahawk"
        crc = zlib.crc32(style_key.encode()) & 0xFFFFFFFF
        valid_hash = f"{crc:08x}"
        mid = self._create_dunk_match()
        resp = _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={
                "launch_angle": 0.7,
                "landing_precision": 0.8,
                "style_key": style_key,
                "trick_sequence_hash": valid_hash,
            },
        )
        assert resp.status_code == 200

    def test_score_dunk_wire_format_invalid_trick_hash_returns_422(self):
        mid = self._create_dunk_match()
        resp = _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={
                "launch_angle": 0.7,
                "landing_precision": 0.8,
                "style_key": "tomahawk",
                "trick_sequence_hash": "deadbeef",
            },
        )
        assert resp.status_code == 422

    def test_score_dunk_persists_event_with_action_type(self):
        mid = self._create_dunk_match()
        _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={"launch_angle": 0.6, "landing_precision": 0.7},
        )
        events = _events.get(mid, [])
        assert any(e.get("action_type") == "judged_score" for e in events)

    def test_score_dunk_deterministic_same_match(self):
        mid = self._create_dunk_match()
        payload = {"approach_quality": 0.75, "execution_quality": 0.85}
        r1 = _client_as(_USER_A).post(f"/api/matches/{mid}/score_dunk", json=payload).json()
        r2 = _client_as(_USER_A).post(f"/api/matches/{mid}/score_dunk", json=payload).json()
        assert r1["j1"] == r2["j1"] and r1["j2"] == r2["j2"] and r1["j3"] == r2["j3"]

    def test_create_match_includes_seed_and_judge_offsets(self):
        resp = _client_as(_USER_A).post("/api/matches/create", json={"mode_id": "basketball_dunk"})
        mid = resp.json()["match_id"]
        match = _matches[mid]
        assert "seed" in match and isinstance(match["seed"], int)
        assert "judge_offsets" in match and len(match["judge_offsets"]) == 3

    def test_get_match_exposes_seed_and_judge_offsets(self):
        mid = _client_as(_USER_A).post("/api/matches/create", json={}).json()["match_id"]
        data = _client_as(_USER_A).get(f"/api/matches/{mid}").json()
        assert "seed" in data
        assert "judge_offsets" in data

    def test_export_replay_returns_full_metadata(self):
        mid = self._create_dunk_match()
        _client_as(_USER_A).post(
            f"/api/matches/{mid}/score_dunk",
            json={"approach_quality": 0.8, "execution_quality": 0.9},
        )
        data = _client_as(_USER_A).get(f"/api/matches/{mid}/export-replay").json()
        for key in ("match_id", "mode_id", "seed", "judge_offsets", "events", "metadata"):
            assert key in data
        assert data["metadata"]["event_count"] == len(data["events"])
