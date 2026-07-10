"""
Unit tests for /api/system-scan/unified endpoint.

Runs entirely offline — no real MongoDB required.
All motor/DB calls are mocked; MONGO_URL is set to a dummy value so
core.py can be imported without a live database.
"""
import os

# Must set env vars BEFORE any module in this process imports core.py
os.environ.setdefault("MONGO_URL", "mongodb://localhost:27017")
os.environ.setdefault("DB_NAME", "test_fel")
os.environ.setdefault("EMERGENT_LLM_KEY", "test-key-unused")

# Stub out optional third-party modules that are not installed in CI/dev.
# Must happen before any FEL module is imported.
import sys
import types
from unittest.mock import MagicMock  # needed for stubs below

def _stub_module(name: str) -> types.ModuleType:
    """Create and register a stub module (and all parent packages)."""
    parts = name.split(".")
    for i in range(1, len(parts) + 1):
        pkg = ".".join(parts[:i])
        if pkg not in sys.modules:
            sys.modules[pkg] = types.ModuleType(pkg)
    return sys.modules[name]

_em = _stub_module("emergentintegrations")
_em_llm = _stub_module("emergentintegrations.llm")
_em_chat = _stub_module("emergentintegrations.llm.chat")
_em_chat.LlmChat = MagicMock  # type: ignore[attr-defined]
_em_chat.UserMessage = MagicMock  # type: ignore[attr-defined]
_em_chat.ImageContent = MagicMock  # type: ignore[attr-defined]

# Patch motor at the class level so AsyncIOMotorClient never actually
# opens a socket, even during module-level core.py initialization.
from unittest.mock import AsyncMock, patch  # MagicMock already imported above

_motor_patcher = patch("motor.motor_asyncio.AsyncIOMotorClient")
_mock_motor_class = _motor_patcher.start()
# client[db_name] returns a generic MagicMock (never raises AttributeError)
_mock_motor_class.return_value.__getitem__ = lambda self, name: MagicMock()

# ── Safe to import app code now ────────────────────────────────────────────
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

import core  # noqa: E402 (needs env vars above)
from core import User
from routers.system_scan import router as scan_router, get_current_user

_test_app = FastAPI()
_test_app.include_router(scan_router)


# ── Helpers ────────────────────────────────────────────────────────────────

_MOCK_USER = User(
    user_id="u_test_01",
    email="athlete@fellab.io",
    name="Test Athlete",
    sport="basketball",
    prq_score=82.5,
    level=3,
    xp=450,
    streak_days=7,
    coins=350,
)


def _cursor(rows: list) -> MagicMock:
    """Return a chainable motor cursor mock that resolves .to_list() to `rows`."""
    m = MagicMock()
    m.sort.return_value = m
    m.limit.return_value = m
    m.to_list = AsyncMock(return_value=list(rows))
    return m


def _make_db(
    prq=None,
    health=None,
    vj=None,
    cards=None,
    payments=0,
    games=0,
    last_game=None,
    mode_docs=None,
    collections=None,
    sovereign=0,
    edu=None,
    bio_digital=None,
    biofuel_log=None,
    biofuel_scans=0,
) -> MagicMock:
    """Build a MagicMock that mimics core.db with full cursor chains."""
    d = MagicMock()

    # SCAN
    d.prq_metrics.find_one = AsyncMock(return_value=prq)
    d.health_metrics.find_one = AsyncMock(return_value=health)
    d.vertical_jump_log.find = MagicMock(return_value=_cursor(vj or []))

    # CARDS
    d.user_cards.find = MagicMock(return_value=_cursor(cards or []))
    d.payments.count_documents = AsyncMock(return_value=payments)

    # ARENA
    d.game_sessions.count_documents = AsyncMock(return_value=games)
    # find() is called twice: once for last_game, once for modes_unlocked
    _last_game_cursor = _cursor(last_game or [])
    _mode_cursor = _cursor(mode_docs or [])
    _call_count = [0]

    def _game_find(*args, **kwargs):
        _call_count[0] += 1
        # First call → last_game; subsequent call → mode list
        return _last_game_cursor if _call_count[0] == 1 else _mode_cursor

    d.game_sessions.find = MagicMock(side_effect=_game_find)
    d.list_collection_names = AsyncMock(return_value=collections or [])
    d.sovereign_sessions.count_documents = AsyncMock(return_value=sovereign)

    # ACADEMY
    d.education_progress.find = MagicMock(return_value=_cursor(edu or []))
    # _build_kinesiology_eligibility calls find_one on education_progress
    d.education_progress.find_one = AsyncMock(return_value=None)
    d.bio_digital_progress.find_one = AsyncMock(return_value=bio_digital)

    # BIOFUEL (5th pillar)
    d.biofuel_logs.find_one = AsyncMock(return_value=biofuel_log)
    d.biofuel_scans.count_documents = AsyncMock(return_value=biofuel_scans)

    return d


