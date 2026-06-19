"""Game/session routes."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Header
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.jwt_handler import decode_access_token
from app.dependencies import get_db
from app.schemas.session_receipt import SessionReceiptIn, SessionReceiptOut
from app.services.session_processor import session_processor

router = APIRouter(prefix="/games", tags=["games"])


def shell_subject(authorization: str | None = Header(default=None)) -> str:
    """Return authenticated user id, falling back to the local shell athlete."""

    if authorization and authorization.startswith("Bearer "):
        try:
            claims = decode_access_token(authorization.removeprefix("Bearer ").strip())
            subject = claims.get("sub")
            if isinstance(subject, str) and subject:
                return subject
        except Exception:
            pass
    return "dev-athlete"


@router.post("/session", response_model=SessionReceiptOut)
async def create_game_session(
    receipt: SessionReceiptIn,
    user_id: str = Depends(shell_subject),
    db: AsyncSession = Depends(get_db),
) -> SessionReceiptOut:
    """Submit a session receipt and return server-computed economy rewards."""

    return await session_processor.process(db=db, user_id=user_id, receipt=receipt)

