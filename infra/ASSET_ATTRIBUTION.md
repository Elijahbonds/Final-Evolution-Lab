# Asset Attribution

Per-item provenance for all demo/mock assets. Every entry must state source
and license so QA can verify shippability. Append new entries; never delete.

## nexus/sceneit-demo — Who Scene It

| Asset | Type | Source | License | Notes |
|---|---|---|---|---|
| `backend/lib/sceneit/data/mock_datadump.json` | Text content (13 fictional films, 18 fictional creator personas, scenes, credits, bios, lessons, soundtrack/dance sections) | Original — authored in-repo for the Final Evolution universe by the nexus/sceneit-demo agent | FEL-Original-1.0 (all rights held by Final Evolution Lab) | No real films, actors, studios, or IMDb-derived data. Every JSON item also carries its own `source` + `license` fields, enforced by `lib/sceneit/content.require_shippable()` and `lib/creator_cards.validate_sections()`. Track/dance/link *titles* are original fiction; the audio bytes they resolve to are the CC0 clips below. |
| Scene stills served at `/api/sceneit/stills/{scene_id}.svg` | Generated SVG images (abstract geometric compositions, ~2–4 KB each, well under the 1 MB cap) | Procedurally generated at request time by `backend/lib/sceneit/stills.py` from palette+seed specs in the datadump | FEL-Original-1.0 | Clearly-original placeholder art, each frame watermarked `FEL ORIGINAL PLACEHOLDER`. To be replaced by Meshy-generated stills at design sign-off (same URL contract). |
| Film-grain overlay in `frontend/src/components/SceneItView.js` | Inline SVG feTurbulence noise (data URI) | Original — generated CSS/SVG, no external asset | FEL-Original-1.0 | Self-contained; no third-party textures. |
| `assets/demo/audio/*.ogg` (9 clips) — Tier-1 jukebox demo audio served at `/api/music/preview/{filename}` | Audio (short interface sounds; each < 15 KB) | Kenney Interface Sounds (kenney.nl), curated into this repo via branch `nexus/asset-fetch-demo` (PR #128) | CC0 1.0 — public domain, attribution not required (credited as courtesy) | Stand-in audio for the SoundtrackMenu / MockMusicProvider. Playback is **discovery only** — never coupled to match scoring (Spotify developer-policy memo). To be replaced by real creator tracks via Tier-2 SoundCloud/Audius providers. `crowd_cheer.m4a` from the same pack is CC-BY 3.0 (Blender Foundation) — not used by sceneit. |

No Wikimedia/public-domain imagery was used in this workstream; if a future
round adds any, list each image here with its exact source URL and license.

## Music provider policy (recorded for QA / legal)

The jukebox (`SoundtrackMenu` + `lib/music_providers.py`) is architected as
**creator discovery, not gameplay**: no points, unlocks, streaks, or penalties
may ever hinge on listening. This is a hard constraint from Spotify's developer
policy (games and gameplay-coupled playback are prohibited; no quota-approval
path exists for games). Tier-2 (SoundCloud/Audius, keyless embeds) is the
realistic MVP; Tier-3 (Spotify/Apple) is approval-gated and preview-only via
oEmbed/iframe with required provider branding. Audio is never proxied or
re-hosted — only Tier-1 CC0 clips are served locally.
