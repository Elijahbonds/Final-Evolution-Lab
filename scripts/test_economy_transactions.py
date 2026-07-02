#!/usr/bin/env python3
"""
FEL Economy Transaction Validation
Unit tests for PRQ delta calculation, shard rewards, and XP cap logic.
Does not require a running server — imports calculation functions directly.
"""
import json
import sys
import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO_ROOT / "backend"))

from app.utils.constants import PRQ_MODE_WEIGHTS, XP_CAP_PER_SESSION
from app.utils.formulas import calculate_mri, calculate_prq_delta, calculate_shards, calculate_xp

PASS = 0
FAIL = 0

def ok(msg):
    global PASS
    PASS += 1
    print(f"  ✅ {msg}")

def fail(msg):
    global FAIL
    FAIL += 1
    print(f"  ❌ {msg}")

def assert_eq(actual, expected, label):
    if actual == expected:
        ok(f"{label}: {actual}")
    else:
        fail(f"{label}: expected {expected}, got {actual}")

def assert_approx(actual, expected, label, tol=0.01):
    if abs(actual - expected) <= tol:
        ok(f"{label}: {actual}")
    else:
        fail(f"{label}: expected ≈{expected}, got {actual}")


# ═══════════════════════════════════════════════════════════════════════════════
# Test Suite
# ═══════════════════════════════════════════════════════════════════════════════

def test_prq_delta_basic():
    print("\n── PRQ Delta: v2 Outcome Calculations ──")
    mri = calculate_mri(arv=50, esi=50, pacing=80)
    delta = calculate_prq_delta(
        mode_id="basketball_h2h",
        score=3,
        outcome="win",
        combo_count=5,
        critical_count=2,
        mri_score=mri,
    )
    assert_approx(delta, 3.29, "basketball_h2h win + combo/critical")

    delta = calculate_prq_delta(
        mode_id="basketball_dunk_irl",
        score=3,
        outcome="win",
        combo_count=0,
        critical_count=0,
        mri_score=50,
    )
    assert_approx(delta, 3.4, "IRL dunk uses 1.5 production weight")

    delta = calculate_prq_delta(
        mode_id="who_scene_it",
        score=0,
        outcome="draw",
        combo_count=0,
        critical_count=0,
        mri_score=50,
    )
    assert_approx(delta, 0.8, "Who Scene It uses 1.1 production weight")

def test_prq_delta_zero_score():
    print("\n── PRQ Delta: Zero/Edge Cases ──")
    delta = calculate_prq_delta(
        mode_id="tennis",
        score=0,
        outcome="loss",
        combo_count=0,
        critical_count=0,
        mri_score=50,
    )
    assert_approx(delta, 0.47, "Zero score still receives outcome/MRI v2 floor")

    # Unknown mode → weight defaults to 1.0
    delta = calculate_prq_delta(
        mode_id="unknown_mode",
        score=100,
        outcome="win",
        combo_count=0,
        critical_count=0,
        mri_score=50,
    )
    assert_approx(delta, 2.75, "Unknown mode → weight 1.0")

def test_shard_rewards():
    print("\n── Shard Rewards: Win/Draw/Loss ──")
    assert_eq(calculate_shards(outcome="win", combo_count=0, critical_count=0, pacing_score=0), 50, "Win base")
    assert_eq(calculate_shards(outcome="draw", combo_count=0, critical_count=0, pacing_score=0), 25, "Draw base")
    assert_eq(calculate_shards(outcome="loss", combo_count=0, critical_count=0, pacing_score=0), 15, "Loss base")
    assert_eq(calculate_shards(outcome="unknown", combo_count=0, critical_count=0, pacing_score=0), 15, "Unknown outcome → loss base")