def _client(mock_db: MagicMock) -> TestClient:
    """Return a TestClient with auth bypassed and DB fully mocked."""
    _test_app.dependency_overrides[get_current_user] = lambda: _MOCK_USER
    return TestClient(
        _test_app,
        # Don't raise errors from within the TestClient — let tests assert on response
        raise_server_exceptions=True,
    )


# ── Tests ──────────────────────────────────────────────────────────────────

class TestUnifiedScanFullData:
    """All collections present — happy path."""

    def test_status_200(self):
        mock_db = _make_db(
            prq={"strength": 88, "speed": 85, "endurance": 80, "agility": 82,
                 "power": 90, "flexibility": 75, "recovery": 78, "mental": 86},
            health={"resting_hr": 58, "hrv": 72.0, "sleep_hours": 8.0, "vo2_max": 52.0},
            vj=[{"height_inches": 34, "recorded_at": "2026-01-01T00:00:00Z"}],
            cards=[{"card_id": "c1", "name": "KD"}, {"card_id": "c2", "name": "LBJ"}],
            payments=5, games=12,
            last_game=[{"mode": "basketball_h2h", "score": 88}],
            mode_docs=[{"mode_id": "basketball_h2h"}, {"mode_id": "court_carnival"}],
            edu=[{"track_id": "common_core", "completed_lessons": ["cc_ela_1", "cc_math_1"]}],
        )
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            resp = _client(mock_db).get("/api/system-scan/unified")

        assert resp.status_code == 200

    def test_top_level_keys_present(self):
        mock_db = _make_db(
            prq={"strength": 88},
            health={"resting_hr": 58},
            games=3,
            last_game=[{"mode": "basketball_h2h"}],
            mode_docs=[{"mode_id": "basketball_h2h"}],
        )
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        for key in ("scan", "cards", "arena", "academy"):
            assert key in data, f"Missing top-level key: {key}"

    def test_no_top_level_nulls(self):
        mock_db = _make_db(
            prq={"strength": 88},
            health={"resting_hr": 58},
            games=2,
            last_game=[{"mode": "surf"}],
            mode_docs=[{"mode_id": "surf"}],
        )
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        for key in ("scan", "cards", "arena", "academy"):
            assert data[key] is not None, f"Top-level key '{key}' must not be null"

    def test_scan_quadrant_values(self):
        mock_db = _make_db(
            prq={"strength": 88, "speed": 85, "endurance": 80, "agility": 82,
                 "power": 90, "flexibility": 75, "recovery": 78, "mental": 86},
            health={"resting_hr": 58, "hrv": 72.0, "sleep_hours": 8.0, "vo2_max": 52.0},
            vj=[{"height_inches": 34, "recorded_at": "2026-01-01T00:00:00Z"}],
        )
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        scan = data["scan"]
        assert scan["prq_score"] == 82.5
        assert scan["level"] == 3
        assert scan["xp"] == 450
        assert scan["streak_days"] == 7
        assert scan["coins"] == 350
        # All metrics present and non-null
        assert set(scan["metrics"].keys()) == {
            "strength", "speed", "endurance", "agility",
            "power", "flexibility", "recovery", "mental"
        }
        assert all(v is not None for v in scan["metrics"].values())
        # Health non-null
        assert scan["health"] is not None
        assert scan["health"]["resting_hr"] == 58.0
        # last_vertical_jump is dict (not None)
        assert isinstance(scan["last_vertical_jump"], dict)
        assert scan["last_vertical_jump"]["height_inches"] == 34

    def test_cards_quadrant(self):
        mock_db = _make_db(
            cards=[{"card_id": "c1"}, {"card_id": "c2"}, {"card_id": "c3"}],
            payments=7,
        )
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        cards = data["cards"]
        assert cards["owned_count"] == 3
        assert cards["lifetime_purchases"] == 7
        assert isinstance(cards["recent"], list)

    def test_arena_quadrant(self):
        mock_db = _make_db(
            games=12,
            last_game=[{"mode": "basketball_h2h", "score": 88, "created_at": "2026-01-01"}],
            mode_docs=[{"mode_id": "basketball_h2h"}, {"mode_id": "court_carnival"}, {"mode_id": "surf"}],
        )
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        arena = data["arena"]
        assert arena["modes_played"] == 12
        assert isinstance(arena["last_game"], dict)
        assert arena["last_game"].get("mode") == "basketball_h2h"
        assert isinstance(arena["modes_unlocked"], list)
        assert "basketball_h2h" in arena["modes_unlocked"]

    def test_academy_tracks_list(self):
        mock_db = _make_db(
            edu=[{"track_id": "common_core", "completed_lessons": ["cc_ela_1", "cc_math_1"]}],
        )
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        academy = data["academy"]
        assert "tracks" in academy
        assert isinstance(academy["tracks"], list)
        assert len(academy["tracks"]) > 0
        assert "certificates" in academy


