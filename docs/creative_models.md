# Creative Modes Foundation — Schema Contract

**Branch:** `nexus/creative-models` (base: `integration/nexus-creative`)

This is the FOUNDATION contract for the three upcoming creative mode branches
(**Music Creation**, **Dance Game**, **Art Showcase**). Mode branches build
against the models and endpoints documented here — you should not need to read
the implementation.

Implementation lives in:

- `backend/lib/creative_store.py` — MOCK_DB-aware storage + Creator Card pack registry
- `backend/routers/music.py`, `backend/routers/dance.py`, `backend/routers/art.py`
- `backend/routers/creator_cards.py` — card apply + generic replay export
- Tests: `backend/tests/test_music_project.py`, `test_dance_project.py`, `test_art_exhibit.py`

## Storage conventions

Same rules as `routers/matches.py`:

- `MOCK_DB=1` (or running under pytest) → in-memory dict stores, no external DB.
- Otherwise → MongoDB collections `music_projects`, `dance_projects`,
  `art_exhibits`, `creator_card_refs` (upsert by primary key, in-memory
  fallback on DB error).
- Auth: production uses the standard session auth (`get_current_user`);
  under `MOCK_DB=1` endpoints fall back to a guest identity, overridable via
  the `X-FEL-Sim-Player` header (same contract as match endpoints).

**Replay events are NOT a new system.** Composition/performance replays reuse
the existing match event store (`routers.matches._persist_event` /
`_load_events`; collection `match_events` in production), keyed by
`project_id`/`exhibit_id` instead of `match_id`. Events carry server-stamped
monotonically increasing `seq` values, exactly like match replays. Mode
branches append gameplay/edit events for a project through this same store —
do not build a parallel event log.

## Data models

### music_projects

| Field | Type | Notes |
|---|---|---|
| `project_id` | str | `mus_` + 12 hex chars, server-generated |
| `owner_id` | str | authenticated user id |
| `name` | str | default `"Untitled Music Project"` |
| `bpm` | int | 20–300, default 120 |
| `key` | str | free-form musical key, default `"C"` |
| `tracks` | list[Track] | see below |
| `created_at` | str | UTC ISO-8601 |
| `seed` | int | 64-bit; client-suppliable at create, else server-generated; persisted for deterministic renders |
| `metadata` | dict | free-form mode-branch extension point |
| `applied_card_packs` | list | Creator Card packs attached via `/api/creator-cards/apply` |

**Track:** `{track_id (str, server-generated if omitted), type ("instrument"|"sample"), clips: [{clip_id, start (beats, >=0), length (beats, >0)}], volume (0..2, default 1), pan (-1..1, default 0), effects: [dict]}`

### dance_projects

| Field | Type | Notes |
|---|---|---|
| `project_id` | str | `dan_` + 12 hex chars |
| `owner_id` | str | authenticated user id |
| `name` | str | default `"Untitled Dance Project"` |
| `skeleton` | str | rig identifier, default `"humanoid_v1"` |
| `animations` | list | `[{id, name, duration (sec, >=0), source ("library"\|"mocap"\|"deepmotion"\|"custom")}]` |
| `timeline` | dict | default `{"entries": []}`; entry shape is mode-branch defined |
| `bpm` | int | 20–300, default 120 |
| `created_at` | str | UTC ISO-8601 |
| `seed` | int | 64-bit, persisted (deterministic playback) |
| `applied_card_packs` | list | as above |

### art_exhibits

| Field | Type | Notes |
|---|---|---|
| `exhibit_id` | str | `art_` + 12 hex chars |
| `owner_id` | str | authenticated user id |
| `title` | str | default `"Untitled Exhibit"` |
| `items` | list | `[{id, type ("image"\|"3d"\|"model"), path (required; asset reference, never a binary), meta: dict}]` |
| `created_at` | str | UTC ISO-8601 |
| `status` | str | `draft` → `published` (via publish endpoint) |
| `published_at` | str/null | null until published |
| `marketplace` | dict | `{listed: bool, listing_id: str\|null, stub: true}` — STUB; real marketplace is a mode-branch concern |
| `applied_card_packs` | list | as above |

