"""
music_scoring.py — Extended, deterministic musicality metrics for the
Composer-Challenge (Music Creation mode).

This module is an *additive* companion to ``lib/music_theory.py``. It does NOT
replace the three canonical sub-scores (variety / rhythm / adherence) that
``music_theory.score_submission`` already computes and that the frontend +
tests depend on. Instead it exposes a set of richer musicality metrics that a
lead can fold into the score dict as an ``extended`` breakdown block.

Design contract (mirrors music_theory.py):
  - Every metric is a **pure function** of ``(loop, constraints, seed)``.
  - No global RNG: any pseudo-random weighting is derived from ``seed`` via
    ``music_theory._seeded_rng_int`` so results are byte-identical across
    processes / platforms.
  - Every metric returns a ``float`` in ``[0.0, 1.0]``; ``compute_extended_
    breakdown`` rounds each to 6 decimal places (matching the existing 6dp
    contract).
  - **Graceful degradation:** submitted loops today only carry clips with
    ``start`` / ``length`` (no pitch). Every pitch-aware metric therefore
    reads *optional* pitch data (``clip["pitches"]`` — a list of pitch classes
    0-11, or ``clip["pitch"]`` — a single one) and, when absent, returns a
    neutral score so existing pitch-free submissions are neither rewarded nor
    penalised and existing tests keep passing.

The module is import-safe (no side effects at import time).

Loop shape (music-project ``tracks`` shape, as in music_theory._collect_hits):
    {
      "tracks": [
        {"type": "instrument"|"sample"|"bass"|"lead"|"drums"|...,
         "role": <optional explicit role>,
         "clips": [{"start": <beats>, "length": <beats>,
                    "pitches": [pc, ...]?, "pitch": pc?}, ...]},
        ...
      ],
      "bpm": <int>?, "key": <str>?,
    }
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional

from lib.music_theory import _seeded_rng_int, parse_key, _MAJOR_STEPS, _MINOR_STEPS

_BEATS_PER_BAR = 4
_NEUTRAL = 0.5  # returned by pitch-aware metrics when no pitch info is present


# ── Hit collection (pitch-aware superset of music_theory._collect_hits) ─────

def _collect_hits(loop: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Flatten a loop's clips into hit dicts, preserving optional pitch data.

    Each hit carries: ``track`` (index), ``type``, ``role`` (explicit role or
    ``type``), ``start``, ``length`` and ``pitches`` (a possibly-empty list of
    pitch classes 0-11). Missing pitch info yields an empty ``pitches`` list,
    which the pitch-aware metrics treat as "no data" (neutral).
    """
    hits: List[Dict[str, Any]] = []
    for ti, track in enumerate(loop.get("tracks", []) or []):
        ttype = track.get("type", "instrument")
        role = track.get("role", ttype)
        for clip in track.get("clips", []) or []:
            hits.append({
                "track": ti,
                "type": ttype,
                "role": role,
                "start": float(clip.get("start", 0.0)),
                "length": float(clip.get("length", 1.0)),
                "pitches": _clip_pitches(clip),
            })
    return hits


def _clip_pitches(clip: Dict[str, Any]) -> List[int]:
    """Extract pitch classes (0-11) from a clip, degrading to [] when absent.

    Accepts ``clip["pitches"]`` (iterable of ints) or ``clip["pitch"]``
    (single int). Non-integer / out-of-range values are dropped. Order is
    preserved so callers stay deterministic.
    """
    raw: List[Any] = []
    if isinstance(clip.get("pitches"), (list, tuple)):
        raw = list(clip["pitches"])
    elif clip.get("pitch") is not None:
        raw = [clip["pitch"]]
    out: List[int] = []
    for p in raw:
        try:
            out.append(int(p) % 12)
        except (TypeError, ValueError):
            continue
    return out


def _all_pitches(hits: List[Dict[str, Any]]) -> List[int]:
    """Every pitch class across all hits (may be empty when no pitch data)."""
    return [p for h in hits for p in h["pitches"]]


def _scale_pitch_classes(key: str) -> set:
    """Diatonic pitch classes (0-11) of the challenge key/scale."""
    parsed = parse_key(key)
    steps = _MINOR_STEPS if parsed["minor"] else _MAJOR_STEPS
    tonic = parsed["tonic"]
    return {(tonic + s) % 12 for s in steps}


def _clamp(x: float) -> float:
    return 0.0 if x < 0.0 else 1.0 if x > 1.0 else float(x)


