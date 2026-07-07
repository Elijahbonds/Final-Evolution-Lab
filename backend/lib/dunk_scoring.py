"""
dunk_scoring.py — Server-side dunk contest scoring (deterministic, seeded).
Mirrors the math in FinalEvolutionLab/Models/DunkContestEngine.swift.
"""
from __future__ import annotations
import random
from dataclasses import dataclass
from typing import List

@dataclass
class DunkResult:
    j1: int
    j2: int
    j3: int
    total: int
    message: str
    is_perfect: bool

def score_dunk(
    approach_quality: float,   # 0.0–1.0
    execution_quality: float,  # 0.0–1.0
    style_difficulty: float,   # 0.0–1.0
    judge_offsets: List[int],  # list of 3 small ints from match seed
) -> DunkResult:
    """Compute dunk result deterministically from inputs + judge_offsets."""
    if len(judge_offsets) < 3:
        judge_offsets = (list(judge_offsets) + [0, 0, 0])[:3]

    # Base score 0-50
    base = (approach_quality * 0.40 + execution_quality * 0.60) * 50.0 * (0.7 + style_difficulty * 0.3)
    base = max(0.0, min(50.0, base))

    # Per-judge score (0-10) with offset, clamped to [3, 10]
    scores = []
    for offset in judge_offsets[:3]:
        raw = (base / 50.0) * 10.0 + offset
        scores.append(max(3, min(10, round(raw))))

    total = sum(scores)
    is_perfect = total >= 28 and all(s >= 9 for s in scores)

    if total >= 28:
        message = "PERFECT SCORE" if is_perfect else "OUTSTANDING"
    elif total >= 24:
        message = "OUTSTANDING"
    elif total >= 18:
        message = "SOLID DUNK"
    else:
        message = "NEEDS WORK"

    return DunkResult(j1=scores[0], j2=scores[1], j3=scores[2],
                     total=total, message=message, is_perfect=is_perfect)
