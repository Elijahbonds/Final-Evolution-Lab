"""
Unit tests for /api/telemetry/* — event ingest, metric aggregation, determinism.

Runs fully offline. Sets MOCK_DB=1 before import so telemetry.py uses the
in-memory list store instead of MongoDB. Mirrors the isolation approach in
test_matches.py (stub third-party modules, mount router on a bare FastAPI app).
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

from routers.telemetry import router as telemetry_router, _events, _compute_dashboard

_app = FastAPI()
_app.include_router(telemetry_router)


@pytest.fixture(autouse=True)
def _clear_store():
    _events.clear()
    yield
    _events.clear()


def _client() -> TestClient:
    return TestClient(_app, raise_server_exceptions=True)


def _emit(client, event_type, payload=None, match_id=None, ts=None):
    body = {"event_type": event_type, "payload": payload or {}}
    if match_id is not None:
        body["match_id"] = match_id
    if ts is not None:
        body["ts"] = ts
    return client.post("/api/telemetry/event", json=body)


# ── Ingest ──────────────────────────────────────────────────────────────────

class TestIngest:
    def test_ingest_valid_event(self):
        r = _emit(_client(), "match_start", {"mode_id": "basketball_h2h"})
        assert r.status_code == 200
        data = r.json()
        assert data["ok"] is True
        assert data["seq"] == 0
        assert data["event_type"] == "match_start"

    def test_ingest_appends_to_store(self):
        c = _client()
        _emit(c, "dunk_score", {"total": 42})
        assert len(_events) == 1
        assert _events[0]["event_type"] == "dunk_score"
        assert _events[0]["payload"]["total"] == 42

    def test_ingest_stamps_ts_when_omitted(self):
        c = _client()
        _emit(c, "latency_sample", {"frame_time_ms": 12.0})
        assert _events[0]["ts"] is not None
        assert _events[0]["received_at"] is not None

    def test_ingest_preserves_supplied_ts(self):
        c = _client()
        _emit(c, "match_end", {}, ts="2026-07-07T00:00:00+00:00")
        assert _events[0]["ts"] == "2026-07-07T00:00:00+00:00"

    def test_seq_increments(self):
        c = _client()
        _emit(c, "match_start", {})
        r = _emit(c, "match_end", {})
        assert r.json()["seq"] == 1

    def test_ingest_rejects_unknown_type(self):
        r = _emit(_client(), "not_a_real_event", {})
        assert r.status_code == 422

    def test_match_id_stored(self):
        c = _client()
        _emit(c, "replay_export", {"valid": True}, match_id="m123")
        assert _events[0]["match_id"] == "m123"

    def test_events_listing(self):
        c = _client()
        for _ in range(3):
            _emit(c, "question_answer", {"correct": True})
        data = c.get("/api/telemetry/events").json()
        assert data["count"] == 3
        assert len(data["events"]) == 3


# ── Aggregation ──────────────────────────────────────────────────────────────

class TestDashboard:
    def test_empty_dashboard_is_zeroed(self):
        d = _client().get("/api/telemetry/dashboard").json()
        assert d["total_events"] == 0
        assert d["desync_rate"] == 0.0
        assert d["frame_time_p95_ms"] == 0.0
        assert d["replay_validator_failures"] == 0
        assert d["creator_card_conversion_rate"] == 0.0
        assert d["per_mode_play_counts"] == {}

    def test_events_by_type_counts(self):
        c = _client()
        _emit(c, "match_start", {"mode_id": "a"})
        _emit(c, "match_start", {"mode_id": "b"})
        _emit(c, "match_end", {})
        d = c.get("/api/telemetry/dashboard").json()
        assert d["total_events"] == 3
        assert d["events_by_type"]["match_start"] == 2
        assert d["events_by_type"]["match_end"] == 1

    def test_frame_time_p95(self):
        c = _client()
        # Samples 1..100 ms; nearest-rank p95 => 95th ordered value == 95
        for ms in range(1, 101):
            _emit(c, "latency_sample", {"frame_time_ms": float(ms)})
        d = c.get("/api/telemetry/dashboard").json()
        assert d["frame_time_p95_ms"] == 95.0
        assert d["frame_time_p50_ms"] == 50.0
        assert d["latency_sample_count"] == 100

    def test_desync_rate(self):
        c = _client()
        # 3 desyncs out of 10 latency samples => 0.3
        for i in range(10):
            _emit(c, "latency_sample", {"frame_time_ms": 10.0, "desync": i < 3})
        d = c.get("/api/telemetry/dashboard").json()
        assert d["desync_rate"] == 0.3

    def test_replay_validator_failures(self):
        c = _client()
        _emit(c, "replay_export", {"valid": True})
        _emit(c, "replay_export", {"valid": False})
        _emit(c, "replay_export", {"valid": False})
        d = c.get("/api/telemetry/dashboard").json()
        assert d["replay_export_count"] == 3
        assert d["replay_validator_failures"] == 2
        assert d["replay_failure_rate"] == round(2 / 3, 4)

    def test_creator_card_conversion_rate(self):
        c = _client()
        # 4 applies, 1 converted-flagged + 1 tied-to-match => 2 conversions
        _emit(c, "creator_card_apply", {"converted": True})
        _emit(c, "creator_card_apply", {}, match_id="m1")
        _emit(c, "creator_card_apply", {})
        _emit(c, "creator_card_apply", {})
        d = c.get("/api/telemetry/dashboard").json()
        assert d["creator_card_applies"] == 4
        assert d["creator_card_conversions"] == 2
        assert d["creator_card_conversion_rate"] == 0.5

    def test_per_mode_play_counts(self):
        c = _client()
        _emit(c, "match_start", {"mode_id": "basketball_h2h"})
        _emit(c, "match_start", {"mode_id": "basketball_h2h"})
        _emit(c, "match_start", {"mode_id": "dunk_contest"})
        _emit(c, "match_start", {})  # unknown mode
        d = c.get("/api/telemetry/dashboard").json()
        assert d["per_mode_play_counts"]["basketball_h2h"] == 2
        assert d["per_mode_play_counts"]["dunk_contest"] == 1
        assert d["per_mode_play_counts"]["unknown"] == 1

    def test_dunk_and_question_rollups(self):
        c = _client()
        _emit(c, "dunk_score", {"total": 80})
        _emit(c, "dunk_score", {"total": 100})
        _emit(c, "question_answer", {"correct": True})
        _emit(c, "question_answer", {"correct": False})
        d = c.get("/api/telemetry/dashboard").json()
        assert d["avg_dunk_score"] == 90.0
        assert d["question_count"] == 2
        assert d["question_accuracy"] == 0.5


# ── Determinism ──────────────────────────────────────────────────────────────

class TestDeterminism:
    def _seed(self, c):
        _emit(c, "match_start", {"mode_id": "basketball_h2h"})
        _emit(c, "match_start", {"mode_id": "dunk_contest"})
        _emit(c, "latency_sample", {"frame_time_ms": 8.0, "desync": False})
        _emit(c, "latency_sample", {"frame_time_ms": 33.0, "desync": True})
        _emit(c, "replay_export", {"valid": False})
        _emit(c, "creator_card_apply", {"converted": True})
        _emit(c, "dunk_score", {"total": 75})
        _emit(c, "match_end", {})

    def test_dashboard_repeated_calls_identical(self):
        c = _client()
        self._seed(c)
        d1 = c.get("/api/telemetry/dashboard").json()
        d2 = c.get("/api/telemetry/dashboard").json()
        d1.pop("generated_at")
        d2.pop("generated_at")
        assert d1 == d2

    def test_compute_is_pure_function_of_events(self):
        c = _client()
        self._seed(c)
        snapshot = list(_events)
        a = _compute_dashboard(snapshot)
        b = _compute_dashboard(snapshot)
        a.pop("generated_at")
        b.pop("generated_at")
        assert a == b

    def test_order_independent_for_counts(self):
        # Same multiset of events in different insertion order => same metrics.
        c1 = _client()
        _emit(c1, "match_start", {"mode_id": "a"})
        _emit(c1, "latency_sample", {"frame_time_ms": 10.0, "desync": True})
        _emit(c1, "latency_sample", {"frame_time_ms": 20.0, "desync": False})
        d1 = c1.get("/api/telemetry/dashboard").json()

        _events.clear()
        c2 = _client()
        _emit(c2, "latency_sample", {"frame_time_ms": 20.0, "desync": False})
        _emit(c2, "match_start", {"mode_id": "a"})
        _emit(c2, "latency_sample", {"frame_time_ms": 10.0, "desync": True})
        d2 = c2.get("/api/telemetry/dashboard").json()

        for key in ("desync_rate", "frame_time_p95_ms", "per_mode_play_counts",
                    "events_by_type"):
            assert d1[key] == d2[key]


# ── Reset (test aid) ─────────────────────────────────────────────────────────

def test_reset_clears_store():
    c = _client()
    _emit(c, "match_start", {})
    r = c.post("/api/telemetry/reset")
    assert r.status_code == 200
    assert r.json()["cleared"] == 1
    assert len(_events) == 0
