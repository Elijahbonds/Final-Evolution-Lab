"""Contract tests for the NEXUS Gateway v1 façade (docs/NEXUS_GATEWAY.md).

Runs fully offline: the gateway is mounted on a bare FastAPI app (no
app.main import, no DB, no Redis). Lane delegation is exercised twice —
once against the in-memory defaults and once against injected fakes to
prove the provider seam.

Run:
    backend/.venv/bin/python -m pytest backend/tests/test_gateway_contract.py -q
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

os.environ.setdefault("ENVIRONMENT", "test")
os.environ.setdefault("USE_SQLITE_DEV", "true")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.auth.jwt_handler import create_access_token
from app.gateway.idempotency import idempotency_store
from app.gateway.providers import (
    InMemoryAdvisorProvider,
    InMemoryMasteryProvider,
    InMemorySequencingProvider,
    MarketplaceCardCatalogProvider,
    SeededCourseCatalogProvider,
    SEEDED_COURSES,
)
from app.gateway.registry import GatewayProviders, reset_providers, set_providers
from app.gateway.schemas import AdvisorOut, CatalogItemOut, FocusAreaOut, QueueItemOut
from app.routers import gateway_v1


def _make_app() -> FastAPI:
    app = FastAPI()
    gateway_v1.register(app)
    return app


@pytest.fixture(autouse=True)
def _fresh_gateway_state():
    """Reset provider registry + idempotency store around every test."""

    reset_providers()
    idempotency_store.reset()
    yield
    reset_providers()
    idempotency_store.reset()


@pytest.fixture()
def client() -> TestClient:
    return TestClient(_make_app(), raise_server_exceptions=True)


def _auth(user_id: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {create_access_token(user_id)}"}


def _session_result(receipt_id: str = "rcpt-1", **overrides) -> dict:
    payload = {
        "client_receipt_id": receipt_id,
        "mode_id": "basketball_dunk",
        "score": 82,
        "outcome": "win",
        "duration_seconds": 95,
        "completed": True,
        "combo_count": 4,
        "critical_count": 2,
        "pacing_score": 80.0,
        "arv": 70.0,
        "esi": 65.0,
        "skill_ids": ["vertical_control", "finishing"],
        "lesson_id": "lesson_dunk_takeoff",
    }
    payload.update(overrides)
    return payload


# ── /nexus/v1/meta ───────────────────────────────────────────────────────────
def test_meta_reports_surface_and_providers(client: TestClient) -> None:
    response = client.get("/nexus/v1/meta")
    assert response.status_code == 200
    body = response.json()
    assert body["api"] == "nexus/v1"
    assert body["gateway_version"] == "v1"
    for capability in ("mastery", "advisor", "sequencing", "catalog_courses", "catalog_cards"):
        assert capability in body["providers"]


# ── Auth ─────────────────────────────────────────────────────────────────────
def test_no_token_falls_back_to_dev_athlete(client: TestClient) -> None:
    body = client.get("/nexus/v1/queue").json()
    assert body["user_id"] == "dev-athlete"


def test_bearer_token_subject_is_used(client: TestClient) -> None:
    body = client.get("/nexus/v1/queue", headers=_auth("athlete-42")).json()
    assert body["user_id"] == "athlete-42"


# ── /nexus/v1/queue ──────────────────────────────────────────────────────────
def test_queue_contract_shape_and_limit(client: TestClient) -> None:
    response = client.get("/nexus/v1/queue?limit=3", headers=_auth("athlete-q"))
    assert response.status_code == 200
    body = response.json()
    assert body["engine"] == "in_memory_default"
    assert len(body["queue"]) == 3
    for position, item in enumerate(body["queue"]):
        assert item["position"] == position
        assert item["kind"] in ("lesson", "review", "micro_lesson")
        assert item["reason"] in ("prq_weakness", "spaced_repetition", "progression")
        assert item["lesson_id"] and item["course_id"] and item["title"]
        assert isinstance(item["target_attributes"], list)


def test_queue_covers_full_seeded_curriculum_without_duplicates(client: TestClient) -> None:
    body = client.get("/nexus/v1/queue?limit=50", headers=_auth("athlete-q2")).json()
    lesson_ids = [item["lesson_id"] for item in body["queue"]]
    seeded = {lesson["id"] for course in SEEDED_COURSES for lesson in course["lessons"]}
    assert len(lesson_ids) == len(set(lesson_ids))
    assert set(lesson_ids) == seeded


def test_queue_reprioritizes_after_weak_session(client: TestClient) -> None:
    """A weak session on a skill should pull its lessons toward the front."""

    headers = _auth("athlete-weak")
    client.post(
        "/nexus/v1/session-result",
        json=_session_result("rcpt-weak", score=5, outcome="loss", skill_ids=["combo_flow"]),
        headers=headers,
    )
    body = client.get("/nexus/v1/queue?limit=50", headers=headers).json()
    first = body["queue"][0]
    assert "combo_flow" in first["target_attributes"]
    assert first["reason"] == "prq_weakness"


def test_queue_limit_validation(client: TestClient) -> None:
    assert client.get("/nexus/v1/queue?limit=0").status_code == 422
    assert client.get("/nexus/v1/queue?limit=51").status_code == 422


# ── /nexus/v1/catalog ────────────────────────────────────────────────────────
def test_catalog_merges_courses_and_cards(client: TestClient) -> None:
    response = client.get("/nexus/v1/catalog")
    assert response.status_code == 200
    body = response.json()
    kinds = {item["kind"] for item in body["items"]}
    assert kinds == {"course", "card"}
    assert body["total"] == len(body["items"])
    for item in body["items"]:
        assert item["status"] == "published"
        assert item["id"] and item["title"]
        assert isinstance(item["payload"], dict)


def test_catalog_kind_filter(client: TestClient) -> None:
    courses = client.get("/nexus/v1/catalog?kind=course").json()
    assert courses["items"] and all(item["kind"] == "course" for item in courses["items"])
    cards = client.get("/nexus/v1/catalog?kind=card").json()
    assert cards["items"] and all(item["kind"] == "card" for item in cards["items"])


def test_catalog_sport_filter_and_pagination(client: TestClient) -> None:
    body = client.get("/nexus/v1/catalog?sport=basketball").json()
    assert body["items"]
    assert all(item["sport"] == "basketball" for item in body["items"])

    page = client.get("/nexus/v1/catalog?limit=1&offset=1").json()
    assert len(page["items"]) == 1
    assert page["limit"] == 1 and page["offset"] == 1
    full = client.get("/nexus/v1/catalog").json()
    assert page["total"] == full["total"]
    assert page["items"][0]["id"] == full["items"][1]["id"]


def test_catalog_rejects_unknown_kind(client: TestClient) -> None:
    assert client.get("/nexus/v1/catalog?kind=bundle").status_code == 422


# ── /nexus/v1/session-result ─────────────────────────────────────────────────
def test_session_result_fans_out_to_economy_prq_mastery(client: TestClient) -> None:
    response = client.post(
        "/nexus/v1/session-result", json=_session_result(), headers=_auth("athlete-sr")
    )
    assert response.status_code == 200
    body = response.json()
    assert body["user_id"] == "athlete-sr"
    assert body["mode_id"] == "basketball_dunk"
    assert body["lesson_id"] == "lesson_dunk_takeoff"
    assert body["idempotent_replay"] is False
    assert body["result_id"]

    economy = body["economy"]
    assert economy["xp"] > 0
    assert economy["shards"] > 0
    assert economy["pacing_bonus_applied"] is True  # pacing 80 >= 75

    prq = body["prq"]
    assert prq["delta"] == economy["prq_delta"]
    assert prq["mri"] == economy["mri"]
    assert isinstance(prq["mri_grade"], str) and prq["mri_grade"]

    updated = {state["skill_id"]: state for state in body["mastery"]["updated"]}
    assert set(updated) == {"vertical_control", "finishing"}
    for state in updated.values():
        assert 0.0 <= state["strength"] <= 1.0
        assert state["reps"] == 1
        assert state["next_due"] > state["last_seen"]


def test_session_result_defaults_skills_to_mode_id(client: TestClient) -> None:
    body = client.post(
        "/nexus/v1/session-result",
        json=_session_result("rcpt-mode", skill_ids=[]),
        headers=_auth("athlete-mode"),
    ).json()
    assert [state["skill_id"] for state in body["mastery"]["updated"]] == ["basketball_dunk"]


def test_session_result_idempotent_replay(client: TestClient) -> None:
    headers = _auth("athlete-idem")
    payload = _session_result("rcpt-idem")
    first = client.post("/nexus/v1/session-result", json=payload, headers=headers).json()
    second = client.post("/nexus/v1/session-result", json=payload, headers=headers).json()

    assert second["idempotent_replay"] is True
    assert second["result_id"] == first["result_id"]
    assert second["economy"] == first["economy"]
    # Replay caused no second mastery write: rep count unchanged.
    assert second["mastery"] == first["mastery"]

    third = client.post(
        "/nexus/v1/session-result",
        json=_session_result("other-receipt"),
        headers={**headers, "Idempotency-Key": "rcpt-idem"},
    ).json()
    assert third["idempotent_replay"] is True  # header key wins over body receipt id


def test_session_result_idempotency_is_per_user(client: TestClient) -> None:
    payload = _session_result("shared-key")
    first = client.post("/nexus/v1/session-result", json=payload, headers=_auth("user-a")).json()
    other = client.post("/nexus/v1/session-result", json=payload, headers=_auth("user-b")).json()
    assert other["idempotent_replay"] is False
    assert other["result_id"] != first["result_id"]


def test_session_result_rejects_anticheat_violations(client: TestClient) -> None:
    response = client.post(
        "/nexus/v1/session-result",
        json=_session_result("rcpt-cheat", score=99_999),
        headers=_auth("athlete-cheat"),
    )
    assert response.status_code == 422
    assert "score_out_of_bounds" in str(response.json()["detail"])

    instant = client.post(
        "/nexus/v1/session-result",
        json=_session_result("rcpt-instant", duration_seconds=0, score=10),
        headers=_auth("athlete-cheat"),
    )
    assert instant.status_code == 422
    assert "instant_scoring_session" in str(instant.json()["detail"])


def test_session_result_requires_client_receipt_id(client: TestClient) -> None:
    payload = _session_result()
    del payload["client_receipt_id"]
    assert client.post("/nexus/v1/session-result", json=payload).status_code == 422


# ── /nexus/v1/advisor ────────────────────────────────────────────────────────
def test_advisor_onboarding_shape_without_history(client: TestClient) -> None:
    response = client.get("/nexus/v1/advisor", headers=_auth("athlete-new"))
    assert response.status_code == 200
    body = response.json()
    assert body["user_id"] == "athlete-new"
    assert body["source"] == "in_memory_default"
    assert body["focus_areas"]
    priorities = [area["priority"] for area in body["focus_areas"]]
    assert priorities == sorted(priorities, reverse=True)
    for area in body["focus_areas"]:
        assert 0.0 <= area["priority"] <= 1.0
        assert area["trend"] in ("declining", "flat", "improving")
        assert area["attribute"] and area["reason"]
        assert isinstance(area["recommended_lesson_ids"], list)


def test_advisor_surfaces_weak_skill_after_sessions(client: TestClient) -> None:
    headers = _auth("athlete-adv")
    client.post(
        "/nexus/v1/session-result",
        json=_session_result("rcpt-a1", score=95, skill_ids=["finishing"]),
        headers=headers,
    )
    client.post(
        "/nexus/v1/session-result",
        json=_session_result("rcpt-a2", score=5, outcome="loss", skill_ids=["balance"]),
        headers=headers,
    )
    body = client.get("/nexus/v1/advisor", headers=headers).json()
    top = body["focus_areas"][0]
    assert top["attribute"] == "balance"
    assert top["priority"] > 0.5
    assert set(top["recommended_lesson_ids"]) == {"lesson_karate_stance", "lesson_karate_recovery"}


# ── Provider seam: injected fakes replace every lane ─────────────────────────
class _FakeSequencing:
    name = "fake_sequencing"

    async def build_queue(self, user_id: str, limit: int) -> list[QueueItemOut]:
        return [
            QueueItemOut(
                position=0,
                lesson_id="fake_lesson",
                course_id="fake_course",
                title="Fake Lesson",
                kind="micro_lesson",
                reason="prq_weakness",
                target_attributes=["fake_attr"],
                drill_id=None,
                estimated_minutes=2,
            )
        ][:limit]


class _FakeCourses:
    name = "fake_courses"

    async def published_courses(self) -> list[CatalogItemOut]:
        return [CatalogItemOut(id="fake_course", kind="course", title="Fake Course")]


class _FakeCards:
    name = "fake_cards"

    async def active_cards(self, sport: str | None) -> list[CatalogItemOut]:
        return [CatalogItemOut(id="fake_card", kind="card", title="Fake Card")]


class _FakeAdvisor:
    name = "fake_advisor"

    async def focus_areas(self, user_id: str) -> AdvisorOut:
        return AdvisorOut(
            user_id=user_id,
            computed_at="2026-01-01T00:00:00+00:00",
            source=self.name,
            focus_areas=[
                FocusAreaOut(attribute="fake_attr", priority=1.0, trend="declining", reason="injected fake")
            ],
        )


def test_injected_lane_providers_serve_the_same_contract(client: TestClient) -> None:
    mastery = InMemoryMasteryProvider()
    set_providers(
        GatewayProviders(
            mastery=mastery,
            advisor=_FakeAdvisor(),
            sequencing=_FakeSequencing(),
            catalog_courses=_FakeCourses(),
            catalog_cards=_FakeCards(),
        )
    )

    meta = client.get("/nexus/v1/meta").json()
    assert meta["providers"]["sequencing"] == "fake_sequencing"
    assert meta["providers"]["advisor"] == "fake_advisor"

    queue = client.get("/nexus/v1/queue", headers=_auth("athlete-fake")).json()
    assert queue["engine"] == "fake_sequencing"
    assert queue["queue"][0]["lesson_id"] == "fake_lesson"

    catalog = client.get("/nexus/v1/catalog").json()
    assert {item["id"] for item in catalog["items"]} == {"fake_course", "fake_card"}

    advisor = client.get("/nexus/v1/advisor", headers=_auth("athlete-fake")).json()
    assert advisor["source"] == "fake_advisor"
    assert advisor["focus_areas"][0]["attribute"] == "fake_attr"

    # session-result still fans out through the injected mastery provider.
    body = client.post(
        "/nexus/v1/session-result",
        json=_session_result("rcpt-fake", skill_ids=["fake_attr"]),
        headers=_auth("athlete-fake"),
    ).json()
    assert body["mastery"]["updated"][0]["skill_id"] == "fake_attr"


def test_default_wiring_uses_marketplace_and_seeded_providers() -> None:
    """Delegation targets: cards come from marketplace_service, courses from the seed."""

    from app.gateway.registry import get_providers

    reset_providers()
    providers = get_providers()
    assert isinstance(providers.catalog_cards, MarketplaceCardCatalogProvider)
    assert isinstance(providers.catalog_courses, SeededCourseCatalogProvider)
    assert isinstance(providers.mastery, InMemoryMasteryProvider)
    assert isinstance(providers.advisor, InMemoryAdvisorProvider)
    assert isinstance(providers.sequencing, InMemorySequencingProvider)
