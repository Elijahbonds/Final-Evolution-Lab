"""
Agent 5 — High-latency reconciliation convergence test (deterministic, seeded).

Acceptance for infra/netcode_contract.md: a simulated high-latency replay
showing client/server convergence. INPUT and SNAPSHOT delivery are each
delayed by a seeded 200-400 ms (quantized to 24 Hz ticks, i.e. 5-10 ticks
one way), the client predicts locally, and reconciliation uses the EXACT
routine shipped in scripts/netcode_client_example.py:

    3a. drop pending inputs with seq <= last_input_seq_ack[me]
    3b. reset local state to authoritative_state
    3c. replay remaining unacked inputs on top

The server side mirrors backend/routers/matches.py semantics: inputs are
applied on arrival (possibly out of order) and the ack is the HIGHEST seq
observed. Positions are modelled as a 1-D integrator so "convergence" is
|client_pos - server_pos| < EPSILON after the in-flight window drains.

No app/db needed — pure simulation, so it runs the same under MOCK_DB=1.
"""
import os
import random
import sys
from pathlib import Path

import pytest

os.environ.setdefault("MOCK_DB", "1")

pytest.importorskip("websockets")  # imported by the client example module
_REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_REPO_ROOT / "scripts"))

from netcode_client_example import reconcile  # noqa: E402

PLAYER = "net_sim_p1"
TICK_HZ = 24.0                       # inside the 20-30 Hz contract window
DT = 1.0 / TICK_HZ
LAT_MIN_S, LAT_MAX_S = 0.200, 0.400  # one-way latency range (each direction)
MAX_DELAY_TICKS = 10                 # ceil(0.400 / DT)
EPSILON = 1e-6


def apply_move(state, inp):
    """Shared client/server input integration: 1-D position accumulator."""
    state["pos"] = state.get("pos", 0.0) + inp["dx"]


def _delay_ticks(rng: random.Random) -> int:
    return max(1, round(rng.uniform(LAT_MIN_S, LAT_MAX_S) / DT))


def simulate(seed: int, send_ticks: int = 48, drain_ticks: int = 40) -> dict:
    """Run a seeded client/server replay under 200-400 ms one-way latency.

    Client sends one INPUT per tick for `send_ticks` ticks (predicting
    locally), then goes quiet for `drain_ticks` ticks while in-flight
    messages land. Returns final states plus a per-tick divergence history.
    """
    rng_lat = random.Random(seed)        # latency jitter
    rng_move = random.Random(seed + 1)   # movement inputs

    # server (mirrors matches.py: apply on arrival, ack = max seq observed)
    server_state = {"pos": 0.0}
    server_ack = 0
    inputs_in_flight = []   # (arrival_tick, INPUT msg)

    # client (contract prediction + reconcile from netcode_client_example)
    local_state = {"pos": 0.0}
    pending = []
    snaps_in_flight = []    # (arrival_tick, SNAPSHOT msg)
    seq = 0

    history = []            # (tick, client_pos, server_pos, n_pending)
    total = send_ticks + drain_ticks
    for tick in range(1, total + 1):
        # 1. client emits INPUT{seq,input,ts} and predicts locally
        if tick <= send_ticks:
            seq += 1
            msg = {"type": "input", "player_id": PLAYER, "seq": seq,
                   "input": {"dx": rng_move.uniform(-1.0, 1.0)},
                   "ts": tick * DT}
            pending.append(msg)
            apply_move(local_state, msg["input"])            # prediction
            inputs_in_flight.append((tick + _delay_ticks(rng_lat), msg))

        # 2. server applies every INPUT that has arrived by this tick
        landed = sorted((x for x in inputs_in_flight if x[0] <= tick),
                        key=lambda x: (x[0], x[1]["seq"]))
        inputs_in_flight = [x for x in inputs_in_flight if x[0] > tick]
        for _, m in landed:
            apply_move(server_state, m["input"])
            server_ack = max(server_ack, m["seq"])           # ack semantics

        # 3. server broadcasts SNAPSHOT{tick,authoritative_state,last_input_seq_ack}
        snap = {"type": "snapshot", "tick": tick,
                "authoritative_state": {"pos": server_state["pos"]},
                "last_input_seq_ack": {PLAYER: server_ack}}
        snaps_in_flight.append((tick + _delay_ticks(rng_lat), snap))

        # 4. client reconciles every SNAPSHOT that has arrived by this tick
        arrived = sorted((x for x in snaps_in_flight if x[0] <= tick),
                         key=lambda x: (x[0], x[1]["tick"]))
        snaps_in_flight = [x for x in snaps_in_flight if x[0] > tick]
        for _, s in arrived:
            local_state, pending = reconcile(pending, s, PLAYER, apply_move)

        history.append((tick, local_state["pos"], server_state["pos"],
                        len(pending)))

    return {
        "send_ticks": send_ticks,
        "final_client": local_state["pos"],
        "final_server": server_state["pos"],
        "final_ack": server_ack,
        "final_seq": seq,
        "final_pending": len(pending),
        "history": history,
    }


def _converged_from(history):
    """First tick from which |client - server| < EPSILON holds to the end."""
    converged_tick = None
    for tick, cpos, spos, _ in history:
        if abs(cpos - spos) < EPSILON:
            if converged_tick is None:
                converged_tick = tick
        else:
            converged_tick = None
    return converged_tick


class TestHighLatencyConvergence:
    def test_client_converges_within_epsilon_after_n_ticks(self):
        r = simulate(seed=1337)
        # every in-flight message drained and every input acked
        assert r["final_pending"] == 0
        assert r["final_ack"] == r["final_seq"] == r["send_ticks"]
        # positions converge within epsilon
        assert abs(r["final_client"] - r["final_server"]) < EPSILON
        # ...and did so within one round trip (+jitter margin) after the
        # last input was sent, then STAYED converged
        converged = _converged_from(r["history"])
        assert converged is not None, "client never locked to server state"
        assert converged <= r["send_ticks"] + 2 * MAX_DELAY_TICKS + 2

    def test_prediction_diverges_mid_flight_then_reconciles(self):
        """Sanity: latency actually created divergence (the test is not
        vacuous), and reconciliation erased it."""
        r = simulate(seed=1337)
        send = r["send_ticks"]
        max_div_during_send = max(abs(c - s) for t, c, s, _ in r["history"]
                                  if t <= send)
        assert max_div_during_send > 0.1, (
            "expected visible client/server divergence while inputs are in "
            f"flight, got {max_div_during_send}")
        # pending buffer was non-empty mid-flight (prediction was live)
        assert any(p > 0 for t, _, _, p in r["history"] if t <= send)

    def test_convergence_across_seeds(self):
        for seed in (1, 7, 42, 99, 2026):
            r = simulate(seed=seed)
            assert r["final_pending"] == 0, f"seed {seed}: pending not drained"
            assert abs(r["final_client"] - r["final_server"]) < EPSILON, (
                f"seed {seed}: diverged by "
                f"{abs(r['final_client'] - r['final_server'])}")

    def test_simulation_is_deterministic(self):
        a, b = simulate(seed=7), simulate(seed=7)
        assert a == b
        # different seeds produce different trajectories (guards against a
        # degenerate constant simulation)
        assert simulate(seed=8)["final_server"] != a["final_server"]
