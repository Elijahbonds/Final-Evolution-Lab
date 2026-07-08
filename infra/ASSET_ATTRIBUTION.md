# Asset Attribution

Per-item provenance for all demo/mock assets. Every entry must state source
and license so QA can verify shippability. Append new entries; never delete.

## nexus/sceneit-demo — Who Scene It

| Asset | Type | Source | License | Notes |
|---|---|---|---|---|
| `backend/lib/sceneit/data/mock_datadump.json` | Text content (12 fictional films, 15 fictional creator personas, scenes, credits, bios, lessons) | Original — authored in-repo for the Final Evolution universe by the nexus/sceneit-demo agent | FEL-Original-1.0 (all rights held by Final Evolution Lab) | No real films, actors, studios, or IMDb-derived data. Every JSON item also carries its own `source` + `license` fields, enforced by `lib/sceneit/content.require_shippable()`. |
| Scene stills served at `/api/sceneit/stills/{scene_id}.svg` | Generated SVG images (abstract geometric compositions, ~2–4 KB each, well under the 1 MB cap) | Procedurally generated at request time by `backend/lib/sceneit/stills.py` from palette+seed specs in the datadump | FEL-Original-1.0 | Clearly-original placeholder art, each frame watermarked `FEL ORIGINAL PLACEHOLDER`. To be replaced by Meshy-generated stills at design sign-off (same URL contract). |
| Film-grain overlay in `frontend/src/components/SceneItView.js` | Inline SVG feTurbulence noise (data URI) | Original — generated CSS/SVG, no external asset | FEL-Original-1.0 | Self-contained; no third-party textures. |

No Wikimedia/public-domain imagery was used in this workstream; if a future
round adds any, list each image here with its exact source URL and license.
