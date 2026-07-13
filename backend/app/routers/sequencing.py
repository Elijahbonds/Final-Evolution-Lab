"""Adaptive sequencing routes (spec: [NEXUS] Education — recommender)."""
from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.shell_auth import shell_subject
from app.dependencies import get_db
from app.models.prq_profile import PRQProfile
from app.models.sequencing import MasteryState, Recommendation
from app.schemas.sequencing_schemas import (
    MasteryStateOut,
    MasteryUpdateIn,
    QueueItemOut,
    SequencingQueueOut,
)
from app.sequencer.engine import sequencing_engine
from app.sequencer.mastery import MasteryConfig, MasterySnapshot, apply_session, ensure_utc

router = APIRouter(prefix="/sequencing", tags=["sequencing"])

PRQ_VECTOR_FIELDS = ("vertical_power", "reaction_time", "mobility", "balance", "stamina")


def _prq_vector(profile: PRQProfile | None) -> dict[str, float]:
    """Attribute vector from the profile, or neutral 50s when unscanned."""

    if profile is None:
        return {attr: 50.0 for attr in PRQ_VECTOR_FIELDS}
    return {attr: float(getattr(profile, attr)) for attr in PRQ_VECTOR_FIELDS}


def _snapshot(state: MasteryState) -> MasterySnapshot:
    return MasterySnapshot(
        skill_id=state.skill_id,
        strength=state.strength,
        reps=state.reps,
        decay_rate=state.decay_rate,
        last_seen=ensure_utc(state.last_seen),
        next_due=ensure_utc(state.next_due),
    )


def _state_out(state: MasteryState) -> MasteryStateOut:
    return MasteryStateOut(
        skill_id=state.skill_id,
        strength=state.strength,
        reps=state.reps,
        decay_rate=state.decay_rate,
        last_seen=ensure_utc(state.last_seen),
        next_due=ensure_utc(state.next_due),
    )


@router.get("/queue", response_model=SequencingQueueOut)
async def get_sequencing_queue(
    readiness: float = Query(default=70.0, ge=0, le=100, description="Health/load readiness signal (0..100)"),
    limit: int = Query(default=10, ge=1, le=50, description="Max queue entries"),
    user_id: str = Depends(shell_subject),
    db: AsyncSession = Depends(get_db),
) -> SequencingQueueOut:
    """Recompute and persist the ordered lesson/drill queue for this user."""

    now = datetime.now(timezone.utc)

    profile = (
        await db.execute(select(PRQProfile).where(PRQProfile.user_id == user_id))
    ).scalar_one_or_none()
    states = (
        (await db.execute(select(MasteryState).where(MasteryState.user_id == user_id))).scalars().all()
    )

    prq = _prq_vector(profile)
    mastery = {state.skill_id: _snapshot(state) for state in states}
    items = sequencing_engine.build_queue(
        prq=prq, mastery=mastery, readiness=readiness, now=now, limit=limit
    )
    queue_payload = [item.as_dict() for item in items]

    recommendation = Recommendation(
        user_id=user_id,
        computed_at=now,
        readiness=readiness,
        queue=queue_payload,
        inputs_snapshot={
            "prq": prq,
            "readiness": readiness,
            "mastery": {
                skill_id: {
                    "strength": snap.strength,
                    "reps": snap.reps,
                    "last_seen": snap.last_seen.isoformat() if snap.last_seen else None,
                    "next_due": snap.next_due.isoformat() if snap.next_due else None,
                }
                for skill_id, snap in mastery.items()
            },
        },
    )
    try:
        db.add(recommendation)
        await db.commit()
    except Exception as exc:  # pragma: no cover - depends on DB availability
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Recommendation persistence failed: {exc}",
        ) from exc

    return SequencingQueueOut(
        recommendation_id=recommendation.id,
        user_id=user_id,
        computed_at=now,
        readiness=readiness,
        items=[QueueItemOut(**payload) for payload in queue_payload],
    )


@router.post("/mastery", response_model=MasteryStateOut)
async def record_mastery_result(
    update: MasteryUpdateIn,
    user_id: str = Depends(shell_subject),
    db: AsyncSession = Depends(get_db),
) -> MasteryStateOut:
    """Fold a session result into the skill's spaced-repetition state."""

    now = datetime.now(timezone.utc)
    state = (
        await db.execute(
            select(MasteryState).where(
                MasteryState.user_id == user_id, MasteryState.skill_id == update.skill_id
            )
        )
    ).scalar_one_or_none()

    if state is None:
        # Column defaults only apply at flush; set explicit initial values so the
        # spaced-repetition math sees numbers, not None.
        state = MasteryState(
            user_id=user_id,
            skill_id=update.skill_id,
            strength=0.0,
            reps=0,
            decay_rate=MasteryConfig.default_decay_rate,
        )
        # Seed the decay rate from the catalog when the skill is known content.
        for lesson in sequencing_engine.catalog:
            if lesson.lesson_id == update.lesson_id or lesson.skill_id == update.skill_id:
                state.decay_rate = lesson.decay_rate
                break
        db.add(state)

    updated = apply_session(_snapshot(state), update.quality, now)
    state.strength = updated.strength
    state.reps = updated.reps
    state.last_seen = updated.last_seen
    state.next_due = updated.next_due

    try:
        await db.commit()
    except Exception as exc:  # pragma: no cover - depends on DB availability
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Mastery persistence failed: {exc}",
        ) from exc

    return _state_out(state)


@router.get("/mastery", response_model=list[MasteryStateOut])
async def list_mastery_states(
    user_id: str = Depends(shell_subject),
    db: AsyncSession = Depends(get_db),
) -> list[MasteryStateOut]:
    """List the user's per-skill spaced-repetition states."""

    states = (
        (
            await db.execute(
                select(MasteryState)
                .where(MasteryState.user_id == user_id)
                .order_by(MasteryState.skill_id)
            )
        )
        .scalars()
        .all()
    )
    return [_state_out(state) for state in states]
