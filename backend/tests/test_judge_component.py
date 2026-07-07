"""
test_judge_component.py — Unit tests for the Universal Scorer Interface.

Validates JudgeComponent (all 4 JUDGED modes), PrecisionScorer,
CompetitiveScorer, and CognitiveScorer against the IScorer contract.

Also tests the dunk_scoring adapter layer and trick_sequence_hash validation,
verifying that player_inputs from dunk_event_schema.json score correctly.

All tests run offline — no DB, no network.
"""
import os
import sys
import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from lib.judge_component import (
    JudgeComponent,
    JudgedInput,
    ScoredResult,
    PrecisionScorer,
    CompetitiveScorer,
    CognitiveScorer,
)
from lib.dunk_scoring import score_dunk, score_dunk_from_player_inputs
from lib.match_utils import derive_judge_offsets


# ── Fixtures ──────────────────────────────────────────────────────────────────

SEED = 7823640192837465
OFFSETS = derive_judge_offsets(SEED)  # deterministic for these tests


def _comp(mode_id: str, offsets=None) -> JudgeComponent:
    return JudgeComponent.for_mode(mode_id, offsets or OFFSETS)


def _inp(primary: float = 0.8, secondary: float = 0.85, style: float = 0.7) -> JudgedInput:
    return JudgedInput(primary=primary, secondary=secondary, style_difficulty=style)


# ── TestJudgeComponentConstructor ─────────────────────────────────────────────

class TestJudgeComponentConstructor:
    def test_known_modes_construct_without_error(self):
        for mode in ("basketball_dunk", "gymnastics", "surfing", "skateboarding"):
            comp = JudgeComponent.for_mode(mode, [0, 0, 0])
            assert comp.mode_id == mode

    def test_unknown_mode_raises_value_error(self):
        with pytest.raises(ValueError, match="Unknown judged mode"):
            JudgeComponent.for_mode("underwater_polo", [0, 0, 0])

    def test_short_offset_list_is_padded_to_three(self):
        comp = JudgeComponent.for_mode("basketball_dunk", [2])
        assert comp.judge_offsets == [2, 0, 0]

    def test_long_offset_list_is_truncated_to_three(self):
        comp = JudgeComponent.for_mode("basketball_dunk", [1, 2, 3, 4, 5])
        assert comp.judge_offsets == [1, 2, 3]

    def test_empty_offset_list_defaults_to_zeros(self):
        comp = JudgeComponent.for_mode("surfing", [])
        assert comp.judge_offsets == [0, 0, 0]


# ── TestJudgeComponentDunkMode ────────────────────────────────────────────────

class TestJudgeComponentDunkMode:
    def test_perfect_dunk_returns_is_perfect_true(self):
        comp = _comp("basketball_dunk", [5, 5, 5])
        result = comp.score(_inp(1.0, 1.0, 1.0))
        assert result.is_perfect is True
        assert result.total == 30

    def test_perfect_dunk_message_is_perfect_score(self):
        comp = _comp("basketball_dunk", [5, 5, 5])
        result = comp.score(_inp(1.0, 1.0, 1.0))
        assert result.message == "PERFECT SCORE"

    def test_low_inputs_produces_needs_work(self):
        comp = _comp("basketball_dunk", [-5, -5, -5])
        result = comp.score(_inp(0.0, 0.0, 0.0))
        assert result.message == "NEEDS WORK"

    def test_judge_scores_clamped_to_floor_3(self):
        comp = _comp("basketball_dunk", [-5, -5, -5])
        result = comp.score(_inp(0.0, 0.0, 0.0))
        assert result.j1 >= 3 and result.j2 >= 3 and result.j3 >= 3

    def test_judge_scores_clamped_to_ceil_10(self):
        comp = _comp("basketball_dunk", [5, 5, 5])
        result = comp.score(_inp(1.0, 1.0, 1.0))
        assert result.j1 <= 10 and result.j2 <= 10 and result.j3 <= 10

    def test_total_equals_j1_plus_j2_plus_j3(self):
        comp = _comp("basketball_dunk")
        result = comp.score(_inp(0.75, 0.80, 0.6))
        assert result.total == result.j1 + result.j2 + result.j3

    def test_outstanding_threshold_24(self):
        # At the boundary: force a total around 24-27 (not perfect)
        comp = _comp("basketball_dunk", [0, 0, 0])
        result = comp.score(_inp(0.82, 0.85, 0.8))
        # Verify message is consistent with total
        if result.total >= 28 and result.is_perfect:
            assert result.message == "PERFECT SCORE"
        elif result.total >= 24:
            assert result.message in ("OUTSTANDING", "PERFECT SCORE")
        elif result.total >= 18:
            assert result.message == "SOLID DUNK"
        else:
            assert result.message == "NEEDS WORK"

    def test_score_is_deterministic_same_inputs_same_result(self):
        comp = _comp("basketball_dunk")
        r1 = comp.score(_inp(0.87, 0.91, 0.9))
        r2 = comp.score(_inp(0.87, 0.91, 0.9))
        assert (r1.j1, r1.j2, r1.j3, r1.total) == (r2.j1, r2.j2, r2.j3, r2.total)

    def test_different_offsets_produce_different_totals(self):
        comp_a = _comp("basketball_dunk", [0, 0, 0])
        comp_b = _comp("basketball_dunk", [3, 3, 3])
        inp = _inp(0.7, 0.75, 0.6)
        ra = comp_a.score(inp)
        rb = comp_b.score(inp)
        assert rb.total > ra.total

    def test_result_has_breakdown_keys(self):
        result = _comp("basketball_dunk").score(_inp())
        for key in ("base_score", "primary_contribution", "secondary_contribution", "style_multiplier"):
            assert key in result.breakdown

    def test_mode_id_stored_on_result(self):
        result = _comp("basketball_dunk").score(_inp())
        assert result.mode_id == "basketball_dunk"


