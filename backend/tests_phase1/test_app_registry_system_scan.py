"""Guide-aligned app coverage for registry and FEL OS system scan routes."""
from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app


def test_app_registry_venues_matches_canonical_mode_manager() -> None:
    client = TestClient(app)

    response = client.get("/api/registry/venues")

    assert response.status_code == 200
    body = response.json()
    modes = {mode["mode_id"]: mode for mode in body["modes"]}

    assert body["total_modes"] == 22
    assert modes["basketball_h2h"]["map_path"].endswith("/Venice_Beach_Court")
    assert modes["basketball_dunk_3d"]["map_token"] == "Venice_Beach_Court"
    assert modes["basketball_dunk_irl"]["render_mode"] == "IRL"
    assert modes["basketball_dunk_irl"]["map_path"] is None
    assert modes["basketball_dunk_irl"]["launchable"] is True
    assert modes["movement_lab"]["status"] == "preview"
    assert modes["movement_lab"]["launchable"] is False


def test_system_scan_unified_powers_fel_os_dashboard() -> None:
    client = TestClient(app)

    response = client.get("/api/system-scan/unified")

    assert response.status_code == 200
    body = response.json()
    assert {"user", "scan", "cards", "arena", "academy", "biofuel"}.issubset(body.keys())
    assert body["scan"]["prq_score"] == 75.0
    assert body["arena"]["launchable_modes"] >= 20
    assert body["academy"]["bio_digital"]["modules_required"] == [
        "skeleton",
        "muscles",
        "movement_planes",
        "injury_prevention",
    ]


def test_system_scan_pass_meta_and_png_are_available() -> None:
    client = TestClient(app)

    meta = client.get("/api/system-scan/pass-meta/dev-athlete")
    image = client.get("/api/system-scan/pass/dev-athlete.png")

    assert meta.status_code == 200
    assert meta.json()["og_image_url_path"] == "/api/system-scan/pass/dev-athlete.png"
    assert "Final Evolution Lab" in meta.json()["share_text"] or "Final Evolution Lab" in meta.json()["name"]
    assert image.status_code == 200
    assert image.headers["content-type"] == "image/png"
    assert image.content.startswith(b"\x89PNG")
