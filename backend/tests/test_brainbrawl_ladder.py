"""
Brain Brawl adaptive ELO ladder + smart-practice tests
(nexus/brainbrawl-ladder, stacks on nexus/brainbrawl-demo / PR #126).

Covers:
  * ELO update math + determinism (fixed prior/difficulty/actual -> identical
    new rating, twice; direction/magnitude of standard Elo)
  * adaptive difficulty selection (rating band -> difficulty tier, deterministic
    pick given seed + rating, exhaustion fallback, no repeats)
  * weakest-skill ranking correctness + drill recommendation (deterministic,
    answers never leaked)
  * end-to-end ladder progression over HTTP: winning raises rating and pulls
    harder questions; the run stays fully replayable / no answers pre-resolution.

Run: cd backend && MOCK_DB=1 python3 -m pytest tests/test_brainbrawl_ladder.py -q
"""
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
from lib import brainbrawl_ladder as ladder  # noqa: E402

client = TestClient(app)


# ── ELO update math + determinism ───────────────────────────────────────────

def test_expected_score_symmetry_and_bounds():
    # Equal ratings -> 50/50.
    assert ladder.expected_score(1200, 1200) == pytest.approx(0.5)
    # Underdog vs a much stronger opponent (question) -> low expectation.
    assert ladder.expected_score(1200, 1600) < 0.1
    # Favourite vs a much weaker opponent -> high expectation.
    assert ladder.expected_score(1600, 1200) > 0.9
    # Expectations of the two sides sum to 1.
    a = ladder.expected_score(1200, 1450)
    b = ladder.expected_score(1450, 1200)
    assert a + b == pytest.approx(1.0)


def test_update_rating_direction_and_magnitude():
    # Beating a hard question (implied 1600) from 1200 is a big upset -> big gain.
    assert ladder.update_rating(1200, "hard", 1.0) == 1229
    # Missing an easy question (implied 1000) from 1200 -> meaningful loss.
    assert ladder.update_rating(1200, "easy", 0.0) == 1176
    # Beating an easy question you were expected to win -> small gain.
    assert ladder.update_rating(1200, "easy", 1.0) == 1208
    # Winning always gains, missing always loses, for every tier.
    for tier in ("easy", "medium", "hard"):
        assert ladder.update_rating(1200, tier, 1.0) > 1200
        assert ladder.update_rating(1200, tier, 0.0) < 1200


def test_update_rating_is_deterministic():
    for _ in range(50):
        assert ladder.update_rating(1337, "medium", 0.5) == ladder.update_rating(1337, "medium", 0.5)


def test_rating_clamped_to_bounds():
    # Repeated losses can never fall below the floor.
    r = ladder.DEFAULT_RATING
    for _ in range(500):
        r = ladder.update_rating(r, "easy", 0.0)
    assert r >= ladder.RATING_FLOOR
    # Repeated wins can never exceed the ceiling.
    r = ladder.DEFAULT_RATING
    for _ in range(500):
        r = ladder.update_rating(r, "hard", 1.0)
    assert r <= ladder.RATING_CEILING


def test_partial_credit_maps_to_fractional_actual():
    result = {"credit_numerator": 1, "credit_denominator": 2}
    assert ladder.credit_fraction(result) == pytest.approx(0.5)
    assert ladder.credit_fraction({"credit_numerator": 0, "credit_denominator": 0}) == 0.0


def test_apply_answer_trace_is_pure():
    q = {"id": "q1", "difficulty": "hard"}
    result = {"credit_numerator": 1, "credit_denominator": 1}
    a = ladder.apply_answer(1200, q, result)
    b = ladder.apply_answer(1200, q, result)
    assert a == b
    assert a["new_rating"] == 1229
    assert a["delta"] == 29
    assert a["prior_rating"] == 1200


# ── Adaptive difficulty selection ───────────────────────────────────────────

def test_target_difficulty_bands():
    assert ladder.target_difficulty(900) == "easy"
    assert ladder.target_difficulty(1149) == "easy"
    assert ladder.target_difficulty(1150) == "medium"
    assert ladder.target_difficulty(1449) == "medium"
    assert ladder.target_difficulty(1450) == "hard"
    assert ladder.target_difficulty(2999) == "hard"


