"""Adaptive sequencing schemas."""
from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, Field


class MasteryUpdateIn(BaseModel):
    """Session result folded into a skill's spaced-repetition state.

    ``quality`` is the server-graded session quality; clients report the raw
    session and the caller (session pipeline or shell) normalizes to [0, 1].
    """

    skill_id: str = Field(min_length=1, max_length=80, description="Skill trained this session")
    quality: float = Field(ge=0, le=1, description="Normalized session quality (0..1)")
    lesson_id: str | None = Field(default=None, max_length=120, description="Lesson/drill that produced the result")
    duration_seconds: int = Field(default=0, ge=0, description="Session duration, for the inputs snapshot")


class MasteryStateOut(BaseModel):
    """Persisted spaced-repetition state for one skill."""

    skill_id: str = Field(description="Skill identifier")
    strength: float = Field(description="Modelled retention at last_seen (0..1)")
    reps: int = Field(description="Total recorded sessions for this skill")
    decay_rate: float = Field(description="Per-day exponential decay rate")
    last_seen: datetime | None = Field(default=None, description="Last reinforcement time (UTC)")
    next_due: datetime | None = Field(default=None, description="When the skill should resurface (UTC)")


class QueueItemOut(BaseModel):
    """One ranked lesson/drill recommendation."""

    lesson_id: str = Field(description="Catalog lesson id")
    title: str = Field(description="Display title")
    skill_id: str = Field(description="Skill the lesson trains")
    kind: str = Field(description="physical | technique | cognitive")
    load: str = Field(description="high | moderate | low physical load")
    priority: float = Field(description="Final ranking score")
    weakness_score: float = Field(description="PRQ weakness-targeting component (0..1)")
    due_score: float = Field(description="Spaced-repetition due component (0..1)")
    readiness_multiplier: float = Field(description="Readiness gating multiplier applied")
    reasons: list[str] = Field(default_factory=list, description="Human-readable ranking rationale")


class SequencingQueueOut(BaseModel):
    """Ordered recommendation queue, recomputed per request."""

    recommendation_id: str = Field(description="Persisted Recommendation row id")
    user_id: str = Field(description="Authenticated user id")
    computed_at: datetime = Field(description="Computation timestamp (UTC)")
    readiness: float = Field(description="Readiness signal used for gating (0..100)")
    items: list[QueueItemOut] = Field(description="Ordered lesson/drill queue, highest priority first")
