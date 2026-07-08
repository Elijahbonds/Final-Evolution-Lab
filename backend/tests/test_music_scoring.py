"""
Unit tests for lib/music_scoring.py — the extended musicality metrics that
augment the canonical composer-challenge scoring.

Covers:
  - determinism (same input -> same output, across 3 seeds, re-imported call)
  - monotonicity for each new metric (the "more X -> higher" direction)
  - graceful degradation when pitch data is absent (pitch-aware metrics stay
    neutral, aggregate never crashes)
  - edge cases (empty loop, single track, single bar)

Runs fully offline using the same bootstrap/stub pattern as test_music_mode.py
(MOCK_DB=1 + sys.modules stubbing) so it needs no live DB / LLM / network.
"""
import os, sys

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_fel")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")
os.environ["MOCK_DB"] = "1"

import types
from unittest.mock import MagicMock, patch


def _stub(name):
    parts = name.split(".")
    for i in range(1, len(parts) + 1):
        pkg = ".".join(parts[:i])
        if pkg not in sys.modules:
            sys.modules[pkg] = types.ModuleType(pkg)
    return sys.modules[name]


_chat = _stub("emergentintegrations.llm.chat")
_chat.LlmChat = MagicMock
_chat.UserMessage = MagicMock
_chat.ImageContent = MagicMock

_motor_patcher = patch("motor.motor_asyncio.AsyncIOMotorClient")
_mock_motor = _motor_patcher.start()
_mock_motor.return_value.__getitem__ = lambda self, n: MagicMock()

import pytest

from lib import music_scoring


# ── Fixtures / helpers ──────────────────────────────────────────────────────

_CONSTRAINTS = {
    "bpm": 120, "key": "Am", "instruments": ["instrument", "sample"],
    "length_beats": 16.0, "max_tracks": 4,
}

# Pitch-free loop (the shape existing submissions use today).
_LOOP_NO_PITCH = {
    "tracks": [
        {"type": "instrument",
         "clips": [{"start": 0, "length": 4}, {"start": 8, "length": 4}]},
        {"type": "sample",
         "clips": [{"start": 0, "length": 1}, {"start": 4, "length": 1},
                   {"start": 8, "length": 1}, {"start": 12, "length": 1}]},
        {"type": "instrument", "clips": [{"start": 2.5, "length": 1.5}]},
    ],
    "bpm": 120, "key": "Am",
}

_SEEDS = [1, 42, 9_999_999_999]


def _loop(*tracks, **kw):
    d = {"tracks": list(tracks), "bpm": 120, "key": "Am"}
    d.update(kw)
    return d


def _trk(role_type, starts, pitches=None):
    clips = []
    for s in starts:
        c = {"start": s, "length": 1}
        if pitches is not None:
            c["pitches"] = pitches
        clips.append(c)
    return {"type": role_type, "clips": clips}


# ── Determinism ─────────────────────────────────────────────────────────────

