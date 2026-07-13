"""First-party lesson/drill catalog the sequencer draws from.

This is the stand-in content registry until the Nexus authoring layer
publishes courses into a database-backed catalog. Each entry declares which
PRQ attributes it targets (weakness-targeting input), its physical ``load``
and ``kind`` (readiness-gating inputs), and a per-skill ``decay_rate``
(spaced-repetition input). Swapping this module for a DB-backed provider is
the integration point for the authoring/marketplace lanes.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

# PRQ attribute names, mirroring app.models.prq_profile.PRQProfile columns.
PRQ_ATTRIBUTES: tuple[str, ...] = (
    "vertical_power",
    "reaction_time",
    "mobility",
    "balance",
    "stamina",
)

LessonKind = Literal["physical", "technique", "cognitive"]
LessonLoad = Literal["high", "moderate", "low"]


@dataclass(frozen=True)
class LessonSpec:
    """One recommendable lesson or drill."""

    lesson_id: str
    title: str
    skill_id: str
    kind: LessonKind
    load: LessonLoad
    difficulty: float  # 0..1, reserved for future prerequisite gating
    targets: tuple[str, ...]  # PRQ attributes this lesson trains
    decay_rate: float = 0.07  # per-day retention decay for the skill


DEFAULT_CATALOG: tuple[LessonSpec, ...] = (
    LessonSpec(
        lesson_id="drill_box_jump_ladder",
        title="Box Jump Ladder",
        skill_id="jump_mechanics",
        kind="physical",
        load="high",
        difficulty=0.6,
        targets=("vertical_power",),
        decay_rate=0.06,
    ),
    LessonSpec(
        lesson_id="drill_depth_drop_primer",
        title="Depth Drop Primer",
        skill_id="eccentric_landing",
        kind="physical",
        load="high",
        difficulty=0.7,
        targets=("vertical_power", "balance"),
        decay_rate=0.06,
    ),
    LessonSpec(
        lesson_id="drill_reaction_sprint",
        title="Reaction Sprint Starts",
        skill_id="first_step_burst",
        kind="physical",
        load="high",
        difficulty=0.5,
        targets=("reaction_time", "stamina"),
        decay_rate=0.08,
    ),
    LessonSpec(
        lesson_id="drill_agility_ladder",
        title="Agility Ladder Circuits",
        skill_id="foot_speed",
        kind="physical",
        load="moderate",
        difficulty=0.4,
        targets=("mobility", "reaction_time"),
        decay_rate=0.08,
    ),
    LessonSpec(
        lesson_id="drill_tempo_run",
        title="Tempo Run Intervals",
        skill_id="aerobic_pacing",
        kind="physical",
        load="moderate",
        difficulty=0.4,
        targets=("stamina",),
        decay_rate=0.05,
    ),
    LessonSpec(
        lesson_id="lesson_landing_mechanics",
        title="Landing Mechanics Breakdown",
        skill_id="eccentric_landing",
        kind="technique",
        load="low",
        difficulty=0.3,
        targets=("vertical_power", "balance"),
        decay_rate=0.05,
    ),
    LessonSpec(
        lesson_id="lesson_footwork_patterns",
        title="Footwork Pattern Library",
        skill_id="foot_speed",
        kind="technique",
        load="moderate",
        difficulty=0.4,
        targets=("mobility", "balance"),
        decay_rate=0.06,
    ),
    LessonSpec(
        lesson_id="lesson_breath_pacing",
        title="Breath Pacing Under Load",
        skill_id="aerobic_pacing",
        kind="technique",
        load="low",
        difficulty=0.2,
        targets=("stamina",),
        decay_rate=0.04,
    ),
    LessonSpec(
        lesson_id="lesson_balance_beam_basics",
        title="Single-Leg Stability Basics",
        skill_id="stability_control",
        kind="technique",
        load="low",
        difficulty=0.3,
        targets=("balance", "mobility"),
        decay_rate=0.05,
    ),
    LessonSpec(
        lesson_id="cog_reaction_grid",
        title="Reaction Grid (Brain Brawl)",
        skill_id="visual_reaction",
        kind="cognitive",
        load="low",
        difficulty=0.3,
        targets=("reaction_time",),
        decay_rate=0.09,
    ),
    LessonSpec(
        lesson_id="cog_pattern_recall",
        title="Pattern Recall Circuits",
        skill_id="play_recognition",
        kind="cognitive",
        load="low",
        difficulty=0.5,
        targets=("reaction_time",),
        decay_rate=0.09,
    ),
    LessonSpec(
        lesson_id="cog_visual_tracking",
        title="Visual Tracking Drills",
        skill_id="visual_reaction",
        kind="cognitive",
        load="low",
        difficulty=0.4,
        targets=("reaction_time", "mobility"),
        decay_rate=0.09,
    ),
)


def catalog_by_lesson_id() -> dict[str, LessonSpec]:
    """Return the default catalog keyed by lesson id."""

    return {lesson.lesson_id: lesson for lesson in DEFAULT_CATALOG}
