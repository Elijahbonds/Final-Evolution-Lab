# NEXUS backend API contract (client-facing)

Minimal route reference for the **NEXUS iOS app** against this repo's FastAPI backend. Source of truth: `backend/server.py` (Docker default) with Phase 1 parity in `backend/app/` (Postgres).

**Canonical repo:** `/Users/elijahbonds/Final-Evolution-Lab` — client wiring map in `docs/NEXUS_PRODUCT_INTEGRATION.md`.

**Base URL (production):** `https://api.finalevolutiongroup.com` (or your deployed Cloud Run / compose host)  
**API prefix:** `/api`  
**Health (K8s):** `GET /health` (no prefix)

## Authentication

All authenticated routes accept either:

- Cookie: `session_token` (HttpOnly, set by `POST /api/auth/session`)
- Header: `Authorization: Bearer <session_token>`

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/auth/session` | Exchange Firebase ID token for server session. Body: `{ "session_id": "<firebase_id_token>" }`. Returns user doc + sets `session_token` cookie. |
| `GET` | `/api/auth/me` | Current user profile. |
| `POST` | `/api/auth/logout` | Invalidate session token. |

## Session & gameplay economy (primary NEXUS paths)

Server computes XP, shards, and PRQ delta — clients must not grant rewards locally.

| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/games/session` | **Session receipt** — commits XP (cap 500/session), shards, PRQ Δ. Body includes `mode_id`, `score`, `duration_seconds`, `completed`, `outcome` (`win`\|`draw`\|`loss`), `combo_count`, `critical_count`, `pacing_score`, `mri_score`. Returns `session`, `xp_earned`, `shards_earned`, `prq_delta`, `economy_version`. |
| `POST` | `/api/session/state` | Live session lifecycle: `session_id`, `state` (`map_loading`\|`active`\|`completed`), optional `score`. |
| `GET` | `/api/session/active` | User's in-flight sessions (`launching`, `map_loading`, `active`). |
| `GET` | `/api/games/modes` | Mode catalog. |
| `GET` | `/api/games/modes/{mode_id}` | Single mode metadata. |
| `POST` | `/api/neurocognitive/session` | MRI / neuro session log (optional training telemetry). |
| `GET` | `/api/prq/metrics` | PRQ breakdown for authenticated user. |
| `POST` | `/api/prq/metrics` | Record PRQ metric sample. |

**Phase 1 Postgres app (`uvicorn app.main:app`):** same receipt at `POST /api/games/session` via `app/services/session_processor.py` (parity with v2.0 formulas in `server.py`).

### iOS client receipt path (NEXUS)

| Step | Component | Behavior |
|------|-----------|----------|
| 1 | C++ `SessionReceiptClient` | Persists JSON to `~/.fel/pending_receipts/{session_id}.json` on arena end (`httpEnabled=false` on iOS) |
| 2 | Swift `NexusGameplayEngine.stop` | `fel.arena.flush_receipts` → triggers `SessionReceiptUploadService.uploadPendingReceipts()` |
| 3 | Swift `NexusBackendClient.postSessionReceipt` | **PREVIEW lane:** skip POST (`previewQueuedLocally`). **Live lane:** `FEL_BACKEND_AUTH_TOKEN` or Firebase Bearer → `POST /api/games/session` |
| 4 | Swift `SessionReceiptUploadService` | Normalizes disk JSON; deletes file on HTTP 2xx; ingests economy via `GameplaySessionReceiptCoordinator` |
| 5 | Swift `NexusEconomyAuthority` | Shards / ranked PRQ mutate **only** on `server_verified` receipts (fail-closed) |

**Overrides:** `FEL_API_BASE_URL`, `FEL_SESSION_RECEIPT_URL`, `FEL_LOCAL_API` (DEBUG default `http://127.0.0.1:8000`).

**Auth (Phase 7 — Firebase optional):** Receipt POST accepts any of:

| Priority | Credential | Header | Notes |
|----------|------------|--------|-------|
| 1 | `FEL_BACKEND_AUTH_TOKEN` or `FEL_SESSION_TOKEN` (env) or UserDefaults `fel_backend_auth_token` | `Authorization: Bearer <session_token>` | From `POST /api/auth/session` or manual dev token — **no Firebase required** |
| 2 | Firebase ID token (anonymous sign-in OK) | `Authorization: Bearer <firebase_jwt>` | When real plist configured |
| — | Keychain anonymous device id (always) | `X-FEL-Device-Id` + `telemetry.device_id` | Queue identity when Firebase offline; not a substitute for Bearer in production |

