"""Portable column types for Postgres prod and SQLite dev."""
from __future__ import annotations

from sqlalchemy import JSON
from sqlalchemy.dialects.postgresql import JSONB

PortableJSON = JSON().with_variant(JSONB, "postgresql")
