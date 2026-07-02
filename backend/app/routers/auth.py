"""Authentication routes."""
from __future__ import annotations

from fastapi import APIRouter, Header, Response
from pydantic import ValidationError

from app.auth.firebase_verify import verify_firebase_token
from app.auth.jwt_handler import create_access_token, decode_access_token
from app.schemas.auth_schemas import AuthTokenOut, FirebaseVerifyIn, SessionExchangeIn

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/verify", response_model=AuthTokenOut)
async def verify_firebase(request: FirebaseVerifyIn) -> AuthTokenOut:
    """Verify Firebase token and mint a FEL API token."""

    claims = await verify_firebase_token(request.id_token)
    user_id = str(claims.get("sub") or claims.get("uid"))
    token = create_access_token(user_id, {"firebase": True, "email": claims.get("email")})
    return AuthTokenOut(access_token=token, user_id=user_id)


def _user_payload(user_id: str, *, email: str | None = None, name: str | None = None, picture: str | None = None) -> dict:
    return {
        "user_id": user_id,
        "id": user_id,
        "email": email or f"{user_id}@local.fel",
        "name": name or "FEL Athlete",
        "picture": picture,
        "role": "athlete",
        "sport": "basketball",
        "level": 1,
        "xp": 0,
        "prq_score": 75.0,
    }


@router.post("/session")
async def session_exchange(request: SessionExchangeIn, response: Response) -> dict:
    """Compatibility endpoint used by the existing React shell.

    Accepts a Firebase ID token (preferred) or an opaque local/dev session id,
    then returns the legacy user payload plus `session_token`.
    """

    claims: dict = {}
    try:
        claims = await verify_firebase_token(request.session_id)
    except Exception:
        # Local shell mode: allow opaque session ids so the UI can boot without Firebase.
        claims = {"sub": request.session_id if request.session_id.startswith("sess_") else "dev-athlete"}

    user_id = str(claims.get("sub") or claims.get("uid") or "dev-athlete")
    token = create_access_token(user_id, {"email": claims.get("email"), "firebase": "email" in claims})
    response.set_cookie(
        "session_token",
        token,
        httponly=True,
        samesite="lax",
        secure=False,
        max_age=60 * 60 * 24,
    )
    payload = _user_payload(
        user_id,
        email=claims.get("email"),
        name=claims.get("name"),
        picture=claims.get("picture"),
    )
    payload["session_token"] = token
    return payload


@router.get("/me")
async def me(authorization: str | None = Header(default=None)) -> dict:
    """Return a shell-safe user payload.

    If no token is present, return a local dev athlete so the shell can boot.
    """

    if authorization and authorization.startswith("Bearer "):
        try:
            claims = decode_access_token(authorization.removeprefix("Bearer ").strip())
            return _user_payload(str(claims.get("sub") or "dev-athlete"), email=claims.get("email"))
        except (ValidationError, Exception):
            pass
    return _user_payload("dev-athlete")


@router.post("/logout")
async def logout(response: Response) -> dict[str, str]:
    """Clear shell auth cookie."""

    response.delete_cookie("session_token")
    return {"status": "ok"}

