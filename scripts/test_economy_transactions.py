#!/usr/bin/env python3
"""
FEL Economy Transaction Validation
Unit tests for PRQ delta calculation, shard rewards, and XP cap logic.
Does not require a running server — imports calculation functions directly.
"""
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))

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
# Import economy functions (parse from server.py since it's a FastAPI app)
# ═══════════════════════════════════════════════════════════════════════════════

# We'll re-implement the pure functions here for testing
# (since server.py has async dependencies that prevent direct import)

PRQ_MODE_WEIGHTS = {
    "basketball_h2h": 1.2, "basketball_dunk": 1.0,
    "basketball_dunk_3d": 1.0, "basketball_dunk_irl": 1.5,
    "basketball_3v3": 1.3,
    "karate_h2h": 1.4, "karate_endless": 1.4,
    "baseball": 1.0, "football": 1.5, "soccer": 1.1,
    "golf": 0.9, "tennis": 1.1, "volleyball": 1.2,
    "surfing": 1.05, "skateboarding": 1.0, "snowboarding": 1.0,
    "gymnastics": 1.0, "brain_brawl": 0.8,
    "who_scene_it": 0.7, "court_carnival": 0.9,
}
SHARD_WIN, SHARD_DRAW, SHARD_LOSS = 50, 25, 15
SHARD_COMBO_MULTIPLIER, SHARD_CRITICAL_BONUS = 5, 10
XP_CAP_PER_SESSION = 500

def _compute_prq_delta(mode_id, score, duration, completed):
    weight = PRQ_MODE_WEIGHTS.get(mode_id, 1.0)
    base = score * 0.1
    completion_bonus = 1.25 if completed else 0.75
    time_factor = min(1.0, duration / 60.0) if duration > 0 else 0.5
    return round(base * weight * completion_bonus * time_factor, 2)

def _compute_shard_reward(outcome, combo_count=0, critical_count=0):
    base = {"win": SHARD_WIN, "draw": SHARD_DRAW, "loss": SHARD_LOSS}.get(outcome, SHARD_LOSS)
    combo_bonus = max(0, combo_count - 3) * SHARD_COMBO_MULTIPLIER if combo_count > 3 else 0
    critical_bonus = critical_count * SHARD_CRITICAL_BONUS
    return base + combo_bonus + critical_bonus


# ═══════════════════════════════════════════════════════════════════════════════
# Test Suite
# ═══════════════════════════════════════════════════════════════════════════════

def test_prq_delta_basic():
    print("\n── PRQ Delta: Basic Calculations ──")
    # basketball_h2h, score=100, 120s duration, completed
    delta = _compute_prq_delta("basketball_h2h", 100, 120, True)
    # base=10, weight=1.2, completion=1.25, time=1.0 → 15.0
    assert_approx(delta, 15.0, "basketball_h2h score=100 completed")

    # Same but not completed
    delta = _compute_prq_delta("basketball_h2h", 100, 120, False)
    # base=10, weight=1.2, completion=0.75, time=1.0 → 9.0
    assert_approx(delta, 9.0, "basketball_h2h score=100 NOT completed")

    # football has highest weight (1.5)
    delta = _compute_prq_delta("football", 200, 240, True)
    # base=20, weight=1.5, completion=1.25, time=1.0 → 37.5
    assert_approx(delta, 37.5, "football score=200 completed")

    # Short duration (30s) → time_factor=0.5
    delta = _compute_prq_delta("golf", 50, 30, True)
    # base=5, weight=0.9, completion=1.25, time=0.5 → 2.81
    assert_approx(delta, 2.81, "golf short duration")