def test_adaptive_pick_matches_target_tier():
    doc = bb.load_content()
    low = ladder.select_adaptive_question(300, seed=42, exclude=[], doc=doc)
    high = ladder.select_adaptive_question(1800, seed=42, exclude=[], doc=doc)
    assert bb.question_by_id(low, doc)["difficulty"] == "easy"
    assert bb.question_by_id(high, doc)["difficulty"] == "hard"
    mid = ladder.select_adaptive_question(1300, seed=42, exclude=[], doc=doc)
    assert bb.question_by_id(mid, doc)["difficulty"] == "medium"


def test_adaptive_pick_is_deterministic():
    for _ in range(20):
        a = ladder.select_adaptive_question(1250, seed=99, exclude=["x"])
        b = ladder.select_adaptive_question(1250, seed=99, exclude=["x"])
        assert a == b


def test_adaptive_pick_excludes_served_no_repeats():
    seen = []
    rating = 1300
    for _ in range(25):
        qid = ladder.select_adaptive_question(rating, seed=7, exclude=seen)
        if qid is None:
            break
        assert qid not in seen
        seen.append(qid)
    assert len(seen) == len(set(seen))


def test_adaptive_fallback_when_tier_exhausted():
    doc = bb.load_content()
    # Exhaust every easy question; a low-rated player must then fall back.
    easy_ids = [q["id"] for q in bb.eligible_questions("blitz", None, doc)
                if q["difficulty"] == "easy"]
    qid = ladder.select_adaptive_question(300, seed=1, exclude=easy_ids, doc=doc)
    assert qid is not None
    assert bb.question_by_id(qid, doc)["difficulty"] in ("medium", "hard")


# ── Weakest-skill ranking + drills ──────────────────────────────────────────

def test_rank_weak_skills_orders_by_accuracy():
    hist = {
        "recall": {"attempts": 10, "correct": 9},       # 90%
        "analysis": {"attempts": 5, "correct": 1},       # 20%
        "explanation": {"attempts": 4, "correct": 2},    # 50%
    }
    order = [w["skill"] for w in ladder.rank_weak_skills(hist)]
    assert order == ["analysis", "explanation", "recall"]


def test_rank_weak_skills_tiebreak_by_attempts_then_name():
    hist = {
        "b_skill": {"attempts": 2, "correct": 1},   # 50%, 2 attempts
        "a_skill": {"attempts": 8, "correct": 4},   # 50%, 8 attempts
        "c_skill": {"attempts": 8, "correct": 4},   # 50%, 8 attempts
    }
    order = [w["skill"] for w in ladder.rank_weak_skills(hist)]
    # more attempts first (stronger evidence), then name for stability
    assert order == ["a_skill", "c_skill", "b_skill"]


def test_rank_weak_skills_min_attempts_filter():
    hist = {"recall": {"attempts": 0, "correct": 0}}
    assert ladder.rank_weak_skills(hist, min_attempts=1) == []


def test_practice_suggestions_deterministic_and_targets_weakest():
    hist = {
        "recall": {"attempts": 10, "correct": 9},
        "analysis": {"attempts": 6, "correct": 1},
        "explanation": {"attempts": 5, "correct": 2},
    }
    a = ladder.practice_suggestions(hist, seed=123, top_skills=2, drill_size=3)
    b = ladder.practice_suggestions(hist, seed=123, top_skills=2, drill_size=3)
    assert a == b
    drilled = [d["skill"] for d in a["drills"]]
    # weakest two skills that have a question pool are drilled, weakest first
    assert drilled[0] == "analysis"
    assert "recall" not in drilled  # strongest skill is not drilled


def test_practice_suggestions_never_leak_answers():
    hist = {"recall": {"attempts": 4, "correct": 1}}
    out = ladder.practice_suggestions(hist, seed=1, top_skills=1, drill_size=4)
    for drill in out["drills"]:
        assert drill["questions"], "expected a non-empty drill"
        for q in drill["questions"]:
            assert "answer" not in q
            assert "explanation" not in q
            assert "micro_lesson" not in q


# ── End-to-end ladder progression over HTTP ─────────────────────────────────

def _correct_selection(qid):
    return list(bb.question_by_id(qid)["answer"])


