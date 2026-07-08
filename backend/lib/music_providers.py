"""
music_providers.py — MusicProviderModule seam (SoundtrackMenu backend).

DESIGN DECISIONS (from the 2026-07 Spotify research memo — bake these into any
future provider work):

  1. PLAYBACK IS DISCOVERY, NOT GAMEPLAY. Spotify's developer policy PROHIBITS
     games and any playback tied to game mechanics, and there is NO quota
     approval path for games. Therefore the SoundtrackMenu/jukebox is
     architected as *creator discovery*: no points, achievements, unlocks,
     skip penalties, or any coupling between listening and match state. The
     match engine (routers/sceneit.py) has zero imports from this module —
     keep it that way.

  2. PROVIDER TIERS:
       Tier 1  MockMusicProvider       — demo; CC0 local audio (this file).
       Tier 2  SoundCloudProvider,     — keyless oEmbed/iframe embeds + public
               AudiusProvider            API; independent-artist native. This
                                         is the realistic MVP path for DJs and
                                         producers linking their own tracks.
       Tier 3  SpotifyWebAPIProvider,  — post-launch only; requires separate
               AppleMusicKitProvider     business/API approval. Spotify is
                                         preview-only via keyless oEmbed/iframe
                                         embeds (30s previews, Spotify branding
                                         REQUIRED in the UI).

  3. Spotify Web API 30s `preview_url`s are DEPRECATED (2026) — do not design
     around them; embeds are the only sanctioned preview surface.

  4. CACHE METADATA ONLY (title/artwork/duration). Never cache, proxy, or
     re-host provider audio. Tier-1 CC0 files are the sole local audio.

  5. Every provider must supply branding/attribution fields; the UI renders
     them verbatim (provider logos/wordmarks where the provider requires it).

Seam interface (implemented by every tier):
    get_creator_tracks(creator_id, track_refs) -> [resolved track metadata]
    get_embed_ref(track_ref)                   -> {kind, url, ...}
    provider_branding()                        -> {name, attribution, ...}
"""
import os
from abc import ABC, abstractmethod
from typing import Any, Dict, List

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CC0_AUDIO_DIR = os.path.join(REPO_ROOT, "assets", "demo", "audio")


class MusicProviderModule(ABC):
    """Swappable music seam. Metadata + embed refs only — never audio bytes."""

    provider_id: str = "abstract"
    tier: int = 0

    @abstractmethod
    def get_creator_tracks(self, creator_id: str,
                           track_refs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Resolve a card's MUSIC section refs to playable track metadata."""

    @abstractmethod
    def get_embed_ref(self, track_ref: Dict[str, Any]) -> Dict[str, Any]:
        """How the client plays/embeds this track:
        {"kind": "local_audio", "url": ...}            (Tier 1)
        {"kind": "oembed_iframe", "embed_url": ...}    (Tier 2/3)"""

    @abstractmethod
    def provider_branding(self) -> Dict[str, Any]:
        """Attribution/branding the UI MUST render for this provider."""


class MockMusicProvider(MusicProviderModule):
    """Tier 1 — demo provider over the CC0 audio pack (assets/demo/audio,
    Kenney Interface Sounds, CC0 1.0; pulled from nexus/asset-fetch-demo PR #128).
    Serves as the stand-in until Tier-2 SoundCloud/Audius providers land."""

    provider_id = "mock_cc0"
    tier = 1

    def _filename(self, track_ref: Dict[str, Any]) -> str:
        # provider_ref format: "cc0:<filename.ogg>"
        ref = track_ref.get("provider_ref", "")
        if not ref.startswith("cc0:"):
            raise ValueError(f"MockMusicProvider cannot resolve provider_ref {ref!r}")
        filename = os.path.basename(ref[len("cc0:"):])  # basename() bars traversal
        if not os.path.exists(os.path.join(CC0_AUDIO_DIR, filename)):
            raise FileNotFoundError(f"CC0 audio asset missing: {filename}")
        return filename

    def get_embed_ref(self, track_ref: Dict[str, Any]) -> Dict[str, Any]:
        return {"kind": "local_audio",
                "url": f"/api/music/preview/{self._filename(track_ref)}"}

    def get_creator_tracks(self, creator_id: str,
                           track_refs: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        tracks = []
        for ref in track_refs:
            if ref.get("provider") != "mock":
                continue  # other tiers own their refs
            tracks.append({
                "track_id": ref["track_id"],
                "title": ref["title"],
                "creator_id": creator_id,
                "duration_s": ref.get("duration_s", 0),
                "artwork_ref": ref.get("artwork_ref", ""),
                "embed": self.get_embed_ref(ref),
                "source": ref["source"],
                "license": ref["license"],
                "attribution": ref.get("attribution", ""),
            })
        return tracks

    def provider_branding(self) -> Dict[str, Any]:
        return {
            "name": "FEL Demo Jukebox (CC0)",
            "tier": self.tier,
            "attribution": "Demo audio: Kenney Interface Sounds (kenney.nl), CC0 1.0 — "
                           "stand-in until Tier-2 SoundCloud/Audius providers land.",
            "logo_ref": None,
            "playback_policy": "discovery_only",  # NEVER tied to match scoring
        }


# ── Tier 2/3 seam stubs (documented, intentionally unimplemented) ──────────
# class SoundCloudProvider(MusicProviderModule):   tier = 2 — keyless oEmbed:
#     GET https://soundcloud.com/oembed?url=<track_url>&format=json  → iframe
# class AudiusProvider(MusicProviderModule):       tier = 2 — public API:
#     discovery nodes, no key; embed via https://audius.co/embed/...
# class SpotifyWebAPIProvider(MusicProviderModule): tier = 3 — APPROVAL-GATED.
#     Games are prohibited by Spotify developer policy; only ship as
#     preview-only oEmbed/iframe with Spotify branding, after separate
#     business approval. preview_url fields are deprecated — do not use.


MUSIC_PROVIDER_REGISTRY: Dict[str, MusicProviderModule] = {}


def register_music_provider(provider: MusicProviderModule) -> MusicProviderModule:
    MUSIC_PROVIDER_REGISTRY[provider.provider_id] = provider
    return provider


register_music_provider(MockMusicProvider())


def get_music_provider(provider_id: str = "mock_cc0") -> MusicProviderModule:
    if provider_id not in MUSIC_PROVIDER_REGISTRY:
        raise KeyError(f"Unknown music provider {provider_id!r}; "
                       f"registered: {sorted(MUSIC_PROVIDER_REGISTRY)}")
    return MUSIC_PROVIDER_REGISTRY[provider_id]
