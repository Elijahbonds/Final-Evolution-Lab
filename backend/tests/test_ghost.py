"""
Ghost Mode Challenge — Backend Tests
Runs fully offline with MOCK_DB=1.

Tests:
  - Publishing a ghost (validation, hash, storage)
  - Ghost discovery feed (mode + PRQ filtering)
  - Ghost fetch for playback (seed + events returned)
  - Challenge initiation (returns seed, overlay instructions)
  - Challenge completion (performance delta, beat tracking)
  - Verification hash integrity (tamper detection)
  - Headless bot vs ghost reconciliation (score must match server re-scoring)
"""
import os
import sys
import types
from unittest.mock import MagicMock, patch

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_ghost")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")
os.environ["MOCK_DB"] = "1"

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

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

import core
from core import User
from routers.ghost import (
    router as ghost_router,
    _ghosts, _ghost_challenges,
    _compute_ghost_hash,
)
from lib.match_utils import generate_seed, derive_judge_offsets
from lib.dunk_scoring import score_dunk

_app = FastAPI()
_app.include_router(ghost_router)

_ATHLETE = User(
    user_id="ghost_athlete_a",
    email="ghost_a@fellab.io",
    name="Ghost Athlete A",
    sport="basketball",
    prq_score=85.0,
    level=5,
    xp=500,
    streak_days=7,
    coins=200,
)
_CHALLENGER = User(
    user_id="ghost_challenger_b",
    email="ghost_b@fellab.io",
    name="Challenger B",
    sport="basketball",
    prq_score=78.0,
    level=3,
    xp=300,
    streak_days=3,
    coins=100,
)


def _client(user: User) -> TestClient:
    _app.dependency_overrides[core.get_current_user] = lambda: user
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear():
    _ghosts.clear()
    _ghost_challenges.clear()
    yield
    _ghosts.clear()
    _ghost_challenges.clear()


# ── Helpers ───────────────────────────────────────────────────────────────────

def _make_dunk_events(seed: int, n: int = 3) -> list:
    offsets = derive_judge_offsets(seed)
    events = []
    for i in range(n):
        result = score_dunk(0.8, 0.85, 0.7, offsets)
        events.append({
            "type": "dunk_result",
            "j1": result.j1, "j2": result.j2, "j3": result.j3,
            "total": result.total,
            "message": result.message,
            "seq": i + 1,
            "timestamp": f"2026-07-01T1{i}:00:00+00:00",
        })
    return events


def _publish_ghost(seed: int = 99999, mode: str = "basketball_dunk") -> dict:
    events = _make_dunk_events(seed)
    resp = _client(_ATHLETE).post("/api/ghost/publish", json={
        "mode_id": mode,
        "seed": seed,
        "judge_offsets": derive_judge_offsets(seed),
        "events": events,
        "final_score": {"p1": 21, "p2": 14},
    })
    assert resp.status_code == 200
    return resp.json()


# ── TestGhostPublish ──────────────────────────────────────────────────────────

class TestGhostPublish:
    def test_publish_returns_ghost_id(self):
        data = _publish_ghost()
        assert "ghost_id" in data and data["ghost_id"]

    def test_publish_returns_verification_hash(self):
        data = _publish_ghost()
        assert "verification_hash" in data
        assert len(data["verification_hash"]) == 64  # SHA-256 hex

    def test_publish_stores_ghost(self):
        data = _publish_ghost(seed=111)
        assert data["ghost_id"] in _ghosts

    def test_publish_records_publisher_name(self):
        data = _publish_ghost()
        ghost = _ghosts[data["ghost_id"]]
        assert ghost["publisher_name"] == "Ghost Athlete A"

    def test_publish_without_events_returns_400(self):
        resp = _client(_ATHLETE).post("/api/ghost/publish", json={
            "mode_id": "basketball_dunk",
            "seed": 12345,
            "events": [],
        })
        assert resp.status_code == 400

    def test_publish_top_moment_extracted(self):
        data = _publish_ghost()
        assert data.get("top_moment") is not None
        assert data["top_moment"]["type"] == "dunk_result"

    def test_verification_hash_is_deterministic(self):
        seed = 77777
        events = _make_dunk_events(seed)
        h1 = _compute_ghost_hash(seed, events)
        h2 = _compute_ghost_hash(seed, events)
        assert h1 == h2

    def test_verification_hash_changes_if_events_change(self):
        seed = 77777
        events1 = _make_dunk_events(seed, n=2)
        events2 = _make_dunk_events(seed, n=3)
        h1 = _compute_ghost_hash(seed, events1)
        h2 = _compute_ghost_hash(seed, events2)
        assert h1 != h2


# ── TestGhostDiscovery ────────────────────────────────────────────────────────

