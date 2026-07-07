"""
dunk_scoring.py — Server-side dunk contest scoring (deterministic, seeded).

Two scoring paths, both pure functions of their inputs:

  score_dunk(...)          — legacy simplified model (approach/execution/style),
                             kept for the sim harness and existing tests.
  score_engine3d_dunk(...) — faithful port of the Swift production path:
                             DunkContestScoring.calculate
                               -> WDAScoringEngine.adaptEngine3D
                               -> WDAScoringEngine.scoreDunk
                             (FinalEvolutionLab/Models/DunkContestEngine.swift +
                              FinalEvolutionLab/Services/WDAScoringEngine.swift),
                             with the match's seeded judge_offsets applied to the
                             three-judge panel (execution / style / attempt).
"""
from __future__ import annotations
import math
from dataclasses import dataclass
from typing import List, Optional, Sequence

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


# ═══════════════════════════════════════════════════════════════════════════
# WDA/FIBA engine-3D port (Swift parity)
# ═══════════════════════════════════════════════════════════════════════════

FIBA_TIME_LIMIT_SECONDS = 75.0

# DunkTrickComplexity: (base_difficulty_score, minimum_required_height_inches)
# Mirrors WDAScoringEngine.swift DunkTrickComplexity.
TRICK_TABLE = {
    "rim_grazer":       (12.0, 20.0),
    "double_clutch":    (16.0, 24.0),
    "windmill":         (20.0, 28.0),
    "honey_dip":        (22.0, 30.0),
    "three_sixty":      (24.0, 32.0),
    "free_throw_line":  (26.0, 28.0),
    "behind_the_back":  (28.0, 34.0),
    "between_the_legs": (29.0, 36.0),
    "seven_twenty":     (30.0, 40.0),
}

# Panel bounds per WDA rubric: j1 execution 10-30, j2 style 1-10, j3 attempt 1-10.
_J1_BOUNDS = (10, 30)
_J2_BOUNDS = (1, 10)
_J3_BOUNDS = (1, 10)


def _round_half_away(x: float) -> int:
    """Swift's .toNearestOrAwayFromZero (Python round() is banker's rounding)."""
    return int(math.floor(x + 0.5)) if x >= 0 else int(math.ceil(x - 0.5))


def _clamp(x, lo, hi):
    return max(lo, min(hi, x))


@dataclass
class DunkEngine3DInput:
    """Mirrors Swift DunkEngine3DScoringInput (scalar, deterministic)."""
    jump_height: float                 # 0.0-1.0 (normalized)
    launch_quality: float              # 0.0-1.0
    landing_quality: float             # 0.0-1.0
    completed_rotation: float          # 0.0-1.0
    trick: str = "rim_grazer"          # key into TRICK_TABLE
    ball_rotation_degrees: Optional[float] = None
    flight_hang_time_seconds: Optional[float] = None
    attempts_count: int = 1
    time_spent_seconds: float = 0.0
    freestyle_points: int = 0
    mid_air_branch_count: int = 0
    style_landing_success: bool = False
    modifier_score_multiplier: float = 1.0
    knee_valgus_detected: bool = False
    ankle_pronation_detected: bool = False
    signature_difficulty_bonus: Optional[float] = None