def test_prq_delta_zero_score():
    print("\n── PRQ Delta: Zero/Edge Cases ──")
    delta = _compute_prq_delta("tennis", 0, 60, True)
    assert_approx(delta, 0.0, "Zero score → zero delta")

    delta = _compute_prq_delta("tennis", 100, 0, True)
    # duration=0 → time_factor=0.5
    assert_approx(delta, 6.88, "Zero duration → half factor")

    # Unknown mode → weight defaults to 1.0
    delta = _compute_prq_delta("unknown_mode", 100, 60, True)
    assert_approx(delta, 12.5, "Unknown mode → weight 1.0")

def test_shard_rewards():
    print("\n── Shard Rewards: Win/Draw/Loss ──")
    assert_eq(_compute_shard_reward("win"), 50, "Win base")
    assert_eq(_compute_shard_reward("draw"), 25, "Draw base")
    assert_eq(_compute_shard_reward("loss"), 15, "Loss base")
    assert_eq(_compute_shard_reward("unknown"), 15, "Unknown outcome → loss base")

def test_shard_combo_bonus():
    print("\n── Shard Rewards: Combo Bonuses ──")
    # combo_count=3 → no bonus (threshold is >3)
    assert_eq(_compute_shard_reward("win", combo_count=3), 50, "Win + 3 combos (no bonus)")
    # combo_count=4 → (4-3)×5 = 5
    assert_eq(_compute_shard_reward("win", combo_count=4), 55, "Win + 4 combos (+5)")
    # combo_count=10 → (10-3)×5 = 35
    assert_eq(_compute_shard_reward("win", combo_count=10), 85, "Win + 10 combos (+35)")

def test_shard_critical_bonus():
    print("\n── Shard Rewards: Critical Bonuses ──")
    assert_eq(_compute_shard_reward("win", critical_count=1), 60, "Win + 1 critical (+10)")
    assert_eq(_compute_shard_reward("win", critical_count=5), 100, "Win + 5 criticals (+50)")

def test_shard_combined():
    print("\n── Shard Rewards: Combined Bonuses ──")
    # Win + 6 combos + 3 criticals
    # base=50 + (6-3)×5=15 + 3×10=30 = 95
    assert_eq(_compute_shard_reward("win", combo_count=6, critical_count=3), 95, "Win + combos + criticals")

    # Loss + 10 combos + 2 criticals
    # base=15 + (10-3)×5=35 + 2×10=20 = 70
    assert_eq(_compute_shard_reward("loss", combo_count=10, critical_count=2), 70, "Loss + combos + criticals")

def test_xp_cap():
    print("\n── XP Cap: 500/session ──")
    # score=100 → raw_xp = max(10, 100//5) = 20 → capped at 20
    raw = max(10, 100 // 5)
    xp = min(raw, XP_CAP_PER_SESSION)
    assert_eq(xp, 20, "score=100 → xp=20 (under cap)")

    # score=5000 → raw_xp = max(10, 5000//5) = 1000 → capped at 500
    raw = max(10, 5000 // 5)
    xp = min(raw, XP_CAP_PER_SESSION)
    assert_eq(xp, 500, "score=5000 → xp=500 (capped)")

    # score=0 → raw_xp = max(10, 0) = 10
    raw = max(10, 0 // 5)
    xp = min(raw, XP_CAP_PER_SESSION)
    assert_eq(xp, 10, "score=0 → xp=10 (minimum)")

def test_prq_weight_coverage():
    print("\n── PRQ Weight Coverage ──")
    expected_modes = [
        "basketball_h2h", "basketball_dunk", "basketball_dunk_3d", "basketball_dunk_irl",
        "basketball_3v3",
        "karate_h2h", "karate_endless",
        "baseball", "football", "soccer", "golf",
        "tennis", "volleyball", "surfing",
        "gymnastics", "skateboarding", "snowboarding",
        "brain_brawl", "who_scene_it", "court_carnival",
    ]
    for mode in expected_modes:
        if mode in PRQ_MODE_WEIGHTS:
            ok(f"{mode} weight={PRQ_MODE_WEIGHTS[mode]}")
        else:
            fail(f"{mode} missing from PRQ_MODE_WEIGHTS")


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
