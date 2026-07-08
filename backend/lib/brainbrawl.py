"""
brainbrawl.py — Brain Brawl round engine (nexus/brainbrawl-demo).

Pure, deterministic functions shared by the API router
(routers/brainbrawl.py), the replay validator (tools/replay_validator.py),
and the test suite. All scoring is integer math so a fixed seed + fixed
inputs always reproduces the exact same score on every platform.

Modes:
  blitz     — 10 s per question, speed + accuracy scoring, streak bonus.
  deep_dive — one explainable question, 30-60 s, micro-lesson payload.

Score model:
  base points by difficulty (easy 100 / medium 150 / hard 200)
  x time scale: 50% floor + 50% proportional to remaining time
  x partial credit for multi-select: (hits - wrong picks) / |correct|
  + streak bonus: +10% per prior consecutive full-correct answer, cap +50%

Latency normalization: reported one-way latency (capped) is credited back
to the response time before scoring; ties are broken by lower total
normalized response time.
"""
import hashlib
import json
import random
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence

# ── Content ─────────────────────────────────────────────────────────────────

CONTENT_PATH = Path(__file__).resolve().parent.parent / "content" / "brainbrawl_questions.json"

BASE_POINTS = {"easy": 100, "medium": 150, "hard": 200}
STREAK_STEP_PCT = 10          # +10% per streak level
STREAK_CAP = 5                # bonus capped at +50%
MAX_LATENCY_CREDIT_MS = 2000  # ignore absurd latency claims

MODES = {
    "blitz": {
        "mode_id": "brainbrawl_blitz",
        "time_limit_ms": 10_000,
        "default_question_count": 10,
    },
    "deep_dive": {
        "mode_id": "brainbrawl_deep_dive",
        "time_limit_ms": 45_000,   # within the 30-60 s window
        "default_question_count": 1,
    },
}

_bank_cache: Optional[Dict[str, Any]] = None


def load_content(path: Optional[Path] = None, force: bool = False) -> Dict[str, Any]:
    """Load (and cache) the MOCK_CONTENT question bank."""
    global _bank_cache
    if _bank_cache is not None and not force and path is None:
        return _bank_cache
    doc = json.loads((path or CONTENT_PATH).read_text(encoding="utf-8"))
    if path is None:
        _bank_cache = doc
    return doc


def content_hash(doc: Optional[Dict[str, Any]] = None) -> str:
    doc = doc or load_content()
    canon = json.dumps(doc["questions"], sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canon.encode("utf-8")).hexdigest()[:16]