class TestDeterminism:
    @pytest.mark.parametrize("seed", _SEEDS)
    def test_same_input_same_breakdown(self, seed):
        a = music_scoring.compute_extended_breakdown(seed, _CONSTRAINTS, _LOOP_NO_PITCH)
        b = music_scoring.compute_extended_breakdown(seed, _CONSTRAINTS, _LOOP_NO_PITCH)
        assert a == b

    def test_breakdown_pure_across_interleaved_calls(self):
        # An unrelated call in between must not perturb the result (no global state).
        direct = music_scoring.compute_extended_breakdown(7, _CONSTRAINTS, _LOOP_NO_PITCH)
        music_scoring.compute_extended_breakdown(999, _CONSTRAINTS, _loop())
        again = music_scoring.compute_extended_breakdown(7, _CONSTRAINTS, _LOOP_NO_PITCH)
        assert again == direct

    @pytest.mark.parametrize("seed", _SEEDS)
    def test_all_metrics_in_unit_range_and_6dp(self, seed):
        out = music_scoring.compute_extended_breakdown(seed, _CONSTRAINTS, _LOOP_NO_PITCH)
        for name, val in out["metrics"].items():
            assert 0.0 <= val <= 1.0, name
            assert round(val, 6) == val, name
        assert 0.0 <= out["musicality"] <= 1.0
        assert round(out["musicality"], 6) == out["musicality"]

    def test_weights_present_and_sum_to_one(self):
        out = music_scoring.compute_extended_breakdown(1, _CONSTRAINTS, _LOOP_NO_PITCH)
        assert set(out["weights"]) == set(out["metrics"])
        assert abs(sum(out["weights"].values()) - 1.0) < 1e-9

    def test_individual_metric_functions_deterministic(self):
        for name, fn in music_scoring._METRIC_FNS.items():
            v1 = fn(_LOOP_NO_PITCH, _CONSTRAINTS, 5)
            v2 = fn(_LOOP_NO_PITCH, _CONSTRAINTS, 5)
            assert v1 == v2, name
            assert 0.0 <= v1 <= 1.0, name


# ── Graceful degradation (pitch data absent) ────────────────────────────────

class TestGracefulDegradation:
    def test_harmony_neutral_without_pitch(self):
        assert music_scoring.harmony_fit(_LOOP_NO_PITCH, _CONSTRAINTS, 1) == 0.5

    def test_tonic_grounding_neutral_without_pitch(self):
        assert music_scoring.tonic_grounding(_LOOP_NO_PITCH, _CONSTRAINTS, 1) == 0.5

    def test_pitch_aware_flag_false_then_true(self):
        no = music_scoring.compute_extended_breakdown(1, _CONSTRAINTS, _LOOP_NO_PITCH)
        assert no["pitch_aware"] is False
        withp = _loop(_trk("instrument", [0, 4], pitches=[0, 3, 7]))
        yes = music_scoring.compute_extended_breakdown(1, _CONSTRAINTS, withp)
        assert yes["pitch_aware"] is True

    def test_rhythm_metrics_work_without_pitch(self):
        # Non-pitch metrics must still produce meaningful (non-neutral-forced) values.
        out = music_scoring.compute_extended_breakdown(1, _CONSTRAINTS, _LOOP_NO_PITCH)
        assert out["metrics"]["downbeat_coverage"] > 0.0
        assert out["metrics"]["bar_occupancy"] > 0.0


# ── Harmony / tonal monotonicity ────────────────────────────────────────────

class TestHarmony:
    def test_in_scale_beats_out_of_scale(self):
        # Am scale contains 0(A? no) — use explicit: A minor pcs = {9,11,0,2,4,5,7}
        in_scale = _loop(_trk("lead", [0, 4], pitches=[9, 0, 4]))   # A, C, E (i triad)
        out_scale = _loop(_trk("lead", [0, 4], pitches=[1, 6, 8]))  # C#, F#, G# (all non-diatonic)
        s_in = music_scoring.harmony_fit(in_scale, _CONSTRAINTS, 1)
        s_out = music_scoring.harmony_fit(out_scale, _CONSTRAINTS, 1)
        assert s_in > s_out
        assert s_in == 1.0
        assert s_out == 0.0

    def test_more_in_scale_notes_score_higher(self):
        mostly = _loop(_trk("lead", [0], pitches=[9, 0, 4, 1]))   # 3/4 in scale
        fewer = _loop(_trk("lead", [0], pitches=[9, 1, 6, 8]))    # 1/4 in scale
        assert (music_scoring.harmony_fit(mostly, _CONSTRAINTS, 1)
                > music_scoring.harmony_fit(fewer, _CONSTRAINTS, 1))

    def test_tonic_grounding_prefers_tonic_triad(self):
        tonic_heavy = _loop(_trk("lead", [0], pitches=[9, 0, 4]))   # i triad (A C E)
        weak = _loop(_trk("lead", [0], pitches=[11, 2, 5]))        # ii-ish weak degrees
        assert (music_scoring.tonic_grounding(tonic_heavy, _CONSTRAINTS, 1)
                > music_scoring.tonic_grounding(weak, _CONSTRAINTS, 1))


