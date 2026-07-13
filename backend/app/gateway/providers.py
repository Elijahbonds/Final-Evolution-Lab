"""Gateway capability providers.

Each capability the façade exposes is defined here as a small Protocol plus an
in-memory default implementation. Other lanes replace a default by exposing a
``provider`` object from their gateway adapter module (see registry.py) or by
calling :func:`app.gateway.registry.set_providers` at wiring time.

Defaults are deterministic and DB-free so the gateway (and its contract tests)
run standalone.
"""
from __future__ import annotations

from datetime import UTC, datetime, timedelta
from typing import Protocol

from app.gateway.schemas import (
    AdvisorOut,
    CatalogItemOut,
    FocusAreaOut,
    MasteryFanoutOut,
    MasteryStateOut,
    QueueItemOut,
    SessionResultIn,
)
from app.services.marketplace_service import marketplace_service

# ── Seeded first-party course content (spec: Dunk/Karate Fundamentals) ───────
SEEDED_COURSES: list[dict] = [
    {
        "id": "course_dunk_fundamentals",
        "title": "Dunk Fundamentals",
        "sport": "basketball",
        "author_id": "first-party",
        "version": 1,
        "status": "published",
        "price_lc": 150,
        "price_usd": None,
        "lessons": [
            {
                "id": "lesson_dunk_approach",
                "title": "Approach & Gather",
                "target_attributes": ["approach_timing", "vertical_control"],
                "drill_id": "drill_dunk_approach",
                "estimated_minutes": 6,
            },
            {
                "id": "lesson_dunk_takeoff",
                "title": "Takeoff Mechanics",
                "target_attributes": ["vertical_control", "explosiveness"],
                "drill_id": "drill_dunk_takeoff",
                "estimated_minutes": 7,
            },
            {
                "id": "lesson_dunk_finish",
                "title": "Contact & Finish",
                "target_attributes": ["finishing", "explosiveness"],
                "drill_id": "drill_dunk_finish",
                "estimated_minutes": 6,
            },
        ],
    },
    {
        "id": "course_karate_fundamentals",
        "title": "Karate Fundamentals",
        "sport": "karate",
        "author_id": "first-party",
        "version": 1,
        "status": "published",
        "price_lc": 150,
        "price_usd": None,
        "lessons": [
            {
                "id": "lesson_karate_stance",
                "title": "Stance & Balance",
                "target_attributes": ["balance", "pacing_discipline"],
                "drill_id": "drill_karate_stance",
                "estimated_minutes": 5,
            },
            {
                "id": "lesson_karate_strikes",
                "title": "Strike Chains",
                "target_attributes": ["combo_flow", "explosiveness"],
                "drill_id": "drill_karate_strikes",
                "estimated_minutes": 8,
            },
            {
                "id": "lesson_karate_recovery",
                "title": "Guard & Recovery",
                "target_attributes": ["recovery", "balance"],
                "drill_id": "drill_karate_recovery",
                "estimated_minutes": 6,
            },
        ],
    },
]


def _now_iso() -> str:
    return datetime.now(UTC).isoformat()


def lessons_for_attribute(attribute: str) -> list[str]:
    """Return seeded lesson ids that target ``attribute``."""

    return [
        lesson["id"]
        for course in SEEDED_COURSES
        for lesson in course["lessons"]
        if attribute in lesson["target_attributes"]
    ]


# ── Protocols ────────────────────────────────────────────────────────────────
class MasteryProvider(Protocol):
    """Spaced-repetition mastery lane."""

    name: str

    async def apply_result(self, user_id: str, result: SessionResultIn, mri: float) -> MasteryFanoutOut: ...

    async def states(self, user_id: str) -> list[MasteryStateOut]: ...


class SequencingProvider(Protocol):
    """Adaptive sequencing lane (the recommender queue)."""

    name: str

    async def build_queue(self, user_id: str, limit: int) -> list[QueueItemOut]: ...


