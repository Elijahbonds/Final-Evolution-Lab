"""
Ball-physics core + soccer adjudication tests (Nexus AAA — Sport Ball-Physics Core).

Covers:
  * Trajectory determinism: same inputs + wind_seed → byte-identical path (3 seeds).
  * No-wind flight is deterministic and wind is purely a function of the seed.
  * Soccer goal / miss / save adjudication correctness.
  * POST /api/sports/soccer/resolve-kick endpoint + replay round-trip
    (export → replay_validator re-derives the outcome exactly).
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
from lib.ball_physics import (
    REGISTRY,
    InitialConditions,
    Vec3,
    draw_wind,
    integrate,
)
import lib.sports  # noqa: F401 — registers soccer
from lib.sports.soccer import GOAL_HEIGHT, GOAL_Y, HALF_WIDTH, SoccerRule
from routers.matches import router as match_router, get_match_user, _matches, _events
from routers.dunk import router as dunk_router
from routers.sports import router as sports_router
from tools.replay_validator import validate_replay

_app = FastAPI()
_app.include_router(match_router)
_app.include_router(dunk_router)
_app.include_router(sports_router)

_USER = User(user_id="pk_a", email="pka@fellab.io", name="PK A")
_USER_B = User(user_id="pk_b", email="pkb@fellab.io", name="PK B")


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


def _make_active_match(mode_id="soccer_penalty") -> str:
    mid = _client_as(_USER).post("/api/matches/create", json={"mode_id": mode_id}).json()["match_id"]
    _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
    return mid


# ═══════════════════════════════════════════════════════════════════════════
# Determinism of the physics core
# ═══════════════════════════════════════════════════════════════════════════

class TestTrajectoryDeterminism:
    def _ic(self, wind_seed):
        return InitialConditions(
            position=Vec3(0.0, 0.0, 0.0),
            velocity=Vec3(3.0, 22.0, 6.0),
            spin=Vec3(0.0, 0.0, 12.0),
            wind_seed=wind_seed,
        )

    @pytest.mark.parametrize("seed", [1, 42, 2026])
    def test_same_inputs_and_seed_give_byte_identical_path(self, seed):
        t1 = integrate(self._ic(seed))
        t2 = integrate(self._ic(seed))
        # Full structural equality of every sample.
        assert t1.as_dict() == t2.as_dict()
        # And the fingerprint.
        assert t1.path_hash() == t2.path_hash()

    def test_no_wind_is_deterministic(self):
        a = integrate(self._ic(None))
        b = integrate(self._ic(None))
        assert a.path_hash() == b.path_hash()
        assert a.wind.as_tuple() == (0.0, 0.0, 0.0)

    def test_different_seeds_generally_diverge(self):
        h1 = integrate(self._ic(1)).path_hash()
        h2 = integrate(self._ic(2)).path_hash()
        assert h1 != h2

    def test_wind_is_pure_function_of_seed(self):
        assert draw_wind(7).as_tuple() == draw_wind(7).as_tuple()
        assert draw_wind(None).as_tuple() == (0.0, 0.0, 0.0)

    def test_trajectory_starts_at_launch_and_lands_or_stops(self):
        t = integrate(self._ic(None))
        assert t.samples[0].position.as_tuple() == (0.0, 0.0, 0.0)
        assert t.stop_reason in ("ground", "max_time", "boundary_stop", "max_steps")

    def test_gravity_pulls_ball_down_eventually(self):
        # Straight-up-ish shot must come back to the ground.
        ic = InitialConditions(position=Vec3(0.0, 0.0, 0.0),
                               velocity=Vec3(0.0, 1.0, 15.0), wind_seed=None)
        t = integrate(ic)
        assert t.stop_reason == "ground"
        assert t.final.position.z == 0.0


# ═══════════════════════════════════════════════════════════════════════════
# Soccer adjudication correctness
# ═══════════════════════════════════════════════════════════════════════════

class TestSoccerAdjudication:
    def _resolve(self, **inputs):
        return REGISTRY.resolve("soccer", inputs)

    def test_goal_when_aimed_at_open_corner_past_keeper(self):
        # Fast, aimed to the far corner; keeper dives to the centre.
        traj, outcome = self._resolve(
            speed=30.0, aim_x=3.0, aim_z=1.5, spin_rps=0.0,
            keeper_dive_x=0.0, keeper_reach=1.5, wind_seed=None,
        )
        assert outcome.outcome == "goal"
        assert abs(outcome.crossing["x"]) <= HALF_WIDTH
        assert 0.0 <= outcome.crossing["z"] <= GOAL_HEIGHT

    def test_save_when_keeper_covers_crossing(self):
        # Aim centre; keeper standing centre with wide reach → save.
        traj, outcome = self._resolve(
            speed=28.0, aim_x=0.0, aim_z=1.0, spin_rps=0.0,
            keeper_dive_x=0.0, keeper_reach=2.5, wind_seed=None,
        )
        assert outcome.outcome == "save"

    def test_miss_wide_when_aimed_outside_posts(self):
        # Aim well outside the right post.
        traj, outcome = self._resolve(
            speed=30.0, aim_x=8.0, aim_z=1.5, spin_rps=0.0,
            keeper_dive_x=0.0, keeper_reach=1.5, wind_seed=None,
        )
        assert outcome.outcome == "miss"
        assert "wide" in outcome.detail["reason"]

    def test_miss_over_the_bar(self):
        traj, outcome = self._resolve(
            speed=32.0, aim_x=0.0, aim_z=4.5, spin_rps=0.0,
            keeper_dive_x=0.0, keeper_reach=1.0, wind_seed=None,
        )
        assert outcome.outcome == "miss"
        assert "over" in outcome.detail["reason"]

    def test_miss_short_when_too_weak_to_reach_line(self):
        traj, outcome = self._resolve(
            speed=6.0, aim_x=0.0, aim_z=0.3, spin_rps=0.0,
            keeper_reach=0.0, wind_seed=None,
        )
        assert outcome.outcome == "miss"
        # Either never reached the line, or dribbled and stopped on the ground.
        assert outcome.detail["reason"] in ("short", "wide", "over", "off_target") or outcome.crossing is None

    def test_keeper_seed_is_deterministic(self):
        _, o1 = self._resolve(speed=28.0, aim_x=1.0, aim_z=1.0, keeper_seed=99, keeper_reach=1.2)
        _, o2 = self._resolve(speed=28.0, aim_x=1.0, aim_z=1.0, keeper_seed=99, keeper_reach=1.2)
        assert o1.outcome == o2.outcome
        assert o1.detail["keeper"]["dive_x"] == o2.detail["keeper"]["dive_x"]

    def test_resolve_is_repeatable_end_to_end(self):
        for _ in range(3):
            traj, outcome = self._resolve(
                speed=27.0, aim_x=2.0, aim_z=0.9, spin_rps=4.0,
                wind_seed=2026, keeper_dive_x=-1.0, keeper_reach=1.4,
            )
            first = (traj.path_hash(), outcome.outcome, outcome.crossing)
            traj2, outcome2 = self._resolve(
                speed=27.0, aim_x=2.0, aim_z=0.9, spin_rps=4.0,
                wind_seed=2026, keeper_dive_x=-1.0, keeper_reach=1.4,
            )
            assert (traj2.path_hash(), outcome2.outcome, outcome2.crossing) == first

    def test_flight_stops_at_or_past_goal_line_on_target(self):
        traj, outcome = self._resolve(speed=30.0, aim_x=0.0, aim_z=1.0, keeper_reach=0.0)
        assert traj.final.position.y >= GOAL_Y - 1e-6


# ═══════════════════════════════════════════════════════════════════════════
# Endpoint + replay round-trip
# ═══════════════════════════════════════════════════════════════════════════

class TestResolveKickEndpoint:
    def test_resolve_kick_returns_outcome_and_trajectory(self):
        resp = _client_as(_USER).post("/api/sports/soccer/resolve-kick", json={
            "speed": 30.0, "aim_x": 3.0, "aim_z": 1.5, "keeper_reach": 1.5,
        })
        assert resp.status_code == 200
        body = resp.json()
        assert body["sport"] == "soccer"
        assert body["outcome"] in ("goal", "miss", "save")
        assert body["trajectory"]["sample_count"] == len(body["trajectory"]["samples"])
        assert isinstance(body["path_hash"], str) and len(body["path_hash"]) == 64

    def test_same_request_gives_same_path_hash(self):
        req = {"speed": 27.0, "aim_x": 2.0, "aim_z": 0.9, "spin_rps": 4.0,
               "wind_seed": 42, "keeper_dive_x": -1.0, "keeper_reach": 1.4}
        c = _client_as(_USER)
        h1 = c.post("/api/sports/soccer/resolve-kick", json=req).json()["path_hash"]
        h2 = c.post("/api/sports/soccer/resolve-kick", json=req).json()["path_hash"]
        assert h1 == h2

    def test_kick_appended_to_match_replay_log(self):
        mid = _make_active_match()
        resp = _client_as(_USER).post("/api/sports/soccer/resolve-kick", json={
            "match_id": mid, "player_id": "pk_a",
            "speed": 30.0, "aim_x": 3.0, "aim_z": 1.5, "keeper_reach": 1.5,
        })
        assert resp.status_code == 200
        kicks = [e for e in _events[mid] if e["type"] == "soccer_kick_result"]
        assert len(kicks) == 1
        assert kicks[0]["inputs"]["speed"] == 30.0
        assert "path_hash" in kicks[0]

    def test_resolve_kick_missing_match_404(self):
        resp = _client_as(_USER).post("/api/sports/soccer/resolve-kick", json={
            "match_id": "does_not_exist", "speed": 25.0,
        })
        assert resp.status_code == 404

    def test_replay_export_validates_soccer_kick(self):
        mid = _make_active_match()
        c = _client_as(_USER)
        c.post("/api/sports/soccer/resolve-kick", json={
            "match_id": mid, "player_id": "pk_a",
            "speed": 30.0, "aim_x": 3.0, "aim_z": 1.5, "keeper_reach": 1.5, "wind_seed": 7,
        })
        c.post("/api/sports/soccer/resolve-kick", json={
            "match_id": mid, "player_id": "pk_b",
            "speed": 28.0, "aim_x": 0.0, "aim_z": 1.0, "keeper_reach": 2.5,
        })
        c.post(f"/api/matches/{mid}/end", json={})
        replay = c.get(f"/api/matches/{mid}/export-replay").json()
        # The validator must re-derive both kicks with zero mismatches.
        errors = validate_replay(replay)
        assert errors == [], f"replay validation errors: {errors}"
        kicks = [e for e in replay["events"] if e["type"] == "soccer_kick_result"]
        assert len(kicks) == 2

    def test_replay_detects_tampered_outcome(self):
        mid = _make_active_match()
        c = _client_as(_USER)
        c.post("/api/sports/soccer/resolve-kick", json={
            "match_id": mid, "speed": 30.0, "aim_x": 3.0, "aim_z": 1.5, "keeper_reach": 1.5,
        })
        c.post(f"/api/matches/{mid}/end", json={})
        replay = c.get(f"/api/matches/{mid}/export-replay").json()
        # Flip the recorded outcome — the validator must catch the mismatch.
        for e in replay["events"]:
            if e["type"] == "soccer_kick_result":
                e["outcome"] = "save" if e["outcome"] != "save" else "goal"
        errors = validate_replay(replay)
        assert any("outcome mismatch" in err for err in errors)
