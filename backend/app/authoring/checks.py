"""Automated review checks for course submissions.

Every check is pure: content document in, findings out. ``run_review_checks``
aggregates them into a ``CheckReport`` that is stored on the version and
gates the draft -> in_review transition.

Checks implemented (spec: "Submits to review -> automated checks"):
- ``schema``       structure limits, unique ids, resolvable + acyclic prereqs
- ``provenance``   every clip/asset ref matches the provenance whitelist
- ``prq_caps``     lesson/module/course prqDelta caps (anti-farming)
- ``ip_screen``    keyword screen for unlicensed IP (Who Scene It rule)
"""
from __future__ import annotations

from typing import Any

from app.authoring import policy
from app.authoring.schemas import CheckFinding, CheckReport, CourseContent

CHECK_NAMES: tuple[str, ...] = ("schema", "provenance", "prq_caps", "ip_screen")


def _lessons(content: CourseContent) -> list[tuple[str, Any]]:
    """Yield (module_id, lesson) pairs."""

    return [(module.id, lesson) for module in content.modules for lesson in module.lessons]


def check_schema(content: CourseContent) -> list[CheckFinding]:
    """Structure, id uniqueness, and prerequisite graph sanity."""

    findings: list[CheckFinding] = []
    if not content.modules:
        findings.append(CheckFinding(check="schema", message="Course has no modules", where="modules"))
    module_ids: set[str] = set()
    for module in content.modules:
        if module.id in module_ids:
            findings.append(
                CheckFinding(check="schema", message=f"Duplicate module id '{module.id}'", where=module.id)
            )
        module_ids.add(module.id)
        if not module.lessons:
            findings.append(
                CheckFinding(check="schema", message=f"Module '{module.id}' has no lessons", where=module.id)
            )

    lesson_ids: set[str] = set()
    for module_id, lesson in _lessons(content):
        if lesson.id in lesson_ids:
            findings.append(
                CheckFinding(
                    check="schema",
                    message=f"Duplicate lesson id '{lesson.id}'",
                    where=f"{module_id}/{lesson.id}",
                )
            )
        lesson_ids.add(lesson.id)

    # Prereqs must reference lessons inside this course version.
    prereq_graph: dict[str, list[str]] = {}
    for module_id, lesson in _lessons(content):
        prereq_graph[lesson.id] = list(lesson.prereq_ids)
        for prereq in lesson.prereq_ids:
            if prereq not in lesson_ids:
                findings.append(
                    CheckFinding(
                        check="schema",
                        message=f"Lesson '{lesson.id}' declares unknown prerequisite '{prereq}'",
                        where=f"{module_id}/{lesson.id}",
                    )
                )
            if prereq == lesson.id:
                findings.append(
                    CheckFinding(
                        check="schema",
                        message=f"Lesson '{lesson.id}' lists itself as a prerequisite",
                        where=f"{module_id}/{lesson.id}",
                    )
                )

    # Cycle detection (iterative DFS; the graph is small by policy caps).
    WHITE, GRAY, BLACK = 0, 1, 2
    color: dict[str, int] = {node: WHITE for node in prereq_graph}
    for root in prereq_graph:
        if color[root] != WHITE:
            continue
        stack: list[tuple[str, int]] = [(root, 0)]
        color[root] = GRAY
        while stack:
            node, edge_index = stack[-1]
            edges = [p for p in prereq_graph.get(node, []) if p in prereq_graph]
            if edge_index < len(edges):
                stack[-1] = (node, edge_index + 1)
                child = edges[edge_index]
                if color[child] == GRAY:
                    findings.append(
                        CheckFinding(
                            check="schema",
                            message=f"Prerequisite cycle detected through lesson '{child}'",
                            where=child,
                        )
                    )
                elif color[child] == WHITE:
                    color[child] = GRAY
                    stack.append((child, 0))
            else:
                color[node] = BLACK
                stack.pop()
    return findings


def check_provenance(content: CourseContent) -> list[CheckFinding]:
    """Every clip ref must come from a whitelisted asset source."""

    findings: list[CheckFinding] = []
    for module_id, lesson in _lessons(content):
        for ref in lesson.clip_refs:
            if not ref.startswith(policy.ASSET_PROVENANCE_WHITELIST):
                findings.append(
                    CheckFinding(
                        check="provenance",
                        message=f"Asset ref '{ref}' is not from a whitelisted source",
                        where=f"{module_id}/{lesson.id}",
                    )
                )
    return findings


