"""Application configuration for the guide-aligned FEL backend."""
from __future__ import annotations

from functools import lru_cache
from typing import Literal

try:
    from pydantic_settings import BaseSettings, SettingsConfigDict
except ModuleNotFoundError:  # pragma: no cover - compatibility with the legacy venv
    from pydantic import BaseSettings  # type: ignore[attr-defined]

    SettingsConfigDict = dict  # type: ignore[misc,assignment]


class Settings(BaseSettings):
    """Environment-backed settings.

    Defaults are local-development safe. Production must provide strong secrets and
    exact CORS origins.
    """

    app_name: str = "Final Evolution Lab API"
    environment: Literal["development", "test", "staging", "production"] = "development"
    api_prefix: str = "/api"
    cors_origins: list[str] = ["http://localhost:3000", "http://localhost:5173"]

    database_url: str = "postgresql+asyncpg://fel_user:fel_password@localhost:5432/fel_db"
    # USE_SQLITE_DEV=true enables local SQLite when Postgres is unavailable (dev/test only).
    # See backend/README.md for Docker migration steps before production cutover.
    use_sqlite_dev: bool = False
    sqlite_dev_path: str = "fel_dev.sqlite3"
    database_pool_size: int = 20
    database_max_overflow: int = 10

    redis_url: str = "redis://localhost:6379/0"
    celery_broker_url: str = "redis://localhost:6379/1"
    mongodb_url: str = "mongodb://localhost:27017/fel_telemetry"

    firebase_project_id: str = "final-evolution-lab"
    firebase_credentials_path: str | None = None
    jwt_secret_key: str = "dev-only-change-me-to-a-256-bit-secret-before-prod"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24

    stripe_secret_key: str | None = None
    stripe_webhook_secret: str | None = None
    marketplace_offline_payments: bool = True

    vault_ws_path: str = "/ws/vault"
    hud_ws_path: str = "/ws/hud"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    """Return cached process settings."""

    return Settings()

