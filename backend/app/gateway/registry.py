"""Provider registry: where other lanes plug into the gateway.

Discovery convention (documented in docs/NEXUS_GATEWAY.md):
a lane ships a module at one of the candidate paths below exposing a
module-level ``provider`` object satisfying the matching Protocol in
:mod:`app.gateway.providers`. First importable candidate wins; anything
missing or broken falls back to the in-memory default, so the gateway is
always serveable.

Tests (and app wiring code) may also inject providers directly with
:func:`set_providers` / :func:`reset_providers`.
"""
from __future__ import annotations

import importlib
from dataclasses import dataclass, field

from app.gateway.providers import (
    AdvisorProvider,
    CardCatalogProvider,
    CourseCatalogProvider,
    InMemoryAdvisorProvider,
    InMemoryMasteryProvider,
    InMemorySequencingProvider,
    MarketplaceCardCatalogProvider,
    MasteryProvider,
    SeededCourseCatalogProvider,
    SequencingProvider,
)

# Candidate adapter modules per capability, in priority order.
_DISCOVERY_PATHS: dict[str, tuple[str, ...]] = {
    "mastery": ("app.mastery.gateway_adapter",),
    "advisor": ("app.advisor.gateway_adapter", "app.cell.gateway_adapter"),
    "sequencing": ("app.sequencing.gateway_adapter",),
    "catalog_courses": ("app.education.gateway_adapter", "app.authoring.gateway_adapter"),
    "catalog_cards": ("app.marketplace.gateway_adapter",),
}


def _discover(capability: str):
    """Return the first importable lane provider for ``capability`` or None."""

    for module_path in _DISCOVERY_PATHS.get(capability, ()):
        try:
            module = importlib.import_module(module_path)
        except Exception:  # noqa: BLE001 — a broken lane must never take the gateway down
            continue
        provider = getattr(module, "provider", None)
        if provider is not None:
            return provider
    return None


@dataclass
class GatewayProviders:
    """The active provider set behind the v1 façade."""

    mastery: MasteryProvider
    advisor: AdvisorProvider
    sequencing: SequencingProvider
    catalog_courses: CourseCatalogProvider
    catalog_cards: CardCatalogProvider

    def names(self) -> dict[str, str]:
        """Active provider name per capability (served by /nexus/v1/meta)."""

        return {
            "mastery": self.mastery.name,
            "advisor": self.advisor.name,
            "sequencing": self.sequencing.name,
            "catalog_courses": self.catalog_courses.name,
            "catalog_cards": self.catalog_cards.name,
        }


def _build_default_providers() -> GatewayProviders:
    """Assemble discovered lane providers with in-memory fallbacks."""

    mastery = _discover("mastery") or InMemoryMasteryProvider()
    advisor = _discover("advisor") or InMemoryAdvisorProvider(mastery)
    sequencing = _discover("sequencing") or InMemorySequencingProvider(mastery, advisor)
    return GatewayProviders(
        mastery=mastery,
        advisor=advisor,
        sequencing=sequencing,
        catalog_courses=_discover("catalog_courses") or SeededCourseCatalogProvider(),
        catalog_cards=_discover("catalog_cards") or MarketplaceCardCatalogProvider(),
    )


_active: GatewayProviders | None = None


def get_providers() -> GatewayProviders:
    """Return the active provider set, building defaults on first use."""

    global _active
    if _active is None:
        _active = _build_default_providers()
    return _active


def set_providers(providers: GatewayProviders) -> None:
    """Replace the active provider set (wiring code / tests)."""

    global _active
    _active = providers


def reset_providers() -> None:
    """Drop overrides and rebuild defaults on next access."""

    global _active
    _active = None
