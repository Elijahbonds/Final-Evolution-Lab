"""
Brain Brawl round engine tests (nexus/brainbrawl-demo).

Covers:
  * content seeding / import (schema, taxonomy, size, no leakage)
  * scoring determinism (fixed seed + fixed inputs -> identical score, twice)
  * answer-secrecy (no correct indices / explanations before resolution)
  * multi-select partial credit
  * replay export round-trip through tools/replay_validator.py
  * latency-normalization tie-break
  * Deep Dive micro-lesson payload + recording-pack gating

Run: cd backend && MOCK_DB=1 python3 -m pytest tests/test_brainbrawl.py -q
"""
import copy
import json
import os
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

os.environ.setdefault("MOCK_DB", "1")

from server import app  # noqa: E402
from lib import brainbrawl as bb  # noqa: E402
from tools.replay_validator import validate_replay  # noqa: E402

client = TestClient(app)

SEED = 1234567890123456789  # fixed 64-bit seed for deterministic assertions
FIXED_INPUTS = [
    # (response_ms, latency_ms) per question; answers chosen below.
    # All response_ms stay under the server's 1500 ms transport-grace window so
    # the server-elapsed clamp never binds and scores are exactly reproducible
    # regardless of test-machine speed (see routers/brainbrawl.py submit_answer).
    (1200, 40), (1400, 40), (900, 40), (1300, 40), (700, 40),
]


def _play_round(seed=SEED, mode="blitz", count=5, answer_strategy="correct"):
    """Drive a full round over HTTP; returns (round_id, final_score, responses)."""
    r = client.post("/api/brainbrawl/rounds/start", json={
        "mode": mode, "seed": seed, "question_count": count,
        "player_id": "tester_a",
    })
    assert r.status_code == 200, r.text
    data = r.json()
    round_id = data["round_id"]
    question = data["question"]
    doc = bb.load_content()
    responses = []
    i = 0
    while question is not None:
        q_full = bb.question_by_id(question["id"], doc)
        if answer_strategy == "correct":
            selected = list(q_full["answer"])
        elif answer_strategy == "wrong":
            selected = [next(j for j in range(len(q_full["options"]))
                             if j not in q_full["answer"])]
        else:
            selected = []
        resp_ms, lat_ms = FIXED_INPUTS[i % len(FIXED_INPUTS)]
        r = client.post(f"/api/brainbrawl/rounds/{round_id}/answer", json={
            "question_index": question["index"],
            "selected": selected,
            "response_ms": resp_ms,
            "latency_ms": lat_ms,
            "client_ts": 1700000000.0 + i,
        })
        assert r.status_code == 200, r.text
        payload = r.json()
        responses.append(payload)
        question = payload["next_question"]
        i += 1
    return round_id, responses[-1]["score"], responses


# ── Content seeding / import ────────────────────────────────────────────────

