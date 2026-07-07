"""
dunk_scoring.py — Server-side dunk contest scoring (deterministic, seeded).

Thin adapter around JudgeComponent that accepts the raw player_inputs format
defined in infra/dunk_event_schema.json and returns a DunkResult compatible
with existing callers throughout the backend.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import List, Optional

from lib.judge_component import JudgeComponent, JudgedInput


@dataclass
class DunkResult:
    j1: int
    j2: int
    j3: int
    total: int
    message: str
    is_perfect: bool


def score_dunk(
    approach_quality: float,   # 0.0–1.0  (maps to primary)
    execution_quality: float,  # 0.0–1.0  (maps to secondary)
    style_difficulty: float,   # 0.0–1.0
    judge_offsets: List[int],  # 3 seeded offsets from derive_judge_offsets()
) -> DunkResult:
    """Compute dunk result deterministically from inputs + judge_offsets."""
    comp = JudgeComponent.for_mode("basketball_dunk", judge_offsets)
    inp = JudgedInput(
        primary=approach_quality,
        secondary=execution_quality,
        style_difficulty=style_difficulty,
    )
    r = comp.score(inp)
    return DunkResult(
        j1=r.j1, j2=r.j2, j3=r.j3,
        total=r.total, message=r.message, is_perfect=r.is_perfect,
    )


def score_dunk_from_player_inputs(
    launch_angle: float,          # from player_inputs.launch_angle
    landing_precision: float,     # from player_inputs.landing_precision
    judge_offsets: List[int],
    style_key: Optional[str] = None,
    trick_sequence_hash: Optional[str] = None,
) -> DunkResult:
    """
    Score a dunk from the dunk_event_schema player_inputs fields directly.

    style_key is the human-readable trick name (e.g. '360_windmill').
    If omitted, style_difficulty defaults to 0.5.
    trick_sequence_hash is validated but not used in the formula (server holds truth).
    """
    style_difficulty = (
        JudgeComponent.style_difficulty_for(style_key) if style_key else 0.5
    )
    if style_key and trick_sequence_hash:
        expected_hash = JudgeComponent.trick_sequence_hash(style_key)
        if expected_hash != trick_sequence_hash:
            raise ValueError(
                f"trick_sequence_hash mismatch for '{style_key}': "
                f"expected {expected_hash}, got {trick_sequence_hash}"
            )
    return score_dunk(launch_angle, landing_precision, style_difficulty, judge_offsets)
