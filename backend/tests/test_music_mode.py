"""
Unit tests for the Music Creation MODE (built on the creative-models foundation).

Covers:
  - composer-challenge scoring determinism (same seed+loop -> same score, 3 seeds)
  - composer-challenge constraint adherence affects the score sensibly
  - export round-trip (project JSON re-imports to identical playback structure)
  - auto-generation determinism (auto-beat/auto-harmony seeded + reproducible)
  - save-as-pack produces a Creator-Card-shaped payload via the existing contract

Runs fully offline: MOCK_DB=1 set before import so lib/creative_store.py and
routers/matches.py use in-memory stores.
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
from routers.creator_cards import router as cards_router

_app = FastAPI()
_app.include_router(music_router)
_app.include_router(cards_router)

_USER = User(user_id="composer_a", email="ca@fellab.io", name="Composer A")


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


# A representative submitted loop (music-project `tracks` shape).
_LOOP_TRACKS = [
    {"type": "instrument",
     "clips": [{"start": 0, "length": 4}, {"start": 8, "length": 4}]},
    {"type": "sample",
     "clips": [{"start": 0, "length": 1}, {"start": 4, "length": 1},
               {"start": 8, "length": 1}, {"start": 12, "length": 1}]},
    {"type": "instrument", "clips": [{"start": 2.5, "length": 1.5}]},
]

_CONSTRAINTS = {
    "bpm": 120, "key": "Am", "instruments": ["instrument", "sample"],
    "length_beats": 16.0, "max_tracks": 4,
}


def _create(seed=None, **overrides):
    body = {"name": "Mode Beat", "bpm": 120, "key": "Am", "tracks": _LOOP_TRACKS, **overrides}
    if seed is not None:
        body["seed"] = seed
    r = _client().post("/api/music/projects", json=body)
    assert r.status_code == 200, r.text
    return r.json()


# ── Composer challenge scoring determinism ─────────────────────────────────

class TestComposerChallengeDeterminism:
    @pytest.mark.parametrize("seed", [1, 42, 9_999_999_999])
    def test_same_seed_same_loop_same_score(self, seed):
        body = {"seed": seed, "constraints": _CONSTRAINTS, "tracks": _LOOP_TRACKS,
                "bpm": 120, "key": "Am"}
        s1 = _client().post("/api/music/composer-challenge/score", json=body).json()
        s2 = _client().post("/api/music/composer-challenge/score", json=body).json()
        assert s1 == s2
        assert s1["deterministic"] is True
        assert 0.0 <= s1["score"] <= 100.0

    def test_score_is_pure_function_across_process_no_state(self):
        # Scoring must not depend on any global RNG / call ordering.
        body = {"seed": 7, "constraints": _CONSTRAINTS, "tracks": _LOOP_TRACKS,
                "bpm": 120, "key": "Am"}
        # interleave an unrelated scoring call
        _client().post("/api/music/composer-challenge/score",
                       json={"seed": 999, "constraints": _CONSTRAINTS, "tracks": []})
        again = _client().post("/api/music/composer-challenge/score", json=body).json()
        direct = music_theory.score_submission(
            7, _CONSTRAINTS, {"tracks": _LOOP_TRACKS, "bpm": 120, "key": "Am"})
        assert again == direct

    def test_challenge_id_stable_for_seed(self):
        g1 = _client().post("/api/music/composer-challenge/generate",
                            json={"seed": 555, "constraints": _CONSTRAINTS}).json()
        g2 = _client().post("/api/music/composer-challenge/generate",
                            json={"seed": 555, "constraints": _CONSTRAINTS}).json()
        assert g1 == g2
        assert g1["challenge_id"].startswith("chal_")


class TestComposerChallengeScoring:
    def test_more_variety_scores_higher(self):
        lean = [{"type": "instrument", "clips": [{"start": 0, "length": 4}]}]
        rich = _LOOP_TRACKS
        base = {"seed": 3, "constraints": _CONSTRAINTS, "bpm": 120, "key": "Am"}
        s_lean = _client().post("/api/music/composer-challenge/score",
                                json={**base, "tracks": lean}).json()
        s_rich = _client().post("/api/music/composer-challenge/score",
                                json={**base, "tracks": rich}).json()
        assert s_rich["breakdown"]["variety"] > s_lean["breakdown"]["variety"]

    def test_wrong_key_lowers_adherence(self):
        base = {"seed": 3, "constraints": _CONSTRAINTS, "tracks": _LOOP_TRACKS, "bpm": 120}
        right = _client().post("/api/music/composer-challenge/score",
                               json={**base, "key": "Am"}).json()
        wrong = _client().post("/api/music/composer-challenge/score",
                               json={**base, "key": "F#"}).json()
        assert right["breakdown"]["adherence"] > wrong["breakdown"]["adherence"]

    def test_off_grid_onsets_raise_rhythm(self):
        on_grid = [{"type": "sample",
                    "clips": [{"start": 0, "length": 1}, {"start": 4, "length": 1}]}]
        syncop = [{"type": "sample",
                   "clips": [{"start": 0.5, "length": 1}, {"start": 2.5, "length": 1}]}]
        base = {"seed": 3, "constraints": _CONSTRAINTS, "bpm": 120, "key": "Am"}
        r_on = _client().post("/api/music/composer-challenge/score",
                              json={**base, "tracks": on_grid}).json()
        r_syn = _client().post("/api/music/composer-challenge/score",
                               json={**base, "tracks": syncop}).json()
        assert r_syn["breakdown"]["rhythm"] > r_on["breakdown"]["rhythm"]


# ── Auto-generation determinism ────────────────────────────────────────────

class TestAutoGenerationDeterminism:
    def test_auto_generate_deterministic_for_project(self):
        pid = _create(seed=1234)["project_id"]
        a = _client().post(f"/api/music/projects/{pid}/auto-generate", json={"bars": 4}).json()
        b = _client().post(f"/api/music/projects/{pid}/auto-generate", json={"bars": 4}).json()
        assert a == b
        comp = a["composition"]
        assert comp["bars"] == 4
        assert len(comp["harmony"]) == 4
        assert set(comp["drums"].keys()) == {"kick", "snare", "hat"}
        assert all(len(v) == 16 for v in comp["drums"].values())

    @pytest.mark.parametrize("seed", [11, 22, 33])
    def test_same_seed_same_key_same_composition(self, seed):
        c1 = music_theory.generate_composition(seed, "C", bars=4)
        c2 = music_theory.generate_composition(seed, "C", bars=4)
        assert c1 == c2

    def test_key_changes_harmony(self):
        c_major = music_theory.generate_composition(5, "C", bars=4)
        a_minor = music_theory.generate_composition(5, "Am", bars=4)
        # Same seed, different key/mode -> different harmony notes.
        assert c_major["harmony"] != a_minor["harmony"]

    def test_auto_generate_missing_project_404(self):
        assert _client().post("/api/music/projects/mus_nope/auto-generate",
                              json={"bars": 4}).status_code == 404


# ── Export round-trip (JSON re-imports to identical playback structure) ─────

class TestExportRoundTrip:
    def test_export_reimports_identically(self):
        created = _create(seed=42)
        pid = created["project_id"]
        exported = _client().post(f"/api/music/projects/{pid}/export").json()
        # Re-create a fresh project from the exported project payload — the
        # playback-relevant fields (bpm/key/seed/tracks) must round-trip 1:1.
        proj = exported["project"]
        reimport_body = {
            "name": proj["name"], "bpm": proj["bpm"], "key": proj["key"],
            "seed": proj["seed"], "tracks": proj["tracks"], "metadata": proj["metadata"],
        }
        r = _client().post("/api/music/projects", json=reimport_body)
        assert r.status_code == 200, r.text
        reimported = r.json()
        # Playback determinism: identical seed+bpm+key -> identical render manifest.
        m_orig = _client().post(f"/api/music/projects/{pid}/render-preview").json()
        m_reimp = _client().post(
            f"/api/music/projects/{reimported['project_id']}/render-preview").json()
        assert m_orig["sections"] == m_reimp["sections"]
        assert m_orig["waveform_checksum"] == m_reimp["waveform_checksum"]
        # Track structure preserved (ignoring server-regenerated ids).
        def _shape(tracks):
            return [(t["type"], [(c["start"], c["length"]) for c in t["clips"]]) for t in tracks]
        assert _shape(reimported["tracks"]) == _shape(proj["tracks"])

    def test_generated_composition_survives_project_metadata(self):
        # Auto-generated composition can be stashed in metadata and re-imported.
        pid = _create(seed=77)["project_id"]
        comp = _client().post(f"/api/music/projects/{pid}/auto-generate",
                              json={"bars": 4}).json()["composition"]
        r = _client().post("/api/music/projects", json={
            "name": "With Comp", "bpm": 120, "key": "Am", "seed": 77,
            "tracks": _LOOP_TRACKS, "metadata": {"composition": comp}})
        assert r.status_code == 200
        got = _client().get(f"/api/music/projects/{r.json()['project_id']}").json()
        assert got["metadata"]["composition"] == comp


# ── Save as pack (Creator-Card-shaped payload, existing contract) ──────────

class TestSaveAsPack:
    def test_save_as_pack_shape(self):
        pid = _create()["project_id"]
        r = _client().post(f"/api/music/projects/{pid}/save-as-pack",
                           json={"card_id": "card_sampler_01"})
        assert r.status_code == 200, r.text
        data = r.json()
        assert data["ok"] is True
        assert data["pack"]["pack_id"] == "pack_beatmaking_101"
        assert data["sample_count"] == len(data["samples"])
        assert data["sample_count"] > 0
        # apply block is a valid /api/creator-cards/apply body.
        applied = _client().post("/api/creator-cards/apply", json=data["apply"])
        assert applied.status_code == 200, applied.text
        assert applied.json()["pack"]["pack_id"] == "pack_beatmaking_101"

    def test_save_as_pack_rejects_non_music_card(self):
        pid = _create()["project_id"]
        r = _client().post(f"/api/music/projects/{pid}/save-as-pack",
                           json={"card_id": "card_groove_01"})
        assert r.status_code == 422

    def test_save_as_pack_unknown_card_404(self):
        pid = _create()["project_id"]
        r = _client().post(f"/api/music/projects/{pid}/save-as-pack",
                           json={"card_id": "card_nope"})
        assert r.status_code == 404

    def test_save_as_pack_missing_project_404(self):
        assert _client().post("/api/music/projects/mus_nope/save-as-pack",
                              json={"card_id": "card_sampler_01"}).status_code == 404
