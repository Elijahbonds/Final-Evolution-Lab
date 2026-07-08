"""
music_theory.py — Deterministic, seed-driven music generation + scoring rules
for the Music Creation mode. NO external ML: everything here is rule-based and
reproducible from an integer seed + explicit inputs.

This module is the single source of truth for:
  - auto-beat / auto-harmony generation (chord tables by key, drum patterns by
    genre), seeded from a project seed.
  - composer-challenge scoring (variety, rhythm complexity, constraint
    adherence), seeded + reproducible.

The frontend mirrors the *generation* rules in a small JS module so a loop it
builds offline matches what the server would produce for the same seed; the
server remains authoritative for *scoring*.
"""
from __future__ import annotations

import hashlib
from typing import Any, Dict, List

_SEED_MASK = (1 << 64) - 1

# ── Music constants ────────────────────────────────────────────────────────
# 12 pitch classes. Keys are parsed to a tonic pitch-class + major/minor.
_NOTE_INDEX = {
    "C": 0, "C#": 1, "DB": 1, "D": 2, "D#": 3, "EB": 3, "E": 4, "F": 5,
    "F#": 6, "GB": 6, "G": 7, "G#": 8, "AB": 8, "A": 9, "A#": 10, "BB": 10, "B": 11,
}

# Diatonic scale-degree semitone offsets.
_MAJOR_STEPS = [0, 2, 4, 5, 7, 9, 11]
_MINOR_STEPS = [0, 2, 3, 5, 7, 8, 10]

# Roman-numeral chord-progression tables (scale-degree indices, 0-based).
# Chosen so every key yields a musically sensible loop.
_MAJOR_PROGRESSIONS = [
    [0, 4, 5, 3],   # I  V  vi IV
    [0, 3, 4, 4],   # I  IV V  V
    [0, 5, 3, 4],   # I  vi IV V
    [1, 4, 0, 0],   # ii V  I  I
]
_MINOR_PROGRESSIONS = [
    [0, 5, 2, 4],   # i  VI III V
    [0, 3, 4, 0],   # i  iv v  i
    [0, 6, 5, 4],   # i  VII VI V
    [0, 4, 5, 0],   # i  v  VI i
]

