"""Authoring lane test fixtures: in-memory SQLite + standalone app.

No live Postgres/Redis needed. The app under test is a bare FastAPI
instance with ONLY the authoring router mounted via ``register`` — main.py
is untouched by this lane.

Run:  backend/.venv/bin/python -m pytest backend/tests_authoring -q
"""
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
from fastapi import FastAPI
from fastapi.testclient import TestClient

import app.authoring.models  # noqa: F401  (register nexus_* tables on Base.metadata)
from app.auth.jwt_handler import create_access_token
from app.models import Base, User
from app.routers import authoring


SEED_USERS: tuple[tuple[str, str], ...] = (
    ("athlete-user", "athlete"),
    ("second-athlete", "athlete"),
    ("coach-user", "coach"),
    ("admin-user", "admin"),
    ("reviewer-user", "admin"),
)


@pytest.fixture(scope="session", autouse=True)
def bootstrap_database() -> None:
    """Create the full schema and seed users for author-profile FKs."""

    from app.dependencies import SessionLocal, engine

    async def _init() -> None:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        async with SessionLocal() as db:
            for user_id, role in SEED_USERS:
                db.add(
                    User(
                        id=user_id,
                        firebase_uid=f"firebase-{user_id}",
                        email=f"{user_id}@fel.local",
                        display_name=user_id,
                        role=role,
                    )
                )
            await db.commit()

    asyncio.run(_init())


@pytest.fixture(scope="session")
def client() -> TestClient:
    """Standalone app with only the authoring router mounted."""

    test_app = FastAPI(title="authoring-lane-test")
    authoring.register(test_app, api_prefix="/api")
    return TestClient(test_app)


def bearer(user_id: str) -> dict[str, str]:
    """Authorization header for a seeded user."""

    return {"Authorization": f"Bearer {create_access_token(user_id)}"}


def make_lesson(lesson_id: str, **overrides) -> dict:
    lesson = {
        "id": lesson_id,
        "title": f"Lesson {lesson_id}",
        "concept_text": "Load the hips before the arms.",
        "prereq_ids": [],
        "drill_options": ["drill_wall_sit"],
        "clip_refs": ["meshy://clips/hip-load"],
        "prq_delta": {"vertical_power": 2},
        "difficulty": 2,
        "decay_rate": 0.2,
    }
    lesson.update(overrides)
    return lesson


def make_content(**overrides) -> dict:
    content = {
        "modules": [
            {
                "id": "m1",
                "title": "Foundations",
                "lessons": [
                    make_lesson("l1"),
                    make_lesson("l2", prereq_ids=["l1"]),
                ],
            }
        ]
    }
    content.update(overrides)
    return content
