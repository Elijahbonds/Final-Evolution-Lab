"""Shared FastAPI dependencies."""
from __future__ import annotations

from collections.abc import AsyncGenerator

try:
    from redis.asyncio import Redis
except ModuleNotFoundError:  # pragma: no cover - installed in Phase 1 requirements
    Redis = None  # type: ignore[assignment]
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import StaticPool

from app.config import get_settings

settings = get_settings()


def resolve_database_url() -> str:
    """Return the active database URL.

    When ``USE_SQLITE_DEV=true`` (development/test only), fall back to a local
    SQLite file so the app runs without Docker Postgres. Production must keep
    this flag disabled.
    """

    if settings.use_sqlite_dev:
        if settings.database_url.startswith("sqlite"):
            return settings.database_url
        return f"sqlite+aiosqlite:///{settings.sqlite_dev_path}"
    return settings.database_url


def _build_engine() -> AsyncEngine:
    url = resolve_database_url()
    if url.startswith("sqlite"):
        return create_async_engine(
            url,
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
            pool_pre_ping=True,
        )
    return create_async_engine(
        url,
        pool_size=settings.database_pool_size,
        max_overflow=settings.database_max_overflow,
        pool_pre_ping=True,
    )


engine = _build_engine()
SessionLocal = async_sessionmaker(engine, expire_on_commit=False)

_redis: Redis | None = None


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Yield an async DB session."""

    async with SessionLocal() as session:
        yield session


async def get_redis() -> Redis:
    """Return a lazy Redis client."""

    if Redis is None:
        raise RuntimeError("redis package is not installed")
    global _redis
    if _redis is None:
        _redis = Redis.from_url(settings.redis_url, decode_responses=True)
    return _redis


async def close_resources() -> None:
    """Release process-wide clients."""

    global _redis
    if _redis is not None:
        await _redis.aclose()
        _redis = None
    await engine.dispose()
