"""Auth schemas."""
from __future__ import annotations

from pydantic import BaseModel, Field


class FirebaseVerifyIn(BaseModel):
    """Firebase token verification request."""

    id_token: str = Field(min_length=1, description="Firebase ID token")


class SessionExchangeIn(BaseModel):
    """Legacy shell session exchange request."""

    session_id: str = Field(min_length=1, description="Firebase ID token or existing session id")


class AuthTokenOut(BaseModel):
    """FEL API token response."""

    access_token: str = Field(description="FEL API JWT")
    token_type: str = Field(default="bearer", description="Token type")
    user_id: str = Field(description="Firebase uid / FEL user id")