class TestContentSeeding:
    def test_bank_loads_with_expected_volume(self):
        doc = bb.load_content()
        assert doc["question_count"] == len(doc["questions"])
        assert len(doc["questions"]) >= 90  # ~100 target

    def test_every_question_has_required_taxonomy_fields(self):
        for q in bb.load_content()["questions"]:
            assert q["type"] in ("single", "multi")
            assert q["difficulty"] in ("easy", "medium", "hard")
            assert q["taxonomy"]["category"] and q["taxonomy"]["skill"]
            assert q["source"] and q["license"]
            assert len(q["options"]) >= 2
            assert q["answer"] and all(0 <= a < len(q["options"]) for a in q["answer"])
            assert set(q["modes"]) & {"blitz", "deep_dive"}

    def test_deep_dive_pool_has_explanations_and_micro_lessons(self):
        pool = bb.eligible_questions("deep_dive")
        assert len(pool) >= 5
        for q in pool:
            assert q.get("explanation")
            assert q.get("micro_lesson", {}).get("title")
            assert q.get("micro_lesson", {}).get("takeaway")

    def test_music_and_dance_taxonomy_present(self):
        """Coordinator scope: music/dance taxonomy for themed packs; demo
        content must not reference real artists/songs (original CC0 items)."""
        qs = bb.load_content()["questions"]
        music = [q for q in qs if q["taxonomy"]["category"] == "music"]
        dance = [q for q in qs if q["taxonomy"]["category"] == "dance"]
        assert len(music) >= 4 and len(dance) >= 3
        for q in music + dance:
            assert q["id"].startswith("fel_"), "music/dance must be FEL originals"
            assert q["license"] == "CC0-1.0"
        # at least one deep-dive explainable in each themed pool
        assert any("deep_dive" in q["modes"] for q in music)
        assert any("deep_dive" in q["modes"] for q in dance)

    def test_category_filtered_round_only_serves_that_category(self):
        order = bb.derive_question_order(SEED, "blitz", 10, category="music")
        doc = bb.load_content()
        assert order, "music pack must be startable"
        assert all(bb.question_by_id(qid, doc)["taxonomy"]["category"] == "music"
                   for qid in order)
        r = client.post("/api/brainbrawl/rounds/start",
                        json={"mode": "blitz", "seed": SEED, "category": "dance",
                              "question_count": 3})
        assert r.status_code == 200
        assert r.json()["question"]["taxonomy"]["category"] == "dance"

    def test_content_summary_endpoint_has_no_answers(self):
        r = client.get("/api/brainbrawl/content/summary")
        assert r.status_code == 200
        body = r.text.lower()
        assert '"answer"' not in body and '"correct_answer"' not in body
        assert r.json()["question_count"] >= 90


# ── Server-authoritative answer secrecy ─────────────────────────────────────

class TestAnswerSecrecy:
    def test_start_payload_never_leaks_answers(self):
        r = client.post("/api/brainbrawl/rounds/start",
                        json={"mode": "blitz", "seed": SEED, "question_count": 5})
        assert r.status_code == 200
        q = r.json()["question"]
        for forbidden in ("answer", "correct_answer", "explanation", "micro_lesson"):
            assert forbidden not in q
        # and nowhere in the raw payload either
        assert '"answer"' not in r.text and '"explanation"' not in r.text

    def test_answer_reveal_only_after_resolution(self):
        _, _, responses = _play_round(count=2)
        for resp in responses:
            assert resp["result"]["correct_answer"] is not None
            nq = resp["next_question"]
            if nq is not None:
                assert "answer" not in nq and "explanation" not in nq

    def test_out_of_order_answers_rejected(self):
        r = client.post("/api/brainbrawl/rounds/start",
                        json={"mode": "blitz", "seed": SEED, "question_count": 3})
        rid = r.json()["round_id"]
        bad = client.post(f"/api/brainbrawl/rounds/{rid}/answer",
                          json={"question_index": 2, "selected": [0], "response_ms": 100})
        assert bad.status_code == 409


# ── Scoring determinism ─────────────────────────────────────────────────────

class TestScoringDeterminism:
    def test_same_seed_same_inputs_same_score(self):
        rid1, score1, resp1 = _play_round()
        rid2, score2, resp2 = _play_round()
        assert rid1 != rid2
        assert score1 == score2 > 0
        assert [r["result"]["points"] for r in resp1] == \
               [r["result"]["points"] for r in resp2]

    def test_seed_drives_question_order(self):
        order_a = bb.derive_question_order(SEED, "blitz", 10)
        order_b = bb.derive_question_order(SEED, "blitz", 10)
        order_c = bb.derive_question_order(SEED + 1, "blitz", 10)
        assert order_a == order_b
        assert order_a != order_c
        # HTTP round presents exactly that order
        r = client.post("/api/brainbrawl/rounds/start",
                        json={"mode": "blitz", "seed": SEED, "question_count": 10})
        assert r.json()["question"]["id"] == order_a[0]

    def test_faster_correct_answer_scores_more(self):
        q = {"id": "x", "type": "single", "answer": [1], "difficulty": "medium"}
        fast = bb.score_answer(q, [1], 1000, 0, 10_000, 0)
        slow = bb.score_answer(q, [9000], 9000, 0, 10_000, 0)  # wrong+slow: 0
        slow_correct = bb.score_answer(q, [1], 9000, 0, 10_000, 0)
        assert fast["points"] > slow_correct["points"] > 0
        assert slow["points"] == 0

    def test_streak_bonus_applies_and_caps(self):
        q = {"id": "x", "type": "single", "answer": [0], "difficulty": "easy"}
        no_streak = bb.score_answer(q, [0], 2000, 0, 10_000, 0)
        streak3 = bb.score_answer(q, [0], 2000, 0, 10_000, 3)
        streak9 = bb.score_answer(q, [0], 2000, 0, 10_000, 9)
        assert streak3["points"] == no_streak["points"] + (no_streak["raw_points"] * 30) // 100
        assert streak9["streak_bonus"] == (no_streak["raw_points"] * 50) // 100  # capped

    def test_wrong_answer_resets_streak(self):
        q = {"id": "x", "type": "single", "answer": [0], "difficulty": "easy"}
        res = bb.score_answer(q, [1], 2000, 0, 10_000, 4)
        assert res["points"] == 0 and res["streak_after"] == 0


