"""Game/session routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.shell_auth import shell_subject
from app.dependencies import get_db
from app.schemas.session_receipt import SessionReceiptIn, SessionReceiptOut
from app.services.session_processor import session_processor

router = APIRouter(prefix="/games", tags=["games"])


@router.post("/session", response_model=SessionReceiptOut)
async def create_game_session(
    receipt: SessionReceiptIn,
    user_id: str = Depends(shell_subject),
    db: AsyncSession = Depends(get_db),
) -> SessionReceiptOut:
    """Submit a session receipt and return server-computed economy rewards."""

    return await session_processor.process(db=db, user_id=user_id, receipt=receipt)