def check_prq_caps(content: CourseContent) -> list[CheckFinding]:
    """Enforce lesson/module/course prqDelta caps and known attributes."""

    findings: list[CheckFinding] = []
    course_totals: dict[str, int] = {}
    for module in content.modules:
        module_totals: dict[str, int] = {}
        for lesson in module.lessons:
            for attribute, points in lesson.prq_delta.items():
                where = f"{module.id}/{lesson.id}"
                if attribute not in policy.PRQ_ATTRIBUTES:
                    findings.append(
                        CheckFinding(
                            check="prq_caps",
                            message=f"Unknown prqDelta attribute '{attribute}'",
                            where=where,
                        )
                    )
                    continue
                if points < 0:
                    findings.append(
                        CheckFinding(
                            check="prq_caps",
                            message=f"Negative prqDelta for '{attribute}' is not allowed",
                            where=where,
                        )
                    )
                    continue
                if points > policy.PRQ_DELTA_LESSON_CAP:
                    findings.append(
                        CheckFinding(
                            check="prq_caps",
                            message=(
                                f"prqDelta {points} for '{attribute}' exceeds lesson cap "
                                f"{policy.PRQ_DELTA_LESSON_CAP}"
                            ),
                            where=where,
                        )
                    )
                module_totals[attribute] = module_totals.get(attribute, 0) + points
                course_totals[attribute] = course_totals.get(attribute, 0) + points
        for attribute, total in module_totals.items():
            if total > policy.PRQ_DELTA_MODULE_CAP:
                findings.append(
                    CheckFinding(
                        check="prq_caps",
                        message=(
                            f"Module prqDelta total {total} for '{attribute}' exceeds module cap "
                            f"{policy.PRQ_DELTA_MODULE_CAP}"
                        ),
                        where=module.id,
                    )
                )
    for attribute, total in course_totals.items():
        if total > policy.PRQ_DELTA_COURSE_CAP:
            findings.append(
                CheckFinding(
                    check="prq_caps",
                    message=(
                        f"Course prqDelta total {total} for '{attribute}' exceeds course cap "
                        f"{policy.PRQ_DELTA_COURSE_CAP}"
                    ),
                    where="course",
                )
            )
    return findings


def _screen_text(text: str) -> str | None:
    """Return the first blacklisted keyword found in ``text`` (word-ish match)."""

    lowered = text.lower()
    for keyword in policy.IP_KEYWORD_BLACKLIST:
        index = lowered.find(keyword)
        while index != -1:
            before_ok = index == 0 or not lowered[index - 1].isalnum()
            end = index + len(keyword)
            after_ok = end >= len(lowered) or not lowered[end].isalnum()
            if before_ok and after_ok:
                return keyword
            index = lowered.find(keyword, index + 1)
    return None


def check_ip_screen(content: CourseContent, *extra_texts: str) -> list[CheckFinding]:
    """Screen authored text and refs for unlicensed-IP keywords."""

    findings: list[CheckFinding] = []

    def _scan(text: str, where: str) -> None:
        keyword = _screen_text(text)
        if keyword is not None:
            findings.append(
                CheckFinding(
                    check="ip_screen",
                    message=f"Blocked IP keyword '{keyword}' found",
                    where=where,
                )
            )

    for position, text in enumerate(extra_texts):
        _scan(text, where=f"course_meta[{position}]")
    for module in content.modules:
        _scan(module.title, where=module.id)
        for lesson in module.lessons:
            where = f"{module.id}/{lesson.id}"
            _scan(lesson.title, where=where)
            _scan(lesson.concept_text, where=where)
            for ref in lesson.clip_refs:
                _scan(ref, where=where)
            for drill in lesson.drill_options:
                _scan(drill, where=where)
    return findings


def compute_prq_totals(content: CourseContent) -> dict[str, int]:
    """Summed prqDelta per attribute across the whole course version."""

    totals: dict[str, int] = {}
    for _, lesson in _lessons(content):
        for attribute, points in lesson.prq_delta.items():
            totals[attribute] = totals.get(attribute, 0) + points
    return totals


def run_review_checks(content: CourseContent, *extra_texts: str) -> CheckReport:
    """Run every automated check and aggregate a report."""

    findings: list[CheckFinding] = []
    findings.extend(check_schema(content))
    findings.extend(check_provenance(content))
    findings.extend(check_prq_caps(content))
    findings.extend(check_ip_screen(content, *extra_texts))
    return CheckReport(passed=not findings, checks_run=list(CHECK_NAMES), findings=findings)
