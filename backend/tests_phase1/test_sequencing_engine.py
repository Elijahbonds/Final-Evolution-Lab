"""Pure-math coverage for the adaptive sequencing engine (no DB required)."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.sequencer.catalog import DEFAULT_CATALOG, PRQ_ATTRIBUTES, catalog_by_lesson_id
from app.sequencer.engine import QueueItem, SequencerConfig, SequencingEngine
from app.sequencer.mastery import (
    MasteryConfig,
    MasterySnapshot,
    apply_session,
    decayed_strength,
    review_interval_days,
)

NOW = datetime(2026, 7, 13, 12, 0, 0, tzinfo=timezone.utc)
NEUTRAL_PRQ = {attr: 50.0 for attr in PRQ_ATTRIBUTES}


def make_engine(**config_overrides) -> SequencingEngine:
    return SequencingEngine(config=SequencerConfig(**config_overrides))


# ---------------------------------------------------------------- mastery math


def test_decay_reduces_strength_monotonically() -> None:
    strengths = [
        decayed_strength(0.9, 0.07, NOW - timedelta(days=days), NOW) for days in (0, 1, 7, 30)
    ]
    assert strengths[0] == 0.9
    assert strengths == sorted(strengths, reverse=True)
    assert strengths[-1] < 0.15


def test_decay_handles_naive_datetimes_from_sqlite() -> None:
    naive_last_seen = (NOW - timedelta(days=7)).replace(tzinfo=None)
    aware = decayed_strength(0.9, 0.07, NOW - timedelta(days=7), NOW)
    naive = decayed_strength(0.9, 0.07, naive_last_seen, NOW)
    assert abs(aware - naive) < 1e-12


def test_passing_session_reinforces_and_extends_interval() -> None:
    before = MasterySnapshot(skill_id="jump_mechanics", strength=0.4, reps=2,
                             last_seen=NOW - timedelta(days=1), next_due=NOW)
    after = apply_session(before, quality=0.9, now=NOW)

    assert after.strength > decayed_strength(0.4, before.decay_rate, before.last_seen, NOW)
    assert after.reps == 3
    assert after.last_seen == NOW
    assert after.next_due is not None and after.next_due > NOW + timedelta(days=MasteryConfig().min_interval_days)


def test_failing_session_erodes_and_resurfaces_at_min_interval() -> None:
    before = MasterySnapshot(skill_id="jump_mechanics", strength=0.8, reps=5,
                             last_seen=NOW - timedelta(hours=1), next_due=NOW + timedelta(days=10))
    after = apply_session(before, quality=0.1, now=NOW)

    assert after.strength < 0.8
    assert after.next_due == NOW + timedelta(days=MasteryConfig().min_interval_days)


def test_failed_first_rep_still_registers_exposure() -> None:
    after = apply_session(MasterySnapshot(skill_id="new_skill"), quality=0.3, now=NOW)
    assert 0 < after.strength <= MasteryConfig().exposure_floor
    assert after.reps == 1


def test_higher_quality_yields_higher_strength_and_later_due() -> None:
    base = MasterySnapshot(skill_id="s", strength=0.5, last_seen=NOW - timedelta(days=2), next_due=NOW)
    mid = apply_session(base, quality=0.7, now=NOW)
    high = apply_session(base, quality=1.0, now=NOW)
    assert high.strength > mid.strength
    assert high.next_due is not None and mid.next_due is not None
    assert high.next_due > mid.next_due


def test_review_interval_is_bounded() -> None:
    cfg = MasteryConfig()
    assert review_interval_days(0.0, 1.0, cfg) == cfg.min_interval_days
    assert review_interval_days(1.0, 1.0, cfg) == cfg.max_interval_days
    assert review_interval_days(1.0, 0.0, cfg) == cfg.min_interval_days


def test_apply_session_is_deterministic() -> None:
    base = MasterySnapshot(skill_id="s", strength=0.5, last_seen=NOW - timedelta(days=3), next_due=NOW)
    assert apply_session(base, 0.8, NOW) == apply_session(base, 0.8, NOW)


# ------------------------------------------------------------ priority scoring


def test_weakness_targeting_prioritizes_weak_attribute() -> None:
    engine = make_engine()
    prq = dict(NEUTRAL_PRQ, vertical_power=20.0, stamina=95.0)
    queue = engine.build_queue(prq=prq, mastery={}, readiness=70.0, now=NOW, limit=len(DEFAULT_CATALOG))

    vertical = next(i for i in queue if i.lesson_id == "drill_box_jump_ladder")
    stamina = next(i for i in queue if i.lesson_id == "drill_tempo_run")
    assert vertical.weakness_score > stamina.weakness_score
    assert queue.index(vertical) < queue.index(stamina)
    assert queue[0].skill_id in ("jump_mechanics", "eccentric_landing")


def test_due_for_review_outranks_recently_cleared() -> None:
    engine = make_engine()
    mastery = {
        "jump_mechanics": MasterySnapshot(
            skill_id="jump_mechanics", strength=0.7, reps=4,
            last_seen=NOW - timedelta(days=20), next_due=NOW - timedelta(days=6),  # overdue
        ),
        "aerobic_pacing": MasterySnapshot(
            skill_id="aerobic_pacing", strength=0.7, reps=4,
            last_seen=NOW - timedelta(hours=2), next_due=NOW + timedelta(days=12),  # fresh
        ),
    }
    queue = engine.build_queue(prq=NEUTRAL_PRQ, mastery=mastery, readiness=50.0, now=NOW,
                               limit=len(DEFAULT_CATALOG))
    overdue = next(i for i in queue if i.lesson_id == "drill_box_jump_ladder")
    fresh = next(i for i in queue if i.lesson_id == "drill_tempo_run")
    assert overdue.due_score > 0.8
    assert fresh.due_score < 0.2
    assert queue.index(overdue) < queue.index(fresh)


def test_never_seen_skill_gets_novelty_prior() -> None:
    engine = make_engine()
    assert engine.due_score(None, NOW) == SequencerConfig().novelty_prior


def test_readiness_gating_demotes_high_load_when_fatigued() -> None:
    engine = make_engine()
    queue = engine.build_queue(prq=NEUTRAL_PRQ, mastery={}, readiness=25.0, now=NOW,
                               limit=len(DEFAULT_CATALOG))
    assert queue[0].load != "high"
    assert queue[0].kind in ("cognitive", "technique")
    # Every high-load drill got the fatigue penalty; low-impact work got boosted.
    for item in queue:
        if item.load == "high":
            assert item.readiness_multiplier < 1.0
        if item.kind in ("cognitive", "technique") and item.load == "low":
            assert item.readiness_multiplier > 1.0


def test_fresh_readiness_boosts_high_load() -> None:
    engine = make_engine()
    queue = engine.build_queue(prq=NEUTRAL_PRQ, mastery={}, readiness=90.0, now=NOW,
                               limit=len(DEFAULT_CATALOG))
    for item in queue:
        expected = SequencerConfig().fresh_high_load_boost if item.load == "high" else 1.0
        assert item.readiness_multiplier == expected


def test_queue_is_sorted_limited_and_deterministic() -> None:
    engine = make_engine()
    first = engine.build_queue(prq=NEUTRAL_PRQ, mastery={}, readiness=70.0, now=NOW, limit=5)
    second = engine.build_queue(prq=NEUTRAL_PRQ, mastery={}, readiness=70.0, now=NOW, limit=5)

    assert len(first) == 5
    assert first == second
    priorities = [item.priority for item in first]
    assert priorities == sorted(priorities, reverse=True)
    assert all(isinstance(item, QueueItem) for item in first)


def test_queue_items_serialize_to_json_payloads() -> None:
    engine = make_engine()
    item = engine.build_queue(prq=NEUTRAL_PRQ, mastery={}, readiness=70.0, now=NOW, limit=1)[0]
    payload = item.as_dict()
    assert payload["lesson_id"] == item.lesson_id
    assert isinstance(payload["reasons"], list) and payload["reasons"]


def test_catalog_ids_are_unique_and_targets_valid() -> None:
    by_id = catalog_by_lesson_id()
    assert len(by_id) == len(DEFAULT_CATALOG)
    for lesson in DEFAULT_CATALOG:
        assert lesson.targets, lesson.lesson_id
        assert all(attr in PRQ_ATTRIBUTES for attr in lesson.targets)
        assert lesson.kind in ("physical", "technique", "cognitive")
        assert lesson.load in ("high", "moderate", "low")