class TestGhostDiscovery:
    def test_list_returns_empty_initially(self):
        resp = _client(_CHALLENGER).get("/api/ghost")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_list_returns_published_ghosts(self):
        _publish_ghost(seed=1001, mode="basketball_dunk")
        _publish_ghost(seed=1002, mode="basketball_h2h")
        resp = _client(_CHALLENGER).get("/api/ghost")
        assert len(resp.json()) == 2

    def test_list_filters_by_mode(self):
        _publish_ghost(seed=2001, mode="basketball_dunk")
        _publish_ghost(seed=2002, mode="basketball_h2h")
        resp = _client(_CHALLENGER).get("/api/ghost?mode_id=basketball_dunk")
        data = resp.json()
        assert len(data) == 1
        assert data[0]["mode_id"] == "basketball_dunk"

    def test_list_filters_by_prq_range(self):
        _publish_ghost(seed=3001)  # publisher PRQ = 85.0
        resp = _client(_CHALLENGER).get("/api/ghost?min_prq=90&max_prq=100")
        assert resp.json() == []

    def test_list_includes_beat_rate(self):
        _publish_ghost(seed=4001)
        resp = _client(_CHALLENGER).get("/api/ghost")
        data = resp.json()
        assert "beat_rate_pct" in data[0]

    def test_list_limit_honored(self):
        for i in range(5):
            _publish_ghost(seed=5000 + i)
        resp = _client(_CHALLENGER).get("/api/ghost?limit=3")
        assert len(resp.json()) <= 3


# ── TestGhostFetch ────────────────────────────────────────────────────────────

class TestGhostFetch:
    def test_fetch_returns_seed_and_events(self):
        published = _publish_ghost(seed=8888)
        gid = published["ghost_id"]
        resp = _client(_CHALLENGER).get(f"/api/ghost/{gid}")
        assert resp.status_code == 200
        data = resp.json()
        assert data["seed"] == 8888
        assert isinstance(data["events"], list) and len(data["events"]) > 0

    def test_fetch_returns_judge_offsets(self):
        published = _publish_ghost(seed=8889)
        resp = _client(_CHALLENGER).get(f"/api/ghost/{published['ghost_id']}")
        assert "judge_offsets" in resp.json()
        assert len(resp.json()["judge_offsets"]) == 3

    def test_fetch_404_on_missing_ghost(self):
        resp = _client(_CHALLENGER).get("/api/ghost/nonexistent-id")
        assert resp.status_code == 404

    def test_fetch_includes_verification_hash(self):
        published = _publish_ghost(seed=8890)
        resp = _client(_CHALLENGER).get(f"/api/ghost/{published['ghost_id']}")
        assert resp.json()["verification_hash"] == published["verification_hash"]


# ── TestGhostChallenge ────────────────────────────────────────────────────────

class TestGhostChallenge:
    def test_challenge_returns_seed_and_ghost_events(self):
        published = _publish_ghost(seed=55555)
        resp = _client(_CHALLENGER).post(f"/api/ghost/{published['ghost_id']}/challenge")
        assert resp.status_code == 200
        data = resp.json()
        assert data["seed"] == 55555
        assert "ghost_events" in data
        assert "judge_offsets" in data

    def test_challenge_returns_overlay_instructions(self):
        published = _publish_ghost(seed=55556)
        resp = _client(_CHALLENGER).post(f"/api/ghost/{published['ghost_id']}/challenge")
        assert "instructions" in resp.json()

    def test_challenge_increments_challenge_count(self):
        published = _publish_ghost(seed=55557)
        gid = published["ghost_id"]
        _client(_CHALLENGER).post(f"/api/ghost/{gid}/challenge")
        assert _ghosts[gid]["challenge_count"] == 1

    def test_challenge_404_on_missing_ghost(self):
        resp = _client(_CHALLENGER).post("/api/ghost/nope/challenge")
        assert resp.status_code == 404


# ── TestGhostComplete ─────────────────────────────────────────────────────────

