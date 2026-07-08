"""
Tests for Dance Mode — rhythm performance + choreography (nexus/dance-mode-core).

Covers:
  - beatmap determinism (same seed+bpm+difficulty -> identical events)
  - performance scoring determinism (same hits+seed -> same score, 3 seeds)
  - latency normalisation shifts judgments predictably
  - contest mode (seeded judge offsets) is reproducible
  - record persists a replay event; export/replay round-trips
  - choreography save round-trip + creator-card pack flag

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
from lib import creative_store, dance_beatmap
from lib.creative_store import get_creative_user
from routers.matches import _events, _matches
from routers.dance import router as dance_router
from routers.creator_cards import router as cards_router

_app = FastAPI()
_app.include_router(dance_router)
_app.include_router(cards_router)

_USER = User(user_id="dancer_perf", email="dp@fellab.io", name="Dancer Perf")


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


def _create(seed, bpm=128):
    resp = _client().post("/api/dance/projects", json={
        "name": "Perf Routine", "skeleton": "humanoid_v1", "bpm": bpm, "seed": seed,
        "animations": [{"name": "step", "duration": 2.0, "source": "library"}],
        "timeline": {"entries": []},
    })
    assert resp.status_code == 200, resp.text
    return resp.json()


def _perfect_hits(beatmap):
    """Build hits that land exactly on every beatmap event (should all be perfect)."""
    return [{"time_ms": e["time_ms"], "lane": e["lane"]} for e in beatmap["events"]]


# ── Beatmap determinism ────────────────────────────────────────────────────

class TestBeatmapDeterminism:
    def test_same_seed_bpm_identical(self):
        a = dance_beatmap.generate_beatmap(42, 120)
        b = dance_beatmap.generate_beatmap(42, 120)
        assert a == b
        assert a["note_count"] > 0

    def test_different_seed_differs(self):
        a = dance_beatmap.generate_beatmap(1, 120)
        b = dance_beatmap.generate_beatmap(2, 120)
        assert a["events"] != b["events"]

    def test_difficulty_changes_density(self):
        easy = dance_beatmap.generate_beatmap(7, 120, difficulty="easy")
        expert = dance_beatmap.generate_beatmap(7, 120, difficulty="expert")
        assert expert["note_count"] >= easy["note_count"]

    def test_bpm_affects_timing_not_count_on_downbeats(self):
        slow = dance_beatmap.generate_beatmap(9, 60)
        fast = dance_beatmap.generate_beatmap(9, 120)
        # Same note structure (same seed+difficulty), but times differ by tempo.
        assert slow["note_count"] == fast["note_count"]
        assert slow["duration_ms"] != fast["duration_ms"]

    def test_endpoint_matches_lib(self):
        proj = _create(seed=555, bpm=100)
        api = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        lib = dance_beatmap.generate_beatmap(555, 100)
        assert api["events"] == lib["events"]

    def test_beatmap_404(self):
        assert _client().get("/api/dance/projects/dan_nope/beatmap").status_code == 404


# ── Scoring determinism (3 seeds) ──────────────────────────────────────────

class TestScoringDeterminism:
    @pytest.mark.parametrize("seed", [11, 20260707, 9999999999])
    def test_same_hits_same_seed_same_score(self, seed):
        proj = _create(seed=seed)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = _perfect_hits(bm)
        r1 = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": hits}).json()["result"]
        r2 = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": hits}).json()["result"]
        assert r1 == r2

    @pytest.mark.parametrize("seed", [11, 20260707, 9999999999])
    def test_perfect_run_grades_S(self, seed):
        proj = _create(seed=seed)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": _perfect_hits(bm)}).json()["result"]
        assert r["tallies"]["perfect"] == bm["note_count"]
        assert r["tallies"]["miss"] == 0
        assert r["grade"] == "S"
        assert r["max_combo"] == bm["note_count"]
        assert r["big_combo"] is (bm["note_count"] >= dance_beatmap.BIG_COMBO_THRESHOLD)

    def test_empty_hits_all_miss(self):
        proj = _create(seed=3)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": []}).json()["result"]
        assert r["score"] == 0
        assert r["tallies"]["miss"] == bm["note_count"]
        assert r["grade"] == "D"

    def test_latency_normalisation_recovers_perfect(self):
        proj = _create(seed=77)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        # Shift every hit late by 200ms (would all miss), then normalise it out.
        late = [{"time_ms": e["time_ms"] + 200.0, "lane": e["lane"]} for e in bm["events"]]
        raw = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                             json={"hits": late}).json()["result"]
        assert raw["tallies"]["miss"] == bm["note_count"]
        fixed = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                               json={"hits": late, "latency_ms": 200.0}).json()["result"]
        assert fixed["tallies"]["perfect"] == bm["note_count"]

    def test_contest_seed_reproducible(self):
        proj = _create(seed=44)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = _perfect_hits(bm)
        a = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": hits, "contest_seed": 2024}).json()["result"]
        b = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": hits, "contest_seed": 2024}).json()["result"]
        assert a == b
        assert a["contest_seed"] == 2024

    def test_score_404(self):
        assert _client().post("/api/dance/projects/dan_nope/score",
                              json={"hits": []}).status_code == 404


# ── Record + replay round-trip ─────────────────────────────────────────────

class TestRecordReplay:
    def test_record_persists_event(self):
        proj = _create(seed=101)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        resp = _client().post(f"/api/dance/projects/{proj['project_id']}/record",
                              json={"hits": _perfect_hits(bm), "recording": True})
        assert resp.status_code == 200, resp.text
        assert resp.json()["recorded"] is True
        events = _events.get(proj["project_id"], [])
        assert any(e["type"] == "performance_recorded" for e in events)

    def test_record_score_matches_score_endpoint(self):
        proj = _create(seed=202)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = _perfect_hits(bm)
        scored = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                                json={"hits": hits}).json()["result"]
        recorded = _client().post(f"/api/dance/projects/{proj['project_id']}/record",
                                  json={"hits": hits}).json()["result"]
        assert scored == recorded

    def test_replay_export_includes_performance(self):
        proj = _create(seed=303)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        _client().post(f"/api/dance/projects/{proj['project_id']}/record",
                       json={"hits": _perfect_hits(bm), "recording": True})
        exp = _client().get(f"/api/replays/{proj['project_id']}/export").json()
        assert exp["metadata"]["project_type"] == "dance"
        assert exp["metadata"]["seed"] == 303
        types_seen = {e["type"] for e in exp["events"]}
        assert "project_created" in types_seen
        assert "performance_recorded" in types_seen
        # seq ordering authoritative + monotonic
        seqs = [e["seq"] for e in exp["events"]]
        assert seqs == sorted(seqs)


# ── Choreography editor ────────────────────────────────────────────────────

class TestChoreography:
    def test_save_choreography_round_trip(self):
        proj = _create(seed=404)
        tl = {"entries": [
            {"animation": "step", "start_beat": 0, "speed": 1.0},
            {"animation": "step", "start_beat": 8, "speed": 1.5, "transition": "crossfade"},
        ]}
        resp = _client().post(f"/api/dance/projects/{proj['project_id']}/choreography",
                              json={"timeline": tl})
        assert resp.status_code == 200, resp.text
        got = _client().get(f"/api/dance/projects/{proj['project_id']}").json()
        assert got["timeline"] == tl

    def test_save_as_pack_records_card_event(self):
        proj = _create(seed=505)
        _client().post(f"/api/dance/projects/{proj['project_id']}/choreography",
                       json={"timeline": {"entries": []}, "save_as_pack": True})
        events = _events.get(proj["project_id"], [])
        saved = [e for e in events if e["type"] == "choreography_saved"]
        assert saved and saved[-1]["pack_card_id"] == "card_choreo_01"

    def test_choreography_404(self):
        assert _client().post("/api/dance/projects/dan_nope/choreography",
                              json={"timeline": {"entries": []}}).status_code == 404
