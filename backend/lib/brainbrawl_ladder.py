"""
brainbrawl_ladder.py — adaptive ELO ladder + smart-practice drills
(nexus/brainbrawl-ladder, stacks on nexus/brainbrawl-demo).

Pure, deterministic helpers layered on top of lib/brainbrawl.py. They add a
competitive ladder to Brain Brawl:

  * ELO rating   — a standard Elo update per answer. Each question carries an
                   implied "question rating" derived from its difficulty tier;
                   the player's rating moves toward beating that question. The
                   update is integer-rounded and fully replayable from
                   (prior_rating, question difficulty, credit fraction).

  * Adaptive     — the next question's target difficulty is derived from the
    difficulty   current rating band, so a rising player is fed harder
                 questions. Selection is deterministic given (seed, rating,
                 prior state): a seeded RNG samples the target-difficulty pool,
                 falling back to adjacent bands when a band is exhausted.

  * Drills       — from a player's per-skill accuracy history (question
                   taxonomy `skill` tags already ship in the bank), rank the
                   weakest skills and assemble deterministic drill sets that
                   target them. Powers GET /api/brainbrawl/practice-suggestions.

Everything here is a pure function of its inputs (plus the read-only question
bank), so a fixed seed + fixed prior state always reproduces the same rating,
the same next-question pick, and the same drill recommendations on every
platform. No answers are ever surfaced here — drill/ladder question payloads go
through bb.public_question, which strips answer/explanation/micro_lesson.
"""
import hashlib
import random
from typing import Any, Dict, List, Optional, Sequence

from lib import brainbrawl as bb


def _stable_seed(*parts: Any) -> int:
    """Derive a stable 64-bit int seed from arbitrary parts.

    Python's built-in hash() is salted per-process and tuple-seeding random.Random
    is deprecated (3.9+), so we hash a canonical string with sha256 for a seed
    that is identical on every process and platform.
    """
    canon = "|".join(str(p) for p in parts)
    return int.from_bytes(hashlib.sha256(canon.encode("utf-8")).digest()[:8], "big")


# ── Rating model ────────────────────────────────────────────────────────────

DEFAULT_RATING = 1200          # every new player starts here
RATING_FLOOR = 100
RATING_CEILING = 3000
K_FACTOR = 32                  # standard club-Elo K; larger => faster movement

# Implied rating of a question by difficulty tier. Beating a "hard" question
# (1600) from a 1200 start yields a big gain; missing an "easy" one costs a lot.
DIFFICULTY_RATING = {"easy": 1000, "medium": 1300, "hard": 1600}

# Ladder difficulty bands keyed off the player's current rating. The band names
# map onto the question-bank difficulty tiers. Ordered low -> high.
RATING_BANDS = [
    (0, 1150, "easy"),
    (1150, 1450, "medium"),
    (1450, RATING_CEILING + 1, "hard"),
]

# Fallback search order when a band's pool is empty, per target tier.
_TIER_FALLBACK = {
    "easy": ["easy", "medium", "hard"],
    "medium": ["medium", "easy", "hard"],
    "hard": ["hard", "medium", "easy"],
}


def question_rating(difficulty: str) -> int:
    """Implied Elo rating of a question from its difficulty tier."""
    return DIFFICULTY_RATING.get(difficulty, DIFFICULTY_RATING["medium"])


def expected_score(player_rating: float, opponent_rating: float) -> float:
    """Standard Elo expectation that `player` beats `opponent` (0..1)."""
    return 1.0 / (1.0 + 10.0 ** ((opponent_rating - player_rating) / 400.0))


