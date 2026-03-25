#!/usr/bin/env python3
"""
StressTest_Fatigue — internal biomechanics QA for UFELSaveGame::GetJumpPerformanceTrend (1.0.0 spec).

Mirrors Unreal logic in:
  UnrealStarter/BasketballGame/UFELSaveGame.cpp — FEL_LastNJumpHeightSampleVariance + GetJumpPerformanceTrend

DA COMPOUND session model:
  - 5 max-effort baseline jumps (expanded to 10 prior-window samples for the 20-sample gate),
  - 10 fatigued jumps at 92% of baseline peak Z (8% reduction).

Run:  python3 scripts/StressTest_Fatigue.py
Exit: 0 if all assertions pass, 1 otherwise.
"""

from __future__ import annotations

import math
import sys
from enum import IntEnum
from typing import List


class EFELFatigueState(IntEnum):
    Unknown = 0
    Normal = 1
    Fatigued = 2
    Inconclusive = 3


def last_n_jump_height_sample_variance(h: List[float], n: int, end_exclusive: int) -> float:
    """Matches FEL_LastNJumpHeightSampleVariance (sample variance, n-1 denominator)."""
    if len(h) < n or end_exclusive < n or end_exclusive > len(h):
        return 0.0
    chunk = h[end_exclusive - n : end_exclusive]
    if len(chunk) < 2:
        return 0.0
    mean = sum(chunk) / float(n)
    var_acc = sum((x - mean) ** 2 for x in chunk)
    return var_acc / float(n - 1)


def get_jump_performance_trend(jump_heights: List[float]) -> EFELFatigueState:
    """Port of UFELSaveGame::GetJumpPerformanceTrend."""
    if len(jump_heights) < 20:
        return EFELFatigueState.Unknown

    h = jump_heights
    n = len(h)
    var_recent = last_n_jump_height_sample_variance(h, 10, n)
    # 1.0.0 spec in C++: variance (uu²/s²) of last 10 samples — not standard deviation.
    if var_recent > 15.0:
        return EFELFatigueState.Inconclusive

    sum_recent = sum(h[n - 10 + i] for i in range(10))
    sum_prior = sum(h[n - 20 + i] for i in range(10))
    avg_recent = sum_recent / 10.0
    avg_prior = sum_prior / 10.0
    if avg_prior <= 1.0e-4:
        return EFELFatigueState.Unknown
    if avg_recent < avg_prior * 0.95:
        return EFELFatigueState.Fatigued
    return EFELFatigueState.Normal


def build_da_compound_session(baseline_peak_z: float = 500.0) -> List[float]:
    """
    5 max-effort + 10 fatigued => 15 jumps; pad prior window to 10 samples using the 5 baselines (duplicated)
    so PerformanceHistory has 20 entries and matches the fatigue UX gate.

    Indices 0..9  : baseline (max effort)
    Indices 10..19: fatigued (-8% Z)
    """
    fatigued = baseline_peak_z * 0.92
    # Ten prior-window values: repeat 5 max-effort twice to fill 10 slots (DA compound block).
    prior_ten = [baseline_peak_z] * 10
    fatigued_ten = [fatigued] * 10
    return prior_ten + fatigued_ten


def build_high_variance_last_ten() -> List[float]:
    """Last 10 have sample variance > 15 => Inconclusive per 1.0.0 spec."""
    prior_ten = [100.0] * 10
    # Spread 0..200 around mean 100 => high sample variance
    chaotic = [0.0, 50.0, 100.0, 150.0, 200.0, 25.0, 175.0, 80.0, 120.0, 190.0]
    return prior_ten + chaotic


def main() -> int:
    ok = True

    # 1) Fatigued path
    hist = build_da_compound_session(500.0)
    assert len(hist) == 20
    trend = get_jump_performance_trend(hist)
    if trend != EFELFatigueState.Fatigued:
        print(f"FAIL [DA COMPOUND]: expected Fatigued, got {trend.name}")
        ok = False
    else:
        print("PASS [DA COMPOUND]: GetJumpPerformanceTrend => Fatigued (10 prior max-effort vs 10 fatigued @ -8%)")

    v_last10 = last_n_jump_height_sample_variance(hist, 10, len(hist))
    print(f"      last-10 sample variance = {v_last10:.4f} (gate <= 15 for fatigue UX)")

    # 2) Inconclusive path (variance > 15 on last 10)
    hist_inc = build_high_variance_last_ten()
    trend_inc = get_jump_performance_trend(hist_inc)
    var_inc = last_n_jump_height_sample_variance(hist_inc, 10, len(hist_inc))
    if var_inc <= 15.0:
        print(f"WARN: synthetic inconclusive variance {var_inc:.4f} — adjust chaotic spread if needed")
    if trend_inc != EFELFatigueState.Inconclusive:
        print(f"FAIL [INCONCLUSIVE]: expected Inconclusive, got {trend_inc.name} (var_last10={var_inc:.4f})")
        ok = False
    else:
        print(f"PASS [INCONCLUSIVE]: variance {var_inc:.4f} > 15 => {trend_inc.name}")

    # 3) Unknown path (< 20 samples)
    if get_jump_performance_trend([100.0] * 15) != EFELFatigueState.Unknown:
        print("FAIL [UNKNOWN]: short history should be Unknown")
        ok = False
    else:
        print("PASS [UNKNOWN]: history length < 20 => Unknown")

    if ok:
        print("\nStressTest_Fatigue: ALL CHECKS PASSED")
        return 0
    print("\nStressTest_Fatigue: ONE OR MORE CHECKS FAILED")
    return 1


if __name__ == "__main__":
    sys.exit(main())
