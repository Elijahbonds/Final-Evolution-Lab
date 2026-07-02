#!/usr/bin/env python3
"""
netcode_client_example.py — Minimal snapshot-reconciliation client (Agent 5).

Demonstrates the client side of infra/netcode_contract.md against a running
backend (MOCK_DB=1):

  1. Creates + joins a match over REST.
  2. Connects to WS /ws/match/{id}.
  3. Sends INPUT messages {seq, input, ts} while predicting locally.
  4. On each snapshot: drops acked inputs, resets to authoritative_state,
     re-applies unacked inputs (prediction replay).

Usage:
    cd backend && MOCK_DB=1 python3 -m uvicorn sim_app:app --port 8000
    python3 scripts/netcode_client_example.py --base http://localhost:8000 --inputs 10
"""
import argparse
import asyncio
import json
import time
import urllib.request
from typing import Any, Dict, List

try:
    import websockets
except ImportError:  # pragma: no cover
    raise SystemExit("pip install websockets (server-side dep already in backend/requirements.txt)")

ME = "netcode_demo_p1"


def _rest(base: str, method: str, path: str, body: Dict[str, Any] = None,
          player: str = ME) -> Dict[str, Any]:
    req = urllib.request.Request(
        base.rstrip("/") + path,
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
        headers={"Content-Type": "application/json", "X-FEL-Sim-Player": player},
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())


def apply_input(state: Dict[str, Any], inp: Dict[str, Any]) -> None:
    """Toy local prediction: track a predicted 'charge' meter client-side."""
    state.setdefault("predicted_charge", 0.0)
    state["predicted_charge"] = min(1.0, state["predicted_charge"] + inp.get("power", 0.1))


async def run(base: str, n_inputs: int) -> None:
    created = _rest(base, "POST", "/api/matches/create",
                    {"mode_id": "basketball_dunk_3d", "player_id": ME})
    mid = created["match_id"]
    _rest(base, "POST", "/api/matches/join",
          {"match_id": mid, "player_id": "netcode_demo_p2"}, player="netcode_demo_p2")
    ws_url = base.rstrip("/").replace("http", "ws", 1) + f"/ws/match/{mid}"
    print(f"match {mid} active; connecting {ws_url}")

    pending: List[Dict[str, Any]] = []
    local_state: Dict[str, Any] = {}
    seq = 0
    snapshots_seen = 0

    async with websockets.connect(ws_url) as ws:
        send_every = 0.1
        next_send = time.monotonic()
        while seq < n_inputs or pending or snapshots_seen < 12:
            if seq < n_inputs and time.monotonic() >= next_send:
                seq += 1
                msg = {"type": "input", "player_id": ME, "seq": seq,
                       "input": {"action": "charge", "power": 0.15}, "ts": time.time()}
                pending.append(msg)
                apply_input(local_state, msg["input"])       # client-side prediction
                await ws.send(json.dumps(msg))
                next_send += send_every
            try:
                raw = await asyncio.wait_for(ws.recv(), timeout=0.5)
            except asyncio.TimeoutError:
                continue
            data = json.loads(raw)
            if data.get("type") == "snapshot":
                snapshots_seen += 1
                acked = data["last_input_seq_ack"].get(ME, 0)
                before = len(pending)
                pending = [m for m in pending if m["seq"] > acked]   # 3a drop acked
                authoritative = dict(data["authoritative_state"])    # 3b reset
                local_state = authoritative
                for m in pending:                                    # 3c replay
                    apply_input(local_state, m["input"])
                print(f"  snapshot tick={data['tick']:>4} ack={acked:>3} "
                      f"dropped={before - len(pending)} pending={len(pending)} "
                      f"predicted_charge={local_state.get('predicted_charge', 0):.2f}")
            if seq >= n_inputs and not pending and snapshots_seen >= 12:
                break

    _rest(base, "POST", f"/api/matches/{mid}/end", {"reason": "netcode_demo_done"})
    replay = _rest(base, "GET", f"/api/matches/{mid}/export-replay")
    inputs_persisted = sum(1 for e in replay["events"] if e["type"] == "input")
    print(f"done: {inputs_persisted}/{n_inputs} inputs persisted to replay log; "
          f"{snapshots_seen} snapshots received")
    assert inputs_persisted == n_inputs, "input persistence mismatch!"


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://localhost:8000")
    parser.add_argument("--inputs", type=int, default=10)
    args = parser.parse_args()
    asyncio.run(run(args.base, args.inputs))
