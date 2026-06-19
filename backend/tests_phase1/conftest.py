"""Phase 1 test path setup and in-memory SQLite bootstrap."""
from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("USE_SQLITE_DEV", "true")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

import pytest

from app.models import Base, User


@pytest.fixture(scope="session", autouse=True)
def bootstrap_test_database() -> None:
    """Create schema and seed users required for session FK constraints."""

    from app.dependencies import SessionLocal, engine

    async def _init() -> None:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        async with SessionLocal() as db:
            for user_id, email in (
                ("test-user", "test-user@fel.local"),
                ("dev-athlete", "dev-athlete@fel.local"),
            ):
                db.add(
                    User(
                        id=user_id,
                        firebase_uid=f"firebase-{user_id}",
                        email=email,
                        display_name=user_id,
                    )
                )
            await db.commit()

    asyncio.run(_init())