class CourseCatalogProvider(Protocol):
    """Education/authoring lane: published courses."""

    name: str

    async def published_courses(self) -> list[CatalogItemOut]: ...


class CardCatalogProvider(Protocol):
    """Marketplace lane: active creator cards."""

    name: str

    async def active_cards(self, sport: str | None) -> list[CatalogItemOut]: ...


class AdvisorProvider(Protocol):
    """CELL advisor lane: ranked focus areas."""

    name: str

    async def focus_areas(self, user_id: str) -> AdvisorOut: ...


# ── In-memory defaults ───────────────────────────────────────────────────────
class InMemoryMasteryProvider:
    """Dict-backed spaced-repetition store.

    Strength moves toward the normalized session score with a 0.35 learning
    rate; the review interval grows with strength (1-14 days).
    """

    name = "in_memory_default"

    def __init__(self) -> None:
        self._states: dict[str, dict[str, MasteryStateOut]] = {}

    def reset(self) -> None:
        """Clear all stored mastery state (test helper)."""

        self._states.clear()

    async def apply_result(self, user_id: str, result: SessionResultIn, mri: float) -> MasteryFanoutOut:
        skill_ids = result.skill_ids or [result.mode_id]
        normalized = min(result.score / 100.0, 1.0)
        now = datetime.now(UTC)
        user_states = self._states.setdefault(user_id, {})
        updated: list[MasteryStateOut] = []
        for skill_id in skill_ids:
            previous = user_states.get(skill_id)
            prior_strength = previous.strength if previous else 0.0
            prior_reps = previous.reps if previous else 0
            strength = round(min(max(prior_strength + 0.35 * (normalized - prior_strength), 0.0), 1.0), 4)
            interval_days = 1 + strength * 13
            state = MasteryStateOut(
                skill_id=skill_id,
                strength=strength,
                reps=prior_reps + 1,
                last_seen=now.isoformat(),
                next_due=(now + timedelta(days=interval_days)).isoformat(),
            )
            user_states[skill_id] = state
            updated.append(state)
        return MasteryFanoutOut(updated=updated)

    async def states(self, user_id: str) -> list[MasteryStateOut]:
        return list(self._states.get(user_id, {}).values())


class InMemoryAdvisorProvider:
    """CELL-shaped focus areas derived from the mastery store.

    Weakest tracked skills become focus areas; with no history the athlete
    gets the deterministic onboarding plan. Shape mirrors what the CELL
    subsystem will emit so swapping providers is contract-invisible.
    """

    name = "in_memory_default"

    def __init__(self, mastery: InMemoryMasteryProvider) -> None:
        self._mastery = mastery

    _ONBOARDING: tuple[tuple[str, str], ...] = (
        ("vertical_control", "No session history yet — start with takeoff mechanics."),
        ("balance", "No session history yet — stance work builds every other skill."),
        ("pacing_discipline", "Pacing drives MRI and shard bonuses from day one."),
    )

    async def focus_areas(self, user_id: str) -> AdvisorOut:
        states = await self._mastery.states(user_id)
        areas: list[FocusAreaOut] = []
        if states:
            weakest = sorted(states, key=lambda state: (state.strength, state.skill_id))[:3]
            for state in weakest:
                areas.append(
                    FocusAreaOut(
                        attribute=state.skill_id,
                        priority=round(1.0 - state.strength, 4),
                        trend="improving" if state.reps > 1 and state.strength >= 0.5 else "flat",
                        reason=f"Mastery strength {state.strength:.2f} after {state.reps} rep(s)",
                        recommended_lesson_ids=lessons_for_attribute(state.skill_id),
                    )
                )
        else:
            for index, (attribute, reason) in enumerate(self._ONBOARDING):
                areas.append(
                    FocusAreaOut(
                        attribute=attribute,
                        priority=round(0.9 - index * 0.1, 4),
                        trend="flat",
                        reason=reason,
                        recommended_lesson_ids=lessons_for_attribute(attribute),
                    )
                )
        areas.sort(key=lambda area: (-area.priority, area.attribute))
        return AdvisorOut(
            user_id=user_id,
            computed_at=_now_iso(),
            source=self.name,
            focus_areas=areas,
        )


