"""Priority scoring + queue assembly for the adaptive sequencer.

Per spec ([NEXUS] Education — Adaptive sequencing engine) the recommender
consumes three inputs and emits an ordered lesson/drill queue:

* **PRQ profile** — attribute vector; low attributes raise the priority of
  lessons that target them (weakness-targeting).
* **Mastery history** — spaced-repetition state; skills near/past ``next_due``
  resurface before they decay (due-for-review).
* **Readiness signal** — 0-100 health/load score; a fatigued athlete is gated
  toward cognitive/technique work instead of high-load drills.

The engine is pure: no I/O, deterministic for identical inputs.
"""
from __future__ import annotations

import math
from dataclasses import dataclass, field
from datetime import datetime
from typing import Any, Mapping

from app.sequencer.catalog import DEFAULT_CATALOG, LessonSpec
from app.sequencer.mastery import MasterySnapshot, clamp, decayed_strength, ensure_utc

DEFAULT_ATTRIBUTE_SCORE = 50.0


@dataclass(frozen=True)
class SequencerConfig:
    """Tunable weights and gates for priority scoring."""

    weight_weakness: float = 0.55
    weight_due: float = 0.45
    novelty_prior: float = 0.55  # due-score for never-seen skills
    due_sigmoid_days: float = 3.0  # days-overdue scale of the due sigmoid
    fatigued_threshold: float = 40.0
    fresh_threshold: float = 70.0
    fatigued_high_load_multiplier: float = 0.25
    fatigued_moderate_load_multiplier: float = 0.7
    fatigued_low_impact_boost: float = 1.25  # cognitive/technique boost when fatigued
    fresh_high_load_boost: float = 1.1


@dataclass(frozen=True)
class QueueItem:
    """One ranked entry in the recommendation queue."""

    lesson_id: str
    title: str
    skill_id: str
    kind: str
    load: str
    priority: float
    weakness_score: float
    due_score: float
    readiness_multiplier: float
    reasons: tuple[str, ...] = field(default=())

    def as_dict(self) -> dict[str, Any]:
        """JSON-serializable representation for persistence and transport."""

        return {
            "lesson_id": self.lesson_id,
            "title": self.title,
            "skill_id": self.skill_id,
            "kind": self.kind,
            "load": self.load,
            "priority": self.priority,
            "weakness_score": self.weakness_score,
            "due_score": self.due_score,
            "readiness_multiplier": self.readiness_multiplier,
            "reasons": list(self.reasons),
        }


class SequencingEngine:
    """Assemble the ordered lesson queue from PRQ + mastery + readiness."""

    def __init__(
        self,
        catalog: tuple[LessonSpec, ...] = DEFAULT_CATALOG,
        config: SequencerConfig | None = None,
    ) -> None:
        self._catalog = catalog
        self._config = config or SequencerConfig()

    @property
    def catalog(self) -> tuple[LessonSpec, ...]:
        return self._catalog

    def weakness_score(self, prq: Mapping[str, float], lesson: LessonSpec) -> float:
        """Mean normalized deficit across the lesson's target attributes."""

        if not lesson.targets:
            return 0.0
        deficits = [
            clamp((100.0 - float(prq.get(attr, DEFAULT_ATTRIBUTE_SCORE))) / 100.0, 0.0, 1.0)
            for attr in lesson.targets
        ]
        return sum(deficits) / len(deficits)

    def due_score(self, snapshot: MasterySnapshot | None, now: datetime) -> float:
        """Sigmoid on days past ``next_due``: 0.5 exactly at due, -> 1 overdue."""

        if snapshot is None or snapshot.next_due is None:
            return self._config.novelty_prior
        now_utc = ensure_utc(now)
        due_utc = ensure_utc(snapshot.next_due)
        assert now_utc is not None and due_utc is not None
        overdue_days = (now_utc - due_utc).total_seconds() / 86400.0
        return 1.0 / (1.0 + math.exp(-overdue_days / self._config.due_sigmoid_days))

    def readiness_multiplier(self, readiness: float, lesson: LessonSpec) -> float:
        """Gate lesson priority by the athlete's readiness signal."""

        cfg = self._config
        readiness = clamp(readiness, 0.0, 100.0)
        if readiness < cfg.fatigued_threshold:
            if lesson.load == "high":
                multiplier = cfg.fatigued_high_load_multiplier
            elif lesson.load == "moderate":
                multiplier = cfg.fatigued_moderate_load_multiplier
            else:
                multiplier = 1.0
            if lesson.kind in ("cognitive", "technique"):
                multiplier *= cfg.fatigued_low_impact_boost
            return multiplier
        if readiness >= cfg.fresh_threshold and lesson.load == "high":
            return cfg.fresh_high_load_boost
        return 1.0

    def build_queue(
        self,
        *,
        prq: Mapping[str, float],
        mastery: Mapping[str, MasterySnapshot],
        readiness: float,
        now: datetime,
        limit: int = 10,
    ) -> list[QueueItem]:
        """Score every catalog lesson and return the top ``limit`` in order."""

        cfg = self._config
        items: list[QueueItem] = []
        for lesson in self._catalog:
            snapshot = mastery.get(lesson.skill_id)
            weakness = self.weakness_score(prq, lesson)
            due = self.due_score(snapshot, now)
            multiplier = self.readiness_multiplier(readiness, lesson)
            priority = round((cfg.weight_weakness * weakness + cfg.weight_due * due) * multiplier, 6)

            reasons: list[str] = []
            weakest = min(
                lesson.targets,
                key=lambda attr: float(prq.get(attr, DEFAULT_ATTRIBUTE_SCORE)),
                default=None,
            )
            if weakest is not None:
                reasons.append(
                    f"targets {weakest} ({float(prq.get(weakest, DEFAULT_ATTRIBUTE_SCORE)):.0f}/100)"
                )
            if snapshot is None or snapshot.next_due is None:
                reasons.append("new skill (never trained)")
            else:
                now_utc = ensure_utc(now)
                due_utc = ensure_utc(snapshot.next_due)
                assert now_utc is not None and due_utc is not None
                overdue_days = (now_utc - due_utc).total_seconds() / 86400.0
                if overdue_days >= 0:
                    reasons.append(f"review due ({overdue_days:.1f}d overdue)")
                else:
                    retained = decayed_strength(
                        snapshot.strength, snapshot.decay_rate, snapshot.last_seen, now_utc
                    )
                    reasons.append(f"retention {retained:.0%}, next review in {-overdue_days:.1f}d")
            if multiplier < 1.0:
                reasons.append(f"deprioritized: readiness {readiness:.0f} vs {lesson.load} load")
            elif multiplier > 1.0:
                if readiness < cfg.fatigued_threshold:
                    reasons.append(f"boosted: low-impact {lesson.kind} fit for readiness {readiness:.0f}")
                else:
                    reasons.append(f"boosted: readiness {readiness:.0f} supports {lesson.load} load")

            items.append(
                QueueItem(
                    lesson_id=lesson.lesson_id,
                    title=lesson.title,
                    skill_id=lesson.skill_id,
                    kind=lesson.kind,
                    load=lesson.load,
                    priority=priority,
                    weakness_score=round(weakness, 6),
                    due_score=round(due, 6),
                    readiness_multiplier=round(multiplier, 6),
                    reasons=tuple(reasons),
                )
            )

        items.sort(key=lambda item: (-item.priority, item.lesson_id))
        return items[: max(1, limit)]


sequencing_engine = SequencingEngine()
