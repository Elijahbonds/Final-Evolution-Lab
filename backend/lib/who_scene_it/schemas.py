"""
Who Scene It — data schemas.

All content items carry license + source metadata so the IP constraint
is enforced at the data layer. No real movie clips or celebrity likenesses
should ever appear in SceneContent; use FEL-generated/original assets only.
"""
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Dict, List, Optional


class RoundType(str, Enum):
    image_reveal   = "image_reveal"    # progressive blur-lift reveal
    audio_clip     = "audio_clip"      # short SFX / original music clip
    text_clue      = "text_clue"       # written description, no image
    silhouette     = "silhouette"      # blacked-out shape reveal


@dataclass
class SceneContent:
    """A single piece of content used in a round. Must be FEL-original."""
    content_id:        str
    title:             str               # display name shown after reveal
    description:       str               # short flavour text
    image_path:        str               # relative path inside FEL asset bundle
    round_type:        RoundType
    difficulty:        int               # 1-5
    license:           str               # e.g. "FEL Studios Original — all rights reserved"
    source:            str               # e.g. "FEL Studios internal art team"
    content_provider_id: str            # opaque ID linking to content provider record
    tags:              List[str] = field(default_factory=list)
    did_you_know:      str = ""


@dataclass
class BuzzinResult:
    content_id:    str
    score_awarded: int       # 0 if wrong buzz; positive if correct
    buzz_time_ms:  int       # ms from round start to buzz
    answer_time_ms: int      # ms from buzz to answer submission
    is_correct:    bool
    penalty:       int       # 0 normally; WRONG_BUZZ_PENALTY if wrong buzz
    did_you_know:  str = ""


@dataclass
class BuzzinSession:
    session_id:    str
    user_id:       str
    round_type:    RoundType
    rounds_played: int = 0
    total_score:   int = 0
    results:       List[BuzzinResult] = field(default_factory=list)
    status:        str = "active"        # active | complete
    started_at:    float = field(default_factory=time.time)


@dataclass
class CreatorCard:
    """Collectible awarded for hitting the buzz-in score threshold."""
    card_id:     str
    name:        str
    description: str
    image_placeholder: str
    round_type:  RoundType