class InMemorySequencingProvider:
    """Deterministic queue: due reviews, then focus-area lessons, then progression."""

    name = "in_memory_default"

    def __init__(self, mastery: InMemoryMasteryProvider, advisor: AdvisorProvider) -> None:
        self._mastery = mastery
        self._advisor = advisor

    async def build_queue(self, user_id: str, limit: int) -> list[QueueItemOut]:
        lessons_by_id = {
            lesson["id"]: (course, lesson)
            for course in SEEDED_COURSES
            for lesson in course["lessons"]
        }
        ordered: list[tuple[str, str]] = []  # (lesson_id, reason/kind marker)
        seen: set[str] = set()

        # 1. Spaced-repetition reviews that are due.
        now = datetime.now(UTC)
        for state in sorted(await self._mastery.states(user_id), key=lambda s: s.next_due):
            if datetime.fromisoformat(state.next_due) > now:
                continue
            for lesson_id in lessons_for_attribute(state.skill_id):
                if lesson_id not in seen:
                    ordered.append((lesson_id, "review"))
                    seen.add(lesson_id)

        # 2. Lessons targeting the advisor's focus areas.
        snapshot = await self._advisor.focus_areas(user_id)
        for area in snapshot.focus_areas:
            for lesson_id in area.recommended_lesson_ids:
                if lesson_id not in seen:
                    ordered.append((lesson_id, "prq_weakness"))
                    seen.add(lesson_id)

        # 3. Remaining curriculum in authored order.
        for course in SEEDED_COURSES:
            for lesson in course["lessons"]:
                if lesson["id"] not in seen:
                    ordered.append((lesson["id"], "progression"))
                    seen.add(lesson["id"])

        queue: list[QueueItemOut] = []
        for position, (lesson_id, reason) in enumerate(ordered[:limit]):
            course, lesson = lessons_by_id[lesson_id]
            queue.append(
                QueueItemOut(
                    position=position,
                    lesson_id=lesson_id,
                    course_id=course["id"],
                    title=lesson["title"],
                    kind="review" if reason == "review" else "lesson",
                    reason="spaced_repetition" if reason == "review" else reason,
                    target_attributes=list(lesson["target_attributes"]),
                    drill_id=lesson["drill_id"],
                    estimated_minutes=lesson["estimated_minutes"],
                )
            )
        return queue


class SeededCourseCatalogProvider:
    """Published-course source backed by the seeded first-party curriculum."""

    name = "in_memory_default"

    async def published_courses(self) -> list[CatalogItemOut]:
        return [
            CatalogItemOut(
                id=course["id"],
                kind="course",
                title=course["title"],
                sport=course["sport"],
                status=course["status"],
                author_id=course["author_id"],
                version=course["version"],
                price_lc=course["price_lc"],
                price_usd=course["price_usd"],
                rating=None,
                payload=course,
            )
            for course in SEEDED_COURSES
            if course["status"] == "published"
        ]


class MarketplaceCardCatalogProvider:
    """Card source delegating to the existing marketplace lane.

    Calls ``marketplace_service.list_cards(db=None)`` so the seeded fallback
    catalog is used and the gateway never opens a DB connection itself. Wire a
    DB-backed provider through the registry when the marketplace lane exposes
    one.
    """

    name = "marketplace_service_seeded"

    async def active_cards(self, sport: str | None) -> list[CatalogItemOut]:
        cards = await marketplace_service.list_cards(db=None, category=sport)
        return [
            CatalogItemOut(
                id=card.id,
                kind="card",
                title=card.title or card.name,
                sport=card.sport,
                status="published",
                author_id=card.creator_id,
                version=1,
                price_lc=card.price_shards,
                price_usd=card.price_usd,
                rating=None,
                payload=card.model_dump(),
            )
            for card in cards
            if card.for_sale
        ]
