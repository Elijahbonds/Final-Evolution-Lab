"""
dance_beatmap.py — Deterministic beatmap generation + performance scoring for
the Dance Game "Performance Mode" (rhythm game).

Everything here is a PURE function of (seed, bpm, difficulty) — no wall-clock,
no RNG that isn't seeded. The frontend generates the *identical* beatmap from
the same project seed + bpm (mirrored in frontend/src/components/nexus/beatmap.js),
so the client shows exactly the events the server will score against.

Scoring reuses the seeded-offset pattern from lib/match_utils.derive_judge_offsets
(contest mode applies seeded per-judge timing offsets to the windows) and the
latency-normalisation pattern from the buzzer/match routers (a client-reported
`latency_ms` is subtracted from every hit before it is judged).
"""
from __future__ import annotations

import random
from typing import Any, Dict, List, Optional

# ── Timing windows (milliseconds, absolute error to the nearest beat event) ──
# Matches a typical rhythm-game feel. Contest mode shifts these per "judge".
JUDGMENT_WINDOWS_MS: List[tuple] = [
    ("perfect", 40.0, 100.0),   # |err| <= 40ms  -> 100 pts
    ("good", 90.0, 50.0),       # |err| <= 90ms  -> 50 pts
    ("miss", float("inf"), 0.0),  # anything else -> miss, 0 pts
]

# A big combo triggers the cinematic slow-mo flag in the HUD.
BIG_COMBO_THRESHOLD = 10

# Difficulty controls note density (fraction of eligible sub-beats that fire).
DIFFICULTY_DENSITY: Dict[str, float] = {
    "easy": 0.35,
    "normal": 0.55,
    "hard": 0.80,
    "expert": 1.0,
}
DEFAULT_DIFFICULTY = "normal"


def _beat_ms(bpm: int) -> float:
    """Milliseconds per beat."""
    return 60_000.0 / float(bpm)


def generate_beatmap(
    seed: int,
    bpm: int,
    *,
    beats: int = 32,
    subdivision: int = 2,
    difficulty: str = DEFAULT_DIFFICULTY,
) -> Dict[str, Any]:
    """Deterministically generate a beatmap from a project seed + bpm.

    Returns {seed, bpm, difficulty, beats, subdivision, duration_ms, events:[...]}
    where each event is {index, beat, lane, time_ms, kind}. `time_ms` is the
    ideal hit time from performance start (t=0).

    Identical (seed, bpm, beats, subdivision, difficulty) -> identical events.
    """
    density = DIFFICULTY_DENSITY.get(difficulty, DIFFICULTY_DENSITY[DEFAULT_DIFFICULTY])
    # Note *selection* is a function of (seed, difficulty) only; bpm scales
    # timing (time_ms) but never which sub-beats fire, so beatmaps at different
    # tempos stay directly comparable.
    diff_salt = {"easy": 1, "normal": 2, "hard": 3, "expert": 4}.get(difficulty, 2)
    rng = random.Random((seed << 8) ^ (diff_salt & 0xFF))
    beat_ms = _beat_ms(bpm)
    step_ms = beat_ms / float(subdivision)
    lanes = 4  # 4-lane rhythm game (D/F/J/K or 4 touch columns)

    events: List[Dict[str, Any]] = []
    total_steps = beats * subdivision
    index = 0
    for step in range(total_steps):
        # Downbeats (step on a whole beat) always fire; off-beats fire by density.
        on_beat = step % subdivision == 0
        roll = rng.random()
        if not on_beat and roll > density:
            continue
        # Deterministic lane assignment; avoid immediate lane repeats when possible.
        lane = rng.randrange(lanes)
        if events and events[-1]["lane"] == lane:
            lane = (lane + 1) % lanes
        # Every 8th beat on expert becomes a "hold" flavour (visual only for demo).
        kind = "hold" if (difficulty == "expert" and step % (subdivision * 8) == 0) else "tap"
        events.append({
            "index": index,
            "beat": round(step / subdivision, 4),
            "lane": lane,
            "time_ms": round(step * step_ms, 3),
            "kind": kind,
        })
        index += 1

    return {
        "seed": seed,
        "bpm": bpm,
        "difficulty": difficulty,
        "beats": beats,
        "subdivision": subdivision,
        "duration_ms": round(total_steps * step_ms, 3),
        "note_count": len(events),
        "events": events,
    }


def _windows_for_judge(offset_ms: float) -> List[tuple]:
    """Apply a seeded timing offset to the judgment windows (contest mode).

    A judge with a positive offset is slightly more lenient (wider windows).
    """
    out = []
    for name, bound, points in JUDGMENT_WINDOWS_MS:
        if bound == float("inf"):
            out.append((name, bound, points))
        else:
            out.append((name, max(5.0, bound + offset_ms), points))
    return out


