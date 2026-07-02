"""
Agent 5 — Snapshot netcode foundation tests (MOCK_DB=1).

Verifies:
  - WS INPUT messages {seq,input,ts} are persisted as `input` match events
    and acked with the highest processed seq
  - snapshot broadcasts carry {tick, authoritative_state, last_input_seq_ack}
    and tick increases monotonically
  - snapshot rate config is clamped to the 20-30 Hz contract window
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
from routers.matches import (
    router as match_router,
    get_match_user,
    _matches,
    _events,
    _last_input_seq_ack,
    _snapshot_hz,
    _snapshot_ticks,
)

_app = FastAPI()
_app.include_router(match_router)

_USER_A = User(user_id="net_a", email="na@fellab.io", name="Net A")
_USER_B = User(user_id="net_b", email="nb@fellab.io", name="Net B")


def _client_as(user: User) -> TestClient:
    _app.dependency_overrides[get_match_user] = lambda: user
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear_stores():
    _matches.clear()
    _events.clear()
    _last_input_seq_ack.clear()
    _snapshot_ticks.clear()
    yield
    _matches.clear()
    _events.clear()
    _last_input_seq_ack.clear()
    _snapshot_ticks.clear()


def _make_active_match() -> str:
    mid = _client_as(_USER_A).post("/api/matches/create", json={"mode_id": "basketball_h2h"}).json()["match_id"]
    _client_as(_USER_B).post("/api/matches/join", json={"match_id": mid})
    return mid


class TestSnapshotRateConfig:
    def test_default_rate_in_window(self):
        assert 20.0 <= _snapshot_hz() <= 30.0

    def test_rate_clamped_low_and_high(self):
        old = os.environ.get("FEL_SNAPSHOT_HZ")
        try:
            os.environ["FEL_SNAPSHOT_HZ"] = "5"
            assert _snapshot_hz() == 20.0
            os.environ["FEL_SNAPSHOT_HZ"] = "120"
            assert _snapshot_hz() == 30.0
            os.environ["FEL_SNAPSHOT_HZ"] = "garbage"
            assert 20.0 <= _snapshot_hz() <= 30.0
        finally:
            if old is None:
                os.environ.pop("FEL_SNAPSHOT_HZ", None)
            else:
                os.environ["FEL_SNAPSHOT_HZ"] = old


class TestWsInputIngestion:
    def test_ws_input_is_persisted_and_acked(self):
        mid = _make_active_match()
        client = _client_as(_USER_A)
        with client.websocket_connect(f"/ws/match/{mid}") as ws:
            first = ws.receive_json()
            assert first["type"] == "match_state"
            ws.send_json({"type": "input", "player_id": "net_a", "seq": 7,
                          "input": {"action": "jump"}, "ts": 1.5})
            # snapshots may interleave; read until we see the ack
            for _ in range(50):
                msg = ws.receive_json()
                if msg["type"] == "input_ack":
                    break
            assert msg["type"] == "input_ack"
            assert msg["seq"] == 7
        inputs = [e for e in _events[mid] if e["type"] == "input"]
        assert len(inputs) == 1
        assert inputs[0]["payload"] == {"seq": 7, "input": {"action": "jump"}, "ts": 1.5}
        assert _last_input_seq_ack[mid]["net_a"] == 7

    def test_ack_keeps_highest_seq(self):
        mid = _make_active_match()
        client = _client_as(_USER_A)
        with client.websocket_connect(f"/ws/match/{mid}") as ws:
            ws.receive_json()
            for seq in (3, 9, 5):
                ws.send_json({"type": "input", "player_id": "net_a", "seq": seq,
                              "input": {}, "ts": 0.0})
            acks = []
            for _ in range(100):
                msg = ws.receive_json()
                if msg["type"] == "input_ack":
                    acks.append(msg["seq"])
                    if len(acks) == 3:
                        break
        assert acks == [3, 9, 9]  # ack never regresses

    def test_rest_input_updates_ack(self):
        mid = _make_active_match()
        _client_as(_USER_A).post(
            f"/api/matches/{mid}/events",
            json={"type": "input", "player_id": "net_a",
                  "payload": {"seq": 11, "input": {}, "ts": 2.0}})
        assert _last_input_seq_ack[mid]["net_a"] == 11


class TestSnapshotBroadcast:
    def test_snapshots_flow_with_contract_fields(self):
        mid = _make_active_match()
        client = _client_as(_USER_A)
        with client.websocket_connect(f"/ws/match/{mid}") as ws:
            ws.receive_json()  # match_state
            snaps = []
            for _ in range(200):
                msg = ws.receive_json()
                if msg["type"] == "snapshot":
                    snaps.append(msg)
                    if len(snaps) == 3:
                        break
            assert len(snaps) == 3, "expected 3 snapshots from the broadcast loop"
            for s in snaps:
                assert set(s) == {"type", "tick", "authoritative_state", "last_input_seq_ack"}
                st = s["authoritative_state"]
                assert st["match_id"] == mid
                assert st["status"] == "active"
                assert st["players"] == ["net_a", "net_b"]
            ticks = [s["tick"] for s in snaps]
            assert ticks == sorted(ticks) and len(set(ticks)) == 3

    def test_snapshot_reports_input_ack(self):
        mid = _make_active_match()
        client = _client_as(_USER_A)
        with client.websocket_connect(f"/ws/match/{mid}") as ws:
            ws.receive_json()
            ws.send_json({"type": "input", "player_id": "net_a", "seq": 21,
                          "input": {"action": "sprint"}, "ts": 0.1})
            found = None
            for _ in range(200):
                msg = ws.receive_json()
                if msg["type"] == "snapshot" and msg["last_input_seq_ack"].get("net_a") == 21:
                    found = msg
                    break
            assert found is not None, "snapshot never reflected the acked input seq"