def test_shard_combo_bonus():
    print("\n── Shard Rewards: Combo Bonuses ──")
    # combo_count=3 → no bonus (threshold is >3)
    assert_eq(calculate_shards(outcome="win", combo_count=3, critical_count=0, pacing_score=0), 50, "Win + 3 combos (no bonus)")
    # combo_count=4 → (4-3)×5 = 5
    assert_eq(calculate_shards(outcome="win", combo_count=4, critical_count=0, pacing_score=0), 55, "Win + 4 combos (+5)")
    # combo_count=10 → (10-3)×5 = 35
    assert_eq(calculate_shards(outcome="win", combo_count=10, critical_count=0, pacing_score=0), 85, "Win + 10 combos (+35)")

def test_shard_critical_bonus():
    print("\n── Shard Rewards: Critical Bonuses ──")
    assert_eq(calculate_shards(outcome="win", combo_count=0, critical_count=1, pacing_score=0), 60, "Win + 1 critical (+10)")
    assert_eq(calculate_shards(outcome="win", combo_count=0, critical_count=5, pacing_score=0), 100, "Win + 5 criticals (+50)")

def test_shard_combined():
    print("\n── Shard Rewards: Combined Bonuses ──")
    # Win + 6 combos + 3 criticals
    # base=50 + (6-3)×5=15 + 3×10=30 = 95
    assert_eq(calculate_shards(outcome="win", combo_count=6, critical_count=3, pacing_score=0), 95, "Win + combos + criticals")

    # Loss + 10 combos + 2 criticals
    # base=15 + (10-3)×5=35 + 2×10=20 = 70
    assert_eq(calculate_shards(outcome="loss", combo_count=10, critical_count=2, pacing_score=0), 70, "Loss + combos + criticals")


def test_shard_pacing_bonus():
    print("\n── Shard Rewards: Pacing Bonus ──")
    assert_eq(calculate_shards(outcome="win", combo_count=6, critical_count=2, pacing_score=80), 90, "Pacing ≥75 adds ceil(5%)")
    assert_eq(calculate_shards(outcome="win", combo_count=6, critical_count=2, pacing_score=50), 85, "Pacing <75 has no bonus")

def test_xp_cap():
    print("\n── XP Cap: 500/session ──")
    assert_eq(XP_CAP_PER_SESSION, 500, "configured XP cap")
    assert_eq(calculate_xp(100), 20, "score=100 → xp=20 (under cap)")
    assert_eq(calculate_xp(5000), 500, "score=5000 → xp=500 (capped)")
    assert_eq(calculate_xp(0), 10, "score=0 → xp=10 (minimum)")

def test_prq_weight_coverage():
    print("\n── PRQ Weight Coverage ──")
    registry = json.loads((REPO_ROOT / "backend" / "FEL_ModeManager.production.json").read_text())
    for mode, config in registry["mode_manager"]["mode_registry"].items():
        if "prq_weight" not in config:
            continue
        if mode not in PRQ_MODE_WEIGHTS:
            fail(f"{mode} missing from PRQ_MODE_WEIGHTS")
        elif PRQ_MODE_WEIGHTS[mode] != config["prq_weight"]:
            fail(f"{mode} weight expected {config['prq_weight']}, got {PRQ_MODE_WEIGHTS[mode]}")
        else:
            ok(f"{mode} weight={PRQ_MODE_WEIGHTS[mode]}")


def main():
    print("═══════════════════════════════════════════════════════════")
    print("  FEL Economy Transaction Validation")
    print("═══════════════════════════════════════════════════════════")

    test_prq_delta_basic()
    test_prq_delta_zero_score()
    test_shard_rewards()
    test_shard_combo_bonus()
    test_shard_critical_bonus()
    test_shard_combined()
    test_shard_pacing_bonus()
    test_xp_cap()
    test_prq_weight_coverage()

    total = PASS + FAIL
    print(f"\n{'═'*60}")
    print(f"  Results: {PASS} passed · {FAIL} failed · {total} total")
    print(f"{'═'*60}")

    if FAIL > 0:
        sys.exit(1)
    sys.exit(0)

if __name__ == "__main__":
    main()