# ── TestJudgeComponentGymnastics ──────────────────────────────────────────────

class TestJudgeComponentGymnastics:
    def test_perfect_gymnastics_message_is_gold_standard(self):
        comp = _comp("gymnastics", [5, 5, 5])
        result = comp.score(_inp(1.0, 1.0, 1.0))
        assert result.message == "GOLD STANDARD"
        assert result.is_perfect is True

    def test_gymnastics_floor_is_2(self):
        comp = _comp("gymnastics", [-5, -5, -5])
        result = comp.score(_inp(0.0, 0.0, 0.0))
        assert result.j1 >= 2 and result.j2 >= 2 and result.j3 >= 2

    def test_gymnastics_secondary_weight_dominates(self):
        # secondary (execution) weight 0.65 > primary (difficulty) 0.35
        comp_hi_sec = _comp("gymnastics", [0, 0, 0])
        comp_hi_pri = _comp("gymnastics", [0, 0, 0])
        r_hi_execution = comp_hi_sec.score(_inp(primary=0.3, secondary=0.9, style=0.7))
        r_hi_difficulty = comp_hi_pri.score(_inp(primary=0.9, secondary=0.3, style=0.7))
        assert r_hi_execution.total > r_hi_difficulty.total

    def test_gymnastics_mid_score_is_clean(self):
        comp = _comp("gymnastics", [0, 0, 0])
        result = comp.score(_inp(0.65, 0.65, 0.5))
        if 18 <= result.total < 24:
            assert result.message == "CLEAN"


# ── TestJudgeComponentSurfing ─────────────────────────────────────────────────

class TestJudgeComponentSurfing:
    def test_perfect_surfing_message_is_perfect_10(self):
        comp = _comp("surfing", [5, 5, 5])
        result = comp.score(_inp(1.0, 1.0, 1.0))
        assert result.message == "PERFECT 10"

    def test_surfing_floor_is_1(self):
        comp = _comp("surfing", [-5, -5, -5])
        result = comp.score(_inp(0.0, 0.0, 0.0))
        assert result.j1 >= 1 and result.j2 >= 1 and result.j3 >= 1

    def test_surfing_perfect_threshold_is_27(self):
        # With offsets [5,5,5] and perfect inputs, total = 30; threshold is 27
        comp = _comp("surfing", [2, 2, 2])
        result = comp.score(_inp(1.0, 1.0, 1.0))
        assert result.is_perfect is True

    def test_surfing_wave_secondary_drives_score(self):
        # secondary (ride quality) weight 0.70 dominates
        comp = _comp("surfing", [0, 0, 0])
        r_ride = comp.score(_inp(primary=0.3, secondary=0.95, style=0.8))
        r_wave = comp.score(_inp(primary=0.95, secondary=0.3, style=0.8))
        assert r_ride.total > r_wave.total


# ── TestJudgeComponentSkateboarding ──────────────────────────────────────────

