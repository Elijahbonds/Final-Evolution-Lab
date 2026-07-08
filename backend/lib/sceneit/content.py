"""
content.py — SceneContentModule seam + LocalDatadumpProvider.

The match engine and round modules only ever talk to the SceneContentModule
interface. The demo ships LocalDatadumpProvider, which reads the original
in-universe MOCK_DATADUMP JSON checked into this repo.

FUTURE LICENSED-DATA SEAM (documented, intentionally unimplemented):
    A licensed provider (e.g. a studio content-partner API) implements the
    same interface and is swapped in via `get_default_provider()` or by
    passing `content=` to the match engine. Requirements for any provider:
      - every film/scene/creator dict MUST carry `source` and `license`
        fields (QA gates on these — see require_shippable()),
      - image refs must resolve to assets the license actually covers,
      - NO keyed third-party APIs may be called at request time from this
        demo stack (licensed providers pre-sync into a local cache).

IP CONSTRAINT: this module never touches real film/actor/IMDb data.
"""
import json
import os
from abc import ABC, abstractmethod
from typing import Any, Dict, List, Optional

MOCK_DATADUMP_PATH = os.environ.get(
    "SCENEIT_DATADUMP",
    os.path.join(os.path.dirname(__file__), "data", "mock_datadump.json"),
)


class ContentLicenseError(ValueError):
    """Raised when a content item is missing source/license provenance."""


def require_shippable(item: Dict[str, Any], kind: str) -> Dict[str, Any]:
    """QA gate: every content item must declare where it came from."""
    if not item.get("source") or not item.get("license"):
        raise ContentLicenseError(
            f"{kind} {item.get(f'{kind}_id', '<unknown>')!r} is missing source/license "
            "provenance — not shippable."
        )
    return item


class SceneContentModule(ABC):
    """Swappable content seam (Nexus philosophy: data-driven, provider-agnostic)."""

    provider_id: str = "abstract"

    @abstractmethod
    def films(self) -> List[Dict[str, Any]]: ...

    @abstractmethod
    def film(self, film_id: str) -> Optional[Dict[str, Any]]: ...

    @abstractmethod
    def scenes(self) -> List[Dict[str, Any]]:
        """All scenes, each carrying its parent film_id."""

    @abstractmethod
    def creators(self) -> List[Dict[str, Any]]: ...

    @abstractmethod
    def creator(self, creator_id: str) -> Optional[Dict[str, Any]]: ...


class LocalDatadumpProvider(SceneContentModule):
    """Reads the original-content MOCK_DATADUMP JSON. No network, no keys."""

    provider_id = "local_datadump_v1"

    def __init__(self, path: str = MOCK_DATADUMP_PATH):
        with open(path, "r", encoding="utf-8") as f:
            self._raw = json.load(f)
        self._films: Dict[str, Dict[str, Any]] = {}
        self._creators: Dict[str, Dict[str, Any]] = {}
        self._scenes: List[Dict[str, Any]] = []
        for film in self._raw.get("films", []):
            require_shippable(film, "film")
            self._films[film["film_id"]] = film
            for scene in film.get("scenes", []):
                require_shippable(scene, "scene")
                self._scenes.append({**scene, "film_id": film["film_id"]})
        for creator in self._raw.get("creators", []):
            require_shippable(creator, "creator")
            self._creators[creator["creator_id"]] = creator

    def films(self) -> List[Dict[str, Any]]:
        return list(self._films.values())

    def film(self, film_id: str) -> Optional[Dict[str, Any]]:
        return self._films.get(film_id)

    def scenes(self) -> List[Dict[str, Any]]:
        return list(self._scenes)

    def creators(self) -> List[Dict[str, Any]]:
        return list(self._creators.values())

    def creator(self, creator_id: str) -> Optional[Dict[str, Any]]:
        return self._creators.get(creator_id)


_default_provider: Optional[LocalDatadumpProvider] = None


def get_default_provider() -> LocalDatadumpProvider:
    """Process-wide cached provider (datadump is static content)."""
    global _default_provider
    if _default_provider is None:
        _default_provider = LocalDatadumpProvider()
    return _default_provider
