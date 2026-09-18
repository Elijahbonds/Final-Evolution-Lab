"""Regression coverage for monolith mode map/catalog resolution."""
from __future__ import annotations

import pytest

import server


class _FakeCollection:
    async def count_documents(self, _query: dict) -> int:
        return 0


class _FakeDb:
    def __getitem__(self, _name: str) -> _FakeCollection:
        return _FakeCollection()


def test_resolve_mode_map_preserves_dunk_aliases_and_irl_skip() -> None:
    registry = server.MODE_MANAGER["mode_manager"]["mode_registry"]

    legacy_dunk = server.resolve_mode_map("basketball_dunk", registry["basketball_dunk"])
    split_dunk = server.resolve_mode_map("basketball_dunk_3d", registry["basketball_dunk_3d"])
    irl_dunk = server.resolve_mode_map("basketball_dunk_irl", registry["basketball_dunk_irl"])

    assert legacy_dunk is not None
    assert legacy_dunk["map_token"] == "Venice_Beach_Court"
    assert legacy_dunk["venue_key"] == "venice_beach_court"
    assert legacy_dunk["deep_link"].startswith("finalevolution://launch?")

    assert split_dunk is not None
    assert split_dunk["map_token"] == "Venice_Beach_Court"
    assert split_dunk["venue_key"] == "venice_beach_court"

    assert irl_dunk is None


@pytest.mark.asyncio
async def test_catalog_routes_use_shared_mode_map_resolution(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(server, "db", _FakeDb())

    registry = await server.get_venue_registry()
    mapped = await server.get_all_mapped_modes()
    production = await server.get_production_modes()
    mapped_ids = {mode["mode_id"] for mode in mapped["modes"]}

    assert registry["total_modes"] == 19
    assert mapped["total_modes"] == 19
    assert mapped["all_linked"] is True
    assert production["total_modes"] == 19
    assert production["production_modes"] == 14
    assert production["staging_modes"] == 4
    assert "basketball_dunk" in mapped_ids
    assert "basketball_dunk_3d" in mapped_ids
    assert "basketball_dunk_irl" not in mapped_ids
    assert "market_browse" not in mapped_ids
    assert "movement_lab" not in mapped_ids
