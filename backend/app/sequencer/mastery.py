"""Spaced-repetition mastery math.

Model: retention ``strength`` in [0, 1] decays exponentially between sessions
(Ebbinghaus-style ``s * exp(-decay_rate * days)``). A session result with
``quality`` in [0, 1] either reinforces (quality >= pass_quality) — gaining a
fraction of the remaining headroom — or erodes strength. The review interval
grows quadratically with post-session strength so cleared skills resurface
just before they decay.

All functions are pure and deterministic; the router layer owns persistence.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone


def ensure_utc(dt: datetime | None) -> datetime | None:
    """Return a timezone-aware UTC datetime (SQLite round-trips naive values)."""

    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def clamp(value: float, low: float, high: float) -> float:
    """Clamp ``value`` into [low, high]."""

    return max(low, min(high, value))


@dataclass(frozen=True)
class MasteryConfig:
    """Tunable constants for the spaced-repetition model."""

    default_decay_rate: float = 0.07  # per-day exponential retention decay
    learning_rate: float = 0.35  # headroom fraction gained on a perfect rep
    forgiveness: float = 0.20  # max strength fraction lost on a failed rep
    exposure_floor: float = 0.15  # credit factor so a failed first rep still registers
    pass_quality: float = 0.6  # quality threshold separating reinforce vs erode
    min_interval_days: float = 0.5
    max_interval_days: float = 45.0


@dataclass(frozen=True)
class MasterySnapshot:
    """Engine-facing view of one (user, skill) mastery state."""

    skill_id: str
    strength: float = 0.0
    reps: int = 0
    decay_rate: float = MasteryConfig.default_decay_rate
    last_seen: datetime | None = None
    next_due: datetime | None = None


def decayed_strength(
    strength: float,
    decay_rate: float,
    last_seen: datetime | None,
    now: datetime,
) -> float:
    """Return retention at ``now`` given the last reinforcement at ``last_seen``."""

    last = ensure_utc(last_seen)
    if last is None:
        return clamp(strength, 0.0, 1.0)
    days = max(0.0, (ensure_utc(now) - last).total_seconds() / 86400.0)
    return clamp(strength, 0.0, 1.0) * math.exp(-max(0.0, decay_rate) * days)


def review_interval_days(strength: float, quality: float, config: MasteryConfig) -> float:
    """Return days until the skill should resurface.

    A failed rep always resurfaces at the minimum interval; a passed rep grows
    quadratically with strength so strong skills wait longer.
    """

    if quality < config.pass_quality:
        return config.min_interval_days
    span = config.max_interval_days - config.min_interval_days
    return clamp(
        config.min_interval_days + span * clamp(strength, 0.0, 1.0) ** 2,
        config.min_interval_days,
        config.max_interval_days,
    )


def apply_session(
    snapshot: MasterySnapshot,
    quality: float,
    now: datetime,
    config: MasteryConfig | None = None,
) -> MasterySnapshot:
    """Fold one session result into the mastery state.

    ``quality`` is the server-graded session quality in [0, 1].
    """

    cfg = config or MasteryConfig()
    q = clamp(quality, 0.0, 1.0)
    now_utc = ensure_utc(now)
    assert now_utc is not None
    current = decayed_strength(snapshot.strength, snapshot.decay_rate, snapshot.last_seen, now_utc)

    if q >= cfg.pass_quality:
        new_strength = clamp(current + cfg.learning_rate * q * (1.0 - current), 0.0, 1.0)
    else:
        shortfall = (cfg.pass_quality - q) / cfg.pass_quality
        eroded = current - cfg.forgiveness * shortfall * current
        # Any rep is still exposure: never end below a small quality-scaled floor.
        new_strength = clamp(max(eroded, q * cfg.exposure_floor), 0.0, 1.0)

    interval = review_interval_days(new_strength, q, cfg)
    return MasterySnapshot(
        skill_id=snapshot.skill_id,
        strength=new_strength,
        reps=snapshot.reps + 1,
        decay_rate=snapshot.decay_rate,
        last_seen=now_utc,
        next_due=now_utc + timedelta(days=interval),
    )
