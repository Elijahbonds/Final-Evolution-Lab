"""Phase 1 economy checkpoint tests."""
from __future__ import annotations

from app.schemas.session_receipt import SessionReceiptIn
from app.services.economy_engine import economy_engine
from app.utils.formulas import calculate_mri, calculate_prq_delta, calculate_shards, grade_mri, grade_prq


def test_phase1_basketball_h2h_checkpoint() -> None:
    receipt = SessionReceiptIn(
        mode_id="basketball_h2h",
        score=3,
        outcome="win",
        combo_count=5,
        critical_count=2,
        pacing_score=80,
        duration_seconds=60,
        completed=True,
        arv=50,
        esi=50,
    )

    result = economy_engine.compute_session(receipt)

    assert result.xp == 10
    assert result.shards == 84
    assert result.prq_delta == 3.29
    assert result.pacing_bonus_applied is True


def test_xp_caps_at_500() -> None:
    receipt = SessionReceiptIn(score=10_000, outcome="win", duration_seconds=60)

    assert economy_engine.compute_session(receipt).xp == 500


def test_prq_v2_outcome_bonuses() -> None:
    """PRQ delta follows v2.0 outcome base + capped bonuses."""

    mri = calculate_mri(arv=50, esi=50, pacing=80)
    delta = calculate_prq_delta(
        mode_id="basketball_h2h",
        score=3,
        outcome="win",
        combo_count=5,
        critical_count=2,
        mri_score=mri,
    )
    assert delta == 3.29


def test_shard_pacing_uses_ceil_bonus() -> None:
    # win + combo 6 + 2 crits → subtotal 85; pacing adds ceil(85 * 0.05) = 5
    with_pacing = calculate_shards(outcome="win", combo_count=6, critical_count=2, pacing_score=80)
    without = calculate_shards(outcome="win", combo_count=6, critical_count=2, pacing_score=50)
    assert with_pacing == 90
    assert without == 85


def test_mri_formula_and_grades() -> None:
    assert calculate_mri(arv=80, esi=90, pacing=70) == 82.0
    assert grade_mri(90) == "UNBREAKABLE"
    assert grade_mri(70) == "RESILIENT"
    assert grade_mri(50) == "ADAPTING"
    assert grade_mri(30) == "VULNERABLE"
    assert grade_prq(85) == "ELITE"
    assert grade_prq(65) == "PRIMED"
    assert grade_prq(45) == "READY"
    assert grade_prq(20) == "RECOVERING"
