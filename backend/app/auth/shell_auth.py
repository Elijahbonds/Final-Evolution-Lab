"""Shared auth resolution for shell/PWA endpoints."""
from __future__ import annotations

from fastapi import Header

from app.auth.firebase_verify import verify_firebase_token
from app.auth.jwt_handler import decode_access_token


async def resolve_shell_user_id(authorization: str | None) -> str:
    """Return user id from FEL JWT or Firebase Bearer token, else dev shell athlete."""

    if authorization and authorization.startswith("Bearer "):
        token = authorization.removeprefix("Bearer ").strip()
        if token:
            try:
                claims = decode_access_token(token)
                subject = claims.get("sub")
                if isinstance(subject, str) and subject:
                    return subject
            except Exception:
                pass
            try:
                claims = await verify_firebase_token(token)
                uid = claims.get("sub") or claims.get("uid") or claims.get("user_id")
                if isinstance(uid, str) and uid:
                    return uid
            except Exception:
                pass
    return "dev-athlete"


async def shell_subject(authorization: str | None = Header(default=None)) -> str:
    """FastAPI dependency wrapper for ``resolve_shell_user_id``."""

    return await resolve_shell_user_id(authorization)