# ── Rhythmic sub-metrics monotonicity ───────────────────────────────────────

class TestRhythmicSubMetrics:
    def test_downbeat_coverage_more_downbeats_higher(self):
        few = _loop(_trk("drums", [0]))               # 1 of 4 bar downbeats
        many = _loop(_trk("drums", [0, 4, 8, 12]))    # all 4 downbeats
        assert (music_scoring.downbeat_coverage(many, _CONSTRAINTS, 1)
                > music_scoring.downbeat_coverage(few, _CONSTRAINTS, 1))
        assert music_scoring.downbeat_coverage(many, _CONSTRAINTS, 1) == 1.0

    def test_bar_occupancy_no_empty_bars_scores_higher(self):
        gappy = _loop(_trk("drums", [0]))                     # 1 bar occupied
        full = _loop(_trk("drums", [0, 5, 9, 13]))            # all 4 bars occupied
        assert (music_scoring.bar_occupancy(full, _CONSTRAINTS, 1)
                > music_scoring.bar_occupancy(gappy, _CONSTRAINTS, 1))
        assert music_scoring.bar_occupancy(full, _CONSTRAINTS, 1) == 1.0

    def test_groove_consistency_steady_beats_scattered(self):
        steady = _loop(_trk("drums", [0.0, 1.0, 2.0, 3.0, 4.0]))          # all on-grid
        scattered = _loop(_trk("drums", [0.03, 1.17, 2.41, 3.62, 4.29]))  # jittery
        assert (music_scoring.groove_consistency(steady, _CONSTRAINTS, 1)
                >= music_scoring.groove_consistency(scattered, _CONSTRAINTS, 1))
        assert music_scoring.groove_consistency(steady, _CONSTRAINTS, 1) == 1.0

    def test_fill_variation_varied_bars_beat_identical_bars(self):
        # Identical pattern every bar -> low; varied per-bar -> high.
        same = _loop(_trk("drums", [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]))
        varied = _loop(_trk("drums", [0, 5, 6, 9, 10, 11, 12]))
        assert (music_scoring.fill_variation(varied, _CONSTRAINTS, 1)
                > music_scoring.fill_variation(same, _CONSTRAINTS, 1))


# ── Structure monotonicity ──────────────────────────────────────────────────

class TestStructure:
    def test_bar_usage_multi_bar_beats_single_bar(self):
        one_bar = _loop(_trk("drums", [0, 1, 2, 3]))          # all in bar 0
        four_bar = _loop(_trk("drums", [0, 4, 8, 12]))        # spread across bars
        assert (music_scoring.bar_usage(four_bar, _CONSTRAINTS, 1)
                > music_scoring.bar_usage(one_bar, _CONSTRAINTS, 1))

    def test_density_contour_varying_beats_flat(self):
        flat = _loop(_trk("drums", [0, 1, 4, 5, 8, 9, 12, 13]))   # 2 onsets/bar, flat
        shaped = _loop(_trk("drums", [0, 4, 5, 6, 7, 8, 9, 12]))  # uneven per-bar
        assert (music_scoring.density_contour(shaped, _CONSTRAINTS, 1)
                > music_scoring.density_contour(flat, _CONSTRAINTS, 1))
        assert music_scoring.density_contour(flat, _CONSTRAINTS, 1) == 0.0

    def test_call_and_response_alternating_beats_parallel(self):
        # Parallel: both roles in every bar -> no change. Alternating -> changes.
        parallel = _loop(
            _trk("bass", [0, 4, 8, 12]),
            _trk("lead", [0, 4, 8, 12]),
        )
        alternating = _loop(
            {"type": "bass", "clips": [{"start": 0, "length": 1}, {"start": 8, "length": 1}]},
            {"type": "lead", "clips": [{"start": 4, "length": 1}, {"start": 12, "length": 1}]},
        )
        assert (music_scoring.call_and_response(alternating, _CONSTRAINTS, 1)
                > music_scoring.call_and_response(parallel, _CONSTRAINTS, 1))


