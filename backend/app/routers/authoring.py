"""Nexus authoring pipeline routes (Course Builder backend).

NOT mounted in ``app.main`` yet — the integrator calls :func:`register`::

    from app.routers import authoring
    authoring.register(app)          # uses settings.api_prefix

Everything except ``GET /authoring/catalog`` requires a Bearer token
(``app.auth.permissions.get_current_subject``).
"""
from __future__ import annotations

from fastapi import APIRouter, Body, Depends, FastAPI, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.permissions import CurrentSubject
from app.authoring.models import AuthorProfile
from app.authoring.schemas import (
    AuthorProfileCreate,
    AuthorProfileOut,
    CatalogEntryOut,
    CheckReport,
    CourseContent,
    CourseCreate,
    CourseDetailOut,
    CourseMetaUpdate,
    CourseOut,
    CurriculumCreate,
    CurriculumOut,
    ReviewDecision,
    ReviewQueueItem,
    SubmitOut,
    VersionOut,
)
from app.authoring.service import authoring_service
from app.dependencies import get_db

router = APIRouter(prefix="/authoring", tags=["authoring"])


async def current_author(
    subject: CurrentSubject, db: AsyncSession = Depends(get_db)
) -> AuthorProfile:
    """Resolve the caller's active author profile (403 when missing)."""

    return await authoring_service.get_profile(db, subject)


async def current_reviewer(
    subject: CurrentSubject, db: AsyncSession = Depends(get_db)
) -> AuthorProfile:
    """Resolve the caller as a reviewer-capable author (first_party)."""

    return await authoring_service.require_reviewer(db, subject)


# ----------------------------------------------------------------------
# Author profiles
# ----------------------------------------------------------------------


@router.post("/authors", response_model=AuthorProfileOut, status_code=201)
async def create_author_profile(
    payload: AuthorProfileCreate,
    subject: CurrentSubject,
    db: AsyncSession = Depends(get_db),
) -> AuthorProfileOut:
    """Create the caller's author profile. Elevated roles are gated by users.role."""

    profile = await authoring_service.create_profile(db, subject, payload)
    return AuthorProfileOut.model_validate(profile)


@router.get("/authors/me", response_model=AuthorProfileOut)
async def get_my_author_profile(
    author: AuthorProfile = Depends(current_author),
) -> AuthorProfileOut:
    return AuthorProfileOut.model_validate(author)


# ----------------------------------------------------------------------
# Curricula
# ----------------------------------------------------------------------