### creator_card_refs

Applied-card records: `{ref_id ("ref_"+12hex), card_id, pack_id, project_type ("music"|"dance"|"art"), project_id, owner_id, applied_at}`.

The card→lesson-pack registry (`CREATOR_CARD_PACKS` in
`lib/creative_store.py`, served at `GET /api/creator-cards/packs`) currently
defines these contract-stable card ids:

| card_id | mode | pack_id |
|---|---|---|
| `card_maestro_01` | music | `pack_music_theory_101` |
| `card_sampler_01` | music | `pack_beatmaking_101` |
| `card_groove_01` | dance | `pack_dance_footwork_101` |
| `card_choreo_01` | dance | `pack_choreography_101` |
| `card_visionary_01` | art | `pack_art_composition_101` |
| `card_curator_01` | art | `pack_exhibit_curation_101` |

### replay_events (reused)

Same store and shape as match events. The foundation appends:

- `project_created` — `{type, project_type, project_id, player_id, seed, timestamp, seq}`
- `card_applied` — `{type, project_type, project_id, player_id, card_id, pack_id, timestamp, seq}`

Mode branches append their own event types (inputs, note edits, dance steps,
…) via the same store; `seq` ordering is authoritative for replay.

## Endpoints

| Method + path | Purpose | Errors |
|---|---|---|
| `POST /api/music/projects` | create music project | 422 invalid fields |
| `GET /api/music/projects/{id}` | fetch project | 404 |
| `POST /api/music/projects/{id}/export` | JSON export + audio placeholder | 404 |
| `POST /api/music/projects/{id}/render-preview` | MOCK deterministic render manifest | 404 |
| `POST /api/dance/projects` | create dance project | 422 |
| `GET /api/dance/projects/{id}` | fetch project | 404 |
| `POST /api/dance/projects/{id}/export` | JSON export | 404 |
| `POST /api/art/exhibits` | create exhibit | 422 |
| `GET /api/art/exhibits/{id}` | fetch exhibit | 404 |
| `POST /api/art/exhibits/{id}/publish` | marketplace stub: draft→published | 404, 409 already published |
| `GET /api/creator-cards/packs` | card→pack registry | — |
| `POST /api/creator-cards/apply` | attach card pack to a project | 404 unknown card/project, 422 mode mismatch, 409 already applied |
| `GET /api/replays/{id}/export` | generic replay export (match ids AND creative ids) | 404 |

Determinism guarantees:

- `seed` is persisted at create and never mutated; same project state ⇒
  byte-identical `render-preview` manifest and idempotent `export`.
- `GET /api/replays/{id}/export` returns the canonical
  `{metadata: {...}, events: [...]}` shape for both matches (delegates to the
  existing `/api/matches/{id}/export-replay`) and creative projects
  (`metadata.replay_kind = "creative_project"`, includes `project_type`,
  `seed`, `event_count`).

## Curl examples (run against `MOCK_DB=1` dev server)

```bash
cd backend && MOCK_DB=1 python3 -m uvicorn server:app --port 8791
B=http://127.0.0.1:8791
```

### Music: create → export → render-preview

