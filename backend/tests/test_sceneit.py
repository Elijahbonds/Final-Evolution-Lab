"""
nexus/sceneit-demo — Who Scene It tests.

Covers:
  - BuzzRiskScoring math: countdown decay, floor, lock-in timeout, wrong-buzz penalty
  - Determinism under a fixed 64-bit seed (question order, options, correct ids)
  - Round registry: custom round types swap in without touching the core loop
  - Content provider: every film/scene/creator carries source + license (IP gate)
  - Generated stills: original SVG, < 1MB, mask/reveal variants
  - Match loop over HTTP: options hidden until buzz, countdown lock, risk resolution
  - Replay export + deterministic validation (backend/tools/sceneit_replay_validator.py)
  - Creator card endpoint (CardModule seam)
"""
import os
import sys

os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_fel")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")
os.environ["MOCK_DB"] = "1"

import random
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

import routers.sceneit as sceneit_router_module
from routers.sceneit import router as sceneit_router, _matches
from lib.sceneit.content import ContentLicenseError, get_default_provider, require_shippable
from lib.sceneit.rounds import (
    ROUND_REGISTRY, Question, RoundModule, get_round, list_rounds, register_round,
)
from lib.sceneit.scoring import BuzzRiskScoring, ScoringConfig
from lib.sceneit.stills import render_still
from tools.sceneit_replay_validator import validate_replay

_app = FastAPI()
_app.include_router(sceneit_router)
client = TestClient(_app, raise_server_exceptions=True)

CFG = ScoringConfig()  # max 1000, floor 100, countdown 20s, lock-in 4s, penalty 0.5


@pytest.fixture(autouse=True)
def _clean():
    _matches.clear()
    yield
    _matches.clear()


class FakeClock:
    """Deterministic ms clock injected in place of routers.sceneit._now_ms."""

    def __init__(self, start_ms: int = 100_000):
        self.ms = start_ms

    def advance(self, delta_ms: int):
        self.ms += delta_ms

    def __call__(self) -> int:
        return self.ms


@pytest.fixture()
def clock(monkeypatch):
    fake = FakeClock()
    monkeypatch.setattr(sceneit_router_module, "_now_ms", fake)
    return fake


def _create(seed=42, round_types=None, players=None, n=4):
    resp = client.post("/api/sceneit/match/create", json={
        "players": players or ["p1", "p2"],
        "round_types": round_types or ["invisibles"],
        "num_questions": n,
        "seed": seed,
    })
    assert resp.status_code == 200, resp.text
    return resp.json()


# ── ScoringModule: buzz-in risk math ───────────────────────────────────────