def _judge_one(err_ms: float, windows: List[tuple]) -> tuple:
    """Return (judgment_name, points) for an absolute timing error."""
    for name, bound, points in windows:
        if err_ms <= bound:
            return name, points
    return "miss", 0.0


def score_performance(
    beatmap: Dict[str, Any],
    hits: List[Dict[str, Any]],
    *,
    latency_ms: float = 0.0,
    contest_seed: Optional[int] = None,
) -> Dict[str, Any]:
    """Deterministically score a set of submitted hits against a beatmap.

    hits: [{time_ms: float, lane: int}] — client-reported hit times from t=0.
          `latency_ms` is subtracted from every hit before judging
          (latency-normalisation, mirrors the buzzer routers).

    Scoring is greedy + deterministic: events are processed in time order; each
    event claims the closest unused same-lane hit within the widest (miss)
    window. Same beatmap + same hits + same latency + same contest_seed ->
    byte-identical result.

    contest_seed (optional): seeds per-judgment-window offsets via the same
    derive-offsets pattern as match judge panels, so contests are reproducible.
    """
    # Latency-normalise + index hits by lane, preserving submission order.
    norm_hits: List[Dict[str, Any]] = []
    for h in hits:
        norm_hits.append({
            "time_ms": float(h["time_ms"]) - float(latency_ms),
            "lane": int(h.get("lane", 0)),
            "used": False,
        })

    # Contest mode: seeded per-window offset (deterministic leniency).
    if contest_seed is not None:
        rng = random.Random(contest_seed)
        judge_offset = rng.uniform(-15.0, 15.0)
        windows = _windows_for_judge(judge_offset)
    else:
        judge_offset = 0.0
        windows = list(JUDGMENT_WINDOWS_MS)

    max_window = max(b for _, b, _ in windows if b != float("inf")) if any(
        b != float("inf") for _, b, _ in windows
    ) else 90.0

    tallies = {"perfect": 0, "good": 0, "miss": 0}
    total_score = 0.0
    combo = 0
    max_combo = 0
    big_combo_triggered = False
    per_event: List[Dict[str, Any]] = []

    for ev in beatmap["events"]:
        ev_time = ev["time_ms"]
        ev_lane = ev["lane"]
        # Find nearest unused hit in same lane within the (miss) window.
        best_i = -1
        best_err = None
        for i, h in enumerate(norm_hits):
            if h["used"] or h["lane"] != ev_lane:
                continue
            err = abs(h["time_ms"] - ev_time)
            if err > max_window:
                continue
            if best_err is None or err < best_err or (err == best_err and i < best_i):
                best_err = err
                best_i = i

        if best_i < 0:
            judgment, points, err_ms = "miss", 0.0, None
        else:
            norm_hits[best_i]["used"] = True
            judgment, points = _judge_one(best_err, windows)
            err_ms = round(best_err, 3)

        tallies[judgment] += 1
        # Combo bonus: +1 point per current combo step on a non-miss.
        if judgment == "miss":
            combo = 0
        else:
            combo += 1
            max_combo = max(max_combo, combo)
            if combo >= BIG_COMBO_THRESHOLD:
                big_combo_triggered = True
            points += combo  # simple, deterministic combo bonus
        total_score += points
        per_event.append({
            "index": ev["index"],
            "judgment": judgment,
            "error_ms": err_ms,
            "points": round(points, 3),
            "combo_after": combo,
        })

    note_count = len(beatmap["events"])
    hit_count = tallies["perfect"] + tallies["good"]
    accuracy = round(hit_count / note_count, 6) if note_count else 0.0
    # Weighted accuracy (perfect worth full, good worth half).
    weighted = (tallies["perfect"] + 0.5 * tallies["good"]) / note_count if note_count else 0.0

    if accuracy >= 0.95:
        grade = "S"
    elif accuracy >= 0.85:
        grade = "A"
    elif accuracy >= 0.70:
        grade = "B"
    elif accuracy >= 0.50:
        grade = "C"
    else:
        grade = "D"

    return {
        "score": int(round(total_score)),
        "max_combo": max_combo,
        "accuracy": accuracy,
        "weighted_accuracy": round(weighted, 6),
        "grade": grade,
        "tallies": tallies,
        "note_count": note_count,
        "big_combo": big_combo_triggered,
        "latency_ms": float(latency_ms),
        "contest_seed": contest_seed,
        "judge_offset_ms": round(judge_offset, 3),
        "events": per_event,
    }
