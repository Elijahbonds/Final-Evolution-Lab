"""Nexus authoring service: profiles, curricula, courses, review, publish.

State machine (policy.VERSION_TRANSITIONS)::

    draft -> in_review -> approved -> published -> archived
                \\-> rejected -> draft (on edit/resubmit)

Only ``submit`` runs the automated review gate; drafts may be saved in any
shape. Publishing archives the previously published version and projects the
course into ``nexus_catalog_entries`` (catalog visibility).
"""
from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.authoring import checks, policy
from app.authoring.models import (
    AuthorProfile,
    CatalogEntry,
    Course,
    CourseVersion,
    Curriculum,
    ReviewEvent,
)
from app.authoring.schemas import (
    AuthorProfileCreate,
    CheckReport,
    CourseContent,
    CourseCreate,
    CourseMetaUpdate,
    CurriculumCreate,
    ReviewDecision,
)
from app.models.user import User


def _now() -> datetime:
    return datetime.now(UTC)


class AuthoringService:
    """All authoring pipeline operations. One instance per process."""

    # ------------------------------------------------------------------
    # Author profiles
    # ------------------------------------------------------------------

    async def get_profile(self, db: AsyncSession, user_id: str) -> AuthorProfile:
        result = await db.execute(select(AuthorProfile).where(AuthorProfile.user_id == user_id))
        profile = result.scalar_one_or_none()
        if profile is None or not profile.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No active author profile; create one via POST /authoring/authors",
            )
        return profile

    async def create_profile(
        self, db: AsyncSession, user_id: str, payload: AuthorProfileCreate
    ) -> AuthorProfile:
        if payload.role not in policy.AUTHOR_ROLES:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"role must be one of {policy.AUTHOR_ROLES}",
            )
        existing = await db.execute(select(AuthorProfile).where(AuthorProfile.user_id == user_id))
        if existing.scalar_one_or_none() is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="Author profile already exists"
            )
        granters = policy.ELEVATED_ROLE_GRANTERS.get(payload.role)
        if granters is not None:
            user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
            user_role = user.role if user is not None else ""
            if user_role not in granters:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail=f"users.role '{user_role or 'unknown'}' may not claim author role '{payload.role}'",
                )
        profile = AuthorProfile(
            user_id=user_id,
            role=payload.role,
            display_name=payload.display_name,
            bio=payload.bio,
        )
        db.add(profile)
        await db.commit()
        await db.refresh(profile)
        return profile

    async def get_profile_by_id(self, db: AsyncSession, profile_id: str) -> AuthorProfile | None:
        result = await db.execute(select(AuthorProfile).where(AuthorProfile.id == profile_id))
        return result.scalar_one_or_none()

    async def require_reviewer(self, db: AsyncSession, user_id: str) -> AuthorProfile:
        profile = await self.get_profile(db, user_id)
        if profile.role not in policy.REVIEWER_ROLES:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Review requires one of roles {policy.REVIEWER_ROLES}",
            )
        return profile

    # ------------------------------------------------------------------
    # Curricula
    # ------------------------------------------------------------------

    async def create_curriculum(
        self, db: AsyncSession, author: AuthorProfile, payload: CurriculumCreate
    ) -> Curriculum:
        curriculum = Curriculum(
            author_id=author.id,
            title=payload.title,
            description=payload.description,
            sport=payload.sport,
            course_ids=payload.course_ids,
            target_prq_profile=payload.target_prq_profile,
        )
        db.add(curriculum)
        await db.commit()
        await db.refresh(curriculum)
        return curriculum

    async def list_curricula(self, db: AsyncSession, author: AuthorProfile) -> list[Curriculum]:
        result = await db.execute(
            select(Curriculum).where(
                Curriculum.author_id == author.id, Curriculum.is_active.is_(True)
            )
        )
        return list(result.scalars().all())

    # ------------------------------------------------------------------
    # Courses + versions
    # ------------------------------------------------------------------

    async def create_course(
        self, db: AsyncSession, author: AuthorProfile, payload: CourseCreate
    ) -> tuple[Course, CourseVersion]:
        slug_taken = await db.execute(select(Course.id).where(Course.slug == payload.slug))
        if slug_taken.scalar_one_or_none() is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail=f"Slug '{payload.slug}' already in use"
            )
        if payload.curriculum_id is not None:
            await self._get_owned_curriculum(db, author, payload.curriculum_id)
        course = Course(
            id=str(uuid4()),
            author_id=author.id,
            curriculum_id=payload.curriculum_id,
            title=payload.title,
            slug=payload.slug,
            description=payload.description,
            sport=payload.sport,
            license=payload.license,
            price_credits=payload.price_credits,
        )
        version = CourseVersion(
            id=str(uuid4()),
            course_id=course.id,
            version_number=1,
            state="draft",
            content=payload.content.model_dump(),
        )
        course.head_version_id = version.id
        db.add_all([course, version])
        await db.commit()
        await db.refresh(course)
        await db.refresh(version)
        return course, version

    async def list_courses(self, db: AsyncSession, author: AuthorProfile) -> list[Course]:
        result = await db.execute(
            select(Course).where(Course.author_id == author.id, Course.is_active.is_(True))
        )
        return list(result.scalars().all())

    async def get_course(self, db: AsyncSession, course_id: str) -> Course:
        course = (
            await db.execute(select(Course).where(Course.id == course_id))
        ).scalar_one_or_none()
        if course is None or not course.is_active:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")
        return course

    async def get_owned_course(
        self, db: AsyncSession, author: AuthorProfile, course_id: str
    ) -> Course:
        course = await self.get_course(db, course_id)
        if course.author_id != author.id and author.role not in policy.REVIEWER_ROLES:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Not the author of this course"
            )
        return course

    async def get_version(self, db: AsyncSession, version_id: str) -> CourseVersion:
        version = (
            await db.execute(select(CourseVersion).where(CourseVersion.id == version_id))
        ).scalar_one_or_none()
        if version is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Version not found")
        return version

    async def head_version(self, db: AsyncSession, course: Course) -> CourseVersion:
        if course.head_version_id is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT, detail="Course has no head version"
            )
        return await self.get_version(db, course.head_version_id)

    async def update_meta(
        self, db: AsyncSession, author: AuthorProfile, course_id: str, payload: CourseMetaUpdate
    ) -> Course:
        course = await self.get_owned_course(db, author, course_id)
        if payload.curriculum_id is not None:
            await self._get_owned_curriculum(db, author, payload.curriculum_id)
        for field, value in payload.model_dump(exclude_unset=True).items():
            setattr(course, field, value)
        await db.commit()
        await db.refresh(course)
        return course

    async def update_content(
        self, db: AsyncSession, author: AuthorProfile, course_id: str, content: CourseContent
    ) -> CourseVersion:
        course = await self.get_owned_course(db, author, course_id)
        version = await self.head_version(db, course)
        if version.state not in policy.EDITABLE_STATES:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Head version is '{version.state}'; only {policy.EDITABLE_STATES} accept edits",
            )
        if version.state == "rejected":
            # Editing a rejected version moves it back to draft (rejected -> draft).
            self._transition(version, "draft", actor_user_id=author.user_id, db=db, note="edited after rejection")
        version.content = content.model_dump()
        version.review_report = {}
        await db.commit()
        await db.refresh(version)
        return version

    async def new_draft_version(
        self, db: AsyncSession, author: AuthorProfile, course_id: str
    ) -> CourseVersion:
        """Start version N+1 as a draft copy of the head (post-publish edits)."""

        course = await self.get_owned_course(db, author, course_id)
        head = await self.head_version(db, course)
        if head.state not in ("published", "archived"):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Cannot fork a new draft while head version is '{head.state}'",
            )
        draft = CourseVersion(
            id=str(uuid4()),
            course_id=course.id,
            version_number=head.version_number + 1,
            state="draft",
            content=dict(head.content),
        )
        course.head_version_id = draft.id
        db.add(draft)
        await db.commit()
        await db.refresh(draft)
        return draft

    # ------------------------------------------------------------------
    # Review gate + queue
    # ------------------------------------------------------------------

    def run_checks(self, course: Course, version: CourseVersion) -> CheckReport:
        content = CourseContent.model_validate(version.content)
        return checks.run_review_checks(content, course.title, course.description)

    async def submit_for_review(
        self, db: AsyncSession, author: AuthorProfile, course_id: str
    ) -> tuple[CourseVersion, CheckReport]:
        course = await self.get_owned_course(db, author, course_id)
        version = await self.head_version(db, course)
        if version.state not in policy.EDITABLE_STATES:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Only draft/rejected versions can be submitted (state '{version.state}')",
            )
        if version.state == "rejected":
            self._transition(version, "draft", actor_user_id=author.user_id, db=db, note="resubmission")
        report = self.run_checks(course, version)
        version.review_report = report.model_dump()
        content = CourseContent.model_validate(version.content)
        version.prq_totals = checks.compute_prq_totals(content)
        if not report.passed:
            await db.commit()
            await db.refresh(version)
            return version, report
        self._transition(version, "in_review", actor_user_id=author.user_id, db=db, note="submitted")
        version.submitted_at = _now()
        await db.commit()
        await db.refresh(version)
        return version, report

    async def review_queue(self, db: AsyncSession) -> list[tuple[CourseVersion, Course]]:
        result = await db.execute(
            select(CourseVersion, Course)
            .join(Course, CourseVersion.course_id == Course.id)
            .where(CourseVersion.state == "in_review")
            .order_by(CourseVersion.submitted_at)
        )
        return [(version, course) for version, course in result.all()]

    async def decide_review(
        self, db: AsyncSession, reviewer: AuthorProfile, version_id: str, decision: ReviewDecision
    ) -> CourseVersion:
        version = await self.get_version(db, version_id)
        if version.state != "in_review":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Version is '{version.state}', not in_review",
            )
        course = await self.get_course(db, version.course_id)
        if course.author_id == reviewer.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Authors cannot review their own course"
            )
        target = "approved" if decision.decision == "approve" else "rejected"
        self._transition(version, target, actor_user_id=reviewer.user_id, db=db, note=decision.note)
        version.reviewer_user_id = reviewer.user_id
        version.reviewed_at = _now()
        if target == "rejected":
            version.rejection_reason = decision.note or "rejected"
        await db.commit()
        await db.refresh(version)
        return version

    # ------------------------------------------------------------------
    # Publish -> catalog
    # ------------------------------------------------------------------

    async def publish(
        self, db: AsyncSession, author: AuthorProfile, course_id: str
    ) -> tuple[Course, CourseVersion]:
        course = await self.get_owned_course(db, author, course_id)
        version = await self.head_version(db, course)
        if version.state != "approved":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Only approved versions publish (state '{version.state}')",
            )
        if course.published_version_id and course.published_version_id != version.id:
            previous = await self.get_version(db, course.published_version_id)
            if previous.state == "published":
                self._transition(
                    previous, "archived", actor_user_id=author.user_id, db=db, note="superseded"
                )
        self._transition(version, "published", actor_user_id=author.user_id, db=db, note="published")
        version.published_at = _now()
        course.published_version_id = version.id

        entry = (
            await db.execute(select(CatalogEntry).where(CatalogEntry.course_id == course.id))
        ).scalar_one_or_none()
        if entry is None:
            entry = CatalogEntry(course_id=course.id)
            db.add(entry)
        entry.version_id = version.id
        entry.title = course.title
        entry.sport = course.sport
        entry.summary = course.description
        entry.author_id = course.author_id
        entry.author_role = author.role
        entry.price_credits = course.price_credits
        entry.visibility = "public"
        entry.published_at = version.published_at
        await db.commit()
        await db.refresh(course)
        await db.refresh(version)
        return course, version

    async def catalog(self, db: AsyncSession, sport: str | None = None) -> list[CatalogEntry]:
        query = select(CatalogEntry).where(CatalogEntry.visibility == "public")
        if sport:
            query = query.where(CatalogEntry.sport == sport)
        result = await db.execute(query.order_by(CatalogEntry.published_at.desc()))
        return list(result.scalars().all())

    async def review_events(self, db: AsyncSession, version_id: str) -> list[ReviewEvent]:
        result = await db.execute(
            select(ReviewEvent)
            .where(ReviewEvent.version_id == version_id)
            .order_by(ReviewEvent.created_at)
        )
        return list(result.scalars().all())

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------

    def _transition(
        self,
        version: CourseVersion,
        target: str,
        *,
        actor_user_id: str,
        db: AsyncSession,
        note: str = "",
    ) -> None:
        allowed = policy.VERSION_TRANSITIONS.get(version.state, ())
        if target not in allowed:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"Illegal transition {version.state} -> {target}; allowed: {allowed}",
            )
        db.add(
            ReviewEvent(
                version_id=version.id,
                actor_user_id=actor_user_id,
                from_state=version.state,
                to_state=target,
                note=note,
            )
        )
        version.state = target

    async def _get_owned_curriculum(
        self, db: AsyncSession, author: AuthorProfile, curriculum_id: str
    ) -> Curriculum:
        curriculum = (
            await db.execute(select(Curriculum).where(Curriculum.id == curriculum_id))
        ).scalar_one_or_none()
        if curriculum is None or not curriculum.is_active:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Curriculum not found")
        if curriculum.author_id != author.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Not the author of this curriculum"
            )
        return curriculum


authoring_service = AuthoringService()
