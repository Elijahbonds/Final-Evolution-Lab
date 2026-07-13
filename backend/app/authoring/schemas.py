"""Pydantic schemas for the Nexus authoring API.

Structural validation lives here (types, lengths, counts). Semantic review
gates (prereq graphs, prqDelta caps, provenance, IP screen) live in
``app.authoring.checks`` so a draft can be saved in an invalid-for-publish
state and fixed later — only *submit* enforces the gates.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any

from pydantic import BaseModel, ConfigDict, Field

from app.authoring.policy import MAX_LESSONS_PER_MODULE, MAX_MODULES_PER_COURSE


class LessonIn(BaseModel):
    """Authored lesson (spec: Lesson — branching + spaced-rep fields)."""

    id: str = Field(min_length=1, max_length=80)
    title: str = Field(min_length=1, max_length=200)
    concept_text: str = Field(default="", max_length=8000)
    prereq_ids: list[str] = Field(default_factory=list, max_length=16)
    drill_options: list[str] = Field(default_factory=list, max_length=12)
    clip_refs: list[str] = Field(default_factory=list, max_length=12)
    prq_delta: dict[str, int] = Field(default_factory=dict)
    difficulty: int = Field(default=1, ge=1, le=5)
    decay_rate: float = Field(default=0.1, ge=0.0, le=1.0)


class ModuleIn(BaseModel):
    """Authored module grouping lessons."""

    id: str = Field(min_length=1, max_length=80)
    title: str = Field(min_length=1, max_length=200)
    lessons: list[LessonIn] = Field(default_factory=list, max_length=MAX_LESSONS_PER_MODULE)


class CourseContent(BaseModel):
    """Full modules -> lessons document stored on a CourseVersion."""

    modules: list[ModuleIn] = Field(default_factory=list, max_length=MAX_MODULES_PER_COURSE)


class CourseCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    slug: str = Field(min_length=1, max_length=160, pattern=r"^[a-z0-9][a-z0-9\-]*$")
    description: str = Field(default="", max_length=4000)
    sport: str = Field(default="basketball", max_length=64)
    license: str = Field(default="standard", max_length=64)
    price_credits: int = Field(default=0, ge=0)
    curriculum_id: str | None = None
    content: CourseContent = Field(default_factory=CourseContent)


class CourseMetaUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=4000)
    sport: str | None = Field(default=None, max_length=64)
    license: str | None = Field(default=None, max_length=64)
    price_credits: int | None = Field(default=None, ge=0)
    curriculum_id: str | None = None


class AuthorProfileCreate(BaseModel):
    role: str = Field(default="creator")
    display_name: str = Field(min_length=1, max_length=160)
    bio: str = Field(default="", max_length=4000)


class AuthorProfileOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    user_id: str
    role: str
    display_name: str
    bio: str
    rating: float
    is_active: bool


class CurriculumCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    description: str = Field(default="", max_length=4000)
    sport: str = Field(default="basketball", max_length=64)
    course_ids: list[str] = Field(default_factory=list, max_length=64)
    target_prq_profile: dict[str, float] = Field(default_factory=dict)


class CurriculumOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    author_id: str
    title: str
    description: str
    sport: str
    course_ids: list[str]
    target_prq_profile: dict[str, float]
    is_active: bool


class CheckFinding(BaseModel):
    check: str
    message: str
    where: str = ""


class CheckReport(BaseModel):
    passed: bool
    checks_run: list[str]
    findings: list[CheckFinding] = Field(default_factory=list)


class VersionOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    course_id: str
    version_number: int
    state: str
    content: dict[str, Any]
    prq_totals: dict[str, Any]
    review_report: dict[str, Any]
    rejection_reason: str | None
    reviewer_user_id: str | None
    submitted_at: datetime | None
    reviewed_at: datetime | None
    published_at: datetime | None


class CourseOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    author_id: str
    curriculum_id: str | None
    title: str
    slug: str
    description: str
    sport: str
    license: str
    price_credits: int
    head_version_id: str | None
    published_version_id: str | None
    is_active: bool


class CourseDetailOut(CourseOut):
    head_version: VersionOut | None = None


class ReviewQueueItem(BaseModel):
    version: VersionOut
    course_title: str
    course_slug: str
    author_id: str
    author_role: str


class ReviewDecision(BaseModel):
    decision: str = Field(pattern=r"^(approve|reject)$")
    note: str = Field(default="", max_length=2000)


class SubmitOut(BaseModel):
    version: VersionOut
    report: CheckReport


class CatalogEntryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    course_id: str
    version_id: str
    title: str
    sport: str
    summary: str
    author_id: str
    author_role: str
    price_credits: int
    visibility: str
    published_at: datetime | None