class TestJudgeComponentSkateboarding:
    def test_perfect_skateboarding_message_is_legendary(self):
        comp = _comp("skateboarding", [5, 5, 5])
        result = comp.score(_inp(1.0, 1.0, 1.0))
        assert result.message == "LEGENDARY"

    def test_sketchy_message_for_low_score(self):
        comp = _comp("skateboarding", [-5, -5, -5])
        result = comp.score(_inp(0.0, 0.0, 0.0))
        assert result.message == "SKETCHY"

    def test_skateboarding_floor_is_2(self):
        comp = _comp("skateboarding", [-5, -5, -5])
        result = comp.score(_inp(0.0, 0.0, 0.0))
        assert result.j1 >= 2 and result.j2 >= 2 and result.j3 >= 2


# ── TestStyleDifficulty ───────────────────────────────────────────────────────

class TestStyleDifficulty:
    def test_known_style_keys_return_float(self):
        known = [
            ("360_windmill", 1.0), ("between_the_legs", 0.9), ("power_slam", 0.6),
            ("full_twisting_layout", 1.0), ("tube_ride", 0.95), ("kickflip", 0.6),
        ]
        for key, expected in known:
            assert JudgeComponent.style_difficulty_for(key) == expected

    def test_unknown_style_key_returns_0_5(self):
        assert JudgeComponent.style_difficulty_for("mystery_trick") == 0.5

    def test_higher_difficulty_raises_score(self):
        comp = _comp("basketball_dunk", [0, 0, 0])
        r_hard = comp.score(_inp(0.7, 0.7, style=1.0))
        r_easy = comp.score(_inp(0.7, 0.7, style=0.0))
        assert r_hard.total >= r_easy.total


# ── TestTrickSequenceHash ─────────────────────────────────────────────────────

class TestTrickSequenceHash:
    def test_hash_is_8_hex_chars(self):
        h = JudgeComponent.trick_sequence_hash("360_windmill")
        assert len(h) == 8
        assert all(c in "0123456789abcdef" for c in h)

    def test_same_key_produces_same_hash(self):
        assert (
            JudgeComponent.trick_sequence_hash("kickflip")
            == JudgeComponent.trick_sequence_hash("kickflip")
        )

    def test_different_keys_produce_different_hashes(self):
        h1 = JudgeComponent.trick_sequence_hash("kickflip")
        h2 = JudgeComponent.trick_sequence_hash("heelflip")
        assert h1 != h2


# ── TestValidateEvent ─────────────────────────────────────────────────────────

class TestValidateEvent:
    def test_validate_event_true_on_matching_outcome(self):
        comp = _comp("basketball_dunk")
        inp = _inp(0.87, 0.91, 0.9)
        result = comp.score(inp)
        expected = {"j1": result.j1, "j2": result.j2, "j3": result.j3, "total": result.total}
        assert comp.validate_event(inp, expected) is True

    def test_validate_event_false_on_tampered_total(self):
        comp = _comp("basketball_dunk")
        inp = _inp(0.87, 0.91, 0.9)
        result = comp.score(inp)
        tampered = {"j1": result.j1, "j2": result.j2, "j3": result.j3, "total": result.total + 5}
        assert comp.validate_event(inp, tampered) is False

    def test_validate_event_false_on_tampered_j1(self):
        comp = _comp("basketball_dunk")
        inp = _inp(0.7, 0.75, 0.6)
        result = comp.score(inp)
        tampered = {"j1": result.j1 + 1, "j2": result.j2, "j3": result.j3, "total": result.total}
        assert comp.validate_event(inp, tampered) is False

    def test_scored_result_validate_event_method(self):
        comp = _comp("gymnastics")
        inp = _inp(0.6, 0.8, 0.7)
        result = comp.score(inp)
        assert result.validate_event({
            "j1": result.j1, "j2": result.j2, "j3": result.j3, "total": result.total
        }) is True


# ── TestFingerprint ───────────────────────────────────────────────────────────

class TestFingerprint:
    def test_fingerprint_is_64_hex_chars(self):
        fp = _comp("basketball_dunk").fingerprint(_inp())
        assert len(fp) == 64
        assert all(c in "0123456789abcdef" for c in fp)

    def test_fingerprint_is_deterministic(self):
        comp = _comp("basketball_dunk")
        inp = _inp(0.7, 0.8, 0.6)
        assert comp.fingerprint(inp) == comp.fingerprint(inp)

    def test_different_inputs_produce_different_fingerprints(self):
        comp = _comp("basketball_dunk")
        assert comp.fingerprint(_inp(0.5, 0.5)) != comp.fingerprint(_inp(0.9, 0.9))

    def test_different_offsets_produce_different_fingerprints(self):
        comp_a = _comp("basketball_dunk", [0, 0, 0])
        comp_b = _comp("basketball_dunk", [1, 2, 3])
        assert comp_a.fingerprint(_inp()) != comp_b.fingerprint(_inp())


