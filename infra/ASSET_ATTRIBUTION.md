# Asset & Content Attribution

Record every third-party or generated asset/content source here (append-only).

| Asset / Content | Where | Source | License | Notes |
|---|---|---|---|---|
| Brain Brawl trivia questions (80 items, ids `otdb_*`) | `backend/content/brainbrawl_questions.json` | [Open Trivia Database](https://opentdb.com) public API, fetched 2026-07-07 by `scripts/seed_mock_content.py` | CC BY-SA 4.0 | Free to use; per-question `source`/`license` fields recorded in the JSON. HTML entities unescaped; option order shuffled deterministically at seed time. |
| Brain Brawl original questions (34 items, ids `fel_dd_*`, `fel_ms_*`, `fel_sg_*`) | `backend/content/brainbrawl_questions.json` | Authored for Final Evolution Lab in `scripts/seed_mock_content.py` (2026-07-07) | CC0-1.0 | Includes Deep Dive explanations + micro-lessons, multi-select partial-credit items, and music/dance taxonomy questions (original + factual; no real artists, songs, or recordings referenced). |
