"""Unit tests for the automated review checks (pure functions)."""
from __future__ import annotations

import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

from app.authoring import checks, policy
from app.authoring.schemas import CourseContent

from conftest import make_content, make_lesson


def _content(**overrides) -> CourseContent:
    return CourseContent.model_validate(make_content(**overrides))


def _findings_for(report, check_name):
    return [finding for finding in report.findings if finding.check == check_name]


class TestSchemaCheck:
    def test_valid_content_passes_all_checks(self) -> None:
        report = checks.run_review_checks(_content())
        assert report.passed
        assert report.findings == []
        assert set(report.checks_run) == set(checks.CHECK_NAMES)

    def test_empty_course_fails(self) -> None:
        report = checks.run_review_checks(CourseContent(modules=[]))
        assert not report.passed
        assert any("no modules" in finding.message for finding in report.findings)

    def test_duplicate_lesson_ids_flagged(self) -> None:
        content = _content()
        content.modules[0].lessons[1].id = "l1"
        findings = checks.check_schema(content)
        assert any("Duplicate lesson id" in finding.message for finding in findings)

    def test_unknown_prereq_flagged(self) -> None:
        content = _content()
        content.modules[0].lessons[0].prereq_ids = ["ghost-lesson"]
        findings = checks.check_schema(content)
        assert any("unknown prerequisite" in finding.message for finding in findings)

    def test_prereq_cycle_flagged(self) -> None:
        content = _content()
        content.modules[0].lessons[0].prereq_ids = ["l2"]  # l2 already requires l1
        findings = checks.check_schema(content)
        assert any("cycle" in finding.message.lower() for finding in findings)

    def test_self_prereq_flagged(self) -> None:
        content = _content()
        content.modules[0].lessons[0].prereq_ids = ["l1"]
        findings = checks.check_schema(content)
        assert any("itself" in finding.message for finding in findings)


class TestProvenanceCheck:
    def test_whitelisted_sources_pass(self) -> None:
        content = _content()
        content.modules[0].lessons[0].clip_refs = [
            "deepmotion://mocap/jump-01",
            "upload://verified/coach-footage-9",
            "https://assets.finalevolutionlab.com/clips/x.mp4",
        ]
        assert checks.check_provenance(content) == []

    def test_unwhitelisted_source_flagged(self) -> None:
        content = _content()
        content.modules[0].lessons[0].clip_refs = ["https://randomcdn.example.com/clip.mp4"]
        findings = checks.check_provenance(content)
        assert len(findings) == 1
        assert "not from a whitelisted source" in findings[0].message


class TestPrqCaps:
    def test_lesson_cap_enforced(self) -> None:
        content = _content()
        content.modules[0].lessons[0].prq_delta = {
            "vertical_power": policy.PRQ_DELTA_LESSON_CAP + 1
        }
        findings = checks.check_prq_caps(content)
        assert any("exceeds lesson cap" in finding.message for finding in findings)

    def test_module_cap_enforced(self) -> None:
        lessons = [
            make_lesson(f"l{i}", prq_delta={"balance": policy.PRQ_DELTA_LESSON_CAP})
            for i in range(4)  # 4 * 5 = 20 > module cap 12
        ]
        content = CourseContent.model_validate(
            {"modules": [{"id": "m1", "title": "M", "lessons": lessons}]}
        )
        findings = checks.check_prq_caps(content)
        assert any("exceeds module cap" in finding.message for finding in findings)

    def test_course_cap_enforced(self) -> None:
        modules = [
            {
                "id": f"m{m}",
                "title": f"M{m}",
                "lessons": [
                    make_lesson(f"m{m}l{i}", prq_delta={"stamina": 4}) for i in range(3)
                ],
            }
            for m in range(4)  # 4 modules * 12 = 48 > course cap 40
        ]
        content = CourseContent.model_validate({"modules": modules})
        findings = checks.check_prq_caps(content)
        assert any("exceeds course cap" in finding.message for finding in findings)

    def test_unknown_attribute_and_negative_flagged(self) -> None:
        content = _content()
        content.modules[0].lessons[0].prq_delta = {"charisma": 3, "balance": -1}
        messages = [finding.message for finding in checks.check_prq_caps(content)]
        assert any("Unknown prqDelta attribute" in message for message in messages)
        assert any("Negative prqDelta" in message for message in messages)

    def test_compute_prq_totals(self) -> None:
        totals = checks.compute_prq_totals(_content())
        assert totals == {"vertical_power": 4}


class TestIpScreen:
    def test_blacklisted_keyword_in_title_flagged(self) -> None:
        content = _content()
        content.modules[0].lessons[0].title = "Train like an NBA star"
        findings = checks.check_ip_screen(content)
        assert any(finding.check == "ip_screen" for finding in findings)

    def test_keyword_must_match_word_boundary(self) -> None:
        # 'nba' inside another word must NOT trip the screen.
        content = _content()
        content.modules[0].lessons[0].title = "Urbanball crossover"
        assert checks.check_ip_screen(content) == []

    def test_extra_texts_screened(self) -> None:
        report = checks.run_review_checks(_content(), "Official FIFA drills")
        assert not report.passed
        assert any(finding.check == "ip_screen" for finding in report.findings)

    def test_keyword_in_drill_option_flagged(self) -> None:
        content = _content()
        content.modules[0].lessons[1].drill_options = ["space jam dunk contest"]
        findings = checks.check_ip_screen(content)
        assert len(findings) == 1