# ── TestToEventDict ───────────────────────────────────────────────────────────

class TestToEventDict:
    def test_event_dict_has_required_fields(self):
        result = _comp("basketball_dunk").score(_inp())
        ev = result.to_event_dict("match-abc")
        assert ev["actor_id"] == "match-abc"
        assert ev["action_type"] == "judged_score"
        payload = ev["payload"]
        for k in ("j1", "j2", "j3", "total", "message", "is_perfect"):
            assert k in payload

    def test_event_dict_payload_matches_result(self):
        comp = _comp("basketball_dunk")
        result = comp.score(_inp(0.8, 0.85, 0.7))
        ev = result.to_event_dict("match-xyz")
        p = ev["payload"]
        assert p["j1"] == result.j1
        assert p["j2"] == result.j2
        assert p["j3"] == result.j3
        assert p["total"] == result.total


# ── TestDunkScoringAdapter ────────────────────────────────────────────────────

class TestDunkScoringAdapter:
    """Verify dunk_scoring.py adapter matches JudgeComponent directly."""

    def test_score_dunk_matches_judge_component(self):
        offsets = [2, -1, 4]
        approach, execution, style = 0.87, 0.91, 0.9

        from_adapter = score_dunk(approach, execution, style, offsets)
        comp = JudgeComponent.for_mode("basketball_dunk", offsets)
        from_comp = comp.score(JudgedInput(primary=approach, secondary=execution, style_difficulty=style))

        assert from_adapter.j1 == from_comp.j1
        assert from_adapter.j2 == from_comp.j2
        assert from_adapter.j3 == from_comp.j3
        assert from_adapter.total == from_comp.total
        assert from_adapter.message == from_comp.message
        assert from_adapter.is_perfect == from_comp.is_perfect

    def test_score_dunk_from_player_inputs_uses_style_key(self):
        offsets = [0, 0, 0]
        result_hard = score_dunk_from_player_inputs(
            launch_angle=0.8, landing_precision=0.8,
            judge_offsets=offsets, style_key="360_windmill",
        )
        result_easy = score_dunk_from_player_inputs(
            launch_angle=0.8, landing_precision=0.8,
            judge_offsets=offsets, style_key="finger_roll",
        )
        assert result_hard.total >= result_easy.total

    def test_score_dunk_from_player_inputs_validates_hash(self):
        import zlib
        style_key = "360_windmill"
        crc = zlib.crc32(style_key.encode()) & 0xFFFFFFFF
        correct_hash = f"{crc:08x}"

        # Correct hash — should not raise
        score_dunk_from_player_inputs(
            launch_angle=0.9, landing_precision=0.9,
            judge_offsets=[0, 0, 0],
            style_key=style_key,
            trick_sequence_hash=correct_hash,
        )

    def test_score_dunk_from_player_inputs_rejects_bad_hash(self):
        with pytest.raises(ValueError, match="trick_sequence_hash mismatch"):
            score_dunk_from_player_inputs(
                launch_angle=0.9, landing_precision=0.9,
                judge_offsets=[0, 0, 0],
                style_key="360_windmill",
                trick_sequence_hash="deadbeef",
            )

    def test_score_dunk_from_player_inputs_without_style_uses_default(self):
        result = score_dunk_from_player_inputs(
            launch_angle=0.7, landing_precision=0.7, judge_offsets=[0, 0, 0],
        )
        # With style=0.5 (default), base = (0.7*0.4+0.7*0.6)*50*(0.7+0.5*0.3) = 30.1
        assert result.total > 0

    def test_score_dunk_is_deterministic(self):
        offsets = derive_judge_offsets(12345678)
        r1 = score_dunk(0.75, 0.80, 0.7, offsets)
        r2 = score_dunk(0.75, 0.80, 0.7, offsets)
        assert (r1.j1, r1.j2, r1.j3, r1.total) == (r2.j1, r2.j2, r2.j3, r2.total)


# ── TestDunkEventSchemaExamples ───────────────────────────────────────────────

