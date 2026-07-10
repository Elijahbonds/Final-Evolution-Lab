"""
dance_beatmap.py — Deterministic beatmap generation + performance scoring for
the Dance Game "Performance Mode" (rhythm game).

Everything here is a PURE function of its inputs — no wall-clock, no RNG that
isn't seeded. The frontend fetches the *identical* beatmap from the server
(GET /beatmap), so the client shows exactly the events the server will score
against.

Scoring reuses the seeded-offset pattern from lib/match_utils.derive_judge_offsets
(contest mode applies seeded per-judge timing offsets to the windows) and the
latency-normalisation pattern from the buzzer/match routers (a client-reported
`latency_ms` is subtracted from every hit before it is judged).

── Enrichment (nexus/dance-mode-enhance, 2nd pass) ──────────────────────────
The generator supports a richer, opt-in `style="phrased"` engine (musical
patterns, difficulty curve, multi-lane chords) plus additive hold-duration and
per-map `summary` fields. The DEFAULT path (`style="classic"`) is the ORIGINAL
loop preserved *verbatim* in `_generate_classic`, so classic output is
byte-identical to the first pass and every legacy call is unchanged.

Scoring is likewise ADDITIVE only: new result keys (`tallies_detailed`,
`per_lane`, `full_combo`/`full_combo_bonus`/`score_with_bonus`, early/late bias,
`rank_points`/`sub_grade`) are layered on top without changing any existing key's
value for any existing input. No new RNG is introduced in scoring.
"""
from __future__ import annotations

import math
import random
from typing import Any, Dict, List, Optional

# ── Timing windows (milliseconds, absolute error to the nearest beat event) ──
# Matches a typical rhythm-game feel. Contest mode shifts these per "judge".
JUDGMENT_WINDOWS_MS: List[tuple] = [
    ("perfect", 40.0, 100.0),   # |err| <= 40ms  -> 100 pts
    ("good", 90.0, 50.0),       # |err| <= 90ms  -> 50 pts
    ("miss", float("inf"), 0.0),  # anything else -> miss, 0 pts
]

# Finer sub-tiers used ONLY to compute the additive `tallies_detailed`. They are
# a strict refinement of JUDGMENT_WINDOWS_MS (marvelous+perfect == coarse
# perfect; great+good == coarse good) so the coarse `tallies` are never changed.
JUDGMENT_WINDOWS_DETAILED_MS: List[tuple] = [
    ("marvelous", 15.0),   # |err| <= 15ms   (dead-on / near-frame-perfect)
    ("perfect", 40.0),     # 15 < |err| <= 40ms
    ("great", 65.0),       # 40 < |err| <= 65ms
    ("good", 90.0),        # 65 < |err| <= 90ms
    # miss: |err| > 90ms (or unmatched)
]

# Additive full-combo reward (kept OUT of `score` so the pinned score is stable).
FULL_COMBO_BONUS_PER_NOTE = 10
# Integer weights for the additive rank_points composite (no float drift).
MARV_W, PERF_W, GREAT_W, GOOD_W = 110, 100, 70, 50

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

# ── Phrased-engine constants (opt-in style="phrased") ───────────────────────
PHRASE_BEATS = 4                                     # phrase length in beats
PATTERNS = ["stair", "roll", "alt", "jack", "random"]
# Per-difficulty pattern weights (deterministic; more readable patterns on easy,
# more demanding roll/jack on hard/expert). Order matches PATTERNS.
PATTERN_WEIGHTS: Dict[str, List[float]] = {
    "easy":   [4.0, 1.0, 4.0, 0.5, 1.0],
    "normal": [3.0, 2.0, 3.0, 1.0, 1.5],
    "hard":   [2.0, 3.0, 2.0, 2.0, 2.0],
    "expert": [2.0, 3.5, 1.5, 3.0, 2.0],
}
HOLD_BEATS_BY_DIFF: Dict[str, float] = {
    "easy": 2.0, "normal": 1.5, "hard": 1.0, "expert": 1.0,
}
CHORD_PROB: Dict[str, float] = {"hard": 0.15, "expert": 0.30}
_PHRASED_SALT = 0x9E3779B9  # keeps the phrased RNG stream distinct from classic