class TestUnifiedScanPartialData:
    """Some collections missing or empty — must not raise or return nulls."""

    def test_missing_health_doc_returns_zero_defaults(self):
        """health_doc is None — health payload must be zeroed dict, not null."""
        mock_db = _make_db(health=None)  # health collection empty
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        health = data["scan"]["health"]
        assert health is not None, "health must not be null when doc is missing"
        assert health["resting_hr"] == 0.0
        assert health["hrv"] == 0.0
        assert health["sleep_hours"] == 0.0
        assert health["vo2_max"] == 0.0

    def test_missing_prq_doc_returns_zero_metrics(self):
        """prq_metrics doc is None — all metric values must be 0.0, not null."""
        mock_db = _make_db(prq=None)
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        metrics = data["scan"]["metrics"]
        assert all(v == 0.0 for v in metrics.values()), (
            f"All metrics must be 0.0 when prq doc missing, got: {metrics}"
        )

    def test_partial_prq_doc_fills_missing_fields_with_zero(self):
        """Only some metric fields present in doc — rest should be 0.0."""
        mock_db = _make_db(prq={"strength": 90, "speed": 85})
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        metrics = data["scan"]["metrics"]
        assert metrics["strength"] == 90.0
        assert metrics["speed"] == 85.0
        assert metrics["endurance"] == 0.0  # not in doc → 0.0

    def test_empty_cards_collection(self):
        """No owned cards — owned_count=0, recent=[]."""
        mock_db = _make_db(cards=[], payments=0)
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        cards = data["cards"]
        assert cards["owned_count"] == 0
        assert cards["recent"] == []

    def test_no_vertical_jump_history(self):
        """No VJ log — last_vertical_jump must be {} not None."""
        mock_db = _make_db(vj=[])
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        assert data["scan"]["last_vertical_jump"] == {}

    def test_no_game_sessions(self):
        """No games played — arena last_game={} and modes_unlocked=[]."""
        mock_db = _make_db(games=0, last_game=[], mode_docs=[])
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        arena = data["arena"]
        assert arena["modes_played"] == 0
        assert arena["last_game"] == {}
        assert arena["modes_unlocked"] == []


class TestUnifiedScanNewUser:
    """Completely fresh user — all collections empty."""

    def test_new_user_no_errors(self):
        """Brand new user with zero data must return 200 with valid payload."""
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            resp = _client(mock_db).get("/api/system-scan/unified")
        assert resp.status_code == 200

    def test_new_user_top_level_keys_present(self):
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        for key in ("scan", "cards", "arena", "academy"):
            assert key in data
            assert data[key] is not None

    def test_new_user_prq_score_from_user_model(self):
        """PRQ score comes from the User model default (82.5 for our mock user)."""
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        assert data["scan"]["prq_score"] == 82.5

    def test_new_user_all_metrics_zero(self):
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        metrics = data["scan"]["metrics"]
        for k, v in metrics.items():
            assert v == 0.0, f"metrics.{k} must be 0.0 for new user, got {v}"

    def test_new_user_zero_games(self):
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        assert data["arena"]["modes_played"] == 0
        assert data["cards"]["owned_count"] == 0
        assert data["academy"]["lessons_completed"] == 0

    def test_new_user_academy_tracks_populated(self):
        """Tracks list comes from seeded EDU_TRACKS constant — always non-empty."""
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        assert len(data["academy"]["tracks"]) > 0


class TestResponseModelValidation:
    """Verify pydantic model enforces expected shape."""

    def test_scan_metrics_keys_match_spec(self):
        expected_keys = {"strength", "speed", "endurance", "agility",
                         "power", "flexibility", "recovery", "mental"}
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        assert set(data["scan"]["metrics"].keys()) == expected_keys

    def test_health_keys_match_spec(self):
        expected_keys = {"resting_hr", "hrv", "sleep_hours", "vo2_max"}
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        assert set(data["scan"]["health"].keys()) == expected_keys

    def test_cards_keys_match_spec(self):
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        assert {"owned_count", "lifetime_purchases", "recent"}.issubset(data["cards"].keys())

    def test_arena_keys_match_spec(self):
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        assert {"modes_played", "last_game", "modes_unlocked"}.issubset(data["arena"].keys())

    def test_academy_keys_match_spec(self):
        mock_db = _make_db()
        with patch("routers.system_scan.db", mock_db), \
             patch("routers.education_tracks.db", mock_db):
            data = _client(mock_db).get("/api/system-scan/unified").json()

        assert {"tracks", "certificates"}.issubset(data["academy"].keys())
