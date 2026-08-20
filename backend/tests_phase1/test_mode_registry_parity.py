from __future__ import annotations

import json
import re
from pathlib import Path

from app.routers.mechanics import ARENA_MODES
from app.utils.constants import PRQ_MODE_WEIGHTS


REPO_ROOT = Path(__file__).resolve().parents[2]
MODE_MANAGER_PATH = REPO_ROOT / "backend" / "FEL_ModeManager.production.json"
FRONTEND_ARENA_MODES_PATH = REPO_ROOT / "frontend" / "src" / "lib" / "arenaModes.js"
FRONTEND_APP_PATH = REPO_ROOT / "frontend" / "src" / "App.js"


def _mode_registry() -> dict[str, dict]:
    payload = json.loads(MODE_MANAGER_PATH.read_text())
    return payload["mode_manager"]["mode_registry"]


def _shell_expected_ids() -> set[str]:
    registry = _mode_registry()
    return {
        mode_id
        for mode_id, entry in registry.items()
        if entry.get("status") == "production" or entry.get("status") == "non-game-module"
    }


def _frontend_fallback_ids() -> set[str]:
    content = FRONTEND_ARENA_MODES_PATH.read_text()
    return set(re.findall(r'\["([a-z0-9_]+)"', content))


def _frontend_prq_weight_ids() -> set[str]:
    content = FRONTEND_APP_PATH.read_text()
    weights_block = content.split("const PRQ_MODE_WEIGHTS = {", 1)[1].split("};", 1)[0]
    return set(re.findall(r"\b([a-z][a-z0-9_]*)\s*:", weights_block))


def test_phase1_shell_modes_match_mode_manager_shipping_surface() -> None:
    shell_ids = {row[0] for row in ARENA_MODES}

    assert shell_ids == _shell_expected_ids()
    assert "movement_lab" not in shell_ids
    assert "trivia_arena" not in shell_ids


def test_frontend_fallback_modes_match_phase1_shell_modes() -> None:
    assert _frontend_fallback_ids() == {row[0] for row in ARENA_MODES}


def test_phase1_and_frontend_prq_weights_cover_scored_registry_modes() -> None:
    scored_ids = {
        mode_id
        for mode_id, entry in _mode_registry().items()
        if entry.get("prq_weight", 0.0) > 0.0
    }

    assert scored_ids <= set(PRQ_MODE_WEIGHTS)
    assert scored_ids <= _frontend_prq_weight_ids()

    for mode_id in scored_ids:
        assert PRQ_MODE_WEIGHTS[mode_id] == _mode_registry()[mode_id]["prq_weight"]