# ── Multi-select partial credit ─────────────────────────────────────────────

class TestPartialCredit:
    Q = {"id": "m", "type": "multi", "answer": [0, 2, 3], "difficulty": "medium"}

    def test_full_selection_full_credit(self):
        res = bb.score_answer(self.Q, [0, 2, 3], 0, 0, 10_000, 0)
        assert res["full_correct"] and res["points"] == 150

    def test_partial_selection_partial_credit(self):
        res = bb.score_answer(self.Q, [0, 2], 0, 0, 10_000, 0)
        assert not res["full_correct"]
        assert res["points"] == (150 * 2) // 3
        assert res["streak_after"] == 0  # partial does not extend streak

    def test_wrong_picks_cancel_hits(self):
        res = bb.score_answer(self.Q, [0, 1, 2, 4], 0, 0, 10_000, 0)  # 2 hits - 2 wrong
        assert res["points"] == 0

    def test_schema_supports_multi_select_over_http(self):
        doc = bb.load_content()
        multi = [q for q in doc["questions"] if q["type"] == "multi"]
        assert len(multi) >= 3


# ── Replay round-trip ───────────────────────────────────────────────────────

class TestReplayRoundTrip:
    def _export(self, rid):
        r = client.get(f"/api/brainbrawl/rounds/{rid}/export-replay")
        assert r.status_code == 200
        return r.json()

    def test_replay_validates_clean(self):
        rid, _, _ = _play_round()
        replay = self._export(rid)
        assert replay["metadata"]["seed"] == SEED
        assert replay["metadata"]["content_hash"] == bb.content_hash()
        # original inputs (client timestamps + answers) present
        answers = [e for e in replay["events"] if e["type"] == "answer_result"]
        assert answers and all(e["inputs"]["client_ts"] is not None for e in answers)
        assert validate_replay(replay) == []

    def test_tampered_points_detected(self):
        rid, _, _ = _play_round()
        replay = self._export(rid)
        tampered = copy.deepcopy(replay)
        for ev in tampered["events"]:
            if ev["type"] == "answer_result":
                ev["points"] += 500
                break
        assert validate_replay(tampered) != []

    def test_tampered_question_order_detected(self):
        rid, _, _ = _play_round()
        tampered = copy.deepcopy(self._export(rid))
        presented = [e for e in tampered["events"] if e["type"] == "question_presented"]
        presented[0]["question_id"], presented[1]["question_id"] = \
            presented[1]["question_id"], presented[0]["question_id"]
        assert any("order" in e for e in validate_replay(tampered))

    def test_tampered_final_score_detected(self):
        rid, _, _ = _play_round()
        tampered = copy.deepcopy(self._export(rid))
        for ev in tampered["events"]:
            if ev["type"] == "round_end":
                ev["score"]["tester_a"] += 1
        assert any("round_end" in e for e in validate_replay(tampered))

    def test_replay_file_round_trip(self, tmp_path):
        """Full disk round-trip exactly as the CLI validator consumes it."""
        rid, _, _ = _play_round()
        path = tmp_path / f"replay_{rid}.json"
        path.write_text(json.dumps(self._export(rid)))
        assert validate_replay(json.loads(path.read_text())) == []


