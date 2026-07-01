""" 
judge_component.py — Universal Deterministic Scorer for all FEL judged modes.

Implements the IScorer interface across four mode categories:

  JUDGED     — dunk, gymnastics, surfing, skateboarding
               3-judge panel, seeded offsets, 0–30 total
  PRECISION  — karate, tennis, golf, baseball
               Timing-window score, single authoritative check
  COMPETITIVE — basketball_h2h, basketball_3v3, football, soccer
               Point accumulation with state snapshot
  COGNITIVE  — brain_brawl, who_scene_it
               Latency-adjusted answer resolution

This module ships the JUDGED scorer in full. PRECISION / COMPETITIVE /
COGNITIVE categories expose the interface contract so future modules can
plug in without touching MatchEngine plumbing.

Usage:
    from lib.judge_component import JudgeComponent, JudgedInput, ScoredResult
    from lib.match_utils import derive_judge_offsets

    comp = JudgeComponent.for_mode("basketball_dunk", judge_offsets)
    result = comp.score(JudgedInput(primary=0.87, secondary=0.91, style_difficulty=0.9))
    print(result.total, result.message)   # 27, OUTSTANDING
"""
from __future__ import annotations

import hashlib
import json
import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

# ── Shared data structures ────────────────────────────────────────────────────

@dataclass
class JudgedInput:
    """Normalised inputs for any judged mode (0.0–1.0 each)."""
    primary: float          # approach quality, difficulty rating, wave selection …
    secondary: float        # execution quality, landing precision, ride quality …
    style_difficulty: float = 0.5  # trick complexity, routine difficulty …
    raw_inputs: Dict[str, Any] = field(default_factory=dict)


@dataclass
class ScoredResult:
    """Output of JudgeComponent.score(). Mirrors DunkResult but is mode-agnostic."""
    j1: int
    j2: int
    j3: int
    total: int
    message: str
    is_perfect: bool
    breakdown: Dict[str, float] = field(default_factory=dict)
    timestamp: float = field(default_factory=time.time)
    mode_id: str = ""
    raw_inputs: Dict[str, Any] = field(default_factory=dict)

    def validate_event(self, expected_outcome: Dict[str, Any]) -> bool:
        """Check if this result matches a stored expected outcome (anticheat hook)."""
        return (
            self.j1 == expected_outcome.get("j1")
            and self.j2 == expected_outcome.get("j2")
            and self.j3 == expected_outcome.get("j3")
            and self.total == expected_outcome.get("total")
        )

    def to_event_dict(self, match_id: str) -> Dict[str, Any]:
        """Serialize to the fel_event_schema sequence entry format."""
        return {
            "frame": int(self.timestamp * 1000) % 1_000_000,
            "actor_id": match_id,
            "action_type": "judged_score",
            "payload": {
                "j1": self.j1, "j2": self.j2, "j3": self.j3,
                "total": self.total,
                "message": self.message,
                "is_perfect": self.is_perfect,
                "breakdown": self.breakdown,
                "mode_id": self.mode_id,
            }
        }


# ── Mode configurations ───────────────────────────────────────────────────────

@dataclass
class _ModeConfig:
    """Per-mode tuning for the JUDGED scoring formula."""
    primary_weight: float     # weight of primary input in base score
    secondary_weight: float   # weight of secondary input (should sum to 1.0 with primary)
    score_floor: int          # minimum per-judge score (dunk=3, gymnastics=2, surfing=1)
    score_ceil: int           # maximum per-judge score (normally 10)
    perfect_threshold: int    # total score that qualifies as "perfect"
    perfect_per_judge: int    # every judge must score at least this for "perfect"
    messages: Dict[str, int]  # {message_label: min_total} — checked highest→lowest


_MODE_CONFIGS: Dict[str, _ModeConfig] = {
    # Basketball dunk: approach 40%, execution 60%; judges strict (floor 3)
    "basketball_dunk": _ModeConfig(
        primary_weight=0.40, secondary_weight=0.60,
        score_floor=3, score_ceil=10,
        perfect_threshold=28, perfect_per_judge=9,
        messages={"PERFECT SCORE": 28, "OUTSTANDING": 24, "SOLID DUNK": 18, "NEEDS WORK": 0},
    ),
    # Gymnastics: difficulty 35%, execution 65%; judges strict (floor 2)
    "gymnastics": _ModeConfig(
        primary_weight=0.35, secondary_weight=0.65,
        score_floor=2, score_ceil=10,
        perfect_threshold=28, perfect_per_judge=9,
        messages={"GOLD STANDARD": 28, "ELITE": 24, "CLEAN": 18, "NEEDS POLISH": 0},
    ),
    # Surfing: wave selection 30%, ride 70%; judges lenient (floor 1)
    "surfing": _ModeConfig(
        primary_weight=0.30, secondary_weight=0.70,
        score_floor=1, score_ceil=10,
        perfect_threshold=27, perfect_per_judge=9,
        messages={"PERFECT 10": 27, "EXCELLENT": 23, "GOOD": 16, "AVERAGE": 0},
    ),
    # Skateboarding: trick difficulty 45%, landing 55%; floor 2
    "skateboarding": _ModeConfig(
        primary_weight=0.45, secondary_weight=0.55,
        score_floor=2, score_ceil=10,
        perfect_threshold=28, perfect_per_judge=9,
        messages={"LEGENDARY": 28, "BANGER": 24, "SOLID": 18, "SKETCHY": 0},
    ),
}

