"""
creator_cards.py — SHARED Creator Card schema (CardModule seam).

This module is the canonical, importable card model for every mode that
surfaces Creator Cards (Who Scene It, Brain Brawl, Court Carnival, ...).
Do NOT fork per-view card shapes — import from here.

Card payload (CARD_SCHEMA_VERSION):
  card_id, creator_id, name, creator_type, persona, tagline, rarity,
  bio, timeline[], top_works[], facts[], lesson_stub{},
  sections: {
    music: [TrackRef],   — soundtrack/discography refs (metadata ONLY; audio
                           is resolved at play time via lib.music_providers)
    dance: [DanceClipRef]— choreo/lesson clip refs with difficulty + style tags
    links: [ExternalLink]— masterclass / profile links with provider + license
  },
  source, license        — provenance (QA gate; every nested item carries its own too)

Creator types are an extensible registry, not a hard enum: modes may register
new types (e.g. "COACH") without touching this file's callers.
"""
from typing import Any, Dict, List, Optional, Set

CARD_SCHEMA_VERSION = "1.1"

# Extensible creator-type registry (coordinator-approved base set).
CREATOR_TYPES: Set[str] = {
    "DJ", "ARTIST", "DANCER", "PRODUCER", "DIRECTOR", "ACTOR", "EDUCATOR",
}

DANCE_DIFFICULTIES = {"beginner", "intermediate", "advanced"}

_RARITY_BY_TYPE = {
    "DIRECTOR": "legendary",
    "ACTOR": "epic",
    "DJ": "epic",
    "PRODUCER": "rare",
    "ARTIST": "rare",
    "DANCER": "rare",
    "EDUCATOR": "rare",
}


class CardSchemaError(ValueError):
    """Raised when card content violates the shared schema (incl. provenance)."""


def register_creator_type(creator_type: str) -> None:
    """Extensibility seam: new modes may add creator types at import time."""
    CREATOR_TYPES.add(creator_type.upper())


def _require(item: Dict[str, Any], fields: List[str], kind: str) -> None:
    for f in fields:
        if not item.get(f):
            raise CardSchemaError(f"{kind} {item!r} missing required field {f!r}")


def validate_creator_type(creator_type: str) -> str:
    if creator_type not in CREATOR_TYPES:
        raise CardSchemaError(
            f"Unknown creator_type {creator_type!r}; registered: {sorted(CREATOR_TYPES)}")
    return creator_type


def validate_track_ref(track: Dict[str, Any]) -> Dict[str, Any]:
    """MUSIC section item. Metadata only — never embeds or caches audio bytes."""
    _require(track, ["track_id", "title", "provider", "provider_ref", "source", "license"],
             "TrackRef")
    if not isinstance(track.get("duration_s", 0), (int, float)):
        raise CardSchemaError(f"TrackRef {track['track_id']}: duration_s must be numeric")
    return track


def validate_dance_clip(clip: Dict[str, Any]) -> Dict[str, Any]:
    """DANCE section item: choreo/lesson clip ref with difficulty + style tags."""
    _require(clip, ["clip_id", "title", "difficulty", "source", "license"], "DanceClipRef")
    if clip["difficulty"] not in DANCE_DIFFICULTIES:
        raise CardSchemaError(
            f"DanceClipRef {clip['clip_id']}: difficulty must be one of {sorted(DANCE_DIFFICULTIES)}")
    if not isinstance(clip.get("style_tags"), list) or not clip["style_tags"]:
        raise CardSchemaError(f"DanceClipRef {clip['clip_id']}: style_tags must be a non-empty list")
    return clip


def validate_link(link: Dict[str, Any]) -> Dict[str, Any]:
    """LINKS section item: masterclass / external profile link."""
    _require(link, ["title", "url", "provider", "source", "license"], "ExternalLink")
    return link


_SECTION_VALIDATORS = {
    "music": validate_track_ref,
    "dance": validate_dance_clip,
    "links": validate_link,
}


def validate_sections(sections: Dict[str, List[Dict[str, Any]]]) -> Dict[str, List[Dict[str, Any]]]:
    for name, items in sections.items():
        validator = _SECTION_VALIDATORS.get(name)
        if validator is None:
            raise CardSchemaError(f"Unknown card section {name!r}; known: {sorted(_SECTION_VALIDATORS)}")
        for item in items:
            validator(item)
    return sections


def build_card(creator: Dict[str, Any], film_lookup) -> Dict[str, Any]:
    """Build the shared Creator Card payload from a content-provider creator dict.

    `film_lookup(film_id) -> film dict | None` decouples this module from any
    specific SceneContentModule implementation.
    """
    creator_type = validate_creator_type(creator.get("creator_type", ""))
    top_works = []
    for fid in creator.get("top_work_ids", []):
        film = film_lookup(fid)
        if film:
            top_works.append({"film_id": fid, "title": film["title"], "year": film["year"]})
    sections = validate_sections(creator.get("sections", {}))
    return {
        "schema_version": CARD_SCHEMA_VERSION,
        "card_id": f"card_{creator['creator_id']}",
        "creator_id": creator["creator_id"],
        "name": creator["name"],
        "creator_type": creator_type,
        "persona": creator.get("persona", creator_type.lower()),
        "tagline": creator.get("tagline", ""),
        "rarity": _RARITY_BY_TYPE.get(creator_type, "common"),
        "bio": creator.get("bio", ""),
        "timeline": creator.get("timeline", []),
        "top_works": top_works,
        "facts": creator.get("facts", []),
        "lesson_stub": creator.get("lesson_stub", {}),
        "sections": sections,
        "portrait_ref": creator.get("portrait_ref", ""),
        "source": creator.get("source", ""),
        "license": creator.get("license", ""),
    }
