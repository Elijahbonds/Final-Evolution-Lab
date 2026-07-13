"""NEXUS Gateway v1 — the one stable surface the Abacus web app consumes.

Contract: docs/NEXUS_GATEWAY.md. Versioning: additive-only within
``/nexus/v1``; breaking changes ship as ``/nexus/v2`` alongside v1.

Wiring: this module deliberately does NOT touch app.main. Call
:func:`register` from composition code::

    from app.routers import gateway_v1
    gateway_v1.register(app)
"""
from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, FastAPI, Header, HTTPException, Query, status

from app.auth.shell_auth import shell_subject
from app.gateway import GATEWAY_API_VERSION
from app.gateway.idempotency import idempotency_store
from app.gateway.registry import get_providers
from app.gateway.schemas import (
    AdvisorOut,
    CatalogKind,
    CatalogOut,
    EconomyFanoutOut,
    GatewayMetaOut,
    PrqFanoutOut,
    QueueOut,
    SessionResultIn,
    SessionResultOut,
)
from app.schemas.session_receipt import SessionReceiptIn
from app.services.anticheat_validator import anti_cheat_validator
from app.services.economy_engine import economy_engine
from app.services.mri_engine import mri_engine
from app.utils.formulas import calculate_prq_delta

router = APIRouter(prefix=f"/nexus/{GATEWAY_API_VERSION}", tags=["nexus-gateway"])


def register(app: FastAPI) -> None:
    """Mount the gateway façade on an existing FastAPI app."""

    app.include_router(router)


@router.get("/meta", response_model=GatewayMetaOut)
async def gateway_meta() -> GatewayMetaOut:
    """Describe the gateway surface and its active providers."""

    return GatewayMetaOut(
        api=f"nexus/{GATEWAY_API_VERSION}",
        gateway_version=GATEWAY_API_VERSION,
        providers=get_providers().names(),
    )


@router.get("/queue", response_model=QueueOut)
async def get_queue(
    user_id: str = Depends(shell_subject),
    limit: int = Query(default=10, ge=1, le=50, description="Maximum queue length"),
) -> QueueOut:
    """Return the athlete's adaptive learning queue (sequencing lane)."""

    providers = get_providers()
    return QueueOut(
        user_id=user_id,
        computed_at=datetime.now(UTC).isoformat(),
        engine=providers.sequencing.name,
        queue=await providers.sequencing.build_queue(user_id, limit),
    )


@router.get("/catalog", response_model=CatalogOut)
async def get_catalog(
    kind: CatalogKind | None = Query(default=None, description="Filter: course | card; omit for both"),
    sport: str | None = Query(default=None, description="Filter by sport/category"),
    limit: int = Query(default=50, ge=1, le=200, description="Page size"),
    offset: int = Query(default=0, ge=0, description="Page offset"),
) -> CatalogOut:
    """Return the merged published-course + creator-card catalog."""

    providers = get_providers()
    items = []
    if kind in (None, "course"):
        items.extend(await providers.catalog_courses.published_courses())
    if kind in (None, "card"):
        items.extend(await providers.catalog_cards.active_cards(sport))
    if sport is not None:
        items = [item for item in items if item.sport == sport]
    items.sort(key=lambda item: (item.kind, item.id))
    return CatalogOut(items=items[offset : offset + limit], total=len(items), limit=limit, offset=offset)


@router.post("/session-result", response_model=SessionResultOut)
async def ingest_session_result(
    payload: SessionResultIn,
    user_id: str = Depends(shell_subject),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> SessionResultOut:
    """Ingest one finished session and fan out to prq / mastery / economy.

    Idempotent per (user, ``Idempotency-Key`` header, falling back to
    ``client_receipt_id``): replays return the original fan-out with
    ``idempotent_replay=true`` and cause no further writes.
    """

    key = idempotency_key or payload.client_receipt_id
    stored = idempotency_store.get(user_id, key)
    if stored is not None:
        return SessionResultOut(**{**stored, "idempotent_replay": True})

    receipt = SessionReceiptIn(
        mode_id=payload.mode_id,
        score=payload.score,
        outcome=payload.outcome,
        duration_seconds=payload.duration_seconds,
        completed=payload.completed,
        combo_count=payload.combo_count,
        critical_count=payload.critical_count,
        pacing_score=payload.pacing_score,
        arv=payload.arv,
        esi=payload.esi,
        telemetry=payload.telemetry,
    )
    validation = anti_cheat_validator.validate(receipt)
    if not validation.accepted:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=validation.reason)

    # Fan-out 1: economy (server-authoritative rewards; pure computation).
    economy = economy_engine.compute_session(receipt)

    # Fan-out 2: prq (delta bounded by the shared formula; MRI graded).
    prq_delta = calculate_prq_delta(
        mode_id=receipt.mode_id,
        score=receipt.score,
        outcome=receipt.outcome,
        combo_count=receipt.combo_count,
        critical_count=receipt.critical_count,
        mri_score=economy.mri,
        completed=receipt.completed,
        duration_seconds=receipt.duration_seconds,
    )

    # Fan-out 3: mastery (spaced-repetition state for the exercised skills).
    mastery = await get_providers().mastery.apply_result(user_id, payload, economy.mri)

    result = SessionResultOut(
        result_id=str(uuid4()),
        user_id=user_id,
        mode_id=payload.mode_id,
        lesson_id=payload.lesson_id,
        idempotent_replay=False,
        economy=EconomyFanoutOut(
            xp=economy.xp,
            shards=economy.shards,
            prq_delta=economy.prq_delta,
            mri=economy.mri,
            pacing_bonus_applied=economy.pacing_bonus_applied,
        ),
        prq=PrqFanoutOut(delta=prq_delta, mri=economy.mri, mri_grade=mri_engine.grade(economy.mri)),
        mastery=mastery,
    )
    idempotency_store.put(user_id, key, result.model_dump())
    return result


@router.get("/advisor", response_model=AdvisorOut)
async def get_advisor(user_id: str = Depends(shell_subject)) -> AdvisorOut:
    """Return the CELL focus-areas snapshot for the athlete."""

    return await get_providers().advisor.focus_areas(user_id)