def score_engine3d_dunk(inp: DunkEngine3DInput, judge_offsets: Sequence[int]) -> DunkResult:
    """
    Deterministic pure function: same input + same judge_offsets -> same result.

    Port of WDAScoringEngine.adaptEngine3D + WDAScoringEngine.scoreDunk with the
    seeded per-match judge_offsets applied to the three-judge panel, each judge
    clamped to its rubric bounds.
    """
    if inp.trick not in TRICK_TABLE:
        raise ValueError(f"Unknown trick '{inp.trick}'. Valid: {sorted(TRICK_TABLE)}")
    base_difficulty, min_height = TRICK_TABLE[inp.trick]

    offs = list(judge_offsets)[:3]
    offs += [0] * (3 - len(offs))

    # ── adaptEngine3D ──────────────────────────────────────────────────────
    jump_height_inches = inp.jump_height * 42.0 + min_height * 0.12
    takeoff_velocity_fps = 10.0 + inp.jump_height * 14.0 + inp.launch_quality * 4.0
    hang_time = (inp.flight_hang_time_seconds
                 if inp.flight_hang_time_seconds is not None
                 else 0.45 + inp.jump_height * 0.85 + inp.completed_rotation * 0.25)
    rotation_degrees = (inp.ball_rotation_degrees
                        if inp.ball_rotation_degrees is not None
                        else inp.completed_rotation * 360.0)
    freestyle_norm = min(10.0, 5.0 + min(inp.freestyle_points, 30) / 6.0)
    chain_bonus = min(2.0, inp.mid_air_branch_count * 0.5)
    modifier_bonus = max(0.0, (inp.modifier_score_multiplier - 1.0) * 4.0)
    fluid_motion = _clamp(inp.launch_quality * 9.0 + modifier_bonus + chain_bonus * 0.5, 1.0, 10.0)
    landing_control = _clamp(inp.landing_quality * 10.0, 1.0, 10.0)
    aesthetic = _clamp(freestyle_norm + chain_bonus + (1.5 if inp.style_landing_success else 0.0), 1.0, 10.0)

    # ── scoreDunk ──────────────────────────────────────────────────────────
    # 1. FIBA 75s time limit
    if inp.time_spent_seconds > FIBA_TIME_LIMIT_SECONDS:
        over = inp.time_spent_seconds - FIBA_TIME_LIMIT_SECONDS
        time_penalty = min(10.0, 3.0 + over * 0.25)
    else:
        time_penalty = 0.0

    # 2. Execution & difficulty (10-30)
    raw_execution = base_difficulty
    if inp.signature_difficulty_bonus is not None:
        raw_execution += inp.signature_difficulty_bonus
    if jump_height_inches >= min_height:
        raw_execution += min(3.0, (jump_height_inches - min_height) * 0.15)
    else:
        raw_execution -= min(4.0, (min_height - jump_height_inches) * 0.2)
    if takeoff_velocity_fps > 12.0:
        raw_execution += min(1.0, (takeoff_velocity_fps - 12.0) * 0.1)
    if hang_time > 0.8:
        raw_execution += min(1.5, (hang_time - 0.8) * 3.0)
    if rotation_degrees >= 360:
        raw_execution += 1.5
    elif rotation_degrees >= 180:
        raw_execution += 0.75
    execution_score = _clamp(raw_execution, 10.0, 30.0)

    # 3. Artistic expression & style (1-10)
    raw_artistic = _clamp((fluid_motion + landing_control + aesthetic) / 3.0, 1.0, 10.0)
    if inp.knee_valgus_detected:
        raw_artistic -= 1.5
    if inp.ankle_pronation_detected:
        raw_artistic -= 1.0
    artistic_score = _clamp(raw_artistic, 1.0, 10.0)

    # 4. First-try success (1-10)
    first_try_score = {1: 10.0, 2: 7.0, 3: 4.0}.get(inp.attempts_count, 1.0)

    # 5. Seeded judge panel: rubric panel + per-judge offset, clamped to bounds
    j1 = _clamp(_round_half_away(execution_score) + offs[0], *_J1_BOUNDS)
    j2 = _clamp(_round_half_away(artistic_score) + offs[1], *_J2_BOUNDS)
    j3 = _clamp(_round_half_away(first_try_score) + offs[2], *_J3_BOUNDS)
    total = int(_clamp(j1 + j2 + j3 - _round_half_away(time_penalty), 0, 50))

    # wdaCrowdMessage thresholds (WDAScoringEngine.swift)
    if total >= 45:
        message = "PERFECT DUNK!"
    elif total >= 42:
        message = "LEGENDARY!"
    elif total >= 40:
        message = "CROWD GOES WILD!"
    elif total >= 38:
        message = "ELECTRIFYING!"
    elif total >= 35:
        message = "POWERFUL!"
    elif total >= 30:
        message = "SOLID DUNK"
    else:
        message = "NEEDS WORK"

    return DunkResult(j1=j1, j2=j2, j3=j3, total=total,
                      message=message, is_perfect=total >= 45)
