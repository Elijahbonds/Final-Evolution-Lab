"""
av_cues.py — server-side audio/VFX/haptic cue hints for match events.

Maps logical gameplay event types to LOGICAL cue names. The client resolves
logical names to concrete asset paths via infra/audio_event_map.json
(nexus/audio-vfx-assets, PR #120), which follows the maintainer-fetched
freesound/opengameart downloader pattern in infra/asset_sources.json.
This module deliberately carries no file paths and no binaries — clients
that don't recognise a cue simply ignore the field (fallback policy:
missing assets are skipped silently).

Contract:
  event["av_cues"] = {
      "audio":  <logical audio cue name | None>,
      "vfx":    <logical vfx sprite id | None>,
      "haptic": <"light" | "medium" | "heavy" | None>,
  }

The field is additive and optional. Consumers (Swift scene host / Nexus
runtime) may drive SCNAudioPlayer, particle systems, and UIImpactFeedback
from it; anything else ignores it.
"""
from typing import Any, Dict, Optional

# Logical event type -> cue hint. Names mirror infra/audio_event_map.json
# (buzzer, score_sting, rim_clank, ...) so the client-side map stays the
# single source of truth for actual asset files.
AV_CUE_TABLE: Dict[str, Dict[str, Optional[str]]] = {
    "match_start": {"audio": "buzzer",      "vfx": None,             "haptic": None},
    "score_event": {"audio": "score_sting", "vfx": "particle_soft",  "haptic": "light"},
    "dunk_result": {"audio": "rim_clank",   "vfx": "particle_burst", "haptic": "heavy"},
    "match_end":   {"audio": "buzzer",      "vfx": "particle_soft",  "haptic": "medium"},
}

VALID_HAPTIC_LEVELS = {"light", "medium", "heavy"}


def av_cues_for(event_type: str) -> Optional[Dict[str, Optional[str]]]:
    """Return a copy of the cue hint for an event type, or None if unmapped."""
    cues = AV_CUE_TABLE.get(event_type)
    return dict(cues) if cues is not None else None


def attach_av_cues(event: Dict[str, Any]) -> Dict[str, Any]:
    """Attach an av_cues field to an event dict (mutates and returns it).

    No-op for event types without a cue mapping and for events that already
    carry an av_cues field (explicit cues win over table defaults).
    """
    if "av_cues" in event:
        return event
    cues = av_cues_for(str(event.get("type", "")))
    if cues is not None:
        event["av_cues"] = cues
    return event