```bash
curl -s -X POST $B/api/music/projects -H 'Content-Type: application/json' -d '{
  "name": "Demo Beat", "bpm": 92, "key": "F#m", "seed": 42,
  "tracks": [
    {"type": "instrument", "clips": [{"start": 0, "length": 4}],
     "volume": 0.8, "pan": -0.2, "effects": [{"type": "reverb", "wet": 0.3}]},
    {"type": "sample", "clips": [{"start": 4, "length": 2}]}
  ]}'
# -> {"project_id": "mus_3ffe7460e86f", "owner_id": "sim_guest", "name": "Demo Beat",
#     "bpm": 92, "key": "F#m", "tracks": [{"track_id": "trk_ced04df7", ...}],
#     "created_at": "2026-07-08T05:55:07.451862+00:00", "seed": 42,
#     "metadata": {}, "applied_card_packs": []}

curl -s -X POST $B/api/music/projects/mus_3ffe7460e86f/export
# -> {"export_version": "1.0", "project_type": "music", "project": {...full model...},
#     "audio": {"status": "placeholder", "format": null, "url": null, ...},
#     "replay": {"replay_id": "mus_3ffe7460e86f", "seed": 42, "event_count": 1}}

curl -s -X POST $B/api/music/projects/mus_3ffe7460e86f/render-preview
# -> {"render_id": "render_000000000000002a", "status": "mock_rendered",
#     "deterministic": true, "seed": 42, "bpm": 92, "key": "F#m", "track_count": 2,
#     "sample_rate": 44100, "bit_depth": 16,
#     "sections": [{"index": 0, "start_beat": 0, "length_beats": 16, "energy": 0.639427}, ...],
#     "waveform_checksum": "bc8960a9", ...}
#    (calling again returns the byte-identical manifest)
```

### Dance: create → export

```bash
curl -s -X POST $B/api/dance/projects -H 'Content-Type: application/json' -d '{
  "name": "Demo Routine", "skeleton": "humanoid_v1", "bpm": 128, "seed": 321,
  "animations": [{"name": "wave_intro", "duration": 3.5, "source": "mocap"}],
  "timeline": {"entries": [{"animation": "wave_intro", "start_beat": 0}]}}'
# -> {"project_id": "dan_910365f43d87", ..., "seed": 321, ...}

curl -s -X POST $B/api/dance/projects/dan_910365f43d87/export
# -> {"export_version": "1.0", "project_type": "dance", "project": {...},
#     "replay": {"replay_id": "dan_910365f43d87", "seed": 321, "event_count": 1}}
```

### Art: create → publish

```bash
curl -s -X POST $B/api/art/exhibits -H 'Content-Type: application/json' -d '{
  "title": "First Light",
  "items": [{"type": "image", "path": "assets/gallery/sunrise.png", "meta": {"w": 1920}},
            {"type": "3d", "path": "assets/venues/sculpture_01.scn"}]}'
# -> {"exhibit_id": "art_d247cb22b569", "status": "draft", "published_at": null,
#     "marketplace": {"listed": false, "listing_id": null}, ...}

curl -s -X POST $B/api/art/exhibits/art_d247cb22b569/publish
# -> {"exhibit_id": "art_d247cb22b569", "status": "published",
#     "published_at": "...", "marketplace": {"listed": true, "listing_id": "list_...", "stub": true}}
```

### Creator Cards + generic replay export

```bash
curl -s -X POST $B/api/creator-cards/apply -H 'Content-Type: application/json' \
  -d '{"card_id": "card_maestro_01", "project_type": "music", "project_id": "mus_3ffe7460e86f"}'
# -> {"ok": true, "ref_id": "ref_...", "card_id": "card_maestro_01",
#     "pack": {"pack_id": "pack_music_theory_101", "title": "Music Theory 101",
#              "lessons": ["intervals", "chord_progressions", "song_structure"]},
#     "project_type": "music", "project_id": "mus_3ffe7460e86f"}

curl -s $B/api/replays/mus_3ffe7460e86f/export
# -> {"metadata": {"replay_id": "mus_3ffe7460e86f", "replay_kind": "creative_project",
#                  "project_type": "music", "owner_id": "sim_guest", "seed": 42,
#                  "created_at": "...", "export_version": "1.1", "event_count": 2},
#     "events": [{"type": "project_created", "seq": 0, ...},
#                {"type": "card_applied", "card_id": "card_maestro_01", "seq": 1, ...}]}
```

## Running the tests

```bash
cd backend && MOCK_DB=1 python3 -m pytest tests/ -q
# 165 passed (110 pre-existing + 55 creative-foundation)
```