# Genre -> 16-step drum pattern for kick / snare / hat lanes (1 = hit).
_DRUM_PATTERNS: Dict[str, Dict[str, List[int]]] = {
    "boom_bap": {
        "kick":  [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0],
        "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 1],
        "hat":   [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 1],
    },
    "house": {
        "kick":  [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
        "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        "hat":   [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
    },
    "trap": {
        "kick":  [1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0],
        "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        "hat":   [1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1],
    },
    "rock": {
        "kick":  [1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0],
        "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        "hat":   [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
    },
    "funk": {
        "kick":  [1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0],
        "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        "hat":   [1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1],
    },
    "dnb": {
        "kick":  [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
        "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        "hat":   [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
    },
    "reggaeton": {
        "kick":  [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
        "snare": [0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 1, 0],
        "hat":   [1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0],
    },
    "disco": {
        "kick":  [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
        "snare": [0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
        "hat":   [0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0],
    },
}
DRUM_GENRES = tuple(_DRUM_PATTERNS.keys())


def _seeded_rng_int(seed: int, *salt: Any) -> int:
    """Deterministic 64-bit int from seed + salt values (no global RNG state).

    Uses a hash so the same (seed, salt) always yields the same value on any
    Python version / platform — safer than random.Random for a persisted
    contract.
    """
    h = hashlib.sha256(("%d|" % (int(seed) & _SEED_MASK) + "|".join(map(str, salt))).encode())
    return int.from_bytes(h.digest()[:8], "big")


def parse_key(key: str) -> Dict[str, Any]:
    """Parse a free-form key like 'F#m' / 'C' / 'Ab major' -> tonic + mode."""
    k = (key or "C").strip()
    low = k.lower()
    is_minor = low.endswith("m") and not low.endswith("maj") or "min" in low
    # Strip mode suffixes to isolate the tonic token.
    token = k.replace("min", "").replace("Min", "").replace("maj", "").replace("Maj", "")
    token = token.rstrip("mM ").strip()
    token = token[:2] if len(token) >= 2 and token[1] in "#bB" else token[:1]
    tonic = _NOTE_INDEX.get(token.upper(), 0)
    return {"tonic": tonic, "minor": is_minor, "normalized": ("%s%s" % (token, "m" if is_minor else ""))}


def chord_notes(tonic: int, minor: bool, degree: int) -> List[int]:
    """MIDI-ish pitch classes (0-11) for a triad on the given scale degree."""
    steps = _MINOR_STEPS if minor else _MAJOR_STEPS
    root = (tonic + steps[degree % 7]) % 12
    third = (tonic + steps[(degree + 2) % 7]) % 12
    fifth = (tonic + steps[(degree + 4) % 7]) % 12
    return [root, third, fifth]


def choose_genre(seed: int) -> str:
    return DRUM_GENRES[_seeded_rng_int(seed, "genre") % len(DRUM_GENRES)]


def generate_composition(seed: int, key: str, bars: int = 4) -> Dict[str, Any]:
    """Deterministic auto-beat + auto-harmony for `bars` bars.

    Returns a serialisable structure:
      {
        "seed", "key", "genre", "bars",
        "harmony": [{"bar", "degree", "notes": [pc,pc,pc]}...],
        "drums": {"kick": [...16], "snare": [...], "hat": [...]},
      }
    Same (seed, key, bars) -> byte-identical result on any platform.
    """
    parsed = parse_key(key)
    tonic, minor = parsed["tonic"], parsed["minor"]
    prog_table = _MINOR_PROGRESSIONS if minor else _MAJOR_PROGRESSIONS
    progression = prog_table[_seeded_rng_int(seed, "prog") % len(prog_table)]

    harmony = []
    for bar in range(bars):
        degree = progression[bar % len(progression)]
        harmony.append({
            "bar": bar,
            "degree": degree,
            "notes": chord_notes(tonic, minor, degree),
        })

    genre = choose_genre(seed)
    drums = {lane: list(pat) for lane, pat in _DRUM_PATTERNS[genre].items()}
    return {
        "seed": int(seed) & _SEED_MASK,
        "key": parsed["normalized"],
        "genre": genre,
        "bars": bars,
        "harmony": harmony,
        "drums": drums,
    }


# ── Composer-challenge scoring ─────────────────────────────────────────────

def _collect_hits(loop: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Flatten a submitted loop's clips into (track_index, start, length) hits.

    A submitted loop is the music-project `tracks` shape:
      [{type, clips: [{start, length}], ...}, ...]
    """
    hits: List[Dict[str, Any]] = []
    for ti, track in enumerate(loop.get("tracks", [])):
        for clip in track.get("clips", []):
            hits.append({
                "track": ti,
                "type": track.get("type", "instrument"),
                "start": float(clip.get("start", 0.0)),
                "length": float(clip.get("length", 1.0)),
            })
    return hits


def score_submission(
    seed: int,
    constraints: Dict[str, Any],
    loop: Dict[str, Any],
) -> Dict[str, Any]:
    """Deterministically score a submitted loop against a seeded challenge.

    Scoring is a weighted sum of three sub-scores in [0, 1]:
      - variety:     how many distinct tracks + pitch/instrument spread are used
      - rhythm:      onset density + syncopation (off-grid placement) complexity
      - adherence:   BPM/key/instrument-set/duration constraint satisfaction

    Determinism: identical (seed, constraints, loop) -> identical score dict.
    No randomness that isn't derived from `seed`; floats are rounded to 6dp.
    """
    hits = _collect_hits(loop)
    bpm = int(loop.get("bpm", constraints.get("bpm", 120)))
    beats_per_bar = 4
    total_beats = float(constraints.get("length_beats", 16)) or 16.0

    # ── variety ──
    tracks_used = len({h["track"] for h in hits})
    types_used = len({h["type"] for h in hits})
    max_tracks = max(1, int(constraints.get("max_tracks", 4)))
    variety = min(1.0, (tracks_used / max_tracks) * 0.7 + (types_used / 2) * 0.3)

    # ── rhythm complexity ──
    # density: onsets per beat, saturating around 1 onset/beat.
    onsets = len(hits)
    density = min(1.0, onsets / max(1.0, total_beats))
    # syncopation: fraction of onsets that land off the downbeat grid.
    off_grid = sum(1 for h in hits if abs((h["start"] % 1.0)) > 1e-6)
    syncopation = (off_grid / onsets) if onsets else 0.0
    rhythm = min(1.0, density * 0.6 + syncopation * 0.4)

    # ── constraint adherence ──
    adherence_parts: List[float] = []
    # BPM within tolerance of the target.
    target_bpm = int(constraints.get("bpm", bpm))
    bpm_ok = 1.0 - min(1.0, abs(bpm - target_bpm) / max(1, target_bpm))
    adherence_parts.append(bpm_ok)
    # Key match (exact normalized tonic+mode).
    if "key" in constraints:
        want = parse_key(constraints["key"])["normalized"]
        got = parse_key(loop.get("key", constraints["key"]))["normalized"]
        adherence_parts.append(1.0 if want == got else 0.0)
    # Instrument-set: every used type must be in the allowed set.
    allowed = set(constraints.get("instruments", ["instrument", "sample"]))
    used_types = {h["type"] for h in hits} or {"instrument"}
    adherence_parts.append(1.0 if used_types.issubset(allowed) else 0.0)
    # Duration: loop must fill a target beat window (within one bar tolerance).
    if hits:
        span = max(h["start"] + h["length"] for h in hits)
    else:
        span = 0.0
    dur_ok = 1.0 - min(1.0, abs(span - total_beats) / max(1.0, total_beats))
    adherence_parts.append(dur_ok)
    adherence = sum(adherence_parts) / len(adherence_parts)

    # ── weighted total (weights themselves seed-stable) ──
    weights = {"variety": 0.3, "rhythm": 0.35, "adherence": 0.35}
    total = variety * weights["variety"] + rhythm * weights["rhythm"] + adherence * weights["adherence"]

    def r(x: float) -> float:
        return round(float(x), 6)

    # A seed-derived, deterministic "challenge id" so the same challenge is
    # addressable and reproducible.
    challenge_id = "chal_%012x" % (_seeded_rng_int(seed, "challenge", bpm, total_beats) & ((1 << 48) - 1))

    # ── extended musicality metrics (additive, non-canonical) ──
    # Richer deterministic musicality analysis lives in lib/music_scoring.py.
    # It is purely informational here: the canonical `score` and the three
    # `breakdown` keys (variety/rhythm/adherence) and their weights are
    # UNCHANGED, so existing monotonic contracts + tests keep holding. Imported
    # lazily to keep music_theory import-safe and avoid any import cycle.
    try:
        from lib import music_scoring
        extended = music_scoring.compute_extended_breakdown(seed, constraints, loop)
    except Exception:  # pragma: no cover - defensive; extended is optional
        extended = None

    return {
        "challenge_id": challenge_id,
        "seed": int(seed) & _SEED_MASK,
        "score": r(total * 100),  # 0..100
        "deterministic": True,
        "breakdown": {
            "variety": r(variety),
            "rhythm": r(rhythm),
            "adherence": r(adherence),
        },
        "weights": weights,
        "stats": {
            "tracks_used": tracks_used,
            "types_used": types_used,
            "onsets": onsets,
            "off_grid_onsets": off_grid,
            "span_beats": r(span),
            "bpm": bpm,
        },
        # Extended musicality breakdown (harmony/groove/structure/balance).
        # None only if the optional module is unavailable.
        "extended": extended,
        "constraints": constraints,
    }
