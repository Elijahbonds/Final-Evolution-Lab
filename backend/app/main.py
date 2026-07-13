"""FastAPI application factory for the guide-aligned backend."""
from __future__ import annotations

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.dependencies import close_resources
from app.routers import (
    auth,
    economy,
    games,
    marketplace,
    mechanics,
    payments,
    prq,
    sequencing,
    webhooks,
)
from app.websockets.hud_channel import hud_ws_router
from app.websockets.vault_channel import vault_ws_router


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncGenerator[None, None]:
    """Application lifecycle."""

    yield
    await close_resources()


def create_app() -> FastAPI:
    """Create and configure the FEL API."""

    settings = get_settings()
    app = FastAPI(title=settings.app_name, version="1.0.0", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(auth.router, prefix=settings.api_prefix)
    app.include_router(games.router, prefix=settings.api_prefix)
    app.include_router(economy.router, prefix=settings.api_prefix)
    app.include_router(prq.router, prefix=settings.api_prefix)
    app.include_router(marketplace.router, prefix=settings.api_prefix)
    app.include_router(mechanics.router, prefix=settings.api_prefix)
    app.include_router(sequencing.router, prefix=settings.api_prefix)
    app.include_router(payments.router, prefix=settings.api_prefix)
    app.include_router(webhooks.router, prefix=settings.api_prefix)
    app.include_router(vault_ws_router)
    app.include_router(hud_ws_router)

    @app.get("/healthz")
    async def healthz() -> dict[str, str]:
        return {"status": "ok"}

    return app


app = create_app()