def _beat_ms(bpm: int) -> float:
    """Milliseconds per beat."""
    return 60_000.0 / float(bpm)


def _diff_salt(difficulty: str) -> int:
    return {"easy": 1, "normal": 2, "hard": 3, "expert": 4}.get(difficulty, 2)


# ── Classic generator (ORIGINAL loop, preserved verbatim) ───────────────────

def _generate_classic(
    seed: int,
    bpm: int,
    *,
    beats: int,
    subdivision: int,
    difficulty: str,
) -> List[Dict[str, Any]]:
    """The original deterministic event loop, byte-for-byte unchanged.

    Note *selection* is a function of (seed, difficulty) only; bpm scales timing
    (time_ms) but never which sub-beats fire. RNG consumption order is
    load-bearing — do not touch.
    """
    density = DIFFICULTY_DENSITY.get(difficulty, DIFFICULTY_DENSITY[DEFAULT_DIFFICULTY])
    diff_salt = _diff_salt(difficulty)
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
    return events


# ── Phrased generator (opt-in richer engine) ────────────────────────────────

def _density_at(step: int, total_steps: int, base: float, curve: bool) -> float:
    """Deterministic per-step density. Flat `base` unless `curve` ramps it.

    Closed form of step/total_steps only — no RNG, no bpm. A smooth arch: calmer
    intro, peak ~75% through (climax before the outro), calmer outro; clamped so
    downbeats still always fire.
    """
    if not curve:
        return base
    p = step / max(1, total_steps - 1)  # 0.0 .. 1.0
    if p <= 0.75:
        shape = 0.55 + 0.75 * math.sin(math.pi * min(1.0, p / 0.75))
    else:
        shape = 0.55 + 0.75 * math.sin(math.pi * (1 - (p - 0.75) / 0.25) * 0.5)
    return max(0.05, min(1.0, base * shape))


def _weighted_choice(prng: random.Random, options: List[str], weights: List[float]) -> str:
    """Deterministic weighted pick from `prng` (one draw)."""
    total = sum(weights)
    r = prng.random() * total
    acc = 0.0
    for opt, w in zip(options, weights):
        acc += w
        if r <= acc:
            return opt
    return options[-1]


def _lane_for_pattern(pattern: str, start_lane: int, direction: int,
                      n: int, prng: random.Random, lanes: int) -> int:
    """Pure lane assignment for a firing step index `n` within its phrase.

    `random` draws from prng in fixed step order; all others are closed-form.
    """
    if pattern == "stair":
        return (start_lane + direction * n) % lanes
    if pattern == "roll":
        return (start_lane + n) % lanes
    if pattern == "alt":
        return start_lane if n % 2 == 0 else (start_lane + 2) % lanes
    if pattern == "jack":
        return start_lane
    # random
    return prng.randrange(lanes)


