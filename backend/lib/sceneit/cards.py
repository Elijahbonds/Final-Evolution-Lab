"""
cards.py — CardModule seam: collectible Creator Cards.

Each scene/question links to a Creator Card (in-universe director/actor
persona) carrying educational facts sourced from the content provider.

Demo scope: card data model + deep-dive payload (bio, timeline, top works,
linked lesson stub). The full collection loop (ownership, packs, trading)
is intentionally STUBBED — see CardProvider.collection_for().
"""
from typing import Any, Dict, List, Optional

from .content import SceneContentModule, get_default_provider

_RARITY_BY_PERSONA = {
    "director": "legendary",
    "actor": "epic",
    "cinematographer": "rare",
    "composer": "rare",
    "science_consultant": "rare",
}


def creator_card_for(creator: Dict[str, Any], content: SceneContentModule) -> Dict[str, Any]:
    """Build the collectible Creator Card payload for a creator persona."""
    top_works = []
    for fid in creator.get("top_work_ids", []):
        film = content.film(fid)
        if film:
            top_works.append({"film_id": fid, "title": film["title"], "year": film["year"]})
    return {
        "card_id": f"card_{creator['creator_id']}",
        "creator_id": creator["creator_id"],
        "name": creator["name"],
        "persona": creator["persona"],
        "tagline": creator.get("tagline", ""),
        "rarity": _RARITY_BY_PERSONA.get(creator["persona"], "common"),
        "bio": creator.get("bio", ""),
        "timeline": creator.get("timeline", []),
        "top_works": top_works,
        "facts": creator.get("facts", []),
        "lesson_stub": creator.get("lesson_stub", {}),
        "portrait_ref": creator.get("portrait_ref", ""),
        "source": creator.get("source", ""),
        "license": creator.get("license", ""),
    }


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
