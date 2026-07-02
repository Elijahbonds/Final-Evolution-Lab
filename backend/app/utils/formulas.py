"""Pure economy and readiness formulas.

PRQ and shard math align with server.py v2.0 outcome-based economy (§6.1–6.2).
"""
from __future__ import annotations

import math

from app.utils.constants import (
    MRI_ARV_WEIGHT,
    MRI_ESI_WEIGHT,
    MRI_PACING_WEIGHT,
    PRQ_COMBO_BONUS_CAP,
    PRQ_COMBO_BONUS_RATE,
    PRQ_CRITICAL_BONUS_CAP,
    PRQ_CRITICAL_BONUS_RATE,
    PRQ_DELTA_CAP,
    PRQ_DOMINANCE_BONUS_CAP,
    PRQ_DOMINANCE_BONUS_RATE,
    PRQ_MODE_WEIGHTS,
    PRQ_MRI_BONUS_SCALE,
    PRQ_OUTCOME_BASE,
    SHARD_BASE_BY_OUTCOME,
    SHARD_COMBO_MULTIPLIER,
    SHARD_COMBO_THRESHOLD,
    SHARD_CRITICAL_BONUS,
    SHARD_PACING_BONUS_RATE,
    SHARD_PACING_THRESHOLD,
    XP_CAP_PER_SESSION,
    XP_MIN_PER_SESSION,
    XP_SCORE_DIVISOR,
)


def clamp(value: float, lower: float = 0.0, upper: float = 100.0) -> float:
    """Clamp a numeric score into a bounded range."""

    return max(lower, min(upper, value))


def calculate_xp(score: int) -> int:
    """XP: score / 5, min 10, cap 500."""

    raw = score // XP_SCORE_DIVISOR
    return min(XP_CAP_PER_SESSION, max(XP_MIN_PER_SESSION, raw))


def calculate_shards(
    *,
    outcome: str,
    combo_count: int,
    critical_count: int,
    pacing_score: float,
) -> int:
    """Shard reward from outcome, combo, criticals, and pacing quality (v2.0 §6.2)."""

    base = SHARD_BASE_BY_OUTCOME.get(outcome, SHARD_BASE_BY_OUTCOME["loss"])
    combo_bonus = (
        max(0, combo_count - SHARD_COMBO_THRESHOLD) * SHARD_COMBO_MULTIPLIER
        if combo_count > SHARD_COMBO_THRESHOLD
        else 0
    )
    critical_bonus = critical_count * SHARD_CRITICAL_BONUS
    subtotal = base + combo_bonus + critical_bonus
    pacing_bonus = (
        math.ceil(subtotal * SHARD_PACING_BONUS_RATE)
        if pacing_score >= SHARD_PACING_THRESHOLD
        else 0
    )
    return subtotal + pacing_bonus


def calculate_prq_delta(
    *,
    mode_id: str,
    score: int,
    outcome: str,
    combo_count: int = 0,
    critical_count: int = 0,
    mri_score: float = 50.0,
    completed: bool = True,
    duration_seconds: int = 0,
) -> float:
    """PRQ Δ per v2.0 Architecture §6.1 (outcome-based, not score-linear).

    ``completed`` and ``duration_seconds`` are accepted for receipt compatibility
    but do not affect the v2.0 delta (mirrors server.py ``_compute_prq_delta``).
    """

    _ = completed, duration_seconds
    weight = PRQ_MODE_WEIGHTS.get(mode_id, 1.0)
    prq_base = PRQ_OUTCOME_BASE.get(outcome, PRQ_OUTCOME_BASE["loss"])

    combo_bonus = min(PRQ_COMBO_BONUS_CAP, combo_count * PRQ_COMBO_BONUS_RATE)
    critical_bonus = min(PRQ_CRITICAL_BONUS_CAP, critical_count * PRQ_CRITICAL_BONUS_RATE)
    dominance_bonus = (
        min(PRQ_DOMINANCE_BONUS_CAP, score * PRQ_DOMINANCE_BONUS_RATE)
        if outcome == "win"
        else 0.0
    )
    mri_bonus = (clamp(mri_score) / 100.0) * PRQ_MRI_BONUS_SCALE

    delta = prq_base * weight + combo_bonus + critical_bonus + dominance_bonus + mri_bonus
    return round(min(PRQ_DELTA_CAP, delta), 2)


def calculate_mri(*, arv: float, esi: float, pacing: float) -> float:
    """MRI: 0.30*ARV + 0.45*ESI + 0.25*Pacing."""

    value = (
        clamp(arv) * MRI_ARV_WEIGHT
        + clamp(esi) * MRI_ESI_WEIGHT
        + clamp(pacing) * MRI_PACING_WEIGHT
    )
    return round(clamp(value), 2)


def grade_prq(score: float) -> str:
    """Grade a Physical Readiness Quotient score."""

    score = clamp(score)
    if score >= 80:
        return "ELITE"
    if score >= 60:
        return "PRIMED"
    if score >= 40:
        return "READY"
    return "RECOVERING"


def grade_mri(score: float) -> str:
    """Grade a Mental Resiliency Index score."""

    score = clamp(score)
    if score >= 85:
        return "UNBREAKABLE"
    if score >= 65:
        return "RESILIENT"
    if score >= 45:
        return "ADAPTING"
    return "VULNERABLE"