def _play_ladder(seed, player_id, count=8, strategy="correct"):
    r = client.post("/api/brainbrawl/ladder/start", json={
        "player_id": player_id, "seed": seed, "question_count": count,
    })
    assert r.status_code == 200, r.text
    data = r.json()
    round_id = data["round_id"]
    question = data["question"]
    ratings = [data["ladder"]["rating"]]
    difficulties = []
    while question is not None:
        difficulties.append(question["difficulty"])
        qid = question["id"]
        if strategy == "correct":
            selected = _correct_selection(qid)
        else:
            selected = []  # always wrong
        ans = client.post(f"/api/brainbrawl/ladder/{round_id}/answer", json={
            "question_index": question["index"], "selected": selected,
            "response_ms": 1200, "latency_ms": 40,
        })
        assert ans.status_code == 200, ans.text
        payload = ans.json()
        ratings.append(payload["ladder"]["rating"])
        question = payload["next_question"]
    return round_id, ratings, difficulties, payload


def test_ladder_progression_winner_climbs_and_gets_harder():
    round_id, ratings, difficulties, final = _play_ladder(
        seed=2024, player_id="climber", count=10, strategy="correct")
    # rating strictly rose overall for a perfect run
    assert ratings[-1] > ratings[0]
    assert final["status"] == "finished"
    # the served difficulty is a non-decreasing function of the rising rating:
    # every question is at least as hard as the tier the *starting* rating maps
    # to, and the last question is at least as hard as the first.
    order = {"easy": 0, "medium": 1, "hard": 2}
    start_tier = ladder.target_difficulty(ratings[0])
    for d in difficulties:
        assert order[d] >= order[start_tier]
    assert order[difficulties[-1]] >= order[difficulties[0]]


def test_ladder_winner_crosses_a_band_boundary():
    # A long perfect run from the default rating must cross from the medium band
    # into the hard band, at which point hard questions start being served.
    _, ratings, difficulties, final = _play_ladder(
        seed=4242, player_id="grinder", count=25, strategy="correct")
    assert ladder.target_difficulty(ratings[0]) == "medium"
    assert ratings[-1] >= ladder.RATING_BANDS[2][0]  # reached the hard band floor
    assert "hard" in difficulties


def test_ladder_loser_drops_and_stays_easy():
    _, ratings, difficulties, final = _play_ladder(
        seed=2024, player_id="faller", count=8, strategy="wrong")
    assert ratings[-1] < ratings[0]
    # a losing player is never pushed up into the hard tier
    assert "hard" not in difficulties


def test_ladder_rating_persists_across_runs():
    client.post("/api/brainbrawl/ladder/start", json={"player_id": "persist_me", "seed": 5, "question_count": 3})
    # play a full winning run
    _play_ladder(seed=11, player_id="persist_me", count=5, strategy="correct")
    r = client.get("/api/brainbrawl/ladder/rating", params={"player_id": "persist_me"})
    assert r.status_code == 200
    rating1 = r.json()["rating"]
    assert rating1 > ladder.DEFAULT_RATING
    # a second winning run starts from the raised rating
    start = client.post("/api/brainbrawl/ladder/start",
                        json={"player_id": "persist_me", "seed": 12, "question_count": 3}).json()
    assert start["ladder"]["rating"] == rating1


def test_ladder_answer_never_ships_answer_pre_resolution():
    start = client.post("/api/brainbrawl/ladder/start",
                        json={"player_id": "secret", "seed": 3, "question_count": 4}).json()
    q = start["question"]
    assert "answer" not in q and "explanation" not in q and "micro_lesson" not in q


def test_ladder_deterministic_same_seed_same_play():
    r1 = _play_ladder(seed=777, player_id="det_a", count=6, strategy="correct")
    r2 = _play_ladder(seed=777, player_id="det_b", count=6, strategy="correct")
    # same seed + identical correct play -> identical rating trace + difficulty order
    assert r1[1] == r2[1]
    assert r1[2] == r2[2]


def test_practice_suggestions_endpoint_after_ladder_play():
    # Build a skewed history: this player answers, accruing per-skill accuracy.
    _play_ladder(seed=555, player_id="drill_me", count=10, strategy="wrong")
    r = client.get("/api/brainbrawl/practice-suggestions",
                   params={"player_id": "drill_me", "seed": 0, "top_skills": 3})
    assert r.status_code == 200
    body = r.json()
    assert body["player_id"] == "drill_me"
    assert "weak_skills" in body and "drills" in body
    # deterministic: same params -> identical payload
    r2 = client.get("/api/brainbrawl/practice-suggestions",
                    params={"player_id": "drill_me", "seed": 0, "top_skills": 3})
    assert r2.json() == body
    # no answers leaked through the endpoint either
    for drill in body["drills"]:
        for q in drill["questions"]:
            assert "answer" not in q
