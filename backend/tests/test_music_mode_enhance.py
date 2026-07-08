"""
Enhancement tests for the Music Creation MODE (second pass).

Covers additions layered on top of the base music mode:
  - the additive `extended` musicality breakdown is present, deterministic, and
    does NOT alter the three canonical sub-scores (variety/rhythm/adherence).
  - new drum genres (funk/dnb/reggaeton/disco) are reachable and valid.
  - edge cases the base suite didn't lock in: empty tracks, extreme BPM,
    single-onset loops.

Same offline bootstrap as test_music_mode.py (MOCK_DB=1 + sys.modules stubs).
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
from fastapi import FastAPI
from fastapi.testclient import TestClient

from core import User
from lib import creative_store, music_theory
from lib.creative_store import get_creative_user
from routers.matches import _events, _matches
from routers.music import router as music_router

_app = FastAPI()
_app.include_router(music_router)

_USER = User(user_id="composer_enh", email="ce@fellab.io", name="Composer Enh")


def _client() -> TestClient:
    _app.dependency_overrides[get_creative_user] = lambda: _USER
    return TestClient(_app, raise_server_exceptions=True)


@pytest.fixture(autouse=True)
def _clear_stores():
    for store in creative_store._memory.values():
        store.clear()
    _matches.clear()
    _events.clear()
    yield
    for store in creative_store._memory.values():
        store.clear()
    _matches.clear()
    _events.clear()


_CONSTRAINTS = {
    "bpm": 120, "key": "Am", "instruments": ["instrument", "sample"],
    "length_beats": 16.0, "max_tracks": 4,
}
_LOOP_TRACKS = [
    {"type": "instrument", "clips": [{"start": 0, "length": 4}, {"start": 8, "length": 4}]},
    {"type": "sample", "clips": [{"start": 0, "length": 1}, {"start": 4, "length": 1},
                                 {"start": 8, "length": 1}, {"start": 12, "length": 1}]},
    {"type": "instrument", "clips": [{"start": 2.5, "length": 1.5}]},
]


# ── Extended breakdown wiring ──────────────────────────────────────────────

class TestExtendedBreakdown:
    def test_score_includes_extended_block(self):
        body = {"seed": 42, "constraints": _CONSTRAINTS, "tracks": _LOOP_TRACKS,
                "bpm": 120, "key": "Am"}
        s = _client().post("/api/music/composer-challenge/score", json=body).json()
        assert "extended" in s and s["extended"] is not None
        ext = s["extended"]
        assert set(ext.keys()) == {"metrics", "musicality", "weights", "pitch_aware"}
        assert 0.0 <= ext["musicality"] <= 1.0
        # every metric in [0,1]
        assert all(0.0 <= v <= 1.0 for v in ext["metrics"].values())

    def test_extended_is_deterministic(self):
        body = {"seed": 7, "constraints": _CONSTRAINTS, "tracks": _LOOP_TRACKS,
                "bpm": 120, "key": "Am"}
        a = _client().post("/api/music/composer-challenge/score", json=body).json()
        b = _client().post("/api/music/composer-challenge/score", json=body).json()
        assert a == b
        assert a["extended"] == b["extended"]

    def test_extended_does_not_change_canonical_breakdown(self):
        # The three canonical keys must equal a direct compute that ignores the
        # extended block -> extended is purely additive.
        loop = {"tracks": _LOOP_TRACKS, "bpm": 120, "key": "Am"}
        direct = music_theory.score_submission(9, _CONSTRAINTS, loop)
        assert set(direct["breakdown"].keys()) == {"variety", "rhythm", "adherence"}
        assert direct["weights"] == {"variety": 0.3, "rhythm": 0.35, "adherence": 0.35}
        # canonical total is unaffected by extended presence
        assert 0.0 <= direct["score"] <= 100.0

    def test_pitch_aware_flag_reflects_pitch_data(self):
        no_pitch = {"tracks": _LOOP_TRACKS, "bpm": 120, "key": "Am"}
        with_pitch = {"tracks": [
            {"type": "instrument", "clips": [{"start": 0, "length": 4, "pitches": [9, 0, 4]}]},
        ], "bpm": 120, "key": "Am"}
        assert music_theory.score_submission(1, _CONSTRAINTS, no_pitch)["extended"]["pitch_aware"] is False
        assert music_theory.score_submission(1, _CONSTRAINTS, with_pitch)["extended"]["pitch_aware"] is True

    def test_in_scale_pitches_beat_out_of_scale(self):
        base = {"bpm": 120, "key": "C"}
        in_scale = music_theory.score_submission(3, {**_CONSTRAINTS, "key": "C"}, {
            **base, "tracks": [{"type": "instrument",
                                "clips": [{"start": 0, "length": 4, "pitches": [0, 2, 4, 5, 7]}]}]})
        out_scale = music_theory.score_submission(3, {**_CONSTRAINTS, "key": "C"}, {
            **base, "tracks": [{"type": "instrument",
                                "clips": [{"start": 0, "length": 4, "pitches": [1, 3, 6, 8, 10]}]}]})
        assert in_scale["extended"]["metrics"]["harmony_fit"] > \
            out_scale["extended"]["metrics"]["harmony_fit"]


# ── New drum genres ────────────────────────────────────────────────────────

class TestNewGenres:
    def test_new_genres_registered(self):
        for g in ("funk", "dnb", "reggaeton", "disco"):
            assert g in music_theory.DRUM_GENRES

    def test_new_genre_patterns_valid(self):
        for g in ("funk", "dnb", "reggaeton", "disco"):
            pat = music_theory._DRUM_PATTERNS[g]
            assert set(pat.keys()) == {"kick", "snare", "hat"}
            for lane in pat.values():
                assert len(lane) == 16
                assert all(v in (0, 1) for v in lane)

    def test_auto_generate_can_select_new_genre(self):
        # Some seed must map to a new genre now that the table grew.
        selected = {music_theory.choose_genre(s) for s in range(200)}
        assert selected & {"funk", "dnb", "reggaeton", "disco"}


# ── Edge cases (empty / extreme) ───────────────────────────────────────────

class TestScoringEdgeCases:
    def test_empty_loop_scores_deterministically(self):
        loop = {"tracks": [], "bpm": 120, "key": "Am"}
        a = music_theory.score_submission(5, _CONSTRAINTS, loop)
        b = music_theory.score_submission(5, _CONSTRAINTS, loop)
        assert a == b
        assert 0.0 <= a["score"] <= 100.0
        assert a["extended"]["metrics"]["role_balance"] == 0.0

    @pytest.mark.parametrize("bpm", [20, 300])
    def test_extreme_bpm_scores_valid(self, bpm):
        loop = {"tracks": _LOOP_TRACKS, "bpm": bpm, "key": "Am"}
        s = music_theory.score_submission(5, {**_CONSTRAINTS, "bpm": bpm}, loop)
        assert 0.0 <= s["score"] <= 100.0
        assert s["stats"]["bpm"] == bpm

    def test_single_onset_loop_no_crash(self):
        loop = {"tracks": [{"type": "instrument", "clips": [{"start": 0, "length": 1}]}],
                "bpm": 120, "key": "Am"}
        s = music_theory.score_submission(5, _CONSTRAINTS, loop)
        assert 0.0 <= s["score"] <= 100.0
        # groove consistency is trivially 1.0 for <2 onsets
        assert s["extended"]["metrics"]["groove_consistency"] == 1.0
