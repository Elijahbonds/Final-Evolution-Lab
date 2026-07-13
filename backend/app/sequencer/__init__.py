"""Adaptive sequencing engine (spec: [NEXUS] Education — recommender).

Pure computation lives in :mod:`app.sequencer.mastery` (spaced-repetition math)
and :mod:`app.sequencer.engine` (priority scoring + queue assembly).
Content the engine draws from lives in :mod:`app.sequencer.catalog`.
Persistence + HTTP wiring live in ``app.models.sequencing`` and
``app.routers.sequencing``.
"""
from app.sequencer.catalog import DEFAULT_CATALOG, LessonSpec
from app.sequencer.engine import QueueItem, SequencerConfig, SequencingEngine, sequencing_engine
from app.sequencer.mastery import MasteryConfig, MasterySnapshot, apply_session, decayed_strength

__all__ = [
    "DEFAULT_CATALOG",
    "LessonSpec",
    "MasteryConfig",
    "MasterySnapshot",
    "QueueItem",
    "SequencerConfig",
    "SequencingEngine",
    "apply_session",
    "decayed_strength",
    "sequencing_engine",
]
