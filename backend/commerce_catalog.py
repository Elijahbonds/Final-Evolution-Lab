"""
Server-authoritative PayPal catalog (COMMERCE-01).

Prices MUST NOT be taken from the client. Keys are ``item_id``; ``kind`` must match ``item_type``.
"""
from typing import Any, Dict

from fastapi import HTTPException

# USD — keep in sync with seeded courses/cards used by the storefront UI.
COMMERCE_CATALOG: Dict[str, Dict[str, Any]] = {
    # Courses (see ``get_seeded_courses``)
    "brain_brawl_101": {"kind": "course", "price_usd": 0.0, "title": "Brain Brawl Fundamentals"},
    "kinesiology_cert": {"kind": "course", "price_usd": 299.0, "title": "Applied Kinesiology Certificate"},
    "stem_sports": {"kind": "course", "price_usd": 49.0, "title": "STEM in Sports Science"},
    "college_prep": {"kind": "course", "price_usd": 79.0, "title": "College Prep for Athletes"},
    "advanced_bb": {"kind": "course", "price_usd": 99.0, "title": "Brain Brawl: Advanced Tactics"},
    # Creator cards (see ``get_seeded_creator_cards``)
    "card_elijah": {"kind": "card", "price_usd": 99.99, "title": "Creator Card — Elijah Bonds"},
    "card_amir": {"kind": "card", "price_usd": 79.99, "title": "Creator Card — Amir Smith"},
    "card_eric": {"kind": "card", "price_usd": 49.99, "title": "Creator Card — Eric Nash"},
}


def resolve_paypal_line_item(item_type: str, item_id: str) -> Dict[str, Any]:
    if not item_id:
        raise HTTPException(status_code=400, detail="item_id required")
    meta = COMMERCE_CATALOG.get(item_id)
    if not meta:
        raise HTTPException(status_code=404, detail="Unknown product")
    if meta["kind"] != item_type:
        raise HTTPException(status_code=400, detail="item_type does not match catalog entry")
    price = float(meta["price_usd"])
    if price <= 0:
        raise HTTPException(
            status_code=400,
            detail="This item has no charge — use free enrollment instead of PayPal.",
        )
    return meta


def catalog_price_usd(item_type: str, item_id: str) -> float:
    return float(resolve_paypal_line_item(item_type, item_id)["price_usd"])
