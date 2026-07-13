"""End-to-end authoring pipeline tests over the mounted router.

Covers: author profile roles, course CRUD, draft editing, the automated
review gate, the review queue, the state machine, publish -> catalog, and
re-versioning.
"""
from __future__ import annotations

import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from conftest import bearer, make_content, make_lesson

API = "/api/authoring"

_slug_counter = 0


def _new_course(client, headers, **overrides) -> dict:
    global _slug_counter
    _slug_counter += 1
    payload = {
        "title": f"Vertical Foundations {_slug_counter}",
        "slug": f"vertical-foundations-{_slug_counter}",
        "description": "Two-lesson jump course.",
        "sport": "basketball",
        "price_credits": 150,
        "content": make_content(),
    }
    payload.update(overrides)
    response = client.post(f"{API}/courses", json=payload, headers=headers)
    assert response.status_code == 201, response.text
    return response.json()


def _ensure_profile(client, user_id: str, role: str = "creator") -> dict:
    headers = bearer(user_id)
    response = client.get(f"{API}/authors/me", headers=headers)
    if response.status_code == 200:
        return response.json()
    response = client.post(
        f"{API}/authors",
        json={"role": role, "display_name": f"{user_id} ({role})"},
        headers=headers,
    )
    assert response.status_code == 201, response.text
    return response.json()


class TestAuthAndProfiles:
    def test_requires_bearer_token(self, client) -> None:
        assert client.get(f"{API}/courses").status_code == 401
        assert client.post(f"{API}/authors", json={"display_name": "x"}).status_code == 401

    def test_catalog_is_public(self, client) -> None:
        response = client.get(f"{API}/catalog")
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    def test_athlete_can_become_creator(self, client) -> None:
        profile = _ensure_profile(client, "athlete-user", "creator")
        assert profile["role"] == "creator"
        assert profile["user_id"] == "athlete-user"

    def test_duplicate_profile_conflicts(self, client) -> None:
        _ensure_profile(client, "athlete-user", "creator")
        response = client.post(
            f"{API}/authors",
            json={"role": "creator", "display_name": "again"},
            headers=bearer("athlete-user"),
        )
        assert response.status_code == 409

    def test_athlete_cannot_claim_coach_or_first_party(self, client) -> None:
        for role in ("coach", "first_party"):
            response = client.post(
                f"{API}/authors",
                json={"role": role, "display_name": "sneaky"},
                headers=bearer("second-athlete"),
            )
            assert response.status_code == 403, role

    def test_coach_user_can_claim_coach_role(self, client) -> None:
        profile = _ensure_profile(client, "coach-user", "coach")
        assert profile["role"] == "coach"

    def test_admin_user_can_claim_first_party(self, client) -> None:
        profile = _ensure_profile(client, "reviewer-user", "first_party")
        assert profile["role"] == "first_party"

    def test_invalid_role_rejected(self, client) -> None:
        response = client.post(
            f"{API}/authors",
            json={"role": "warlord", "display_name": "nope"},
            headers=bearer("second-athlete"),
        )
        assert response.status_code == 422

    def test_no_profile_means_403_on_authoring(self, client) -> None:
        response = client.get(f"{API}/courses", headers=bearer("second-athlete"))
        assert response.status_code == 403