class TestBuzzRiskScoring:
    def test_potential_starts_at_max(self):
        assert BuzzRiskScoring().potential_at(0) == CFG.max_points

    def test_potential_counts_down_linearly(self):
        s = BuzzRiskScoring()
        halfway = s.potential_at(CFG.countdown_ms // 2)
        assert halfway == (CFG.max_points + CFG.floor_points) // 2
        assert s.potential_at(5_000) > s.potential_at(10_000) > s.potential_at(15_000)

    def test_potential_floors_after_countdown(self):
        s = BuzzRiskScoring()
        assert s.potential_at(CFG.countdown_ms) == CFG.floor_points
        assert s.potential_at(CFG.countdown_ms * 10) == CFG.floor_points

    def test_negative_elapsed_clamps_to_max(self):
        assert BuzzRiskScoring().potential_at(-500) == CFG.max_points

    def test_correct_answer_awards_locked_potential(self):
        s = BuzzRiskScoring()
        res = s.resolve(buzz_elapsed_ms=0, answer_elapsed_ms=1_000, correct=True)
        assert res.correct and not res.timed_out
        assert res.delta == res.potential == CFG.max_points

    def test_wrong_buzz_loses_half_the_locked_potential(self):
        s = BuzzRiskScoring()
        res = s.resolve(buzz_elapsed_ms=0, answer_elapsed_ms=1_000, correct=False)
        assert not res.correct
        assert res.delta == -round(CFG.max_points * CFG.wrong_buzz_penalty_ratio)

    def test_lock_in_timeout_counts_as_wrong(self):
        s = BuzzRiskScoring()
        late = s.resolve(buzz_elapsed_ms=0, answer_elapsed_ms=CFG.lock_in_ms + 1, correct=True)
        assert late.timed_out and not late.correct and late.delta < 0
        never = s.resolve(buzz_elapsed_ms=0, answer_elapsed_ms=None, correct=True)
        assert never.timed_out and never.delta < 0

    def test_answer_exactly_at_lock_in_boundary_counts(self):
        s = BuzzRiskScoring()
        res = s.resolve(buzz_elapsed_ms=1_000, answer_elapsed_ms=1_000 + CFG.lock_in_ms, correct=True)
        assert not res.timed_out and res.correct

    def test_late_buzz_locks_lower_potential(self):
        s = BuzzRiskScoring()
        early = s.resolve(0, 100, True)
        late = s.resolve(15_000, 15_100, True)
        assert late.delta < early.delta
        assert late.delta == s.potential_at(15_000)


# ── Determinism under fixed seed ───────────────────────────────────────────

class TestDeterminism:
    def _questions_fingerprint(self, seed):
        m = _create(seed=seed, round_types=["invisibles"], n=6)
        match = _matches[m["match_id"]]
        return [(q.question_id, q.correct_option_id, tuple(o["option_id"] for o in q.options))
                for q in match.questions]

    def test_same_seed_same_questions_options_and_answers(self):
        assert self._questions_fingerprint(777) == self._questions_fingerprint(777)

    def test_different_seed_different_order(self):
        assert self._questions_fingerprint(1) != self._questions_fingerprint(999_999_999_999)

    def test_seed_is_64_bit_capable(self):
        big = 2**63 + 12345
        m = _create(seed=big)
        assert m["seed"] == big

    def test_correct_option_always_present_in_options(self):
        m = _create(seed=31337, n=6)
        for q in _matches[m["match_id"]].questions:
            assert q.correct_option_id in {o["option_id"] for o in q.options}
            assert len(q.options) == 4
            assert len({o["option_id"] for o in q.options}) == 4


# ── Round registry seam ────────────────────────────────────────────────────

class TestRoundRegistry:
    def test_demo_rounds_registered(self):
        types_ = {r["round_type"]: r["implemented"] for r in list_rounds()}
        assert types_["invisibles"] is True
        assert types_["frame_freeze"] is True
        assert types_["credit_roll"] is True
        assert types_["quick_pitch"] is False
        assert types_["chrono_order"] is False

    def test_stub_round_rejected_at_match_create(self):
        resp = client.post("/api/sceneit/match/create", json={
            "players": ["p1"], "round_types": ["quick_pitch"], "num_questions": 2, "seed": 1})
        assert resp.status_code == 422
        assert "stub" in resp.json()["detail"]

    def test_unknown_round_rejected(self):
        resp = client.post("/api/sceneit/match/create", json={
            "players": ["p1"], "round_types": ["nope"], "num_questions": 2, "seed": 1})
        assert resp.status_code == 422

    def test_custom_round_swaps_in_without_touching_core_loop(self):
        @register_round
        class EchoRound(RoundModule):
            round_type = "test_echo"
            display_name = "Echo (test)"

            def build_question(self, index, scene, content, rng):
                film = content.film(scene["film_id"])
                return Question(
                    question_id=f"q{index}_echo_{scene['scene_id']}",
                    round_type=self.round_type,
                    prompt="Echo?",
                    options=[{"option_id": scene["film_id"], "label": film["title"]},
                             {"option_id": "x", "label": "X"}],
                    correct_option_id=scene["film_id"],
                    media={"kind": "echo"},
                    content_refs={"film_id": scene["film_id"]},
                    provenance={"source": scene["source"], "license": scene["license"]},
                )

        try:
            m = _create(seed=5, round_types=["test_echo"], n=2)
            match = _matches[m["match_id"]]
            assert all(q.round_type == "test_echo" for q in match.questions)
            # full loop works with the swapped-in round
            r = client.post(f"/api/sceneit/match/{m['match_id']}/buzz",
                            json={"player_id": "p1"}).json()
            correct = match.questions[0].correct_option_id
            res = client.post(f"/api/sceneit/match/{m['match_id']}/answer",
                              json={"player_id": "p1", "option_id": correct}).json()
            assert res["correct"] is True and res["delta"] == r["locked_potential"]
        finally:
            ROUND_REGISTRY.pop("test_echo", None)

    def test_round_types_cycle_across_questions(self):
        m = _create(seed=9, round_types=["invisibles", "credit_roll"], n=4)
        types_ = [q.round_type for q in _matches[m["match_id"]].questions]
        assert types_ == ["invisibles", "credit_roll", "invisibles", "credit_roll"]


# ── Content provider: IP/license gate ──────────────────────────────────────

class TestContentProvenance:
    def test_every_film_scene_creator_has_source_and_license(self):
        content = get_default_provider()
        for film in content.films():
            assert film["source"] and film["license"], film["film_id"]
        for scene in content.scenes():
            assert scene["source"] and scene["license"], scene["scene_id"]
        for creator in content.creators():
            assert creator["source"] and creator["license"], creator["creator_id"]

    def test_datadump_meets_demo_content_bar(self):
        content = get_default_provider()
        assert len(content.films()) >= 12
        assert len(content.creators()) >= 15

    def test_unlicensed_item_raises(self):
        with pytest.raises(ContentLicenseError):
            require_shippable({"film_id": "film_pirate", "title": "Stolen"}, "film")

    def test_films_endpoint_exposes_provenance_for_qa(self):
        data = client.get("/api/sceneit/content/films").json()
        assert data["provider"] == "local_datadump_v1"
        assert all(f["source"] and f["license"] for f in data["films"])

    def test_every_question_carries_provenance(self):
        m = _create(seed=11, round_types=["invisibles", "frame_freeze", "credit_roll"], n=6)
        for q in _matches[m["match_id"]].questions:
            assert q.provenance["source"] and q.provenance["license"]


# ── Generated stills ───────────────────────────────────────────────────────

class TestStills:
    def test_still_endpoint_serves_svg_under_1mb(self):
        content = get_default_provider()
        for scene in content.scenes():
            resp = client.get(f"/api/sceneit/stills/{scene['scene_id']}.svg")
            assert resp.status_code == 200
            assert resp.headers["content-type"].startswith("image/svg+xml")
            assert len(resp.content) < 1_000_000  # hard rule: mock assets < 1MB

    def test_mask_variant_blanks_the_element(self):
        content = get_default_provider()
        scene = content.scenes()[0]
        masked_id = scene["still"]["invisibles_element"]
        plain = client.get(f"/api/sceneit/stills/{scene['scene_id']}.svg").text
        masked = client.get(f"/api/sceneit/stills/{scene['scene_id']}.svg?mask={masked_id}").text
        assert plain != masked
        assert "stroke-dasharray" in masked

    def test_reveal_stages_uncover_progressively(self):
        content = get_default_provider()
        scene = content.scenes()[0]
        covered_counts = []
        for stage in range(5):
            svg = client.get(f"/api/sceneit/stills/{scene['scene_id']}.svg?reveal={stage}").text
            covered_counts.append(svg.count('opacity="0.35"'))
        assert covered_counts == sorted(covered_counts, reverse=True)
        assert covered_counts[0] > covered_counts[-1]

    def test_still_render_is_deterministic(self):
        scene = get_default_provider().scenes()[0]
        assert render_still(scene) == render_still(scene)
        assert render_still(scene, mask="el_hoop") == render_still(scene, mask="el_hoop")

    def test_missing_scene_404(self):
        assert client.get("/api/sceneit/stills/sc_nope.svg").status_code == 404


# ── Match loop over HTTP: the buzz-in risk mechanic ───────────────────────

class TestBuzzInLoop:
    def test_options_hidden_until_buzz(self, clock):
        m = _create(seed=42)
        state = client.get(f"/api/sceneit/match/{m['match_id']}/state",
                           params={"player_id": "p1"}).json()
        assert "options" not in state["question"]
        assert state["potential"] == CFG.max_points
        buzz = client.post(f"/api/sceneit/match/{m['match_id']}/buzz",
                           json={"player_id": "p1"}).json()
        assert len(buzz["options"]) == 4
        # buzzer sees options in state; the other player still does not
        s1 = client.get(f"/api/sceneit/match/{m['match_id']}/state",
                        params={"player_id": "p1"}).json()
        s2 = client.get(f"/api/sceneit/match/{m['match_id']}/state",
                        params={"player_id": "p2"}).json()
        assert "options" in s1["question"] and "options" not in s2["question"]

    def test_countdown_decreases_potential_server_side(self, clock):
        m = _create(seed=42)
        clock.advance(10_000)
        state = client.get(f"/api/sceneit/match/{m['match_id']}/state").json()
        assert state["potential"] == BuzzRiskScoring().potential_at(10_000)
        buzz = client.post(f"/api/sceneit/match/{m['match_id']}/buzz",
                           json={"player_id": "p1"}).json()
        assert buzz["locked_potential"] == BuzzRiskScoring().potential_at(10_000)

    def test_correct_answer_awards_locked_potential(self, clock):
        m = _create(seed=42)
        mid = m["match_id"]
        clock.advance(4_000)
        buzz = client.post(f"/api/sceneit/match/{mid}/buzz", json={"player_id": "p1"}).json()
        clock.advance(2_000)  # inside 4s lock-in
        correct = _matches[mid].questions[0].correct_option_id
        res = client.post(f"/api/sceneit/match/{mid}/answer",
                          json={"player_id": "p1", "option_id": correct}).json()
        assert res["correct"] is True
        assert res["delta"] == buzz["locked_potential"]
        assert res["score_snapshot"]["p1"] == buzz["locked_potential"]
        assert res["question_resolved"] is True

    def test_wrong_buzz_loses_points(self, clock):
        m = _create(seed=42)
        mid = m["match_id"]
        buzz = client.post(f"/api/sceneit/match/{mid}/buzz", json={"player_id": "p1"}).json()
        clock.advance(1_000)
        wrong = next(o["option_id"] for o in buzz["options"]
                     if o["option_id"] != _matches[mid].questions[0].correct_option_id)
        res = client.post(f"/api/sceneit/match/{mid}/answer",
                          json={"player_id": "p1", "option_id": wrong}).json()
        assert res["correct"] is False
        assert res["delta"] == -round(buzz["locked_potential"] * CFG.wrong_buzz_penalty_ratio)
        assert res["score_snapshot"]["p1"] < 0
        # question stays open for the other player
        assert res["question_resolved"] is False

    def test_lock_in_expiry_penalizes(self, clock):
        m = _create(seed=42)
        mid = m["match_id"]
        client.post(f"/api/sceneit/match/{mid}/buzz", json={"player_id": "p1"})
        clock.advance(CFG.lock_in_ms + 500)  # blow the window
        correct = _matches[mid].questions[0].correct_option_id
        res = client.post(f"/api/sceneit/match/{mid}/answer",
                          json={"player_id": "p1", "option_id": correct}).json()
        assert res["timed_out"] is True and res["correct"] is False and res["delta"] < 0

    def test_buzz_contention_and_lockouts(self, clock):
        m = _create(seed=42)
        mid = m["match_id"]
        client.post(f"/api/sceneit/match/{mid}/buzz", json={"player_id": "p1"})
        # second buzz while p1 holds it
        assert client.post(f"/api/sceneit/match/{mid}/buzz",
                           json={"player_id": "p2"}).status_code == 409
        # p2 cannot answer p1's buzz
        assert client.post(f"/api/sceneit/match/{mid}/answer",
                           json={"player_id": "p2", "option_id": "x"}).status_code == 409
        # wrong answer locks p1 out of re-buzzing this question
        wrong = next(o["option_id"] for o in _matches[mid].questions[0].options
                     if o["option_id"] != _matches[mid].questions[0].correct_option_id)
        client.post(f"/api/sceneit/match/{mid}/answer",
                    json={"player_id": "p1", "option_id": wrong})
        assert client.post(f"/api/sceneit/match/{mid}/buzz",
                           json={"player_id": "p1"}).status_code == 409
        # p2 may now buzz
        assert client.post(f"/api/sceneit/match/{mid}/buzz",
                           json={"player_id": "p2"}).status_code == 200

    def test_next_advances_and_match_finishes(self, clock):
        m = _create(seed=42, n=2)
        mid = m["match_id"]
        r1 = client.post(f"/api/sceneit/match/{mid}/next").json()
        assert r1 == {"status": "active", "question_index": 1}
        r2 = client.post(f"/api/sceneit/match/{mid}/next").json()
        assert r2["status"] == "finished"
        state = client.get(f"/api/sceneit/match/{mid}/state").json()
        assert state["status"] == "finished"
        assert len(state["timeline"]) == 2  # both skipped questions on the reveal timeline

    def test_frame_freeze_presentation_is_server_timed(self, clock):
        m = _create(seed=8, round_types=["frame_freeze"], n=1)
        mid = m["match_id"]
        s0 = client.get(f"/api/sceneit/match/{mid}/state").json()
        assert s0["question"]["presentation"]["reveal_stage"] == 0
        clock.advance(9_000)
        s1 = client.get(f"/api/sceneit/match/{mid}/state").json()
        assert s1["question"]["presentation"]["reveal_stage"] == 2
        assert "reveal=2" in s1["question"]["presentation"]["still_url"]

    def test_credit_roll_lines_reveal_over_time(self, clock):
        m = _create(seed=8, round_types=["credit_roll"], n=1)
        mid = m["match_id"]
        s0 = client.get(f"/api/sceneit/match/{mid}/state").json()
        clock.advance(7_500)
        s1 = client.get(f"/api/sceneit/match/{mid}/state").json()
        assert s0["question"]["presentation"]["visible_count"] == 1
        assert s1["question"]["presentation"]["visible_count"] > 1
        # the film's own title never appears in rolled credits
        mq = _matches[mid].questions[0]
        title = get_default_provider().film(mq.correct_option_id)["title"].lower()
        assert all(title not in line.lower() for line in mq.media["credits"])


# ── Replay export + deterministic validation ───────────────────────────────

def _play_scripted_match(clock, seed=4242):
    """Two players, three questions: correct buzz, wrong buzz, skip."""
    m = _create(seed=seed, round_types=["invisibles", "credit_roll"], n=3)
    mid = m["match_id"]
    match = _matches[mid]
    # Q0: p1 buzzes at 3s, answers correctly
    clock.advance(3_000)
    client.post(f"/api/sceneit/match/{mid}/buzz", json={"player_id": "p1"})
    clock.advance(1_500)
    client.post(f"/api/sceneit/match/{mid}/answer",
                json={"player_id": "p1", "option_id": match.questions[0].correct_option_id})
    client.post(f"/api/sceneit/match/{mid}/next")
    # Q1: p2 buzzes late and answers wrong
    clock.advance(12_000)
    buzz = client.post(f"/api/sceneit/match/{mid}/buzz", json={"player_id": "p2"}).json()
    wrong = next(o["option_id"] for o in buzz["options"]
                 if o["option_id"] != match.questions[1].correct_option_id)
    clock.advance(2_000)
    client.post(f"/api/sceneit/match/{mid}/answer",
                json={"player_id": "p2", "option_id": wrong})
    client.post(f"/api/sceneit/match/{mid}/next")
    # Q2: nobody buzzes, skipped
    client.post(f"/api/sceneit/match/{mid}/next")
    return mid


class TestReplay:
    def test_export_shape_and_buzz_timestamps(self, clock):
        mid = _play_scripted_match(clock)
        data = client.get(f"/api/sceneit/match/{mid}/export-replay").json()
        meta = data["metadata"]
        for key in ("match_id", "mode_id", "seed", "round_types", "players",
                    "scoring", "question_count", "content_provider"):
            assert key in meta, f"missing metadata.{key}"
        types_present = {e["type"] for e in data["events"]}
        assert {"match_start", "question_start", "buzz", "answer",
                "question_result", "match_end"} <= types_present
        buzzes = [e for e in data["events"] if e["type"] == "buzz"]
        assert [b["elapsed_ms"] for b in buzzes] == [3_000, 12_000]

    def test_replay_validator_accepts_honest_export(self, clock):
        mid = _play_scripted_match(clock)
        data = client.get(f"/api/sceneit/match/{mid}/export-replay").json()
        assert validate_replay(data) == []

    def test_replay_validator_catches_tampered_score(self, clock):
        mid = _play_scripted_match(clock)
        data = client.get(f"/api/sceneit/match/{mid}/export-replay").json()
        for ev in data["events"]:
            if ev["type"] == "answer":
                ev["delta"] += 500  # score tampering
                break
        assert validate_replay(data), "validator must flag tampered delta"

    def test_replay_validator_catches_seed_drift(self, clock):
        mid = _play_scripted_match(clock)
        data = client.get(f"/api/sceneit/match/{mid}/export-replay").json()
        data["metadata"]["seed"] = data["metadata"]["seed"] + 1
        assert validate_replay(data), "validator must flag questions not derivable from seed"

    def test_export_is_stable_across_calls(self, clock):
        mid = _play_scripted_match(clock)
        d1 = client.get(f"/api/sceneit/match/{mid}/export-replay").json()
        d2 = client.get(f"/api/sceneit/match/{mid}/export-replay").json()
        assert d1 == d2


# ── Creator cards (CardModule seam) ────────────────────────────────────────

class TestCreatorCards:
    def test_creator_endpoint_returns_deep_dive_payload(self):
        card = client.get("/api/creators/cr_mara_quill").json()
        assert card["card_id"] == "card_cr_mara_quill"
        assert card["bio"] and card["timeline"] and card["facts"]
        assert card["lesson_stub"]["title"]
        assert {"film_id", "title", "year"} <= set(card["top_works"][0].keys())
        assert card["source"] and card["license"]

    def test_unknown_creator_404(self):
        assert client.get("/api/creators/cr_nobody").status_code == 404

    def test_collection_loop_is_explicit_stub(self):
        data = client.get("/api/creators/cr_mara_quill/collection",
                          params={"player_id": "p1"}).json()
        assert data["implemented"] is False

    def test_questions_link_to_creator_cards(self):
        m = _create(seed=3, n=4)
        for q in _matches[m["match_id"]].questions:
            assert q.content_refs["card_id"].startswith("card_cr_")
            creator_id = q.content_refs["creator_id"]
            assert client.get(f"/api/creators/{creator_id}").status_code == 200