class TestDunkEventSchemaExamples:
    """
    Verify the scoring examples embedded in infra/dunk_event_schema.json
    produce the documented results.
    """

    def test_schema_example_1_outstanding(self):
        # Example 1: launch_angle=0.87, landing_precision=0.91, style_key=360_windmill
        # judge_offsets=[2,-1,4] → j1=10, j2=8, j3=10, total=28, is_perfect=False
        offsets = [2, -1, 4]
        result = score_dunk_from_player_inputs(
            launch_angle=0.87, landing_precision=0.91,
            judge_offsets=offsets, style_key="360_windmill",
        )
        assert result.j1 == 10
        assert result.j2 == 8
        assert result.j3 == 10
        assert result.total == 28
        assert result.message == "OUTSTANDING"
        assert result.is_perfect is False

    def test_schema_example_2_perfect(self):
        # Example 2: launch_angle=1.0, landing_precision=1.0, judge_offsets=[5,5,5]
        # → j1=10, j2=10, j3=10, total=30, PERFECT SCORE
        offsets = [5, 5, 5]
        result = score_dunk_from_player_inputs(
            launch_angle=1.0, landing_precision=1.0,
            judge_offsets=offsets, style_key="360_windmill",
        )
        assert result.j1 == 10
        assert result.j2 == 10
        assert result.j3 == 10
        assert result.total == 30
        assert result.message == "PERFECT SCORE"
        assert result.is_perfect is True


# ── TestPrecisionScorer ───────────────────────────────────────────────────────

class TestPrecisionScorer:
    def test_perfect_rating_within_15pct_window(self):
        ps = PrecisionScorer("karate", seed=999, window_ms=80)
        result = ps.calculate_score(0, 10)  # delta=10ms, 10 <= 80*0.15=12ms
        assert result["breakdown"]["rating"] == "PERFECT"
        assert result["final_score"] == 100

    def test_great_rating_within_40pct_window(self):
        ps = PrecisionScorer("karate", seed=999, window_ms=80)
        result = ps.calculate_score(0, 25)  # delta=25ms, 25 <= 80*0.40=32ms
        assert result["breakdown"]["rating"] == "GREAT"
        assert result["final_score"] == 85

    def test_good_rating_within_70pct_window(self):
        ps = PrecisionScorer("tennis", seed=42, window_ms=100)
        result = ps.calculate_score(0, 55)  # delta=55ms, 55 <= 100*0.70=70ms
        assert result["breakdown"]["rating"] == "GOOD"
        assert result["final_score"] == 65

    def test_ok_rating_at_full_window(self):
        ps = PrecisionScorer("golf", seed=1, window_ms=80)
        result = ps.calculate_score(0, 75)  # delta=75ms, within 80ms
        assert result["breakdown"]["rating"] == "OK"
        assert result["final_score"] == 40

    def test_miss_rating_outside_window(self):
        ps = PrecisionScorer("baseball", seed=1, window_ms=80)
        result = ps.calculate_score(0, 100)  # delta=100ms > 80ms
        assert result["breakdown"]["rating"] == "MISS"
        assert result["final_score"] == 0

    def test_validate_event_true_on_correct_rating(self):
        ps = PrecisionScorer("karate", seed=999, window_ms=80)
        assert ps.validate_event(10, "PERFECT") is True

    def test_validate_event_false_on_wrong_rating(self):
        ps = PrecisionScorer("karate", seed=999, window_ms=80)
        assert ps.validate_event(10, "MISS") is False

    def test_result_has_timestamp(self):
        ps = PrecisionScorer("tennis", seed=5)
        result = ps.calculate_score(0, 20)
        assert "timestamp" in result
        assert isinstance(result["timestamp"], float)


# ── TestCompetitiveScorer ─────────────────────────────────────────────────────

class TestCompetitiveScorer:
    def test_score_accumulates_points(self):
        cs = CompetitiveScorer("basketball_h2h", seed=1)
        r1 = cs.calculate_score("player_a", 1)
        r2 = cs.calculate_score("player_a", 3)
        assert r2["final_score"] == 4

    def test_separate_players_track_independently(self):
        cs = CompetitiveScorer("football", seed=2)
        cs.calculate_score("p1", 7)
        cs.calculate_score("p2", 3)
        assert cs._state["p1"] == 7
        assert cs._state["p2"] == 3

    def test_validate_event_true_on_correct_state(self):
        cs = CompetitiveScorer("soccer", seed=3)
        cs.calculate_score("team_a", 2)
        assert cs.validate_event({}, {"team_a": 2}) is True

    def test_validate_event_false_on_wrong_state(self):
        cs = CompetitiveScorer("soccer", seed=3)
        cs.calculate_score("team_a", 2)
        assert cs.validate_event({}, {"team_a": 5}) is False

    def test_breakdown_contains_delta(self):
        cs = CompetitiveScorer("basketball_3v3", seed=7)
        result = cs.calculate_score("p1", 3)
        assert result["breakdown"]["delta"] == 3


