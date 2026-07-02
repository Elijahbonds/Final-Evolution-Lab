"""Firebase ID token verification.

Production uses Google's Firebase public certs. Local/test environments may use
unsigned emulator tokens so developers can run without Firebase credentials.
"""
from __future__ import annotations

from functools import lru_cache
from typing import Any

import httpx
import jwt
from fastapi import HTTPException, status

from app.config import get_settings

FIREBASE_CERT_URL = (
    "https://www.googleapis.com/robot/v1/metadata/x509/"
    "securetoken-system@system.gserviceaccount.com"
)


def _emulator_enabled() -> bool:
    settings = get_settings()
    return settings.environment != "production"


@lru_cache(maxsize=1)
def _project_id() -> str:
    return get_settings().firebase_project_id


async def verify_firebase_token(id_token: str) -> dict[str, Any]:
    """Verify a Firebase ID token and return decoded claims."""

    if _emulator_enabled():
        try:
            decoded = jwt.decode(id_token, options={"verify_signature": False})
        except Exception as exc:  # noqa: BLE001 - convert token parser errors to 401
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Invalid emulator Firebase token: {exc}",
            ) from exc
        if "sub" not in decoded and "uid" not in decoded:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token missing uid")
        return decoded

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.get(FIREBASE_CERT_URL)
            response.raise_for_status()
            public_keys = response.json()

        header = jwt.get_unverified_header(id_token)
        kid = header.get("kid")
        if not kid or kid not in public_keys:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token kid")

        project_id = _project_id()
        return jwt.decode(
            id_token,
            public_keys[kid],
            algorithms=["RS256"],
            audience=project_id,
            issuer=f"https://securetoken.google.com/{project_id}",
        )
    except HTTPException:
        raise
    except jwt.ExpiredSignatureError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired") from exc
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=f"Invalid token: {exc}") from exc
    except Exception as exc:  # noqa: BLE001 - normalize third-party failures
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token verification failed") from exc

