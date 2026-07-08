# assets/external — raw downloads (NOT committed)

Everything in this directory except the READMEs is fetched on demand by
`scripts/fetch_assets.sh` (see `infra/asset_sources.json` for the catalog and
`infra/ASSET_CHECKSUMS.json` for pinned sha256s). Zips are gitignored; the
curated, committed outputs live in `assets/demo/` and are rebuilt with
`scripts/build_demo_assets.sh`.

## Manual downloads still required (login- or browser-gated sources)
These are VALUABLE but cannot be auto-fetched; follow the steps and never
commit anything license-forbidden:

1. Mixamo animation clips — needs a free Adobe login. Steps in
   `assets/external/mixamo/README.txt`. NEVER commit the raw FBX.
2. Kenney Sports Pack + full Kenney packs from kenney.nl — CDN paths are
   dynamic; browser-download from https://kenney.nl/assets/sports-pack and
   unzip to `assets/external/kenney/`. (Interface Sounds and the Particle
   Pack are auto-fetched from Kenney's own OpenGameArt mirrors instead.)
3. Quaternius packs — browser-download (no login) from
   https://quaternius.com / https://quaternius.itch.io, CC0.
4. Freesound full-quality files — need a free account; use the CC0 filter,
   drop WAVs in `assets/external/audio/`, then record sound ID + author +
   license in `infra/ASSET_ATTRIBUTION.md` in the same commit.
5. TMDB imagery — EXCLUDED on purpose (login-gated API + film-IP constraint).
   The Who Scene It demo uses original in-universe content only; do not add
   film stills, posters, or celebrity images.
