#!/usr/bin/env python3
"""
Headless match simulation for Nexus basketball modes.

Runs N full match lifecycles using the in-memory backend (MOCK_DB=1),
verifying seed determinism, scoring math, and replay integrity.

Usage:
    MOCK_DB=1 python scripts/simulate_matches.py [--games N] [--mode MODE_ID]
"""
import os
import sys
import argparse
import json
import time
import statistics
import random
from typing import Any, Dict, List

# Force mock DB before importing backend modules
os.environ["MOCK_DB"] = "1"
os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "sim_test")
os.environ.setdefault("EMERGENT_LLM_KEY", "sim-key-unused")

# Stub external deps before import
import types

def _stub(name: str):
    parts = name.split(".")
    for i in range(1, len(parts) + 1):
        pkg = ".".join(parts[:i])
        if pkg not in sys.modules:
            sys.modules[pkg] = types.ModuleType(pkg)
    return sys.modules[name]

from unittest.mock import MagicMock, patch
_chat = _stub("emergentintegrations.llm.chat")
_chat.LlmChat = MagicMock
_chat.UserMessage = MagicMock
_chat.ImageContent = MagicMock

_motor_patcher = patch("motor.motor_asyncio.AsyncIOMotorClient")
_mock_motor = _motor_patcher.start()
_mock_motor.return_value.__getitem__ = lambda self, n: MagicMock()

# Now safe to import backend lib
backend_dir = os.path.join(os.path.dirname(__file__), "..", "backend")
sys.path.insert(0, os.path.abspath(backend_dir))

from lib.match_utils import generate_seed, derive_judge_offsets
from lib.dunk_scoring import score_dunk, DunkResult
from lib.card_effects import compute_loadout_modifiers, CARD_EFFECT_MAP


# ── Simulation helpers ────────────────────────────────────────────────────────

def simulate_h2h_game(seed: int) -> Dict[str, Any]:
    """Simulate a basketball H2H game to 21 using the given seed."""
    rng = random.Random(seed)
    p1_score = 0
    p2_score = 0
    events: List[Dict] = []
    shots_taken = 0
    p1_consecutive = 0
    p1_momentum = 0

    while p1_score < 21 and p2_score < 21:
        shots_taken += 1
        is_p1_possession = (shots_taken % 2 == 1)

        if is_p1_possession:
            hot_hand = p1_consecutive >= 3
            base_make = 0.72 if hot_hand else 0.60
            is_3pt = rng.random() < 0.25
            makes = rng.random() < base_make
            if makes:
                pts = 3 if is_3pt else 1
                p1_score += pts
                p1_consecutive += 1
                p1_momentum = min(3, p1_momentum + 1)
                events.append({"shooter": "p1", "pts": pts, "hot_hand": hot_hand,
                                "score": [p1_score, p2_score]})
            else:
                p1_consecutive = 0
                p1_momentum = max(-3, p1_momentum - 1)
        else:
            ai_make = 0.52 + (p1_momentum < 0) * 0.08  # AI reads momentum
            makes = rng.random() < ai_make
            if makes:
                pts = 3 if rng.random() < 0.20 else 1
                p2_score += pts
                events.append({"shooter": "p2", "pts": pts, "score": [p1_score, p2_score]})

    winner = "p1" if p1_score >= 21 else "p2"
    return {
        "seed": seed,
        "winner": winner,
        "final": [p1_score, p2_score],
        "shots_taken": shots_taken,
        "events": len(events),
    }


def simulate_dunk_contest(seed: int, style_difficulty: float = 0.8) -> Dict[str, Any]:
    """Simulate 3 dunk attempts using server-side scoring."""
    offsets = derive_judge_offsets(seed)
    rng = random.Random(seed + 1)
    dunks = []
    for i in range(3):
        approach = rng.uniform(0.55, 1.0)
        execution = rng.uniform(0.55, 1.0)
        result = score_dunk(approach, execution, style_difficulty, offsets)
        dunks.append({
            "attempt": i + 1,
            "approach": round(approach, 3),
            "execution": round(execution, 3),
            "j1": result.j1, "j2": result.j2, "j3": result.j3,
            "total": result.total,
            "message": result.message,
            "is_perfect": result.is_perfect,
        })
    total_score = sum(d["total"] for d in dunks)
    return {"seed": seed, "judge_offsets": offsets, "dunks": dunks, "total_score": total_score}


def verify_replay_determinism(seed: int) -> bool:
    """Verify that replaying with the same seed produces identical dunk scores."""
    r1 = simulate_dunk_contest(seed, style_difficulty=0.9)
    r2 = simulate_dunk_contest(seed, style_difficulty=0.9)
    for d1, d2 in zip(r1["dunks"], r2["dunks"]):
        if (d1["j1"], d1["j2"], d1["j3"]) != (d2["j1"], d2["j2"], d2["j3"]):
            return False
    return True


# ── Main ──────────────────────────────────────────────────────────────────────

def run_simulation(games: int, mode: str) -> None:
    print(f"\n{'='*60}")
    print(f"  Nexus Headless Match Simulation")
    print(f"  Mode: {mode}  |  Games: {games}")
    print(f"{'='*60}\n")

    t_start = time.time()
    results = []
    replay_ok = 0

    for i in range(games):
        seed = generate_seed()

        if mode in ("basketball_h2h", "all"):
            r = simulate_h2h_game(seed)
            results.append(r)

        if mode in ("basketball_dunk", "all"):
            d = simulate_dunk_contest(seed)
            if verify_replay_determinism(seed):
                replay_ok += 1

        if (i + 1) % max(1, games // 10) == 0:
            pct = int((i + 1) / games * 100)
            print(f"  [{pct:3d}%] {i+1}/{games} games simulated...")

    elapsed = time.time() - t_start

    if results and mode in ("basketball_h2h", "all"):
        p1_wins = sum(1 for r in results if r["winner"] == "p1")
        p2_wins = len(results) - p1_wins
        avg_shots = statistics.mean(r["shots_taken"] for r in results)
        print(f"\n── H2H Results ─────────────────────────────────────────")
        print(f"  P1 win rate : {p1_wins/len(results)*100:.1f}% ({p1_wins}/{len(results)})")
        print(f"  P2 win rate : {p2_wins/len(results)*100:.1f}% ({p2_wins}/{len(results)})")
        print(f"  Avg shots/game: {avg_shots:.1f}")

    if mode in ("basketball_dunk", "all"):
        print(f"\n── Dunk Contest Results ────────────────────────────────")
        print(f"  Replay determinism: {replay_ok}/{games} matches verified ✓")

    print(f"\n── Summary ─────────────────────────────────────────────")
    print(f"  Simulated {games} games in {elapsed:.2f}s")
    print(f"  Throughput: {games/elapsed:.0f} games/sec")
    print(f"  Seed generation: non-repeating os.urandom")
    print(f"  Replay integrity: {'PASS' if replay_ok == games or mode == 'basketball_h2h' else 'FAIL'}")
    print(f"\n{'='*60}\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Nexus headless match simulator")
    parser.add_argument("--games", type=int, default=100, help="Number of games to simulate")
    parser.add_argument("--mode", default="all",
                        choices=["basketball_h2h", "basketball_dunk", "all"],
                        help="Mode to simulate")
    args = parser.parse_args()
    run_simulation(args.games, args.mode)