**PREVIEW lane** (`FirebaseBootstrap.isPreviewMode`, placeholder plist): **no POST** — honest local queue only.

**Live lane without auth token:** receipts accumulate; Dashboard shows `LIVE · AWAITING AUTH TOKEN`.

**AI Studio era metadata:** when `NEXUS_AGENT_GEMINI_KEY` / `GEMINI_API_KEY` / `AI_STUDIO_API_KEY` is set, client adds `telemetry.ai_provider: "ai_studio"` on normalized receipts.

Legacy web clients may also use cookie `session_token` (HttpOnly, set by `POST /api/auth/session`).

### PREVIEW · placeholder plist lane (`--preview-firebase`)

Internal TestFlight archives may ship with placeholder `GoogleService-Info.plist` (`FEL_FIREBASE_PREVIEW=1`). Runtime behavior:

| Signal | Meaning |
|--------|---------|
| `FirebaseBootstrap.isPreviewMode` | Firebase SDK not configured — Auth/Firestore offline |
| `NexusBackendClient.canPostSessionReceipts == false` | No session receipt POST attempted |
| `~/.fel/pending_receipts/*.json` | **Offline-first queue** — receipts accumulate until auth token + backend URL |

**Offline-first workaround (approved for V-003 / V-012 partial close):**

1. **Queue always writes** — C++ flush + disk persist never blocked by Firebase state.
2. **Drain on foreground** — `ContentView.onAppear` / `scenePhase == .active` calls `uploadPendingReceipts()`; PREVIEW lane logs count and returns without error toast.
3. **Upgrade path** — Set `FEL_BACKEND_AUTH_TOKEN` or install build with real plist → same queue drains on next launch (no migration).
4. **Status UI** — Dashboard **SESSION RECEIPTS** card shows pending count + lane label (`PREVIEW · LOCAL QUEUE ONLY`, `LIVE · AWAITING AUTH TOKEN`, `LIVE · BACKEND AUTH`, or `LIVE · FIREBASE AUTH`).
5. **Economy honesty** — PREVIEW builds never grant ranked shards/PRQ from local finalize; only HTTP 2xx ingests `server_verified`.

**Local dev without Firebase:** `export FEL_BACKEND_AUTH_TOKEN=sess_dev` (or Phase 1 unauthenticated dev-athlete) + `FEL_LOCAL_API=http://127.0.0.1:8000` + backend on `:8000`.

**Local dev with emulators:** Real or emulator plist + `FEL_USE_FIREBASE_EMULATORS=1` + Phase 1 backend on `:8000` enables Firebase Bearer POST loop.

**Production close (V-012 remaining):** Deployed `POST /api/games/session` returning 2xx with `FEL_BACKEND_AUTH_TOKEN` or Firebase Bearer; verify file removed from pending queue and PRQ/shards update in Vault.

### Production lane — when real `GoogleService-Info.plist` lands

Use this checklist after replacing the placeholder plist (see `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt` **MIGRATION** section). No queue migration is required — the same `~/.fel/pending_receipts/*.json` files drain automatically.

| Step | Action | Pass signal |
|------|--------|-------------|
| 1 | Drop real plist at `FinalEvolutionLab/GoogleService-Info.plist` (bundle ID `com.finalevolutionlab.app`) | `FirebaseBootstrap.isPreviewMode == false` |
| 2 | Archive **without** `--preview-firebase`: `./scripts/archive-ios-testflight.sh --export` | Crashlytics upload runs; no PREVIEW banner |
| 3 | Launch app → anonymous auth succeeds | `FirebaseIdentity.userId != nil` |
| 4 | Complete one NEXUS arena session | New JSON in `~/.fel/pending_receipts/` |
| 5 | Foreground drain (automatic) or Dashboard **DRAIN PENDING RECEIPTS** | `SessionReceiptUploadService.lastDrainSummary.succeeded >= 1` |
| 6 | Verify disk queue | Pending JSON file **deleted** on HTTP 2xx |
| 7 | Verify economy honesty | Vault PRQ/shards update via `server_verified` ingest only |

**Backend (Phase 1 Postgres):**

```bash
docker compose up -d postgres redis
cd backend && alembic upgrade head && uvicorn app.main:app --reload --port 8000
```

