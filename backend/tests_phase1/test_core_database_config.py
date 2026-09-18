from __future__ import annotations

from core import normalize_asyncpg_dsn


def test_normalize_asyncpg_dsn_accepts_sqlalchemy_asyncpg_scheme() -> None:
    assert (
        normalize_asyncpg_dsn("postgresql+asyncpg://fel_user:fel_password@postgres:5432/fel_db")
        == "postgresql://fel_user:fel_password@postgres:5432/fel_db"
    )


def test_normalize_asyncpg_dsn_preserves_raw_asyncpg_and_non_postgres_urls() -> None:
    assert normalize_asyncpg_dsn("postgresql://user:pass@localhost:5432/db") == (
        "postgresql://user:pass@localhost:5432/db"
    )
    assert normalize_asyncpg_dsn("sqlite+aiosqlite:///:memory:") == "sqlite+aiosqlite:///:memory:"
