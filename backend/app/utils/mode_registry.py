"""Read-only helpers for the canonical FEL mode and venue registries."""
from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

BACKEND_ROOT = Path(__file__).resolve().parents[2]
MODE_MANAGER_PATH = BACKEND_ROOT / "FEL_ModeManager.production.json"
VENUE_REGISTRY_PATH = BACKEND_ROOT / "FEL_VenueRegistry.production.json"


@lru_cache(maxsize=1)
def load_mode_manager() -> dict[str, Any]:
    """Load the production mode manager from disk."""

    with MODE_MANAGER_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


@lru_cache(maxsize=1)
def load_venue_registry() -> dict[str, Any]:
    """Load venue display metadata from disk."""

    with VENUE_REGISTRY_PATH.open(encoding="utf-8") as handle:
        return json.load(handle)


def mode_registry() -> dict[str, dict[str, Any]]:
    """Return the canonical mode registry keyed by mode id."""

    registry = load_mode_manager().get("mode_manager", {}).get("mode_registry", {})
    return {mode_id: config for mode_id, config in registry.items() if isinstance(config, dict)}


def venue_mode_metadata() -> dict[str, dict[str, Any]]:
    """Return mode-specific venue metadata keyed by mode id."""

    modes = load_venue_registry().get("modes", [])
    return {mode.get("id", ""): mode for mode in modes if isinstance(mode, dict) and mode.get("id")}


def registry_prq_mode_weights(fallback: dict[str, float] | None = None) -> dict[str, float]:
    """Return PRQ weights sourced from FEL_ModeManager, with optional fallback values."""

    weights = dict(fallback or {})
    for mode_id, config in mode_registry().items():
        weight = config.get("prq_weight")
        if isinstance(weight, (int, float)):
            weights[mode_id] = float(weight)
    return weights


def production_mode_count() -> int:
    """Count modes marked production in the canonical registry."""

    return sum(1 for config in mode_registry().values() if config.get("status") == "production")


def catalog_mode_ids() -> list[str]:
    """Mode ids exposed to shell clients.

    Preview education modules are omitted from the game catalog, while the
    non-game market module remains visible and explicitly non-playable.
    """

    allowed_statuses = {"production", "staging", "non-game-module"}
    return [
        mode_id
        for mode_id, config in mode_registry().items()
        if config.get("status") in allowed_statuses
    ]
