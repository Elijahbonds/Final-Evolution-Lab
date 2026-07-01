"""
Server-owned StoreKit product ID → internal commerce SKU mapping.

These strings must match identifiers registered in App Store Connect (replace placeholders per bundle).

Overlay / merge deployment-specific IDs via env ``FEL_STOREKIT_CATALOG_JSON``:
``{\"com.my.bundle.card\":{\"item_type\":\"card\",\"item_id\":\"card_elijah\"}}``
"""
from __future__ import annotations

import base64
import json
import os
from typing import Any, Dict, Optional

from commerce_catalog import COMMERCE_CATALOG

# Placeholder bundle prefix — align with your ASC product IDs before shipping.
_PREFIX = "com.finalevolutionlab.iap"

DEFAULT_STOREKIT_MAP: Dict[str, Dict[str, str]] = {
    f"{_PREFIX}.card_elijah": {"item_type": "card", "item_id": "card_elijah"},
    f"{_PREFIX}.card_amir": {"item_type": "card", "item_id": "card_amir"},
    f"{_PREFIX}.card_eric": {"item_type": "card", "item_id": "card_eric"},
    f"{_PREFIX}.course_kinesiology_cert": {"item_type": "course", "item_id": "kinesiology_cert"},
    f"{_PREFIX}.course_stem_sports": {"item_type": "course", "item_id": "stem_sports"},
    f"{_PREFIX}.course_college_prep": {"item_type": "course", "item_id": "college_prep"},
    f"{_PREFIX}.course_advanced_bb": {"item_type": "course", "item_id": "advanced_bb"},
}


def merged_storekit_catalog() -> Dict[str, Dict[str, str]]:
    out = dict(DEFAULT_STOREKIT_MAP)
    raw = os.environ.get("FEL_STOREKIT_CATALOG_JSON", "").strip()
    if not raw:
        return out
    try:
        extra = json.loads(raw)
        if not isinstance(extra, dict):
            return out
        for k, v in extra.items():
            if isinstance(v, dict) and v.get("item_type") and v.get("item_id"):
                out[str(k)] = {"item_type": str(v["item_type"]), "item_id": str(v["item_id"])}
    except Exception:
        pass
    return out


def resolve_storekit_product(apple_product_id: str) -> Optional[Dict[str, str]]:
    if not apple_product_id:
        return None
    return merged_storekit_catalog().get(str(apple_product_id))


def mapping_valid_for_commerce(mapping: Dict[str, str]) -> bool:
    meta = COMMERCE_CATALOG.get(mapping["item_id"])
    return bool(meta and meta.get("kind") == mapping["item_type"])


def decode_unsigned_jws_payload(jws: str) -> Dict[str, Any]:
    """Decode JWT payload segment only — **does not** verify Apple’s signature. Never grant entitlements from this alone."""
    parts = jws.strip().split(".")
    if len(parts) < 2:
        raise ValueError("transaction JWS must have header.payload")

    seg = parts[1]
    pad = "=" * (-len(seg) % 4)
    raw = base64.urlsafe_b64decode(seg + pad)
    return json.loads(raw.decode("utf-8"))