def question_by_id(qid: str, doc: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
    doc = doc or load_content()
    idx = doc.setdefault("_by_id", {q["id"]: q for q in doc["questions"]})
    return idx.get(qid)


def public_question(q: Dict[str, Any], index: int, time_limit_ms: int) -> Dict[str, Any]:
    """Client-safe view: NEVER includes answer/explanation/micro_lesson."""
    return {
        "index": index,
        "id": q["id"],
        "type": q["type"],
        "prompt": q["prompt"],
        "options": q["options"],
        "taxonomy": q["taxonomy"],
        "difficulty": q["difficulty"],
        "time_limit_ms": time_limit_ms,
    }


# ── Deterministic question order ────────────────────────────────────────────

def eligible_questions(mode: str, category: Optional[str] = None,
                       doc: Optional[Dict[str, Any]] = None) -> List[Dict[str, Any]]:
    doc = doc or load_content()
    qs = [q for q in doc["questions"] if mode in q.get("modes", [])]
    if category and category != "all":
        qs = [q for q in qs if q["taxonomy"]["category"] == category]
    return qs


def derive_question_order(seed: int, mode: str, count: int,
                          category: Optional[str] = None,
                          doc: Optional[Dict[str, Any]] = None) -> List[str]:
    """match.seed -> deterministic question-id order (sorted pool + seeded RNG)."""
    pool = sorted(q["id"] for q in eligible_questions(mode, category, doc))
    if not pool:
        return []
    count = max(1, min(count, len(pool)))
    rng = random.Random(seed)
    return rng.sample(pool, count)


# ── Scoring ─────────────────────────────────────────────────────────────────

def normalize_response_ms(response_ms: int, latency_ms: int, time_limit_ms: int) -> int:
    """Credit reported one-way latency back to the responder, clamped to limits."""
    lat = max(0, min(int(latency_ms), MAX_LATENCY_CREDIT_MS))
    normalized = int(response_ms) - lat
    return max(0, min(normalized, time_limit_ms))


def partial_credit(correct: Sequence[int], selected: Sequence[int]):
    """Multi-select credit: (hits - wrong picks) / |correct|, floored at 0."""
    correct_set, sel_set = set(correct), set(selected)
    hits = len(sel_set & correct_set)
    wrong = len(sel_set - correct_set)
    numerator = max(0, hits - wrong)
    return numerator, len(correct_set), sel_set == correct_set


def score_answer(question: Dict[str, Any], selected: Sequence[int],
                 response_ms: int, latency_ms: int,
                 time_limit_ms: int, streak: int) -> Dict[str, Any]:
    """Server-authoritative grade for one answer. Integer math, fully replayable
    from (question_id, selected, response_ms, latency_ms, time_limit_ms, streak)."""
    normalized_ms = normalize_response_ms(response_ms, latency_ms, time_limit_ms)
    numerator, denominator, full_correct = partial_credit(question["answer"], selected)

    base = BASE_POINTS.get(question.get("difficulty", "medium"), 150)
    if numerator <= 0:
        raw = 0
    else:
        remaining_ms = time_limit_ms - normalized_ms
        speed_scaled = base // 2 + (base * remaining_ms) // (2 * time_limit_ms)
        raw = (speed_scaled * numerator) // denominator
    bonus = (raw * min(streak, STREAK_CAP) * STREAK_STEP_PCT) // 100 if raw > 0 else 0
    points = raw + bonus
    new_streak = streak + 1 if full_correct else 0

    return {
        "question_id": question["id"],
        "selected": sorted(int(s) for s in selected),
        "correct_answer": list(question["answer"]),
        "full_correct": full_correct,
        "credit_numerator": numerator,
        "credit_denominator": denominator,
        "normalized_ms": normalized_ms,
        "base_points": base,
        "raw_points": raw,
        "streak_bonus": bonus,
        "points": points,
        "streak_before": streak,
        "streak_after": new_streak,
    }


# ── Tie-break ───────────────────────────────────────────────────────────────

def resolve_standings(entries: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Rank players: higher score first; ties broken by LOWER total normalized
    response time (latency-normalized), then player_id for stability."""
    ranked = sorted(
        entries,
        key=lambda e: (-int(e["score"]), int(e["total_normalized_ms"]), str(e["player_id"])),
    )
    out = []
    for i, e in enumerate(ranked):
        row = dict(e)
        row["rank"] = i + 1
        if i > 0 and ranked[i - 1]["score"] == e["score"]:
            row["tie_break"] = "latency_normalized_time"
        out.append(row)
    return out


# ── Replay validation (used by tools/replay_validator.py + tests) ──────────

def is_brainbrawl_replay(metadata: Dict[str, Any]) -> bool:
    return str(metadata.get("mode_id", "")).startswith("brainbrawl_")


def validate_brainbrawl_replay(replay: Dict[str, Any],
                               doc: Optional[Dict[str, Any]] = None) -> List[str]:
    """Deterministically re-derive question order and re-score every answer from
    the original inputs echoed in the replay. Returns mismatch strings ([] = OK)."""
    errors: List[str] = []
    doc = doc or load_content()
    meta = replay.get("metadata") or replay
    rid = meta.get("match_id", "<unknown>")
    seed = meta.get("seed")
    mode = meta.get("brainbrawl_mode")
    events = replay.get("events", [])

    if seed is None:
        return [f"{rid}: metadata.seed missing"]
    if mode not in MODES:
        return [f"{rid}: unknown brainbrawl_mode {mode!r}"]

    # 0. Content hash must match the bank we are validating against.
    recorded_hash = meta.get("content_hash")
    if recorded_hash and recorded_hash != content_hash(doc):
        errors.append(
            f"{rid}: content_hash {recorded_hash} != current bank {content_hash(doc)} "
            "(bank changed since recording; replay not verifiable)"
        )
        return errors

    time_limit_ms = int(meta.get("time_limit_ms") or MODES[mode]["time_limit_ms"])
    category = meta.get("category")

    # 1. Seed -> question order must be re-derivable. NOTE: rng.sample output
    # depends on k, so we re-derive with the round's original question_count.
    presented = [e["question_id"] for e in events if e.get("type") == "question_presented"]
    count = int(meta.get("question_count") or len(presented) or 1)
    expected = derive_question_order(seed, mode, count, category, doc)
    if presented and presented != expected[: len(presented)]:
        errors.append(
            f"{rid}: presented question order {presented} does not match "
            f"derive_question_order(seed={seed})={expected}"
        )

    # 2. Re-score every answer_result from its echoed original inputs.
    streaks: Dict[str, int] = {}
    scores: Dict[str, int] = {}
    total_norm_ms: Dict[str, int] = {}
    round_end = None
    for ev in events:
        if ev.get("type") == "round_end":
            round_end = ev
        if ev.get("type") != "answer_result":
            continue
        pid = ev.get("player_id") or "unknown"
        inputs = ev.get("inputs") or {}
        q = question_by_id(ev.get("question_id"), doc)
        if q is None:
            errors.append(f"{rid} seq={ev.get('seq')}: unknown question_id {ev.get('question_id')}")
            continue
        result = score_answer(
            q,
            inputs.get("selected", []),
            int(inputs.get("response_ms", time_limit_ms)),
            int(inputs.get("latency_ms", 0)),
            time_limit_ms,
            streaks.get(pid, 0),
        )
        recorded = (ev.get("points"), ev.get("streak_after"), ev.get("full_correct"))
        recomputed = (result["points"], result["streak_after"], result["full_correct"])
        if recorded != recomputed:
            errors.append(
                f"{rid} seq={ev.get('seq')} q={ev.get('question_id')}: "
                f"recorded (points,streak,full)={recorded} recomputed={recomputed}"
            )
        streaks[pid] = result["streak_after"]
        scores[pid] = scores.get(pid, 0) + result["points"]
        total_norm_ms[pid] = total_norm_ms.get(pid, 0) + result["normalized_ms"]
        snap = ev.get("score_snapshot")
        if snap is not None and snap.get(pid) != scores[pid]:
            errors.append(
                f"{rid} seq={ev.get('seq')}: score_snapshot[{pid}]={snap.get(pid)} "
                f"but replayed accumulation gives {scores[pid]}"
            )

    # 3. round_end score + tie-break inputs must match accumulation.
    if round_end is not None:
        final = round_end.get("score", {})
        for pid, pts in scores.items():
            if final.get(pid) != pts:
                errors.append(
                    f"{rid}: round_end score[{pid}]={final.get(pid)} "
                    f"but replayed accumulation gives {pts}"
                )
        recorded_norm = round_end.get("total_normalized_ms", {})
        for pid, ms in total_norm_ms.items():
            if recorded_norm.get(pid) is not None and recorded_norm[pid] != ms:
                errors.append(
                    f"{rid}: round_end total_normalized_ms[{pid}]={recorded_norm[pid]} "
                    f"but replayed accumulation gives {ms}"
                )

    # 4. seq ordering must be strictly increasing.
    seqs = [ev["seq"] for ev in events if "seq" in ev]
    if seqs != sorted(seqs) or len(set(seqs)) != len(seqs):
        errors.append(f"{rid}: event seq values are not strictly increasing: {seqs}")

    return errors
