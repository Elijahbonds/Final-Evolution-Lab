#!/usr/bin/env python3
"""
Simulate N full match lifecycles against a running FEL backend and write
replay JSON artifacts.

For each match:
  1. POST /api/matches/create   (player A)
  2. POST /api/matches/join     (player B → match becomes 'active', backend
                                 emits simulated score_events in background)
  3. Poll GET /api/debug/match/{id}/payload until status == 'finished'
  4. Write artifacts/<match_id>_replay.json with the full event stream.

Auth: sends `X-Sim-Player` headers understood by backend/tools/sim_server.py.
Requires only the `requests` package (see backend/requirements-ci.txt).

Usage:
    python3 scripts/simulate_matches.py --n 3 \
        --base-url http://127.0.0.1:8811 \
        --out artifacts/sim/replays

Exits non-zero if any match fails to reach 'finished' within --timeout.
"""
import argparse
import json
import sys
import time
from pathlib import Path

import requests

PLAYER_A = "sim_player_a"
PLAYER_B = "sim_player_b"


def _headers(player_id: str) -> dict:
    return {"X-Sim-Player": player_id, "Content-Type": "application/json"}


def wait_for_server(base_url: str, timeout: float = 30.0) -> None:
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            r = requests.get(f"{base_url}/health", timeout=2)
            if r.ok:
                return
        except requests.RequestException:
            pass
        time.sleep(0.5)
    raise RuntimeError(f"Server at {base_url} did not become healthy in {timeout}s")


def run_match(base_url: str, mode_id: str, timeout: float) -> dict:
    r = requests.post(
        f"{base_url}/api/matches/create",
        json={"mode_id": mode_id},
        headers=_headers(PLAYER_A),
        timeout=10,
    )
    r.raise_for_status()
    match_id = r.json()["match_id"]

    r = requests.post(
        f"{base_url}/api/matches/join",
        json={"match_id": match_id},
        headers=_headers(PLAYER_B),
        timeout=10,
    )
    r.raise_for_status()
    status = r.json()["status"]
    if status != "active":
        raise RuntimeError(f"Match {match_id} did not activate (status={status})")

    deadline = time.time() + timeout
    payload: dict = {}
    while time.time() < deadline:
        r = requests.get(f"{base_url}/api/debug/match/{match_id}/payload", timeout=10)
        r.raise_for_status()
        payload = r.json()
        if payload.get("status") == "finished":
            return payload
        time.sleep(1.0)
    raise RuntimeError(
        f"Match {match_id} did not finish within {timeout}s (status={payload.get('status')})"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Simulate FEL matches and dump replays")
    parser.add_argument("--n", type=int, default=3, help="Number of matches to simulate")
    parser.add_argument("--base-url", default="http://127.0.0.1:8811")
    parser.add_argument("--mode-id", default="basketball_h2h")
    parser.add_argument("--out", default="artifacts/sim/replays")
    parser.add_argument("--timeout", type=float, default=60.0, help="Per-match finish timeout (s)")
    args = parser.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    wait_for_server(args.base_url)

    failures = 0
    summary = []
    for i in range(args.n):
        print(f"[sim] match {i + 1}/{args.n} (mode={args.mode_id}) ...", flush=True)
        try:
            payload = run_match(args.base_url, args.mode_id, args.timeout)
            match_id = payload["match_id"]
            replay_path = out_dir / f"{match_id}_replay.json"
            replay_path.write_text(json.dumps(payload, indent=2))
            n_events = len(payload.get("events", []))
            print(f"[sim]   finished: {match_id} score={payload['score']} events={n_events}")
            print(f"[sim]   replay -> {replay_path}")
            summary.append({"match_id": match_id, "score": payload["score"], "events": n_events})
        except Exception as exc:  # keep going so all failures are reported
            failures += 1
            print(f"[sim]   FAILED: {exc}", file=sys.stderr)
            summary.append({"error": str(exc)})

    (out_dir / "summary.json").write_text(
        json.dumps({"requested": args.n, "failures": failures, "matches": summary}, indent=2)
    )
    print(f"[sim] done: {args.n - failures}/{args.n} matches finished")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