def _generate_phrased(
    seed: int,
    bpm: int,
    *,
    beats: int,
    subdivision: int,
    difficulty: str,
    curve: bool,
    chords: bool,
) -> List[Dict[str, Any]]:
    """Richer musical-pattern generator on a SEPARATE RNG.

    Never instantiates or draws from the classic `rng`, so its existence cannot
    perturb classic output. Selection reads (seed, difficulty, beats,
    subdivision, PHRASE_BEATS) — still independent of bpm (bpm scales time_ms).
    """
    base = DIFFICULTY_DENSITY.get(difficulty, DIFFICULTY_DENSITY[DEFAULT_DIFFICULTY])
    diff_salt = _diff_salt(difficulty)
    prng = random.Random(((seed << 8) ^ (diff_salt & 0xFF)) ^ _PHRASED_SALT)
    beat_ms = _beat_ms(bpm)
    step_ms = beat_ms / float(subdivision)
    lanes = 4
    total_steps = beats * subdivision
    num_phrases = max(1, math.ceil(beats / PHRASE_BEATS))
    weights = PATTERN_WEIGHTS.get(difficulty, PATTERN_WEIGHTS["normal"])

    # Pre-roll each phrase's plan ONCE, in phrase order, so draws are stable
    # regardless of which steps fire.
    phrase_plan: Dict[int, tuple] = {}
    for ph in range(num_phrases):
        pattern = _weighted_choice(prng, PATTERNS, weights)
        start_lane = prng.randrange(lanes)
        direction = 1 if prng.random() < 0.5 else -1
        phrase_plan[ph] = (pattern, start_lane, direction)

    allow_chord = chords and difficulty in ("hard", "expert")
    chord_prob = CHORD_PROB.get(difficulty, 0.0)
    hold_downbeat = difficulty in ("hard", "expert")

    def phrase_index(step: int) -> int:
        return (step // subdivision) // PHRASE_BEATS

    events: List[Dict[str, Any]] = []
    index = 0
    step_in_phrase = 0
    cur_phrase = 0
    for step in range(total_steps):
        ph = phrase_index(step)
        if ph != cur_phrase:
            cur_phrase = ph
            step_in_phrase = 0
        on_beat = step % subdivision == 0
        roll = prng.random()
        if not on_beat and roll > _density_at(step, total_steps, base, curve):
            continue
        pattern, start_lane, direction = phrase_plan[ph]
        lane = _lane_for_pattern(pattern, start_lane, direction, step_in_phrase, prng, lanes)
        if events and events[-1]["lane"] == lane and pattern != "jack":
            lane = (lane + 1) % lanes
        # Holds start on a phrase-boundary downbeat (hard/expert); duration added
        # later by the additive holds pass. Marked here so summary counts it.
        is_phrase_head = on_beat and (step % (subdivision * PHRASE_BEATS) == 0)
        kind = "hold" if (hold_downbeat and is_phrase_head) else "tap"
        beat_val = round(step / subdivision, 4)
        time_ms = round(step * step_ms, 3)
        events.append({
            "index": index,
            "beat": beat_val,
            "lane": lane,
            "time_ms": time_ms,
            "kind": kind,
            "pattern": pattern,
            "chord": False,
        })
        index += 1
        # Optional chord: a second, DIFFERENT lane at the same time_ms (downbeats
        # only, for readability). Per-lane scoring handles it without contention.
        if allow_chord and on_beat and prng.random() < chord_prob:
            second = (lane + 2) % lanes
            if second == lane:
                second = (lane + 1) % lanes
            events[-1]["chord"] = True
            events.append({
                "index": index,
                "beat": beat_val,
                "lane": second,
                "time_ms": time_ms,
                "kind": "tap",
                "pattern": pattern,
                "chord": True,
            })
            index += 1
        step_in_phrase += 1
    return events


def _apply_holds(events: List[Dict[str, Any]], *, bpm: int, subdivision: int,
                 difficulty: str, total_steps: int) -> None:
    """ADDITIVE post-pass: annotate existing `kind=="hold"` events with a real
    duration. Never adds/removes events or changes lane/time/kind, so it is safe
    for both the classic and phrased paths (RULE-ADD).
    """
    beat_ms = _beat_ms(bpm)
    hold_beats_base = HOLD_BEATS_BY_DIFF.get(difficulty, 1.5)
    for ev in events:
        if ev.get("kind") != "hold":
            continue
        # Clamp so a hold never runs past the map.
        step = round(ev["beat"] * subdivision)
        remaining_beats = (total_steps - step) / subdivision
        hold_beats = min(hold_beats_base, max(0.25, remaining_beats))
        hold_ms = round(hold_beats * beat_ms, 3)
        ev["hold_ms"] = hold_ms
        ev["end_ms"] = round(ev["time_ms"] + hold_ms, 3)
        ev["end_beat"] = round(ev["beat"] + hold_beats, 4)


def _build_summary(events: List[Dict[str, Any]], *, style: str, curve: bool,
                   difficulty: str, total_steps: int, num_phrases: int,
                   base_density: float) -> Dict[str, Any]:
    """ADDITIVE per-map summary computed post-hoc from the built events."""
    breakdown: Dict[str, int] = {}
    for ev in events:
        pat = ev.get("pattern")
        if pat:
            breakdown[pat] = breakdown.get(pat, 0) + 1
    # Peak density reached (== base when curve off).
    if curve:
        peak = max(
            (_density_at(s, total_steps, base_density, True) for s in range(total_steps)),
            default=base_density,
        )
    else:
        peak = base_density
    return {
        "style": style,
        "pattern_breakdown": breakdown,
        "peak_density": round(peak, 4),
        "chord_count": sum(1 for e in events if e.get("chord")),
        "hold_count": sum(1 for e in events if e.get("kind") == "hold"),
        "phrase_count": num_phrases,
        "phrase_beats": PHRASE_BEATS,
    }


def generate_beatmap(
    seed: int,
    bpm: int,
    *,
    beats: int = 32,
    subdivision: int = 2,
    difficulty: str = DEFAULT_DIFFICULTY,
    style: str = "classic",
    curve: bool = False,
    holds: bool = False,
    chords: bool = False,
    summary: bool = True,
) -> Dict[str, Any]:
    """Deterministically generate a beatmap from a project seed + bpm.

    Returns {seed, bpm, difficulty, beats, subdivision, style, duration_ms,
    note_count, events:[...], (summary:{...})} where each event is
    {index, beat, lane, time_ms, kind} (+ additive fields for phrased/holds/chords).
    `time_ms` is the ideal hit time from performance start (t=0).

    Identical (seed, bpm, beats, subdivision, difficulty, style, curve, holds,
    chords, summary) -> identical output.

    Backward compat: the DEFAULT call (`style="classic"`, everything else off)
    reproduces the original event stream byte-for-byte via `_generate_classic`;
    `summary` adds only a new top-level key. Enrichments are strictly additive
    (extra keys) or gated behind opt-in params.

      style="phrased"  — musical pattern engine on a separate RNG (adds `pattern`,
                         `chord` fields; unlocks curve/chords).
      curve=True       — density ramp (phrased only; ignored in classic).
      holds=True       — annotate hold events with hold_ms/end_ms/end_beat
                         (additive; safe in classic — does NOT change selection).
      chords=True      — 2-lane chords on hard/expert (phrased only).
      summary=True     — additive top-level `summary` block (default on).
    """
    total_steps = beats * subdivision
    step_ms = _beat_ms(bpm) / float(subdivision)
    base_density = DIFFICULTY_DENSITY.get(difficulty, DIFFICULTY_DENSITY[DEFAULT_DIFFICULTY])

    if style == "phrased":
        events = _generate_phrased(
            seed, bpm, beats=beats, subdivision=subdivision, difficulty=difficulty,
            curve=curve, chords=chords,
        )
    else:
        style = "classic"
        events = _generate_classic(
            seed, bpm, beats=beats, subdivision=subdivision, difficulty=difficulty,
        )

    # Additive holds pass (annotates existing hold events only).
    if holds:
        _apply_holds(events, bpm=bpm, subdivision=subdivision,
                     difficulty=difficulty, total_steps=total_steps)

    out: Dict[str, Any] = {
        "seed": seed,
        "bpm": bpm,
        "difficulty": difficulty,
        "beats": beats,
        "subdivision": subdivision,
        "style": style,
        "duration_ms": round(total_steps * step_ms, 3),
        "note_count": len(events),
        "events": events,
    }
    if summary:
        num_phrases = max(1, math.ceil(beats / PHRASE_BEATS))
        out["summary"] = _build_summary(
            events, style=style, curve=curve, difficulty=difficulty,
            total_steps=total_steps, num_phrases=num_phrases, base_density=base_density,
        )
    return out


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


def _windows_detailed_for_judge(offset_ms: float) -> List[tuple]:
    """Detailed sub-tier windows with the SAME contest offset (no new RNG)."""
    return [(name, max(5.0, bound + offset_ms)) for name, bound in JUDGMENT_WINDOWS_DETAILED_MS]


def _judge_one(err_ms: float, windows: List[tuple]) -> tuple:
    """Return (judgment_name, points) for an absolute timing error."""
    for name, bound, points in windows:
        if err_ms <= bound:
            return name, points
    return "miss", 0.0


def _judge_detailed(err_ms: float, windows_detailed: List[tuple]) -> str:
    """Return the detailed sub-tier name for an absolute timing error."""
    for name, bound in windows_detailed:
        if err_ms <= bound:
            return name
    return "miss"


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

    ── Additive detail (nexus/dance-mode-enhance) ──────────────────────────
    The result carries additional, purely-derived keys that do NOT change any
    existing key's value for any input: `tallies_detailed` (finer sub-tiers that
    sum back to the coarse tallies), `per_lane` stats, `full_combo` +
    `full_combo_bonus` + `score_with_bonus` (bonus kept OUT of `score`),
    `mean_error_ms`/`early_count`/`late_count` (signed bias; negative == early),
    and `rank_points`/`sub_grade`. No new RNG is used — the same `judge_offset`
    feeds both coarse and detailed windows.
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
    windows_detailed = _windows_detailed_for_judge(judge_offset)

    max_window = max(b for _, b, _ in windows if b != float("inf")) if any(
        b != float("inf") for _, b, _ in windows
    ) else 90.0

    tallies = {"perfect": 0, "good": 0, "miss": 0}
    tallies_detailed = {"marvelous": 0, "perfect": 0, "great": 0, "good": 0, "miss": 0}
    total_score = 0.0
    combo = 0
    max_combo = 0
    big_combo_triggered = False
    per_event: List[Dict[str, Any]] = []

    # Additive accumulators (derived from already-computed data).
    per_lane_acc: Dict[int, Dict[str, int]] = {}
    signed_err_sum = 0.0
    matched_count = 0
    early_count = 0
    late_count = 0

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

        signed_err = None
        if best_i < 0:
            judgment, points, err_ms = "miss", 0.0, None
            detailed = "miss"
        else:
            norm_hits[best_i]["used"] = True
            judgment, points = _judge_one(best_err, windows)
            err_ms = round(best_err, 3)
            detailed = _judge_detailed(best_err, windows_detailed)
            # Signed error (pre-abs) for early/late bias, from the SAME matched hit.
            signed_err = norm_hits[best_i]["time_ms"] - ev_time
            matched_count += 1
            signed_err_sum += signed_err
            if signed_err < 0:
                early_count += 1
            elif signed_err > 0:
                late_count += 1

        tallies[judgment] += 1
        tallies_detailed[detailed] += 1
        # Per-lane coarse counts.
        lane_bucket = per_lane_acc.setdefault(ev_lane, {"perfect": 0, "good": 0, "miss": 0})
        lane_bucket[judgment] += 1
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
            "judgment_detailed": detailed,
            "error_ms": err_ms,
            "signed_error_ms": (round(signed_err, 3) if signed_err is not None else None),
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

    # ── Additive derived metrics ────────────────────────────────────────────
    full_combo = note_count > 0 and tallies["miss"] == 0
    full_combo_bonus = FULL_COMBO_BONUS_PER_NOTE * note_count if full_combo else 0
    score_int = int(round(total_score))

    per_lane = []
    for lane in sorted(per_lane_acc.keys()):
        b = per_lane_acc[lane]
        notes = b["perfect"] + b["good"] + b["miss"]
        per_lane.append({
            "lane": lane,
            "perfect": b["perfect"],
            "good": b["good"],
            "miss": b["miss"],
            "notes": notes,
            "accuracy": round((b["perfect"] + b["good"]) / notes, 6) if notes else 0.0,
        })

    mean_error_ms = round(signed_err_sum / matched_count, 3) if matched_count else 0.0

    rank_points = int(round(
        MARV_W * tallies_detailed["marvelous"]
        + PERF_W * tallies_detailed["perfect"]
        + GREAT_W * tallies_detailed["great"]
        + GOOD_W * tallies_detailed["good"]
        + full_combo_bonus
    ))

    marv_ratio = (tallies_detailed["marvelous"] / note_count) if note_count else 0.0
    if full_combo and marv_ratio == 1.0:
        sub_grade = "SS"
    elif full_combo and weighted >= 0.98:
        sub_grade = "S+"
    elif weighted >= 0.95:
        sub_grade = "S"
    elif weighted >= 0.90:
        sub_grade = "A+"
    elif weighted >= 0.85:
        sub_grade = "A"
    elif weighted >= 0.70:
        sub_grade = "B"
    elif weighted >= 0.50:
        sub_grade = "C"
    else:
        sub_grade = "D"

    return {
        "score": score_int,
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
        # ── Additive detail keys ──
        "tallies_detailed": tallies_detailed,
        "per_lane": per_lane,
        "mean_error_ms": mean_error_ms,
        "early_count": early_count,
        "late_count": late_count,
        "full_combo": full_combo,
        "full_combo_bonus": full_combo_bonus,
        "score_with_bonus": score_int + full_combo_bonus,
        "rank_points": rank_points,
        "sub_grade": sub_grade,
    }
