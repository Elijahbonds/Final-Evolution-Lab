from __future__ import annotations

from fastapi.testclient import TestClient

import server


class _FakeCollection:
    async def count_documents(self, _query: dict) -> int:
        return 0


class _FakeDB:
    def __getitem__(self, _collection: str) -> _FakeCollection:
        return _FakeCollection()


def test_production_server_registry_routes_current_mode_schema(monkeypatch) -> None:
    monkeypatch.setattr(server, "db", _FakeDB())
    client = TestClient(server.app)

    registry = client.get("/api/registry/venues")
    mapped = client.get("/api/modes/mapped")
    production = client.get("/api/production/modes")

    assert registry.status_code == 200
    assert mapped.status_code == 200
    assert production.status_code == 200

    registry_body = registry.json()
    mapped_body = mapped.json()
    production_body = production.json()

    assert registry_body["total_modes"] == 22
    assert len(registry_body["modes"]) == 22
    assert mapped_body["total_modes"] == 22
    assert production_body["total_modes"] == 22
    assert production_body["production_modes"] == 20

    registry_by_id = {mode["mode_id"]: mode for mode in registry_body["modes"]}
    assert registry_by_id["basketball_dunk_3d"]["venue_token"] == "Venice_Beach_Court"
    assert registry_by_id["basketball_dunk_3d"]["launchable"] is True
    assert registry_by_id["basketball_dunk_irl"]["launchable"] is False
    assert registry_by_id["basketball_dunk_irl"]["non_launch_reason"] == "no_unreal_map"
    assert registry_by_id["market_browse"]["launchable"] is False
    assert registry_by_id["movement_lab"]["launchable"] is False
