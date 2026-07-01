"""Shared minors / public-surface privacy helpers (PRIVACY-09)."""
from __future__ import annotations

from datetime import date
from typing import Dict, Optional


def age_from_iso_dob(dob: Optional[str]) -> Optional[int]:
    """Age in years from ISO YYYY-MM-DD, or None if missing/invalid."""
    if not dob:
        return None
    try:
        parts = str(dob).strip().split("-")
        if len(parts) != 3:
            return None
        y, m, d = int(parts[0]), int(parts[1]), int(parts[2])
        bd = date(y, m, d)
        today = date.today()
        return today.year - bd.year - ((today.month, today.day) < (bd.month, bd.day))
    except Exception:
        return None


def athlete_visible_in_public_discovery(doc: Dict[str, object]) -> bool:
    """
    Public athlete discovery requires explicit ``discovery_opt_in``.
    Known minors (<18) are hidden unless ``parental_consent_acknowledged`` (guardian consent).
    """
    if not doc.get("discovery_opt_in"):
        return False
    age = age_from_iso_dob(doc.get("date_of_birth"))
    if age is not None and age < 18:
        return bool(doc.get("parental_consent_acknowledged"))
    return True


def include_prq_in_public_athlete_search(doc: Dict[str, object]) -> bool:
    """PRQ is never returned for minors in `/social/athletes`, even with metrics opt-in."""
    age = age_from_iso_dob(doc.get("date_of_birth"))
    if age is not None and age < 18:
        return False
    return bool(doc.get("profile_public_metrics_opt_in"))