# Style difficulty table: trick/routine style_key → 0.0–1.0
_STYLE_DIFFICULTY: Dict[str, float] = {
    # Dunk styles
    "360_windmill": 1.0, "between_the_legs": 0.9, "reverse_jam": 0.8,
    "tomahawk": 0.7, "alley_oop": 0.75, "finger_roll": 0.5, "power_slam": 0.6,
    # Gymnastics routines
    "full_twisting_layout": 1.0, "double_pike": 0.95, "arabian": 0.85,
    "tuck_back": 0.6, "straddle_jump": 0.4,
    # Surfing maneuvers
    "aerial_360": 1.0, "tube_ride": 0.95, "floater": 0.7, "cutback": 0.6, "bottom_turn": 0.4,
    # Skateboarding tricks
    "900": 1.0, "mctwist": 0.95, "kickflip_indy": 0.85, "heelflip": 0.7, "kickflip": 0.6,
}


# ── JudgeComponent ────────────────────────────────────────────────────────────

class JudgeComponent:
    """
    Deterministic judge panel for any JUDGED mode.

    Construct via JudgeComponent.for_mode(mode_id, judge_offsets).
    Call .score(JudgedInput) → ScoredResult.
    Call .validate_event(input, expected) → bool for anticheat.
    """

    def __init__(self, mode_id: str, judge_offsets: List[int]):
        if mode_id not in _MODE_CONFIGS:
            raise ValueError(
                f"Unknown judged mode '{mode_id}'. "
                f"Known: {sorted(_MODE_CONFIGS)}"
            )
        self.mode_id = mode_id
        self.judge_offsets = (list(judge_offsets) + [0, 0, 0])[:3]
        self._cfg = _MODE_CONFIGS[mode_id]

    @classmethod
    def for_mode(cls, mode_id: str, judge_offsets: List[int]) -> "JudgeComponent":
        return cls(mode_id, judge_offsets)

    @classmethod
    def style_difficulty_for(cls, style_key: str) -> float:
        """Look up style difficulty from a trick/routine key. Returns 0.5 if unknown."""
        return _STYLE_DIFFICULTY.get(style_key, 0.5)

    @classmethod
    def trick_sequence_hash(cls, style_key: str) -> str:
        """CRC32-style 8-hex hash of a style_key — use this as trick_sequence_hash."""
        import zlib
        crc = zlib.crc32(style_key.encode()) & 0xFFFFFFFF
        return f"{crc:08x}"

    def score(self, inp: JudgedInput) -> ScoredResult:
        """
        Compute a deterministic scored result from normalised inputs.

        Formula:
            base = clamp((primary × w1 + secondary × w2) × 50 × (0.7 + style × 0.3), 0, 50)
            j_i  = clamp(round(base/50 × ceil + offset_i), floor, ceil)
            total = j1 + j2 + j3
        """
        cfg = self._cfg
        primary = max(0.0, min(1.0, inp.primary))
        secondary = max(0.0, min(1.0, inp.secondary))
        style = max(0.0, min(1.0, inp.style_difficulty))

        base = (primary * cfg.primary_weight + secondary * cfg.secondary_weight) * 50.0 * (0.7 + style * 0.3)
        base = max(0.0, min(50.0, base))

        scores = []
        for offset in self.judge_offsets:
            raw = (base / 50.0) * cfg.score_ceil + offset
            scores.append(max(cfg.score_floor, min(cfg.score_ceil, round(raw))))

        total = sum(scores)
        is_perfect = (
            total >= cfg.perfect_threshold
            and all(s >= cfg.perfect_per_judge for s in scores)
        )

        first_label = list(cfg.messages.keys())[0]
        message = list(cfg.messages.keys())[-1]  # fallback = lowest tier
        for label, min_total in cfg.messages.items():
            if total >= min_total:
                # Top label (PERFECT SCORE / GOLD STANDARD / …) is reserved for is_perfect only
                if label == first_label and not is_perfect:
                    continue
                message = label
                break

        if is_perfect:
            message = first_label

        breakdown = {
            "base_score": round(base, 2),
            "primary_contribution": round(primary * cfg.primary_weight * 50, 2),
            "secondary_contribution": round(secondary * cfg.secondary_weight * 50, 2),
            "style_multiplier": round(0.7 + style * 0.3, 3),
        }

        return ScoredResult(
            j1=scores[0], j2=scores[1], j3=scores[2],
            total=total, message=message, is_perfect=is_perfect,
            breakdown=breakdown,
            mode_id=self.mode_id,
            raw_inputs=inp.raw_inputs,
        )

    def validate_event(
        self, inp: JudgedInput, expected_outcome: Dict[str, Any]
    ) -> bool:
        """
        Anticheat hook: re-score the inputs and compare to the stored outcome.
        Returns True only if the server-computed scores match the recorded event.
        """
        result = self.score(inp)
        return result.validate_event(expected_outcome)

    def fingerprint(self, inp: JudgedInput) -> str:
        """SHA-256 fingerprint of (mode_id, judge_offsets, primary, secondary, style)."""
        payload = json.dumps({
            "mode_id": self.mode_id,
            "judge_offsets": self.judge_offsets,
            "primary": inp.primary,
            "secondary": inp.secondary,
            "style_difficulty": inp.style_difficulty,
        }, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(payload.encode()).hexdigest()


# ── PRECISION / COMPETITIVE / COGNITIVE stubs ────────────────────────────────
# These expose the interface contract for future mode implementations.
# Each module (karate_scoring.py, h2h_scoring.py, etc.) will implement fully.

class PrecisionScorer:
    """
    Interface stub for timing-window modes: karate, tennis, golf, baseball.
    Scores based on how close the player's input timestamp is to the ideal window.
    """
    def __init__(self, mode_id: str, seed: int, window_ms: int = 80):
        self.mode_id = mode_id
        self.seed = seed
        self.window_ms = window_ms

    def calculate_score(self, input_timestamp_ms: int, ideal_timestamp_ms: int) -> Dict[str, Any]:
        delta_ms = abs(input_timestamp_ms - ideal_timestamp_ms)
        if delta_ms <= self.window_ms * 0.15:
            rating, score = "PERFECT", 100
        elif delta_ms <= self.window_ms * 0.40:
            rating, score = "GREAT", 85
        elif delta_ms <= self.window_ms * 0.70:
            rating, score = "GOOD", 65
        elif delta_ms <= self.window_ms:
            rating, score = "OK", 40
        else:
            rating, score = "MISS", 0
        return {"final_score": score, "breakdown": {"delta_ms": delta_ms, "rating": rating}, "timestamp": time.time()}

    def validate_event(self, delta_ms: int, expected_rating: str) -> bool:
        result = self.calculate_score(0, delta_ms)
        return result["breakdown"]["rating"] == expected_rating


class CompetitiveScorer:
    """
    Interface stub for point-accumulation modes: basketball_h2h, 3v3, football, soccer.
    Accepts a score delta event and validates it against authoritative server state.
    """
    def __init__(self, mode_id: str, seed: int):
        self.mode_id = mode_id
        self.seed = seed
        self._state: Dict[str, int] = {}

    def calculate_score(self, player_id: str, points: int, _inputs: Any = None) -> Dict[str, Any]:
        self._state[player_id] = self._state.get(player_id, 0) + points
        return {"final_score": self._state[player_id], "breakdown": {"delta": points}, "timestamp": time.time()}

    def validate_event(self, event: Dict[str, Any], expected_state: Dict[str, int]) -> bool:
        return self._state == expected_state


class CognitiveScorer:
    """
    Interface stub for latency-adjusted modes: brain_brawl, who_scene_it.
    Correct answer + fastest response wins; ties resolved by seed.
    """
    def __init__(self, mode_id: str, seed: int, base_points: int = 100):
        self.mode_id = mode_id
        self.seed = seed
        self.base_points = base_points

    def calculate_score(self, is_correct: bool, response_time_ms: int, max_time_ms: int = 10000) -> Dict[str, Any]:
        if not is_correct:
            return {"final_score": 0, "breakdown": {"correct": False}, "timestamp": time.time()}
        speed_bonus = max(0, int((1 - response_time_ms / max_time_ms) * 50))
        score = self.base_points + speed_bonus
        return {"final_score": score, "breakdown": {"correct": True, "speed_bonus": speed_bonus, "response_ms": response_time_ms}, "timestamp": time.time()}

    def validate_event(self, response_time_ms: int, expected_score: int) -> bool:
        result = self.calculate_score(True, response_time_ms)
        return abs(result["final_score"] - expected_score) <= 5  # tolerance for clock drift
