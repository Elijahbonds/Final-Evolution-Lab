# Game Mode Design Doc — AAA Quality Checklist

Use this template when adding a new game mode to FEL OS.

---

## Mode Identity

- [ ] **mode_id** — unique snake_case identifier (e.g. `tennis_h2h`)
- [ ] **display_name** — human-readable (e.g. "Tennis · Court")
- [ ] **category** — one of: Basketball, Combat, Field, Court, Board, Academy, Party, Precision, Performance
- [ ] **venue** — physical venue name (maps to `VENUE_REGISTRY`)
- [ ] **player_count** — "1", "1v1", "2v2", "3v3", "2-8"
- [ ] **duration** — "5 min", "15 min", "Unlimited"
- [ ] **difficulty** — Beginner | Intermediate | Advanced | Expert | Variable

---

## Backend

- [ ] Mode registered in `get_seeded_game_modes()` in `server.py`
- [ ] `PRQ_MODE_WEIGHTS` entry added with appropriate multiplier (0.8–1.5)
- [ ] Mode ID added to `modes_unlocked` logic in `system_scan.py`
- [ ] Match lifecycle tested with `mode_id` in `test_matches.py`

---

## Nexus / UE5

- [ ] Map path defined (e.g. `/Game/FEL/Maps/TennisCourt`)
- [ ] Mode registered in `FEL_VenueRegistry.production.json`
- [ ] Mode registered in `FEL_ModeManager.production.json`
- [ ] GameMode class created (e.g. `BP_GameMode_Tennis`)
- [ ] `deep_link` works: `finalevolution://launch?map=tennis_court&mode=tennis_h2h`

---

## Creator Card Integration

- [ ] Relevant card modifiers apply to mode (e.g. `+15% agility` matters for tennis)
- [ ] `_load_loadout()` returns cards with relevant `modifiers_summary`
- [ ] Modifier impact documented in mode design notes

---

## Bio-Digital / Neuro-Cues

- [ ] Neuro-cues registered in `/api/bio-digital/neuro-cues/{mode_id}` if applicable
- [ ] At least 3 joint-angle triggers defined for main moves
- [ ] Anatomy highlights identified (muscle groups, fascial lines)

---

## Frontend

- [ ] Mode appears in `GameView` scoreboard correctly
- [ ] Mode card shown in game modes list (`/api/games/modes`)
- [ ] Image URL set (Unsplash or CDN, 800px wide)

---

## QA

- [ ] Manual playtest via `frontend/public/playtest.html`
- [ ] WS `match_start` + `score_event` + `match_end` all fire correctly
- [ ] 404 on invalid match_id
- [ ] 409 on join-active match
- [ ] All tests pass: `MOCK_DB=1 python -m pytest backend/tests/ -v`

---

## Economy

- [ ] Shard rewards configured (win/draw/loss amounts)
- [ ] XP per session appropriate for mode duration
- [ ] Tournament eligibility flagged if applicable

---

## Launch Criteria (AAA Standard)

- [ ] All checklist items above complete
- [ ] No known P0/P1 bugs
- [ ] PRQ delta calculation validated
- [ ] Mode included in CI test run
- [ ] Infra doc updated with new mode entry