# ── Balance monotonicity ────────────────────────────────────────────────────

class TestBalance:
    def test_role_balance_spread_beats_single_track(self):
        one_track = _loop(_trk("bass", [0, 1, 2, 3, 4, 5, 6, 7]))
        spread = _loop(
            _trk("bass", [0, 4]),
            _trk("lead", [2, 6]),
            _trk("drums", [1, 5]),
        )
        assert (music_scoring.role_balance(spread, _CONSTRAINTS, 1)
                > music_scoring.role_balance(one_track, _CONSTRAINTS, 1))

    def test_role_balance_even_split_near_one(self):
        even = _loop(_trk("bass", [0, 1]), _trk("lead", [2, 3]))
        assert music_scoring.role_balance(even, _CONSTRAINTS, 1) == 1.0

    def test_role_coverage_more_roles_higher(self):
        one = _loop(_trk("bass", [0, 4]))
        many = _loop(
            {"type": "bass", "role": "bass", "clips": [{"start": 0, "length": 1}]},
            {"type": "lead", "role": "lead", "clips": [{"start": 4, "length": 1}]},
            {"type": "drums", "role": "drums", "clips": [{"start": 8, "length": 1}]},
            {"type": "sample", "role": "keys", "clips": [{"start": 12, "length": 1}]},
        )
        assert (music_scoring.role_coverage(many, _CONSTRAINTS, 1)
                >= music_scoring.role_coverage(one, _CONSTRAINTS, 1))
        assert music_scoring.role_coverage(one, _CONSTRAINTS, 1) < 1.0


# ── Edge cases ──────────────────────────────────────────────────────────────

class TestEdgeCases:
    def test_empty_loop_does_not_crash(self):
        out = music_scoring.compute_extended_breakdown(1, _CONSTRAINTS, {"tracks": []})
        assert 0.0 <= out["musicality"] <= 1.0
        assert out["pitch_aware"] is False
        assert out["metrics"]["role_balance"] == 0.0
        assert out["metrics"]["role_coverage"] == 0.0

    def test_missing_tracks_key(self):
        out = music_scoring.compute_extended_breakdown(1, _CONSTRAINTS, {})
        assert 0.0 <= out["musicality"] <= 1.0

    def test_single_track_role_balance_zero(self):
        single = _loop(_trk("bass", [0, 4, 8, 12]))
        assert music_scoring.role_balance(single, _CONSTRAINTS, 1) == 0.0

    def test_single_bar_challenge(self):
        c = dict(_CONSTRAINTS, length_beats=4.0)
        out = music_scoring.compute_extended_breakdown(1, c, _loop(_trk("drums", [0, 1, 2])))
        assert 0.0 <= out["musicality"] <= 1.0

    def test_fill_variation_single_active_bar_neutral(self):
        single = _loop(_trk("drums", [0, 1, 2, 3]))  # all bar 0
        assert music_scoring.fill_variation(single, _CONSTRAINTS, 1) == 0.5

    def test_groove_consistency_under_two_onsets(self):
        assert music_scoring.groove_consistency(_loop(_trk("drums", [0])), _CONSTRAINTS, 1) == 1.0
        assert music_scoring.groove_consistency(_loop(), _CONSTRAINTS, 1) == 1.0

    def test_malformed_pitch_values_ignored(self):
        # Non-int pitch entries must be dropped, not crash; degrades to neutral.
        bad = _loop({"type": "lead",
                     "clips": [{"start": 0, "length": 1, "pitches": ["x", None, 3.9]}]})
        v = music_scoring.harmony_fit(bad, _CONSTRAINTS, 1)
        assert 0.0 <= v <= 1.0
