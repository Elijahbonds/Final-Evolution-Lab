from __future__ import annotations

from fastapi.testclient import TestClient

import server


def test_registry_venues_exposes_mode_manager_entries() -> None:
    client = TestClient(server.app)

    response = client.get("/api/registry/venues")

    assert response.status_code == 200
    body = response.json()
    modes = {mode["mode_id"]: mode for mode in body["modes"]}

    assert body["total_modes"] >= 20
    assert modes["basketball_h2h"]["map_path"].endswith("/Venice_Beach_Court")
    assert modes["basketball_dunk_3d"]["map_token"] == "Venice_Beach_Court"
    assert modes["basketball_dunk_irl"]["render_mode"] == "IRL"
    assert modes["basketball_dunk_irl"]["map_path"] is None
    assert modes["basketball_dunk_irl"]["launchable"] is True
    assert modes["movement_lab"]["status"] == "preview"
    assert modes["movement_lab"]["launchable"] is False


def test_production_resolver_keeps_irl_mode_launchable_without_ue_map() -> None:
    registry = server.MODE_MANAGER["mode_manager"]["mode_registry"]
    production_targets = [
        server._resolve_mode_launch_target(mode_id, config)
        for mode_id, config in registry.items()
        if config.get("status") == "production"
    ]
    production_targets = [target for target in production_targets if target is not None]
    by_mode = {target["mode_id"]: target for target in production_targets}

    assert len(production_targets) == 20
    assert by_mode["basketball_dunk_irl"]["is_irl_mode"] is True
    assert by_mode["basketball_dunk_irl"]["map_path"] is None
    assert by_mode["basketball_dunk_irl"]["map_token"] == "regulation_court_irl"
    assert by_mode["basketball_h2h"]["map_path"].endswith("/Venice_Beach_Court")