def update_rating(prior_rating: int, difficulty: str, actual: float,
                  k: int = K_FACTOR) -> int:
    """One Elo update. `actual` is the score achieved against the question in
    [0,1] — 1.0 = full credit, 0.0 = miss, fractional = multi-select partial.

    Deterministic: `round(prior + k*(actual - expected))`, clamped to
    [RATING_FLOOR, RATING_CEILING]. Python's banker's rounding is stable across
    platforms, so a fixed (prior, difficulty, actual) always yields the same
    new rating.
    """
    actual = max(0.0, min(1.0, float(actual)))
    exp = expected_score(prior_rating, question_rating(difficulty))
    new_rating = prior_rating + k * (actual - exp)
    clamped = max(RATING_FLOOR, min(RATING_CEILING, int(round(new_rating))))
    return clamped


def credit_fraction(result: Dict[str, Any]) -> float:
    """Convert a bb.score_answer result into an Elo `actual` score in [0,1]."""
    denom = result.get("credit_denominator") or 0
    if denom <= 0:
        return 0.0
    return max(0.0, min(1.0, result["credit_numerator"] / denom))


def apply_answer(prior_rating: int, question: Dict[str, Any],
                 result: Dict[str, Any], k: int = K_FACTOR) -> Dict[str, Any]:
    """Fold one graded answer into the ladder rating.

    Returns a fully-explained delta record (deterministic given inputs) so the
    ladder round endpoint and the tests can both re-derive the rating trace.
    """
    difficulty = question.get("difficulty", "medium")
    actual = credit_fraction(result)
    q_rating = question_rating(difficulty)
    expected = expected_score(prior_rating, q_rating)
    new_rating = update_rating(prior_rating, difficulty, actual, k)
    return {
        "question_id": question["id"],
        "difficulty": difficulty,
        "question_rating": q_rating,
        "prior_rating": prior_rating,
        "expected_score": round(expected, 6),
        "actual_score": round(actual, 6),
        "new_rating": new_rating,
        "delta": new_rating - prior_rating,
        "k_factor": k,
    }


# ── Adaptive difficulty selection ───────────────────────────────────────────

def target_difficulty(rating: int) -> str:
    """Map a rating to the difficulty tier the ladder should serve next."""
    for lo, hi, tier in RATING_BANDS:
        if lo <= rating < hi:
            return tier
    # rating at/above ceiling -> hardest tier
    return RATING_BANDS[-1][2]


def _pool_by_difficulty(mode: str, category: Optional[str],
                        doc: Optional[Dict[str, Any]]) -> Dict[str, List[str]]:
    """Sorted question-id pools per difficulty tier for a mode/category."""
    pools: Dict[str, List[str]] = {"easy": [], "medium": [], "hard": []}
    for q in bb.eligible_questions(mode, category, doc):
        pools.setdefault(q["difficulty"], []).append(q["id"])
    for tier in pools:
        pools[tier] = sorted(pools[tier])
    return pools


def select_adaptive_question(rating: int, seed: int, mode: str = "blitz",
                             category: Optional[str] = None,
                             exclude: Optional[Sequence[str]] = None,
                             doc: Optional[Dict[str, Any]] = None) -> Optional[str]:
    """Deterministically pick the next ladder question id for a player.

    Difficulty tier is derived from `rating`; within the tier a seeded RNG
    samples the (sorted) eligible pool, minus anything in `exclude` (already
    served this session). Falls back to adjacent tiers when the target tier is
    exhausted, preserving determinism. Returns None if nothing remains.

    Given the same (rating, seed, mode, category, exclude) this always returns
    the same id.
    """
    doc = doc or bb.load_content()
    excluded = set(exclude or ())
    pools = _pool_by_difficulty(mode, category, doc)
    tier = target_difficulty(rating)
    rng = random.Random(_stable_seed(seed, rating, len(excluded)))
    for candidate_tier in _TIER_FALLBACK[tier]:
        available = [qid for qid in pools.get(candidate_tier, []) if qid not in excluded]
        if available:
            return rng.choice(available)
    return None