# ── Latency-normalization tie-break ─────────────────────────────────────────

class TestLatencyTieBreak:
    def test_latency_credit_normalizes_response_time(self):
        # same wall-clock response, but player B reports 300ms latency
        assert bb.normalize_response_ms(2000, 0, 10_000) == 2000
        assert bb.normalize_response_ms(2000, 300, 10_000) == 1700
        assert bb.normalize_response_ms(2000, 999_999, 10_000) == 0  # capped credit

    def test_tie_broken_by_lower_normalized_time(self):
        standings = bb.resolve_standings([
            {"player_id": "laggy_but_fast", "score": 500, "total_normalized_ms": 4200},
            {"player_id": "low_ping_slow", "score": 500, "total_normalized_ms": 6100},
            {"player_id": "third", "score": 300, "total_normalized_ms": 1000},
        ])
        assert [s["player_id"] for s in standings] == \
               ["laggy_but_fast", "low_ping_slow", "third"]
        assert standings[1]["tie_break"] == "latency_normalized_time"
        assert [s["rank"] for s in standings] == [1, 2, 3]

    def test_equal_latency_equal_score_stable_order(self):
        standings = bb.resolve_standings([
            {"player_id": "b", "score": 100, "total_normalized_ms": 1000},
            {"player_id": "a", "score": 100, "total_normalized_ms": 1000},
        ])
        assert [s["player_id"] for s in standings] == ["a", "b"]


# ── Deep Dive mode ──────────────────────────────────────────────────────────

class TestDeepDive:
    def test_deep_dive_single_explainable_question(self):
        r = client.post("/api/brainbrawl/rounds/start",
                        json={"mode": "deep_dive", "seed": SEED})
        assert r.status_code == 200
        data = r.json()
        assert data["question_count"] == 1
        assert 30_000 <= data["time_limit_ms"] <= 60_000
        q = data["question"]
        assert "explanation" not in q and "micro_lesson" not in q
        # answer it -> micro-lesson payload revealed
        doc = bb.load_content()
        full = bb.question_by_id(q["id"], doc)
        ans = client.post(f"/api/brainbrawl/rounds/{data['round_id']}/answer", json={
            "question_index": 0, "selected": list(full["answer"]),
            "response_ms": 12_000, "latency_ms": 50, "client_ts": 1700000000.0,
        })
        result = ans.json()["result"]
        assert result["explanation"]
        assert result["micro_lesson"]["title"] and result["micro_lesson"]["takeaway"]
        assert ans.json()["status"] == "finished"

    def test_deep_dive_replay_validates(self):
        rid, _, _ = _play_round(mode="deep_dive", count=1)
        r = client.get(f"/api/brainbrawl/rounds/{rid}/export-replay")
        assert validate_replay(r.json()) == []


# ── Recording pack gating ───────────────────────────────────────────────────

class TestRecordingPack:
    def test_forbidden_without_env(self, monkeypatch):
        monkeypatch.delenv("RECORDING_LOCAL", raising=False)
        r = client.get("/api/brainbrawl/recording-pack?mode=blitz&seed=42")
        assert r.status_code == 403

    def test_allowed_with_env_and_deterministic(self, monkeypatch):
        monkeypatch.setenv("RECORDING_LOCAL", "1")
        r1 = client.get("/api/brainbrawl/recording-pack?mode=blitz&seed=42&count=5")
        r2 = client.get("/api/brainbrawl/recording-pack?mode=blitz&seed=42&count=5")
        assert r1.status_code == 200
        assert [q["id"] for q in r1.json()["questions"]] == \
               [q["id"] for q in r2.json()["questions"]]
        assert all("answer" in q for q in r1.json()["questions"])
        assert r1.json()["seed"] == 42