@router.post("/curricula", response_model=CurriculumOut, status_code=201)
async def create_curriculum(
    payload: CurriculumCreate,
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> CurriculumOut:
    curriculum = await authoring_service.create_curriculum(db, author, payload)
    return CurriculumOut.model_validate(curriculum)


@router.get("/curricula", response_model=list[CurriculumOut])
async def list_curricula(
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> list[CurriculumOut]:
    rows = await authoring_service.list_curricula(db, author)
    return [CurriculumOut.model_validate(row) for row in rows]


# ----------------------------------------------------------------------
# Courses + draft editing
# ----------------------------------------------------------------------


@router.post("/courses", response_model=CourseDetailOut, status_code=201)
async def create_course(
    payload: CourseCreate,
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> CourseDetailOut:
    course, version = await authoring_service.create_course(db, author, payload)
    out = CourseDetailOut.model_validate(course)
    out.head_version = VersionOut.model_validate(version)
    return out


@router.get("/courses", response_model=list[CourseOut])
async def list_my_courses(
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> list[CourseOut]:
    rows = await authoring_service.list_courses(db, author)
    return [CourseOut.model_validate(row) for row in rows]


@router.get("/courses/{course_id}", response_model=CourseDetailOut)
async def get_course(
    course_id: str,
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> CourseDetailOut:
    course = await authoring_service.get_owned_course(db, author, course_id)
    out = CourseDetailOut.model_validate(course)
    if course.head_version_id:
        version = await authoring_service.get_version(db, course.head_version_id)
        out.head_version = VersionOut.model_validate(version)
    return out


@router.patch("/courses/{course_id}", response_model=CourseOut)
async def update_course_meta(
    course_id: str,
    payload: CourseMetaUpdate,
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> CourseOut:
    course = await authoring_service.update_meta(db, author, course_id, payload)
    return CourseOut.model_validate(course)


@router.put("/courses/{course_id}/content", response_model=VersionOut)
async def update_course_content(
    course_id: str,
    content: CourseContent = Body(...),
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> VersionOut:
    """Replace the head draft's content (draft/rejected states only)."""

    version = await authoring_service.update_content(db, author, course_id, content)
    return VersionOut.model_validate(version)


@router.get("/courses/{course_id}/checks", response_model=CheckReport)
async def dry_run_checks(
    course_id: str,
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> CheckReport:
    """Run the automated review checks without changing state."""

    course = await authoring_service.get_owned_course(db, author, course_id)
    version = await authoring_service.head_version(db, course)
    return authoring_service.run_checks(course, version)


@router.post("/courses/{course_id}/submit", response_model=SubmitOut)
async def submit_course(
    course_id: str,
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> SubmitOut:
    """Run automated checks; on pass, move head draft -> in_review."""

    version, report = await authoring_service.submit_for_review(db, author, course_id)
    return SubmitOut(version=VersionOut.model_validate(version), report=report)


@router.post("/courses/{course_id}/versions", response_model=VersionOut, status_code=201)
async def fork_new_draft(
    course_id: str,
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> VersionOut:
    """Fork a new draft version from a published/archived head."""

    version = await authoring_service.new_draft_version(db, author, course_id)
    return VersionOut.model_validate(version)


@router.post("/courses/{course_id}/publish", response_model=CourseDetailOut)
async def publish_course(
    course_id: str,
    author: AuthorProfile = Depends(current_author),
    db: AsyncSession = Depends(get_db),
) -> CourseDetailOut:
    """Publish the approved head version and project it into the catalog."""

    course, version = await authoring_service.publish(db, author, course_id)
    out = CourseDetailOut.model_validate(course)
    out.head_version = VersionOut.model_validate(version)
    return out


# ----------------------------------------------------------------------
# Review queue (first_party reviewers)
# ----------------------------------------------------------------------


@router.get("/review/queue", response_model=list[ReviewQueueItem])
async def review_queue(
    reviewer: AuthorProfile = Depends(current_reviewer),
    db: AsyncSession = Depends(get_db),
) -> list[ReviewQueueItem]:
    items: list[ReviewQueueItem] = []
    for version, course in await authoring_service.review_queue(db):
        author = await authoring_service.get_profile_by_id(db, course.author_id)
        items.append(
            ReviewQueueItem(
                version=VersionOut.model_validate(version),
                course_title=course.title,
                course_slug=course.slug,
                author_id=course.author_id,
                author_role=author.role if author is not None else "creator",
            )
        )
    return items


@router.post("/review/{version_id}/decision", response_model=VersionOut)
async def decide_review(
    version_id: str,
    decision: ReviewDecision,
    reviewer: AuthorProfile = Depends(current_reviewer),
    db: AsyncSession = Depends(get_db),
) -> VersionOut:
    """Approve or reject an in_review version (not your own course)."""

    version = await authoring_service.decide_review(db, reviewer, version_id, decision)
    return VersionOut.model_validate(version)


# ----------------------------------------------------------------------
# Catalog (public)
# ----------------------------------------------------------------------


@router.get("/catalog", response_model=list[CatalogEntryOut])
async def public_catalog(
    sport: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
) -> list[CatalogEntryOut]:
    """Published courses visible to every athlete (no auth required)."""

    rows = await authoring_service.catalog(db, sport=sport)
    return [CatalogEntryOut.model_validate(row) for row in rows]


def register(app: FastAPI, api_prefix: str | None = None) -> None:
    """Mount this router on ``app`` (integration hook; main.py stays untouched)."""

    if api_prefix is None:
        from app.config import get_settings

        api_prefix = get_settings().api_prefix
    app.include_router(router, prefix=api_prefix)