def _bar_of(start: float, total_beats: float) -> int:
    """Zero-based bar index for an onset (clamped into the challenge window)."""
    bars = max(1, int(round(total_beats / _BEATS_PER_BAR)) or 1)
    b = int(start // _BEATS_PER_BAR)
    return 0 if b < 0 else (bars - 1) if b >= bars else b


def _num_bars(constraints: Dict[str, Any]) -> int:
    total = float(constraints.get("length_beats", 16) or 16.0)
    return max(1, int(round(total / _BEATS_PER_BAR)) or 1)


# ── Harmony / tonal fit ─────────────────────────────────────────────────────

def harmony_fit(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Fraction of pitched content that lands in the challenge key/scale.

    Formula: ``in_scale_notes / total_notes``, i.e. the share of note pitch
    classes that are diatonic to the constraint key. Degrades gracefully: when
    the loop carries no pitch information at all, returns ``_NEUTRAL`` (0.5) so
    pitch-free submissions are neither rewarded nor penalised.

    Deterministic: a pure function of the (loop, constraints) content; ``seed``
    is accepted for signature uniformity and unused here.
    """
    del seed  # signature uniformity; harmony fit is content-only
    hits = _collect_hits(loop)
    pitches = _all_pitches(hits)
    if not pitches:
        return _NEUTRAL
    scale = _scale_pitch_classes(constraints.get("key", loop.get("key", "C")))
    in_scale = sum(1 for p in pitches if p in scale)
    return _clamp(in_scale / len(pitches))


def tonic_grounding(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Reward pitched content that emphasises tonally-strong scale degrees.

    Weights each in-scale note by the harmonic weight of its scale degree
    (tonic / dominant / mediant strongest), normalised so a loop that leans on
    the tonic triad scores near 1.0 and one that avoids strong degrees scores
    lower. Out-of-scale notes contribute 0. Degrades to ``_NEUTRAL`` with no
    pitch data.
    """
    del seed
    hits = _collect_hits(loop)
    pitches = _all_pitches(hits)
    if not pitches:
        return _NEUTRAL
    parsed = parse_key(constraints.get("key", loop.get("key", "C")))
    steps = _MINOR_STEPS if parsed["minor"] else _MAJOR_STEPS
    tonic = parsed["tonic"]
    # Degree -> weight (I strongest, then V, then III; passing tones lightest).
    degree_weight = {0: 1.0, 4: 0.85, 2: 0.7, 3: 0.55, 5: 0.55, 1: 0.4, 6: 0.4}
    pc_weight: Dict[int, float] = {}
    for deg, off in enumerate(steps):
        pc_weight[(tonic + off) % 12] = degree_weight.get(deg, 0.4)
    total = sum(pc_weight.get(p, 0.0) for p in pitches)
    return _clamp(total / len(pitches))


# ── Rhythmic sub-metrics ────────────────────────────────────────────────────

def downbeat_coverage(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Fraction of bars whose downbeat (beat 1) carries an onset.

    Strong metric anchor: a groove that hits the "one" of every bar scores
    1.0; one that never lands a downbeat scores 0.0. An onset counts for a bar
    when it starts within a small tolerance of that bar's downbeat.
    """
    del seed
    hits = _collect_hits(loop)
    bars = _num_bars(constraints)
    covered = set()
    for h in hits:
        # onset near a bar downbeat?
        rel = h["start"] % _BEATS_PER_BAR
        if rel <= 1e-6 or (_BEATS_PER_BAR - rel) <= 1e-6:
            covered.add(_bar_of(h["start"], float(constraints.get("length_beats", 16) or 16.0)))
    return _clamp(len(covered) / bars)


def bar_occupancy(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Fraction of bars that contain at least one onset (avoid empty bars).

    A loop that fills every bar scores 1.0; one that leaves bars silent scores
    proportionally lower. Complements ``downbeat_coverage`` (which cares about
    *where* in the bar) by rewarding *any* activity per bar.
    """
    del seed
    hits = _collect_hits(loop)
    bars = _num_bars(constraints)
    total = float(constraints.get("length_beats", 16) or 16.0)
    occupied = {_bar_of(h["start"], total) for h in hits}
    return _clamp(len(occupied) / bars)


def groove_consistency(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Consistency of the sub-beat (swing) micro-timing across onsets.

    Looks at each onset's fractional position within its beat, and measures how
    *repeatable* that micro-timing is. A steady groove (onsets clustering at a
    few consistent sub-beat offsets, e.g. straight 0.0 or a consistent swung
    0.66) scores high; scattered, never-repeating offsets score low.

    Formula: ``1 - normalized_spread`` where ``normalized_spread`` is the mean
    absolute deviation of fractional offsets from their rounded 1/12-grid
    cluster, scaled to [0,1]. Loops with <2 onsets are trivially consistent
    (1.0).
    """
    del seed
    hits = _collect_hits(loop)
    if len(hits) < 2:
        return 1.0
    fracs = [h["start"] % 1.0 for h in hits]
    # Quantise to a 1/12 grid (captures both straight-1/4 and swung-1/3 feels),
    # then measure how far onsets sit from their nearest grid cluster.
    grid = 12
    deviations = []
    for f in fracs:
        nearest = round(f * grid) / grid
        deviations.append(abs(f - nearest))
    mean_dev = sum(deviations) / len(deviations)
    # Max possible deviation from a 1/12 grid is 1/24; normalise against it.
    spread = _clamp(mean_dev / (1.0 / (2 * grid)))
    return _clamp(1.0 - spread)


def fill_variation(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Reward variation of the onset pattern from bar to bar (fills/turnarounds).

    Represents each bar by the multiset of its within-bar onset positions
    (quantised to a 1/4-beat grid) and measures how many *distinct* bar
    patterns occur relative to the number of active bars. All-identical bars
    score low (0.0 when >1 bar); every bar different scores high.

    Single-active-bar loops return ``_NEUTRAL`` (variation is undefined with
    one bar of content).
    """
    del seed
    hits = _collect_hits(loop)
    total = float(constraints.get("length_beats", 16) or 16.0)
    per_bar: Dict[int, List[int]] = {}
    for h in hits:
        b = _bar_of(h["start"], total)
        rel = h["start"] % _BEATS_PER_BAR
        per_bar.setdefault(b, []).append(int(round(rel * 4)))  # 1/4-beat grid
    active = [tuple(sorted(v)) for v in per_bar.values()]
    if len(active) < 2:
        return _NEUTRAL
    distinct = len(set(active))
    return _clamp((distinct - 1) / (len(active) - 1))


# ── Structure ───────────────────────────────────────────────────────────────

def bar_usage(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Reward spreading content across multiple bars (vs cramming into one).

    ``active_bars / total_bars`` — distinct from ``bar_occupancy`` only in
    intent/weighting; both share the same numerator but ``bar_usage`` frames
    structure ("did the composer use the full form") while ``bar_occupancy``
    frames the negative ("no empty bars"). Kept separate so a lead can weight
    them independently.
    """
    return bar_occupancy(loop, constraints, seed)


def density_contour(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Reward a non-flat energy contour across bars (build / drop shape).

    Computes per-bar onset counts and scores the *variation* of that contour:
    a flat loop (identical density every bar) scores 0.0; one with a clear
    ebb-and-flow scores high. Uses normalised mean absolute deviation of
    per-bar counts. <2 active bars -> ``_NEUTRAL``.
    """
    del seed
    hits = _collect_hits(loop)
    bars = _num_bars(constraints)
    total = float(constraints.get("length_beats", 16) or 16.0)
    counts = [0] * bars
    for h in hits:
        counts[_bar_of(h["start"], total)] += 1
    active = [c for c in counts if c > 0]
    if len(active) < 2 or not any(counts):
        return _NEUTRAL
    mean = sum(counts) / len(counts)
    if mean <= 0:
        return 0.0
    mad = sum(abs(c - mean) for c in counts) / len(counts)
    # Normalise MAD by the mean (coefficient-of-deviation), saturating at 1.0.
    return _clamp(mad / mean)


def call_and_response(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Reward alternation of activity between tracks/roles across bars.

    Detects a "call and response" texture: bars where one role/track is active
    while another rests, then swaps. Scores the fraction of adjacent bar-pairs
    that exhibit a role-activity *change* (a role turning on or off between
    consecutive bars). A loop where every track plays identically every bar
    scores 0.0; genuine interplay scores high. Needs >=2 tracks and >=2 active
    bars, else ``_NEUTRAL``.
    """
    del seed
    hits = _collect_hits(loop)
    total = float(constraints.get("length_beats", 16) or 16.0)
    bars = _num_bars(constraints)
    roles = sorted({h["role"] for h in hits})
    if len(roles) < 2:
        return _NEUTRAL
    # active[bar] = set of roles sounding in that bar
    active: List[set] = [set() for _ in range(bars)]
    for h in hits:
        active[_bar_of(h["start"], total)].add(h["role"])
    active_bars = [i for i, s in enumerate(active) if s]
    if len(active_bars) < 2:
        return _NEUTRAL
    changes = 0
    pairs = 0
    for a, b in zip(active_bars, active_bars[1:]):
        pairs += 1
        if active[a] != active[b]:
            changes += 1
    return _clamp(changes / pairs) if pairs else _NEUTRAL


# ── Balance ─────────────────────────────────────────────────────────────────

def role_balance(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Reward spreading onsets across track roles (not all on one track).

    Uses normalised Shannon entropy of the onset distribution over tracks: an
    even spread across N tracks scores 1.0; everything on a single track scores
    0.0. This rewards genuine multi-track arrangement (bass vs lead vs drums)
    over a one-track dump. Empty loops score 0.0.
    """
    del seed
    hits = _collect_hits(loop)
    if not hits:
        return 0.0
    counts: Dict[int, int] = {}
    for h in hits:
        counts[h["track"]] = counts.get(h["track"], 0) + 1
    n = len(counts)
    if n < 2:
        return 0.0
    total = sum(counts.values())
    # Shannon entropy in nats, normalised by log(n) -> [0,1].
    import math
    entropy = -sum((c / total) * math.log(c / total) for c in counts.values())
    return _clamp(entropy / math.log(n))


def role_coverage(loop: Dict[str, Any], constraints: Dict[str, Any], seed: int) -> float:
    """Reward covering distinct arrangement roles up to a seed-chosen target.

    Counts distinct track *roles* (bass / lead / drums / instrument / sample /
    …) against a target derived deterministically from the challenge. The
    target is drawn from ``seed`` (so the same challenge always asks for the
    same breadth) within [2, min(4, max_tracks)]. Meeting or exceeding the
    target scores 1.0; fewer roles score proportionally.

    Deterministic: the only pseudo-randomness is ``_seeded_rng_int(seed, ...)``.
    """
    hits = _collect_hits(loop)
    max_tracks = max(1, int(constraints.get("max_tracks", 4)))
    hi = max(2, min(4, max_tracks))
    lo = 2 if hi >= 2 else 1
    span = hi - lo + 1
    target = lo + (_seeded_rng_int(seed, "role_target", max_tracks) % span)
    roles = {h["role"] for h in hits}
    if not roles:
        return 0.0
    return _clamp(len(roles) / target)


# ── Extended breakdown ──────────────────────────────────────────────────────

# Suggested weights for folding the extended metrics into an aggregate
# "musicality" sub-score. These do NOT alter the canonical variety/rhythm/
# adherence weights; a lead can expose the aggregate as a 4th component or keep
# it purely informational. Weights sum to 1.0.
EXTENDED_WEIGHTS: Dict[str, float] = {
    "harmony_fit":        0.16,
    "tonic_grounding":    0.09,
    "downbeat_coverage":  0.12,
    "bar_occupancy":      0.08,
    "groove_consistency": 0.08,
    "fill_variation":     0.10,
    "bar_usage":          0.06,
    "density_contour":    0.08,
    "call_and_response":  0.08,
    "role_balance":       0.09,
    "role_coverage":      0.06,
}

_METRIC_FNS = {
    "harmony_fit":        harmony_fit,
    "tonic_grounding":    tonic_grounding,
    "downbeat_coverage":  downbeat_coverage,
    "bar_occupancy":      bar_occupancy,
    "groove_consistency": groove_consistency,
    "fill_variation":     fill_variation,
    "bar_usage":          bar_usage,
    "density_contour":    density_contour,
    "call_and_response":  call_and_response,
    "role_balance":       role_balance,
    "role_coverage":      role_coverage,
}


def _round6(x: float) -> float:
    return round(float(x), 6)


def compute_extended_breakdown(
    seed: int,
    constraints: Dict[str, Any],
    loop: Dict[str, Any],
) -> Dict[str, Any]:
    """Compute all extended musicality metrics for a submitted loop.

    Returns a dict::

        {
          "metrics": {<name>: <float 0..1, 6dp>, ...},
          "musicality": <float 0..1, 6dp>,   # EXTENDED_WEIGHTS-weighted mean
          "weights": {<name>: <weight>, ...},
          "pitch_aware": <bool>,             # did the loop carry any pitch data
        }

    Determinism: identical ``(seed, constraints, loop)`` -> identical dict.
    Every metric is a pure function; floats are rounded to 6dp. Import-safe and
    free of global RNG.
    """
    metrics: Dict[str, float] = {}
    for name, fn in _METRIC_FNS.items():
        metrics[name] = _round6(fn(loop, constraints, seed))

    musicality = _round6(
        sum(metrics[name] * w for name, w in EXTENDED_WEIGHTS.items())
    )

    hits = _collect_hits(loop)
    pitch_aware = bool(_all_pitches(hits))

    return {
        "metrics": metrics,
        "musicality": musicality,
        "weights": dict(EXTENDED_WEIGHTS),
        "pitch_aware": pitch_aware,
    }
