# Asset License Summary & Approval Checklist

## Acceptable licenses (no approval needed)
- CC0 1.0 / Public Domain — no attribution required (courtesy credit encouraged)
- CMU mocap license — free all uses; REQUIRED credit line (see ASSET_ATTRIBUTION.md)
- Owner-generated: Meshy subscription outputs, DeepMotion of owner's own
  performances, owner-licensed packs (Seeles) — provenance recorded, not redistributed standalone

## Acceptable with conditions
- CC-BY 3.0/4.0 — REQUIRED: author + license + link in ASSET_ATTRIBUTION.md
  AND in-app credits screen entry
- Mixamo — usable in builds; raw FBX must NEVER be committed/redistributed

## Not acceptable
- CC-BY-NC / CC-BY-ND / CC-BY-SA (viral) — commercial game; drop these
  - NARROW CARVE-OUT (owner-approved for web demos): OpenTDB question TEXT in
    `assets/mock/opentdb_questions.json` is CC BY-SA 4.0. It is demo/mock DATA
    (not engine/game art); ShareAlike only obliges us to keep the question set
    itself under CC BY-SA with attribution (embedded in the dump + credits
    line). It does NOT infect code or other assets. Before any commercial
    ship, replace with owner-written questions or re-confirm scope with owner.
- "Free for personal use" — drop
- Unlabeled/unclear license — STOP, record URL + claimed license, escalate to owner

## New-asset checklist (gate for every PR adding assets)
- [ ] License verified on the SOURCE page (not a re-host)
- [ ] Entry added to infra/asset_sources.json (URL, license, fetch mode)
- [ ] Entry added to infra/ASSET_ATTRIBUTION.md (author, license, credit text)
- [ ] sha256 in infra/ASSET_CHECKSUMS.json (via fetch script or manual)
- [ ] File > 5 MB? -> NOT committed; downloader/manual-drop path instead
- [ ] CC-BY? -> credits screen entry added
