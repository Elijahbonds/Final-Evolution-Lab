"""Authoring policy constants: state machine, caps, provenance, IP screen.

Everything here is config, not code paths — tune without touching the
service or the checks. Real-money fields are metadata only; no provider
integration lives in this lane.
"""
from __future__ import annotations

# ---------------------------------------------------------------------------
# Roles
# ---------------------------------------------------------------------------

AUTHOR_ROLES: tuple[str, ...] = ("first_party", "coach", "creator")

#: Roles that may act as reviewers on the review queue.
REVIEWER_ROLES: tuple[str, ...] = ("first_party",)

#: users.role values allowed to self-provision an elevated author role.
ELEVATED_ROLE_GRANTERS: dict[str, tuple[str, ...]] = {
    "first_party": ("admin",),
    "coach": ("admin", "coach"),
}

# ---------------------------------------------------------------------------
# Version state machine
# ---------------------------------------------------------------------------

VERSION_STATES: tuple[str, ...] = (
    "draft",
    "in_review",
    "approved",
    "published",
    "rejected",
    "archived",
)

#: Legal transitions, keyed by current state.
VERSION_TRANSITIONS: dict[str, tuple[str, ...]] = {
    "draft": ("in_review",),
    "in_review": ("approved", "rejected"),
    "approved": ("published",),
    "rejected": ("draft",),
    "published": ("archived",),
    "archived": (),
}

#: Head-version states that accept content edits in place.
EDITABLE_STATES: tuple[str, ...] = ("draft", "rejected")

# ---------------------------------------------------------------------------
# PRQ delta caps (anti-farming: spec Part 1, PRQ coupling)
# ---------------------------------------------------------------------------

#: Attributes a lesson prqDelta may target (mirrors PRQProfile columns).
PRQ_ATTRIBUTES: tuple[str, ...] = (
    "vertical_power",
    "reaction_time",
    "mobility",
    "balance",
    "stamina",
)

#: Max points a single lesson may grant to one attribute.
PRQ_DELTA_LESSON_CAP: int = 5

#: Max summed points a module may grant to one attribute.
PRQ_DELTA_MODULE_CAP: int = 12

#: Max summed points a course version may grant to one attribute.
PRQ_DELTA_COURSE_CAP: int = 40

# ---------------------------------------------------------------------------
# Asset provenance whitelist (review gate for clips/assets)
# ---------------------------------------------------------------------------

#: A clip_ref / asset ref must start with one of these schemes/prefixes.
ASSET_PROVENANCE_WHITELIST: tuple[str, ...] = (
    "meshy://",
    "deepmotion://",
    "fel-assets://",
    "upload://verified/",
    "https://assets.finalevolutionlab.com/",
)

# ---------------------------------------------------------------------------
# IP keyword screen (Who Scene It constraint: no unlicensed IP clears review)
# ---------------------------------------------------------------------------

#: Case-insensitive keywords screened out of authored text and refs.
IP_KEYWORD_BLACKLIST: tuple[str, ...] = (
    "nba",
    "nfl",
    "mlb",
    "nhl",
    "fifa",
    "ufc",
    "olympics",
    "disney",
    "pixar",
    "marvel",
    "star wars",
    "netflix",
    "hbo",
    "espn",
    "nike",
    "adidas",
    "jordan brand",
    "space jam",
)

#: Course content limits (schema check).
MAX_MODULES_PER_COURSE: int = 24
MAX_LESSONS_PER_MODULE: int = 24