class TestCourseDraftLifecycle:
    def test_create_course_creates_draft_v1(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        course = _new_course(client, bearer("athlete-user"))
        head = course["head_version"]
        assert head["state"] == "draft"
        assert head["version_number"] == 1
        assert course["published_version_id"] is None

    def test_slug_collision_conflicts(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        headers = bearer("athlete-user")
        course = _new_course(client, headers)
        response = client.post(
            f"{API}/courses",
            json={"title": "Dup", "slug": course["slug"], "content": make_content()},
            headers=headers,
        )
        assert response.status_code == 409

    def test_edit_draft_content(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        headers = bearer("athlete-user")
        course = _new_course(client, headers)
        new_content = make_content()
        new_content["modules"][0]["lessons"].append(make_lesson("l3", prereq_ids=["l2"]))
        response = client.put(
            f"{API}/courses/{course['id']}/content", json=new_content, headers=headers
        )
        assert response.status_code == 200
        assert len(response.json()["content"]["modules"][0]["lessons"]) == 3

    def test_other_creator_cannot_touch_course(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        _ensure_profile(client, "coach-user", "coach")
        course = _new_course(client, bearer("athlete-user"))
        response = client.put(
            f"{API}/courses/{course['id']}/content",
            json=make_content(),
            headers=bearer("coach-user"),
        )
        assert response.status_code == 403

    def test_dry_run_checks_endpoint(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        headers = bearer("athlete-user")
        course = _new_course(client, headers)
        response = client.get(f"{API}/courses/{course['id']}/checks", headers=headers)
        assert response.status_code == 200
        assert response.json()["passed"] is True


class TestReviewGate:
    def test_failing_checks_keep_draft_and_report(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        headers = bearer("athlete-user")
        bad_content = make_content()
        bad_content["modules"][0]["lessons"][0]["clip_refs"] = ["https://evilcdn.example/clip.mp4"]
        bad_content["modules"][0]["lessons"][1]["title"] = "NBA finals rewatch"
        course = _new_course(client, headers, content=bad_content)

        response = client.post(f"{API}/courses/{course['id']}/submit", headers=headers)
        assert response.status_code == 200
        body = response.json()
        assert body["report"]["passed"] is False
        checks_hit = {finding["check"] for finding in body["report"]["findings"]}
        assert {"provenance", "ip_screen"} <= checks_hit
        assert body["version"]["state"] == "draft"

        # Fix the content and the same course submits cleanly.
        response = client.put(
            f"{API}/courses/{course['id']}/content", json=make_content(), headers=headers
        )
        assert response.status_code == 200
        response = client.post(f"{API}/courses/{course['id']}/submit", headers=headers)
        assert response.status_code == 200
        assert response.json()["version"]["state"] == "in_review"

    def test_prq_totals_computed_on_submit(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        headers = bearer("athlete-user")
        course = _new_course(client, headers)
        response = client.post(f"{API}/courses/{course['id']}/submit", headers=headers)
        assert response.json()["version"]["prq_totals"] == {"vertical_power": 4}

    def test_cannot_edit_while_in_review(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        headers = bearer("athlete-user")
        course = _new_course(client, headers)
        client.post(f"{API}/courses/{course['id']}/submit", headers=headers)
        response = client.put(
            f"{API}/courses/{course['id']}/content", json=make_content(), headers=headers
        )
        assert response.status_code == 409


class TestReviewQueueAndDecisions:
    def _submitted_course(self, client, author="athlete-user") -> dict:
        _ensure_profile(client, author)
        headers = bearer(author)
        course = _new_course(client, headers)
        response = client.post(f"{API}/courses/{course['id']}/submit", headers=headers)
        assert response.json()["version"]["state"] == "in_review"
        course["head_version"] = response.json()["version"]
        return course

    def test_queue_requires_first_party(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        response = client.get(f"{API}/review/queue", headers=bearer("athlete-user"))
        assert response.status_code == 403

    def test_queue_lists_submissions_and_approve_flow(self, client) -> None:
        _ensure_profile(client, "reviewer-user", "first_party")
        course = self._submitted_course(client)
        response = client.get(f"{API}/review/queue", headers=bearer("reviewer-user"))
        assert response.status_code == 200
        queue_ids = {item["version"]["id"] for item in response.json()}
        assert course["head_version"]["id"] in queue_ids

        response = client.post(
            f"{API}/review/{course['head_version']['id']}/decision",
            json={"decision": "approve", "note": "clean"},
            headers=bearer("reviewer-user"),
        )
        assert response.status_code == 200
        assert response.json()["state"] == "approved"
        assert response.json()["reviewer_user_id"] == "reviewer-user"

    def test_reject_edit_resubmit_cycle(self, client) -> None:
        _ensure_profile(client, "reviewer-user", "first_party")
        course = self._submitted_course(client)
        version_id = course["head_version"]["id"]

        response = client.post(
            f"{API}/review/{version_id}/decision",
            json={"decision": "reject", "note": "needs a warmup module"},
            headers=bearer("reviewer-user"),
        )
        assert response.json()["state"] == "rejected"
        assert response.json()["rejection_reason"] == "needs a warmup module"

        # Author edits (rejected -> draft) and resubmits.
        headers = bearer("athlete-user")
        response = client.put(
            f"{API}/courses/{course['id']}/content", json=make_content(), headers=headers
        )
        assert response.json()["state"] == "draft"
        response = client.post(f"{API}/courses/{course['id']}/submit", headers=headers)
        assert response.json()["version"]["state"] == "in_review"

    def test_decision_on_non_queued_version_conflicts(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        _ensure_profile(client, "reviewer-user", "first_party")
        course = _new_course(client, bearer("athlete-user"))  # still draft
        response = client.post(
            f"{API}/review/{course['head_version']['id']}/decision",
            json={"decision": "approve"},
            headers=bearer("reviewer-user"),
        )
        assert response.status_code == 409


class TestPublishAndCatalog:
    def _approved_course(self, client) -> dict:
        _ensure_profile(client, "athlete-user")
        _ensure_profile(client, "reviewer-user", "first_party")
        headers = bearer("athlete-user")
        course = _new_course(client, headers)
        submitted = client.post(f"{API}/courses/{course['id']}/submit", headers=headers).json()
        client.post(
            f"{API}/review/{submitted['version']['id']}/decision",
            json={"decision": "approve"},
            headers=bearer("reviewer-user"),
        )
        return course

    def test_publish_requires_approved_state(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        headers = bearer("athlete-user")
        course = _new_course(client, headers)  # draft
        response = client.post(f"{API}/courses/{course['id']}/publish", headers=headers)
        assert response.status_code == 409

    def test_publish_makes_course_publicly_visible(self, client) -> None:
        course = self._approved_course(client)
        headers = bearer("athlete-user")
        response = client.post(f"{API}/courses/{course['id']}/publish", headers=headers)
        assert response.status_code == 200
        body = response.json()
        assert body["head_version"]["state"] == "published"
        assert body["published_version_id"] == body["head_version"]["id"]

        catalog = client.get(f"{API}/catalog").json()  # no auth
        entry = next(item for item in catalog if item["course_id"] == course["id"])
        assert entry["visibility"] == "public"
        assert entry["price_credits"] == 150
        assert entry["version_id"] == body["head_version"]["id"]

    def test_reversion_publish_archives_previous(self, client) -> None:
        course = self._approved_course(client)
        author_headers = bearer("athlete-user")
        first = client.post(f"{API}/courses/{course['id']}/publish", headers=author_headers).json()
        first_version_id = first["head_version"]["id"]

        # Fork v2, tweak, submit, approve, publish.
        response = client.post(f"{API}/courses/{course['id']}/versions", headers=author_headers)
        assert response.status_code == 201
        assert response.json()["version_number"] == 2
        assert response.json()["state"] == "draft"

        submitted = client.post(f"{API}/courses/{course['id']}/submit", headers=author_headers).json()
        client.post(
            f"{API}/review/{submitted['version']['id']}/decision",
            json={"decision": "approve"},
            headers=bearer("reviewer-user"),
        )
        second = client.post(f"{API}/courses/{course['id']}/publish", headers=author_headers).json()
        assert second["head_version"]["version_number"] == 2
        assert second["head_version"]["state"] == "published"

        # Catalog now points to v2; the course appears exactly once.
        catalog = client.get(f"{API}/catalog").json()
        entries = [item for item in catalog if item["course_id"] == course["id"]]
        assert len(entries) == 1
        assert entries[0]["version_id"] == second["head_version"]["id"]
        assert entries[0]["version_id"] != first_version_id

    def test_cannot_fork_while_draft_in_flight(self, client) -> None:
        _ensure_profile(client, "athlete-user")
        headers = bearer("athlete-user")
        course = _new_course(client, headers)  # head is draft
        response = client.post(f"{API}/courses/{course['id']}/versions", headers=headers)
        assert response.status_code == 409


class TestCurricula:
    def test_curriculum_crud_and_course_linking(self, client) -> None:
        _ensure_profile(client, "coach-user", "coach")
        headers = bearer("coach-user")
        response = client.post(
            f"{API}/curricula",
            json={
                "title": "Complete Guard",
                "description": "Multi-course guard path",
                "target_prq_profile": {"reaction_time": 70.0},
            },
            headers=headers,
        )
        assert response.status_code == 201
        curriculum = response.json()

        course = _new_course(client, headers, curriculum_id=curriculum["id"])
        assert course["curriculum_id"] == curriculum["id"]

        listed = client.get(f"{API}/curricula", headers=headers).json()
        assert any(item["id"] == curriculum["id"] for item in listed)

    def test_cannot_link_someone_elses_curriculum(self, client) -> None:
        _ensure_profile(client, "coach-user", "coach")
        _ensure_profile(client, "athlete-user")
        response = client.post(
            f"{API}/curricula",
            json={"title": "Coach Path"},
            headers=bearer("coach-user"),
        )
        curriculum_id = response.json()["id"]
        response = client.post(
            f"{API}/courses",
            json={
                "title": "Steal",
                "slug": "steal-curriculum-link",
                "curriculum_id": curriculum_id,
                "content": make_content(),
            },
            headers=bearer("athlete-user"),
        )
        assert response.status_code == 403