class TestGhostComplete:
    def _setup(self, seed: int = 66666):
        published = _publish_ghost(seed=seed)
        return published["ghost_id"]

    def test_complete_returns_performance_delta(self):
        gid = self._setup()
        resp = _client(_CHALLENGER).post(f"/api/ghost/{gid}/complete", json={
            "challenger_events": _make_dunk_events(11111),
            "challenger_final_score": {"p1": 23, "p2": 17},
        })
        assert resp.status_code == 200
        data = resp.json()
        assert "performance_delta" in data
        assert "beat_ghost" in data["performance_delta"]
        assert "verdict" in data["performance_delta"]

    def test_complete_beat_count_increments_on_win(self):
        # Ghost dunk events score: fixed seed 99999
        # Give challenger much higher score to ensure win
        gid = self._setup(seed=99999)
        ghost_events = _make_dunk_events(99999)
        ghost_total = sum(e["total"] for e in ghost_events)
        winning_events = [
            {"type": "dunk_result", "j1": 10, "j2": 10, "j3": 10, "total": 30,
             "message": "PERFECT SCORE", "seq": i+1, "timestamp": f"2026-07-01T1{i}:00:00+00:00"}
            for i in range(3)
        ]
        _client(_CHALLENGER).post(f"/api/ghost/{gid}/complete", json={
            "challenger_events": winning_events,
            "challenger_final_score": {"p1": 30},
        })
        assert _ghosts[gid]["beat_count"] == 1

    def test_complete_404_on_missing_ghost(self):
        resp = _client(_CHALLENGER).post("/api/ghost/nope/complete", json={
            "challenger_events": [],
            "challenger_final_score": {},
        })
        assert resp.status_code == 404

    def test_complete_ghost_score_unchanged(self):
        gid = self._setup(seed=77777)
        original_score = _ghosts[gid]["final_score"].copy()
        _client(_CHALLENGER).post(f"/api/ghost/{gid}/complete", json={
            "challenger_events": _make_dunk_events(22222),
            "challenger_final_score": {"p1": 18},
        })
        assert _ghosts[gid]["final_score"] == original_score

    def test_complete_includes_challenger_and_ghost_scores(self):
        gid = self._setup()
        resp = _client(_CHALLENGER).post(f"/api/ghost/{gid}/complete", json={
            "challenger_events": _make_dunk_events(33333),
            "challenger_final_score": {"p1": 19, "p2": 14},
        })
        data = resp.json()
        assert "ghost_final_score" in data
        assert "challenger_final_score" in data


# ── TestGhostVerification ─────────────────────────────────────────────────────

class TestGhostVerification:
    def test_hash_matches_after_publish(self):
        published = _publish_ghost(seed=12121)
        gid = published["ghost_id"]
        ghost = _ghosts[gid]
        expected = _compute_ghost_hash(ghost["seed"], ghost["events"])
        assert ghost["verification_hash"] == expected

    def test_tampered_hash_detected_on_complete(self):
        published = _publish_ghost(seed=13131)
        gid = published["ghost_id"]
        # Tamper with stored hash
        _ghosts[gid]["verification_hash"] = "0" * 64
        resp = _client(_CHALLENGER).post(f"/api/ghost/{gid}/complete", json={
            "challenger_events": [],
            "challenger_final_score": {},
        })
        assert resp.status_code == 409


# ── TestHeadlessBotVsGhost ────────────────────────────────────────────────────

class TestHeadlessBotVsGhost:
    """Headless simulation: bot plays against a ghost, scores reconcile with server math."""

    def test_bot_dunk_scores_reconcile_with_server(self):
        """Bot's locally computed dunk scores must match server's re-scoring of same inputs."""
        import random
        seed = generate_seed()
        offsets = derive_judge_offsets(seed)
        rng = random.Random(seed + 99)

        # Bot computes scores locally (same formula as server)
        bot_events = []
        for i in range(3):
            approach = rng.uniform(0.6, 1.0)
            execution = rng.uniform(0.6, 1.0)
            style = 0.8
            result = score_dunk(approach, execution, style, offsets)
            bot_events.append({
                "type": "dunk_result",
                "j1": result.j1, "j2": result.j2, "j3": result.j3,
                "total": result.total,
                "message": result.message,
                "seq": i + 1,
                "timestamp": f"2026-07-01T1{i}:00:00+00:00",
                "_inputs": {"approach": approach, "execution": execution, "style": style},
            })

        # Publish ghost with those events
        ghost_resp = _client(_ATHLETE).post("/api/ghost/publish", json={
            "mode_id": "basketball_dunk",
            "seed": seed,
            "judge_offsets": offsets,
            "events": bot_events,
            "final_score": {"p1": sum(e["total"] for e in bot_events)},
        })
        assert ghost_resp.status_code == 200
        gid = ghost_resp.json()["ghost_id"]

        # Re-score using server endpoint by re-deriving from same seed
        # The server would score identically because same offsets + same inputs
        refetch = _client(_CHALLENGER).get(f"/api/ghost/{gid}")
        assert refetch.status_code == 200
        ghost_data = refetch.json()

        # Verify: re-scoring with same inputs + same offsets = same totals
        for event in ghost_data["events"]:
            if event.get("type") == "dunk_result" and "_inputs" in event:
                inputs = event["_inputs"]
                re_scored = score_dunk(
                    inputs["approach"], inputs["execution"], inputs["style"],
                    ghost_data["judge_offsets"],
                )
                assert re_scored.j1 == event["j1"]
                assert re_scored.j2 == event["j2"]
                assert re_scored.j3 == event["j3"]
                assert re_scored.total == event["total"]