**Device overrides (DEBUG):** `FEL_LOCAL_API=http://127.0.0.1:8000` or `FEL_API_BASE_URL` + `FEL_SESSION_RECEIPT_URL`.

**Error surfaces (iOS):**

| Outcome | User sees | Receipt on disk |
|---------|-----------|-----------------|
| `previewQueuedLocally` | Dashboard lane label `PREVIEW · LOCAL QUEUE ONLY` | Yes — intentional |
| `authUnavailable` | Toast: backend auth required | Yes — retry after `FEL_BACKEND_AUTH_TOKEN` or Firebase sign-in |
| `serverError(422, detail)` | Toast with HTTP code + FastAPI `detail` | Yes — fix payload or retry |
| `networkError` | Toast with underlying error | Yes |
| `success` | Toast: uploaded N receipt(s) | No — file deleted |

**Client normalization:** `SessionReceiptUploadService.normalizedReceiptBody` maps NEXUS disk JSON (telemetry envelope) to `SessionReceiptIn` before POST. Adds `telemetry.device_id` (Keychain) and optional `telemetry.ai_provider: "ai_studio"`. Required fields: `mode_id`, `score`, `outcome`, `duration_seconds`, `completed`, `combo_count`, `critical_count`, `pacing_score`, `mri_score`, `arv`, `esi`, `telemetry`.

**Anti-cheat (server):** `app/services/anticheat_validator.py` rejects impossible receipts (`score_out_of_bounds`, `instant_scoring_session`, etc.) with HTTP 422 — client surfaces `detail` verbatim.


| Method | Path | Purpose |
|--------|------|---------|
| `POST` | `/api/payments/iap/verify` | **StoreKit (fail-closed).** Body: `signed_transaction_jws` and/or `receipt_data`. Records pending transaction; does **not** grant entitlements until server fulfillment is wired. |
| `GET` | `/api/payments/history` | User payment / order history. |
| `POST` | `/api/payments/create-order` | PayPal — **web / non-digital only.** Blocked for iOS digital goods (`item_type` card/course). |
| `POST` | `/api/payments/capture` | PayPal capture after approval. |
| `GET` | `/api/streaks` | Streak state. |
| `POST` | `/api/streaks/checkin` | Daily check-in. |
| `GET` | `/api/streaks/rewards` | Milestone rewards for current streak. |
| `GET` | `/api/leaderboard` | Public leaderboard slice. |
| `GET` | `/api/stats/overview` | Aggregated user stats. |

**Phase 1 wallet (`app/main.py`):** `GET /api/economy/wallet` — Postgres-backed wallet (when cut over from Mongo monolith).

## Mobile bootstrap

| Method | Path | Purpose |
|--------|------|---------|
| `GET` | `/api/mobile/config` | Public-safe hints (deep link scheme, optional WS hub URL, permission notes). NEXUS clients should prefer compile-time config in the canonical repo; this route remains for remote toggles. |

## WebSockets (optional / legacy hub)

| Path | Purpose |
|------|---------|
| `WS /ws/game/{room_id}` | Multiplayer room sync (`server.py`). |
| `WS /ws/vault` | Vault bridge (UE legacy — NEXUS clients may ignore). |
| `WS /ws/hud` | HUD relay (legacy overlay). |

## Deprecated for NEXUS retail (UE / vault host)

Do not wire new NEXUS features to these; they exist for archived Unreal shell integration:

- `POST /api/hub/connect`, `POST /api/vault/connect`, `POST /api/hub/launch-mode`, `POST /api/vault/launch-mode`
- `GET /api/hub/status`, `GET /api/vault/status`
- `GET /api/streaming/*`, `POST /api/streaming/*`
- `GET /api/modes/mapped` (UE deep-link registry)

## Client headers

- `User-Agent` containing `fel-ios` or header `X-FEL-Client: ios` — enables iOS-specific commerce guards.
- NEXUS builds in the canonical repo should use the same session cookie / Bearer contract until JWT cutover in `app/auth/`.

## Local dev

```bash
# Legacy monolith (Mongo) — current Docker default
cd backend && uvicorn server:app --reload --port 8888

# Phase 1 Postgres app
docker compose up -d postgres redis
cd backend && alembic upgrade head && uvicorn app.main:app --reload --port 8000
```

See `backend/README.md` for migration and test commands.
