"""Pydantic contract models for the NEXUS Gateway v1 surface.

These models ARE the contract documented in docs/NEXUS_GATEWAY.md.
Additive changes only within v1; breaking changes require /nexus/v2.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.session_receipt import Outcome

QueueItemKind = Literal["lesson", "review", "micro_lesson"]
QueueReason = Literal["prq_weakness", "spaced_repetition", "progression"]
CatalogKind = Literal["course", "card"]
FocusTrend = Literal["declining", "flat", "improving"]


# ── /nexus/v1/queue ──────────────────────────────────────────────────────────
class QueueItemOut(BaseModel):
    """One entry in the adaptive learning queue."""

    position: int = Field(ge=0, description="0-based queue position")
    lesson_id: str = Field(description="Lesson id inside the source course")
    course_id: str = Field(description="Owning course id")
    title: str = Field(description="Lesson display title")
    kind: QueueItemKind = Field(description="lesson | review | micro_lesson")
    reason: QueueReason = Field(description="Why the sequencer chose this item")
    target_attributes: list[str] = Field(default_factory=list, description="PRQ attributes this lesson moves")
    drill_id: str | None = Field(default=None, description="Bound Skill Lab drill id, if any")
    estimated_minutes: int = Field(default=5, ge=1, description="Estimated completion time")


class QueueOut(BaseModel):
    """Ordered lesson queue, recomputed after every session."""

    user_id: str = Field(description="Authenticated user id")
    computed_at: str = Field(description="ISO-8601 UTC computation timestamp")
    engine: str = Field(description="Sequencing provider that produced the queue")
    queue: list[QueueItemOut] = Field(default_factory=list, description="Ordered queue items")


# ── /nexus/v1/catalog ────────────────────────────────────────────────────────
class CatalogItemOut(BaseModel):
    """Unified catalog entry: a published course OR a creator card."""

    id: str = Field(description="Stable item id, unique within its kind")
    kind: CatalogKind = Field(description="course | card")
    title: str = Field(description="Display title")
    sport: str = Field(default="training", description="Primary sport/category")
    status: str = Field(default="published", description="Only published items are served")
    author_id: str = Field(default="first-party", description="Author / creator id")
    version: int = Field(default=1, ge=1, description="Published version")
    price_lc: int | None = Field(default=None, description="Soft-currency price (Lab Credits / shards)")
    price_usd: float | None = Field(default=None, description="Hard-currency price; informational, no charge via gateway")
    rating: float | None = Field(default=None, ge=0, le=5, description="Marketplace rating when available")
    payload: dict = Field(default_factory=dict, description="Full underlying object (course JSON or CreatorCardOut)")


class CatalogOut(BaseModel):
    """Merged published-course + creator-card catalog page."""

    items: list[CatalogItemOut] = Field(default_factory=list, description="Catalog page items")
    total: int = Field(ge=0, description="Total items matching the filter, pre-pagination")
    limit: int = Field(ge=1, description="Requested page size")
    offset: int = Field(ge=0, description="Requested page offset")


# ── /nexus/v1/session-result ─────────────────────────────────────────────────
class SessionResultIn(BaseModel):
    """Single ingest payload for a finished session.

    Superset of the game receipt: adds the education/mastery context the
    fan-out needs. Economy values are always recomputed server-side.
    """

    client_receipt_id: str = Field(min_length=1, max_length=128, description="Client-generated id; idempotency fallback key")
    mode_id: str = Field(default="basketball_h2h", description="Arena/skill-lab mode id")
    score: int = Field(ge=0, description="Authoritative score or score proxy")
    outcome: Outcome = Field(default="loss", description="Session outcome")
    duration_seconds: int = Field(default=60, ge=0, description="Session duration")
    completed: bool = Field(default=True, description="Whether the session reached a valid ending")
    combo_count: int = Field(default=0, ge=0, description="Max or total combo count")
    critical_count: int = Field(default=0, ge=0, description="Critical performance events")
    pacing_score: float = Field(default=0, ge=0, le=100, description="0-100 pacing quality")
    arv: float = Field(default=50, ge=0, le=100, description="Adaptive recovery value")
    esi: float = Field(default=50, ge=0, le=100, description="Emotional stability index")
    lesson_id: str | None = Field(default=None, description="Lesson this session completes, if launched from the queue")
    skill_ids: list[str] = Field(default_factory=list, description="Skills exercised; defaults to [mode_id] when empty")
    telemetry: dict = Field(default_factory=dict, description="Raw client telemetry envelope")


class EconomyFanoutOut(BaseModel):
    """Server-computed economy rewards."""

    xp: int = Field(description="XP awarded")
    shards: int = Field(description="Shards (Lab Credits) awarded")
    prq_delta: float = Field(description="PRQ delta awarded")
    mri: float = Field(description="Mental Resiliency Index")
    pacing_bonus_applied: bool = Field(description="Whether the shard pacing bonus applied")


class PrqFanoutOut(BaseModel):
    """PRQ subsystem result."""

    delta: float = Field(description="Bounded PRQ delta for this session")
    mri: float = Field(description="MRI computed from arv/esi/pacing")
    mri_grade: str = Field(description="MRI grade label")


class MasteryStateOut(BaseModel):
    """Spaced-repetition state for one skill."""

    skill_id: str = Field(description="Skill id")
    strength: float = Field(ge=0, le=1, description="0-1 mastery strength")
    reps: int = Field(ge=0, description="Total scored repetitions")
    last_seen: str = Field(description="ISO-8601 UTC of last rep")
    next_due: str = Field(description="ISO-8601 UTC when the skill should resurface")


class MasteryFanoutOut(BaseModel):
    """Mastery subsystem result."""

    updated: list[MasteryStateOut] = Field(default_factory=list, description="States touched by this session")


class SessionResultOut(BaseModel):
    """Fan-out result for one ingested session."""

    result_id: str = Field(description="Server-assigned ingest id")
    user_id: str = Field(description="Authenticated user id")
    mode_id: str = Field(description="Echoed mode id")
    lesson_id: str | None = Field(default=None, description="Echoed lesson id")
    idempotent_replay: bool = Field(default=False, description="True when served from the idempotency store")
    economy: EconomyFanoutOut = Field(description="Economy fan-out")
    prq: PrqFanoutOut = Field(description="PRQ fan-out")
    mastery: MasteryFanoutOut = Field(description="Mastery fan-out")


# ── /nexus/v1/advisor ────────────────────────────────────────────────────────
class FocusAreaOut(BaseModel):
    """One CELL-shaped focus area."""

    attribute: str = Field(description="PRQ attribute or skill id needing attention")
    priority: float = Field(ge=0, le=1, description="0-1 priority; higher = more urgent")
    trend: FocusTrend = Field(default="flat", description="Recent direction of the attribute")
    reason: str = Field(description="Human-readable why")
    recommended_lesson_ids: list[str] = Field(default_factory=list, description="Lessons that target this area")


class AdvisorOut(BaseModel):
    """CELL focus-areas snapshot for the athlete."""

    user_id: str = Field(description="Authenticated user id")
    computed_at: str = Field(description="ISO-8601 UTC computation timestamp")
    source: str = Field(description="Provider that produced the snapshot (cell | in_memory_default | fake)")
    focus_areas: list[FocusAreaOut] = Field(default_factory=list, description="Ranked focus areas, highest priority first")


# ── /nexus/v1/meta ───────────────────────────────────────────────────────────
class GatewayMetaOut(BaseModel):
    """Gateway self-description for client bootstrapping."""

    api: str = Field(description="Surface prefix, e.g. nexus/v1")
    gateway_version: str = Field(description="Contract version")
    providers: dict[str, str] = Field(default_factory=dict, description="Active provider name per capability")
