"""Authorization dependency helpers."""
from __future__ import annotations

from typing import Annotated

from fastapi import Depends, Header, HTTPException, status

from app.auth.jwt_handler import decode_access_token


async def get_current_subject(
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    """Return the authenticated user id from a Bearer token."""

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")
    token = authorization.removeprefix("Bearer ").strip()
    try:
        claims = decode_access_token(token)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid bearer token") from exc
    subject = claims.get("sub")
    if not isinstance(subject, str) or not subject:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid subject")
    return subject


CurrentSubject = Annotated[str, Depends(get_current_subject)]

