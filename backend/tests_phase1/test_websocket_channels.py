"""Phase 2 WebSocket channel tests."""
from __future__ import annotations

from fastapi.testclient import TestClient

from app.auth.jwt_handler import create_access_token
from app.main import app


def test_vault_ping_and_session_end_economy_update() -> None:
    token = create_access_token("test-user")
    client = TestClient(app)

    with client.websocket_connect(f"/ws/vault?token={token}") as ws:
        ws.send_json({"event": "ping"})
        assert ws.receive_json()["event"] == "pong"

        ws.send_json(
            {
                "event": "session_start",
                "session_id": "sess_phase2",
                "timestamp": "2026-06-18T06:00:00Z",
            }
        )
        ack = ws.receive_json()
        assert ack["event"] == "session_ack"
        assert ack["status"] == "active"

        ws.send_json(
            {
                "event": "session_end",
                "session_id": "sess_phase2",
                "mode_id": "basketball_h2h",
                "session": {
                    "score": 3,
                    "outcome": "win",
                    "duration_sec": 60,
                    "completed": True,
                    "combo_count": 5,
                    "critical_count": 2,
                    "mri": {"arv": 78, "esi": 65.2, "pacing": 80},
                },
            }
        )
        update = ws.receive_json()

    assert update["event"] == "economy_update"
    assert update["session_id"] == "sess_phase2"
    assert update["user_id"] == "test-user"
    assert update["economy"]["xp_awarded"] == 10
    assert update["economy"]["shards_total"] == 84
    assert update["economy"]["prq_delta"] == 3.36
    assert update["persisted"] is True


def test_hud_relay_echoes_frame_for_user() -> None:
    client = TestClient(app)

    with client.websocket_connect("/ws/hud?user_id=test-user") as ws:
        connected = ws.receive_json()
        assert connected == {"event": "hud_connected", "user_id": "test-user"}

        frame = {
            "frame": 5421,
            "mode_id": "basketball_h2h",
            "scores": {"player": 2, "opponent": 1},
            "combo": {"chain_length": 3},
        }
        ws.send_json(frame)
        assert ws.receive_json() == frame


def test_hud_relay_normalizes_fel_hud_frame_envelope() -> None:
    client = TestClient(app)

    ios_frame = {
        "type": "fel.hud.frame",
        "event": "fel.hud.frame",
        "seq": 128,
        "payload": {
            "mode_id": "basketball_dunk",
            "score": 7,
            "session_state": "active",
            "mode_state": {
                "dunk": {"player_score": 7, "timing_grade": "great"},
            },
        },
    }

    with client.websocket_connect("/ws/hud?user_id=ios-player") as ws:
        ws.receive_json()
        ws.send_json(ios_frame)
        relayed = ws.receive_json()

    assert relayed["event"] == "fel.hud.frame"
    assert relayed["seq"] == 128
    assert relayed["frame"]["mode_id"] == "basketball_dunk"
    assert relayed["mode_state"]["dunk"]["timing_grade"] == "great"

