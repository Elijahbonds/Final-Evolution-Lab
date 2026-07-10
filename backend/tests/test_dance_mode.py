"""
Tests for Dance Mode — rhythm performance + choreography (nexus/dance-mode-core).

Covers:
  - beatmap determinism (same seed+bpm+difficulty -> identical events)
  - performance scoring determinism (same hits+seed -> same score, 3 seeds)
  - latency normalisation shifts judgments predictably
  - contest mode (seeded judge offsets) is reproducible
  - record persists a replay event; export/replay round-trips
  - choreography save round-trip + creator-card pack flag

Runs fully offline under MOCK_DB=1 (in-memory stores).
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
from lib import creative_store, dance_beatmap
from lib.creative_store import get_creative_user
from routers.matches import _events, _matches
from routers.dance import router as dance_router
from routers.creator_cards import router as cards_router

_app = FastAPI()
_app.include_router(dance_router)
_app.include_router(cards_router)

_USER = User(user_id="dancer_perf", email="dp@fellab.io", name="Dancer Perf")


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


def _create(seed, bpm=128):
    resp = _client().post("/api/dance/projects", json={
        "name": "Perf Routine", "skeleton": "humanoid_v1", "bpm": bpm, "seed": seed,
        "animations": [{"name": "step", "duration": 2.0, "source": "library"}],
        "timeline": {"entries": []},
    })
    assert resp.status_code == 200, resp.text
    return resp.json()


def _perfect_hits(beatmap):
    """Build hits that land exactly on every beatmap event (should all be perfect)."""
    return [{"time_ms": e["time_ms"], "lane": e["lane"]} for e in beatmap["events"]]


# ── Beatmap determinism ────────────────────────────────────────────────────

class TestBeatmapDeterminism:
    def test_same_seed_bpm_identical(self):
        a = dance_beatmap.generate_beatmap(42, 120)
        b = dance_beatmap.generate_beatmap(42, 120)
        assert a == b
        assert a["note_count"] > 0

    def test_different_seed_differs(self):
        a = dance_beatmap.generate_beatmap(1, 120)
        b = dance_beatmap.generate_beatmap(2, 120)
        assert a["events"] != b["events"]

    def test_difficulty_changes_density(self):
        easy = dance_beatmap.generate_beatmap(7, 120, difficulty="easy")
        expert = dance_beatmap.generate_beatmap(7, 120, difficulty="expert")
        assert expert["note_count"] >= easy["note_count"]

    def test_bpm_affects_timing_not_count_on_downbeats(self):
        slow = dance_beatmap.generate_beatmap(9, 60)
        fast = dance_beatmap.generate_beatmap(9, 120)
        # Same note structure (same seed+difficulty), but times differ by tempo.
        assert slow["note_count"] == fast["note_count"]
        assert slow["duration_ms"] != fast["duration_ms"]

    def test_endpoint_matches_lib(self):
        proj = _create(seed=555, bpm=100)
        api = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        lib = dance_beatmap.generate_beatmap(555, 100)
        assert api["events"] == lib["events"]

    def test_beatmap_404(self):
        assert _client().get("/api/dance/projects/dan_nope/beatmap").status_code == 404


# ── Scoring determinism (3 seeds) ──────────────────────────────────────────

class TestScoringDeterminism:
    @pytest.mark.parametrize("seed", [11, 20260707, 9999999999])
    def test_same_hits_same_seed_same_score(self, seed):
        proj = _create(seed=seed)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = _perfect_hits(bm)
        r1 = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": hits}).json()["result"]
        r2 = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": hits}).json()["result"]
        assert r1 == r2

    @pytest.mark.parametrize("seed", [11, 20260707, 9999999999])
    def test_perfect_run_grades_S(self, seed):
        proj = _create(seed=seed)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": _perfect_hits(bm)}).json()["result"]
        assert r["tallies"]["perfect"] == bm["note_count"]
        assert r["tallies"]["miss"] == 0
        assert r["grade"] == "S"
        assert r["max_combo"] == bm["note_count"]
        assert r["big_combo"] is (bm["note_count"] >= dance_beatmap.BIG_COMBO_THRESHOLD)

    def test_empty_hits_all_miss(self):
        proj = _create(seed=3)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": []}).json()["result"]
        assert r["score"] == 0
        assert r["tallies"]["miss"] == bm["note_count"]
        assert r["grade"] == "D"

    def test_latency_normalisation_recovers_perfect(self):
        proj = _create(seed=77)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        # Shift every hit late by 200ms (would all miss), then normalise it out.
        late = [{"time_ms": e["time_ms"] + 200.0, "lane": e["lane"]} for e in bm["events"]]
        raw = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                             json={"hits": late}).json()["result"]
        assert raw["tallies"]["miss"] == bm["note_count"]
        fixed = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                               json={"hits": late, "latency_ms": 200.0}).json()["result"]
        assert fixed["tallies"]["perfect"] == bm["note_count"]

    def test_contest_seed_reproducible(self):
        proj = _create(seed=44)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = _perfect_hits(bm)
        a = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": hits, "contest_seed": 2024}).json()["result"]
        b = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": hits, "contest_seed": 2024}).json()["result"]
        assert a == b
        assert a["contest_seed"] == 2024

    def test_score_404(self):
        assert _client().post("/api/dance/projects/dan_nope/score",
                              json={"hits": []}).status_code == 404


# ── Record + replay round-trip ─────────────────────────────────────────────

class TestRecordReplay:
    def test_record_persists_event(self):
        proj = _create(seed=101)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        resp = _client().post(f"/api/dance/projects/{proj['project_id']}/record",
                              json={"hits": _perfect_hits(bm), "recording": True})
        assert resp.status_code == 200, resp.text
        assert resp.json()["recorded"] is True
        events = _events.get(proj["project_id"], [])
        assert any(e["type"] == "performance_recorded" for e in events)

    def test_record_score_matches_score_endpoint(self):
        proj = _create(seed=202)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = _perfect_hits(bm)
        scored = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                                json={"hits": hits}).json()["result"]
        recorded = _client().post(f"/api/dance/projects/{proj['project_id']}/record",
                                  json={"hits": hits}).json()["result"]
        assert scored == recorded

    def test_replay_export_includes_performance(self):
        proj = _create(seed=303)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        _client().post(f"/api/dance/projects/{proj['project_id']}/record",
                       json={"hits": _perfect_hits(bm), "recording": True})
        exp = _client().get(f"/api/replays/{proj['project_id']}/export").json()
        assert exp["metadata"]["project_type"] == "dance"
        assert exp["metadata"]["seed"] == 303
        types_seen = {e["type"] for e in exp["events"]}
        assert "project_created" in types_seen
        assert "performance_recorded" in types_seen
        # seq ordering authoritative + monotonic
        seqs = [e["seq"] for e in exp["events"]]
        assert seqs == sorted(seqs)


# ── Choreography editor ────────────────────────────────────────────────────

class TestChoreography:
    def test_save_choreography_round_trip(self):
        proj = _create(seed=404)
        tl = {"entries": [
            {"animation": "step", "start_beat": 0, "speed": 1.0},
            {"animation": "step", "start_beat": 8, "speed": 1.5, "transition": "crossfade"},
        ]}
        resp = _client().post(f"/api/dance/projects/{proj['project_id']}/choreography",
                              json={"timeline": tl})
        assert resp.status_code == 200, resp.text
        got = _client().get(f"/api/dance/projects/{proj['project_id']}").json()
        assert got["timeline"] == tl

    def test_save_as_pack_records_card_event(self):
        proj = _create(seed=505)
        _client().post(f"/api/dance/projects/{proj['project_id']}/choreography",
                       json={"timeline": {"entries": []}, "save_as_pack": True})
        events = _events.get(proj["project_id"], [])
        saved = [e for e in events if e["type"] == "choreography_saved"]
        assert saved and saved[-1]["pack_card_id"] == "card_choreo_01"

    def test_choreography_404(self):
        assert _client().post("/api/dance/projects/dan_nope/choreography",
                              json={"timeline": {"entries": []}}).status_code == 404


# ── Beatmap enrichment (nexus/dance-mode-enhance) ──────────────────────────
# Richer opt-in generation must NOT perturb the classic/default path.

class TestBeatmapEnrichment:

    # --- backward compat of the default/classic path ---
    def test_classic_default_unchanged(self):
        a = dance_beatmap.generate_beatmap(42, 120)
        b = dance_beatmap.generate_beatmap(42, 120, style="classic")
        assert a["events"] == b["events"]
        assert a["note_count"] == b["note_count"]

    def test_summary_does_not_change_events(self):
        a = dance_beatmap.generate_beatmap(42, 120, summary=False)
        b = dance_beatmap.generate_beatmap(42, 120, summary=True)
        assert a["events"] == b["events"]
        assert "summary" in b and "summary" not in a

    def test_holds_additive_in_classic_expert(self):
        # holds=True must NOT change which events fire in classic mode.
        base = dance_beatmap.generate_beatmap(7, 120, difficulty="expert")
        held = dance_beatmap.generate_beatmap(7, 120, difficulty="expert", holds=True)
        strip = lambda bm: [(e["index"], e["lane"], e["time_ms"], e["kind"]) for e in bm["events"]]
        assert strip(base) == strip(held)

    # --- determinism of the new phrased path ---
    def test_phrased_deterministic(self):
        a = dance_beatmap.generate_beatmap(42, 120, style="phrased", curve=True, chords=True)
        b = dance_beatmap.generate_beatmap(42, 120, style="phrased", curve=True, chords=True)
        assert a == b

    def test_phrased_differs_from_classic(self):
        c = dance_beatmap.generate_beatmap(42, 120, style="classic")
        p = dance_beatmap.generate_beatmap(42, 120, style="phrased")
        assert c["events"] != p["events"]

    def test_phrased_selection_independent_of_bpm(self):
        slow = dance_beatmap.generate_beatmap(9, 60, style="phrased")
        fast = dance_beatmap.generate_beatmap(9, 120, style="phrased")
        strip = lambda bm: [(e["index"], e["lane"], e["kind"], e["pattern"]) for e in bm["events"]]
        assert strip(slow) == strip(fast)        # selection independent of bpm
        assert slow["duration_ms"] != fast["duration_ms"]

    def test_curve_changes_phrased_selection(self):
        flat = dance_beatmap.generate_beatmap(21, 120, style="phrased", curve=False)
        ramp = dance_beatmap.generate_beatmap(21, 120, style="phrased", curve=True)
        # Curve modulates which off-beats fire -> event lists differ.
        assert flat["events"] != ramp["events"]

    # --- HOLD structural asserts ---
    def test_hold_events_have_duration(self):
        bm = dance_beatmap.generate_beatmap(7, 120, difficulty="expert", holds=True)
        holds = [e for e in bm["events"] if e["kind"] == "hold"]
        assert holds
        for h in holds:
            assert h["end_ms"] > h["time_ms"]
            assert h["hold_ms"] > 0
            assert h["end_beat"] > h["beat"]

    def test_holds_do_not_change_score(self):
        # Scoring ignores hold fields -> perfect run still all-perfect.
        bm = dance_beatmap.generate_beatmap(7, 128, difficulty="expert", holds=True)
        hits = [{"time_ms": e["time_ms"], "lane": e["lane"]} for e in bm["events"]]
        r = dance_beatmap.score_performance(bm, hits)
        assert r["tallies"]["perfect"] == bm["note_count"]
        assert r["tallies"]["miss"] == 0

    # --- CHORD structural asserts ---
    def test_chords_share_time_distinct_lane(self):
        bm = dance_beatmap.generate_beatmap(3, 120, difficulty="expert",
                                            style="phrased", chords=True)
        from collections import defaultdict
        by_time = defaultdict(list)
        for e in bm["events"]:
            by_time[e["time_ms"]].append(e["lane"])
        chords = {t: ls for t, ls in by_time.items() if len(ls) > 1}
        assert chords, "expected at least one chord on expert"
        for t, lanes in chords.items():
            assert len(set(lanes)) == len(lanes)   # all distinct lanes at a time

    def test_no_duplicate_time_lane(self):
        bm = dance_beatmap.generate_beatmap(3, 120, difficulty="expert",
                                            style="phrased", chords=True)
        seen = {(e["time_ms"], e["lane"]) for e in bm["events"]}
        assert len(seen) == len(bm["events"])      # no (time,lane) collision

    def test_chords_scored_per_lane(self):
        # A perfect run on a chord map still grades S (per-lane matching).
        bm = dance_beatmap.generate_beatmap(3, 128, difficulty="expert",
                                            style="phrased", chords=True)
        hits = [{"time_ms": e["time_ms"], "lane": e["lane"]} for e in bm["events"]]
        r = dance_beatmap.score_performance(bm, hits)
        assert r["tallies"]["miss"] == 0
        assert r["grade"] == "S"

    def test_classic_has_no_chords(self):
        bm = dance_beatmap.generate_beatmap(3, 120, difficulty="expert",
                                            style="classic", chords=True)
        seen = {(e["time_ms"], e["lane"]) for e in bm["events"]}
        assert len(seen) == len(bm["events"])      # chords ignored on classic

    # --- summary asserts ---
    def test_summary_fields(self):
        bm = dance_beatmap.generate_beatmap(3, 120, difficulty="expert",
                                            style="phrased", curve=True, chords=True)
        s = bm["summary"]
        assert {"style", "pattern_breakdown", "peak_density",
                "chord_count", "hold_count", "phrase_count"}.issubset(s)
        assert s["chord_count"] == sum(1 for e in bm["events"] if e.get("chord"))
        assert s["hold_count"] == sum(1 for e in bm["events"] if e["kind"] == "hold")

    def test_endpoint_phrased_matches_lib(self):
        proj = _create(seed=777, bpm=100)
        api = _client().get(
            f"/api/dance/projects/{proj['project_id']}/beatmap"
            f"?style=phrased&curve=1&chords=1&difficulty=expert"
        ).json()
        lib = dance_beatmap.generate_beatmap(777, 100, difficulty="expert",
                                             style="phrased", curve=True, chords=True)
        assert api["events"] == lib["events"]


# ── Scoring enrichment (nexus/dance-mode-enhance) ──────────────────────────
# Additive result keys; existing keys must stay byte-identical.

class TestScoringEnriched:

    def test_enriched_keys_present(self):
        proj = _create(seed=11)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": _perfect_hits(bm)}).json()["result"]
        for k in ("tallies_detailed", "per_lane", "mean_error_ms", "early_count",
                  "late_count", "full_combo", "full_combo_bonus", "score_with_bonus",
                  "rank_points", "sub_grade"):
            assert k in r
        for k in ("score", "grade", "tallies", "accuracy", "weighted_accuracy",
                  "max_combo", "big_combo", "note_count"):
            assert k in r

    def test_tallies_detailed_sums_to_coarse(self):
        proj = _create(seed=20260707)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = [{"time_ms": e["time_ms"] + (30.0 if i % 3 else 0.0), "lane": e["lane"]}
                for i, e in enumerate(bm["events"])]
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": hits}).json()["result"]
        d, t = r["tallies_detailed"], r["tallies"]
        assert d["marvelous"] + d["perfect"] == t["perfect"]
        assert d["great"] + d["good"] == t["good"]
        assert d["miss"] == t["miss"]

    def test_perfect_run_all_marvelous_but_coarse_perfect_intact(self):
        proj = _create(seed=11)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": _perfect_hits(bm)}).json()["result"]
        assert r["tallies"]["perfect"] == bm["note_count"]   # pinned invariant holds
        assert r["tallies_detailed"]["marvelous"] == bm["note_count"]
        assert r["tallies_detailed"]["perfect"] == 0
        assert r["sub_grade"] == "SS"
        assert r["grade"] == "S"                              # coarse grade untouched

    def test_per_lane_sums_to_totals(self):
        proj = _create(seed=9999999999)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = [{"time_ms": e["time_ms"] + (300.0 if i % 4 == 0 else 0.0),
                 "lane": e["lane"]} for i, e in enumerate(bm["events"])]
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": hits}).json()["result"]
        pl, t = r["per_lane"], r["tallies"]
        assert sum(l["perfect"] for l in pl) == t["perfect"]
        assert sum(l["good"] for l in pl) == t["good"]
        assert sum(l["miss"] for l in pl) == t["miss"]
        assert sum(l["notes"] for l in pl) == r["note_count"]
        assert [l["lane"] for l in pl] == sorted(l["lane"] for l in pl)
        for l in pl:
            assert l["notes"] == l["perfect"] + l["good"] + l["miss"]
            assert l["accuracy"] == round((l["perfect"] + l["good"]) / l["notes"], 6)

    def test_full_combo_flag_and_bonus(self):
        proj = _create(seed=11)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        fc = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": _perfect_hits(bm)}).json()["result"]
        assert fc["full_combo"] is True
        assert fc["full_combo_bonus"] > 0
        assert fc["score_with_bonus"] == fc["score"] + fc["full_combo_bonus"]

        hits = _perfect_hits(bm)
        hits[0] = {"time_ms": hits[0]["time_ms"] + 500.0, "lane": hits[0]["lane"]}
        nc = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": hits}).json()["result"]
        assert nc["tallies"]["miss"] >= 1
        assert nc["full_combo"] is False
        assert nc["full_combo_bonus"] == 0
        assert nc["score_with_bonus"] == nc["score"]

    def test_empty_hits_not_full_combo(self):
        proj = _create(seed=3)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": []}).json()["result"]
        assert r["full_combo"] is False
        assert r["full_combo_bonus"] == 0
        assert r["score"] == 0 and r["score_with_bonus"] == 0

    def test_early_late_signs(self):
        proj = _create(seed=77)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        early = [{"time_ms": e["time_ms"] - 20.0, "lane": e["lane"]} for e in bm["events"]]
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": early}).json()["result"]
        assert r["early_count"] == bm["note_count"]
        assert r["late_count"] == 0
        assert r["mean_error_ms"] < 0            # negative == early, by convention

        late = [{"time_ms": e["time_ms"] + 20.0, "lane": e["lane"]} for e in bm["events"]]
        r2 = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": late}).json()["result"]
        assert r2["late_count"] == bm["note_count"]
        assert r2["early_count"] == 0
        assert r2["mean_error_ms"] > 0

        r3 = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": _perfect_hits(bm)}).json()["result"]
        assert r3["early_count"] == 0 and r3["late_count"] == 0
        assert r3["mean_error_ms"] == 0.0

    def test_mean_error_empty_hits_is_zero(self):
        proj = _create(seed=3)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": []}).json()["result"]
        assert r["mean_error_ms"] == 0.0
        assert r["early_count"] == 0 and r["late_count"] == 0

    @pytest.mark.parametrize("seed", [11, 20260707, 9999999999])
    def test_enriched_keys_deterministic(self, seed):
        proj = _create(seed=seed)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = [{"time_ms": e["time_ms"] + (25.0 if i % 2 else -10.0), "lane": e["lane"]}
                for i, e in enumerate(bm["events"])]
        r1 = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": hits}).json()["result"]
        r2 = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                            json={"hits": hits}).json()["result"]
        assert r1 == r2
        for k in ("tallies_detailed", "per_lane", "mean_error_ms", "early_count",
                  "late_count", "full_combo", "full_combo_bonus", "score_with_bonus",
                  "rank_points", "sub_grade"):
            assert r1[k] == r2[k]

    @pytest.mark.parametrize("seed", [11, 20260707, 9999999999])
    def test_enriched_keys_deterministic_with_contest_seed(self, seed):
        proj = _create(seed=seed)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        hits = _perfect_hits(bm)
        a = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": hits, "contest_seed": 2024}).json()["result"]
        b = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": hits, "contest_seed": 2024}).json()["result"]
        assert a == b
        assert a["tallies_detailed"] == b["tallies_detailed"]

    def test_rank_points_rewards_full_combo(self):
        proj = _create(seed=11)
        bm = _client().get(f"/api/dance/projects/{proj['project_id']}/beatmap").json()
        r = _client().post(f"/api/dance/projects/{proj['project_id']}/score",
                           json={"hits": _perfect_hits(bm)}).json()["result"]
        # All-marvelous full combo -> rank_points == MARV_W*notes + bonus.
        expected = (dance_beatmap.MARV_W * bm["note_count"]
                    + dance_beatmap.FULL_COMBO_BONUS_PER_NOTE * bm["note_count"])
        assert r["rank_points"] == expected