def band_summary(rating: int) -> Dict[str, Any]:
    """Client-safe description of the player's ladder standing."""
    tier = target_difficulty(rating)
    lo, hi = next((lo, hi) for lo, hi, t in RATING_BANDS if t == tier)
    return {
        "rating": rating,
        "target_difficulty": tier,
        "band_floor": lo,
        "band_ceiling": min(hi, RATING_CEILING),
        "default_rating": DEFAULT_RATING,
    }


# ── Smart-practice drills (weakest-skill targeting) ─────────────────────────

MIN_ATTEMPTS_FOR_RANKING = 1   # a skill needs >=1 attempt before we rank it


def rank_weak_skills(history: Dict[str, Dict[str, int]],
                     min_attempts: int = MIN_ATTEMPTS_FOR_RANKING) -> List[Dict[str, Any]]:
    """Rank a player's skills weakest-first from an accuracy history.

    `history` maps skill -> {"attempts": int, "correct": int}. Skills with fewer
    than `min_attempts` attempts are excluded (not enough signal). Ordering:
    lowest accuracy first; ties broken by MORE attempts (more evidence of a real
    weakness), then skill name for a fully stable, deterministic order.
    """
    ranked: List[Dict[str, Any]] = []
    for skill, stats in history.items():
        attempts = int(stats.get("attempts", 0))
        correct = int(stats.get("correct", 0))
        if attempts < min_attempts:
            continue
        accuracy = correct / attempts if attempts else 0.0
        ranked.append({
            "skill": skill,
            "attempts": attempts,
            "correct": correct,
            "accuracy": round(accuracy, 6),
        })
    ranked.sort(key=lambda r: (r["accuracy"], -r["attempts"], r["skill"]))
    return ranked


def _questions_for_skill(skill: str, mode: Optional[str],
                         doc: Dict[str, Any]) -> List[Dict[str, Any]]:
    qs = [q for q in doc["questions"] if q["taxonomy"].get("skill") == skill]
    if mode:
        qs = [q for q in qs if mode in q.get("modes", [])]
    return sorted(qs, key=lambda q: q["id"])


def practice_suggestions(history: Dict[str, Dict[str, int]],
                         seed: int = 0,
                         top_skills: int = 3,
                         drill_size: int = 5,
                         mode: Optional[str] = "blitz",
                         min_attempts: int = MIN_ATTEMPTS_FOR_RANKING,
                         doc: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """Build deterministic drill sets that target a player's weakest skills.

    For each of the `top_skills` weakest skills we assemble a drill of up to
    `drill_size` client-safe questions (answers stripped) tagged with that
    skill. Question choice is a seeded sample of the (sorted) skill pool, so a
    fixed (history, seed) reproduces the same drills.
    """
    doc = doc or bb.load_content()
    weak = rank_weak_skills(history, min_attempts=min_attempts)
    drills: List[Dict[str, Any]] = []
    for entry in weak[:max(0, top_skills)]:
        skill = entry["skill"]
        pool = _questions_for_skill(skill, mode, doc)
        if not pool:
            continue
        rng = random.Random(_stable_seed(seed, skill))
        take = min(drill_size, len(pool))
        picked = rng.sample(pool, take)
        # keep a stable presentation order (by id) for the returned drill
        picked = sorted(picked, key=lambda q: q["id"])
        drills.append({
            "skill": skill,
            "accuracy": entry["accuracy"],
            "attempts": entry["attempts"],
            "correct": entry["correct"],
            "reason": f"{entry['correct']}/{entry['attempts']} correct "
                      f"({round(entry['accuracy'] * 100)}%) — recommended drill",
            "question_count": len(picked),
            "questions": [
                bb.public_question(q, i, bb.MODES.get(mode or "blitz", bb.MODES["blitz"])["time_limit_ms"])
                for i, q in enumerate(picked)
            ],
        })
    return {
        "weak_skills": weak,
        "drills": drills,
        "params": {
            "seed": seed,
            "top_skills": top_skills,
            "drill_size": drill_size,
            "mode": mode,
            "min_attempts": min_attempts,
        },
    }
