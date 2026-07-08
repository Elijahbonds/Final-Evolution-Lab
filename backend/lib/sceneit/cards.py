"""
cards.py — CardModule seam for Who Scene It.

The card SCHEMA lives in the shared module `lib.creator_cards` (imported by
every mode that surfaces Creator Cards — Brain Brawl, Court Carnival, ...).
This file only binds that schema to the sceneit content provider.

Demo scope: card data model + deep-dive payload (bio, timeline, top works,
linked lesson stub, MUSIC/DANCE/LINKS sections). The full collection loop
(ownership, packs, trading) is intentionally STUBBED — see collection_for().
"""
from typing import Any, Dict, List, Optional

from lib.creator_cards import build_card  # shared schema — do not fork
from .content import SceneContentModule, get_default_provider


def creator_card_for(creator: Dict[str, Any], content: SceneContentModule) -> Dict[str, Any]:
    """Build the shared-schema Creator Card payload for a creator persona."""
    return build_card(creator, content.film)


class CardProvider:
    """Card seam consumed by the router. Swappable like every other module."""

    def __init__(self, content: Optional[SceneContentModule] = None):
        self.content = content or get_default_provider()
        self._cache: Dict[str, Dict[str, Any]] = {}

    def card(self, creator_id: str) -> Optional[Dict[str, Any]]:
        if creator_id not in self._cache:
            creator = self.content.creator(creator_id)
            if creator is None:
                return None
            self._cache[creator_id] = creator_card_for(creator, self.content)
        return self._cache[creator_id]

    def all_cards(self) -> List[Dict[str, Any]]:
        return [self.card(c["creator_id"]) for c in self.content.creators()]

    def collection_for(self, player_id: str) -> Dict[str, Any]:
        """STUB — full collection loop (ownership/packs/trading) is out of demo
        scope. Returns an explicit not-implemented marker so clients can gate."""
        return {"player_id": player_id, "implemented": False,
                "detail": "Card collection loop is stubbed in the sceneit demo."}