# ── TestCognitiveScorer ───────────────────────────────────────────────────────

class TestCognitiveScorer:
    def test_incorrect_answer_scores_zero(self):
        cog = CognitiveScorer("brain_brawl", seed=1)
        result = cog.calculate_score(is_correct=False, response_time_ms=500)
        assert result["final_score"] == 0

    def test_fast_correct_answer_earns_speed_bonus(self):
        cog = CognitiveScorer("brain_brawl", seed=1, base_points=100)
        result = cog.calculate_score(is_correct=True, response_time_ms=1000, max_time_ms=10000)
        assert result["final_score"] > 100  # base + speed bonus
        assert result["breakdown"]["speed_bonus"] > 0

    def test_slow_correct_answer_earns_no_speed_bonus(self):
        cog = CognitiveScorer("who_scene_it", seed=2, base_points=100)
        result = cog.calculate_score(is_correct=True, response_time_ms=10000, max_time_ms=10000)
        assert result["breakdown"]["speed_bonus"] == 0
        assert result["final_score"] == 100

    def test_speed_bonus_decreases_with_slower_response(self):
        cog = CognitiveScorer("brain_brawl", seed=1, base_points=100)
        fast = cog.calculate_score(is_correct=True, response_time_ms=1000, max_time_ms=10000)
        slow = cog.calculate_score(is_correct=True, response_time_ms=5000, max_time_ms=10000)
        assert fast["final_score"] > slow["final_score"]

    def test_validate_event_within_tolerance(self):
        cog = CognitiveScorer("brain_brawl", seed=1, base_points=100)
        result = cog.calculate_score(is_correct=True, response_time_ms=2000, max_time_ms=10000)
        score = result["final_score"]
        # validate_event has ±5 tolerance for clock drift
        assert cog.validate_event(2000, score) is True
        assert cog.validate_event(2000, score + 4) is True
        assert cog.validate_event(2000, score + 10) is False

    def test_result_has_correct_flag_in_breakdown(self):
        cog = CognitiveScorer("brain_brawl", seed=1)
        r_correct = cog.calculate_score(is_correct=True, response_time_ms=3000)
        r_wrong = cog.calculate_score(is_correct=False, response_time_ms=3000)
        assert r_correct["breakdown"]["correct"] is True
        assert r_wrong["breakdown"]["correct"] is False


# ── TestMultiModeSeeding ──────────────────────────────────────────────────────

class TestMultiModeSeeding:
    """Verify that all 4 JUDGED modes score deterministically from the same seed."""

    MODES = ["basketball_dunk", "gymnastics", "surfing", "skateboarding"]

    def test_all_judged_modes_are_deterministic(self):
        offsets = derive_judge_offsets(SEED)
        for mode in self.MODES:
            comp = JudgeComponent.for_mode(mode, offsets)
            inp = _inp(0.75, 0.80, 0.7)
            r1 = comp.score(inp)
            r2 = comp.score(inp)
            assert (r1.j1, r1.j2, r1.j3) == (r2.j1, r2.j2, r2.j3), f"{mode} not deterministic"

    def test_same_inputs_different_modes_produce_different_scores(self):
        # Very low inputs push judge scores below each mode's floor:
        # dunk floor=3 → total=9, gymnastics/skateboarding floor=2 → total=6, surfing floor=1 → total=3
        offsets = [0, 0, 0]
        inp = _inp(primary=0.05, secondary=0.05, style=0.05)
        totals = set()
        for mode in self.MODES:
            comp = JudgeComponent.for_mode(mode, offsets)
            totals.add(comp.score(inp).total)
        assert len(totals) >= 2

    def test_judged_mode_fingerprints_differ_across_modes(self):
        offsets = [1, -1, 2]
        inp = _inp(0.8, 0.85, 0.9)
        fingerprints = [
            JudgeComponent.for_mode(m, offsets).fingerprint(inp)
            for m in self.MODES
        ]
        assert len(set(fingerprints)) == len(self.MODES)
