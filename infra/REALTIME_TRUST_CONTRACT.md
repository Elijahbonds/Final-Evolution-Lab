# Realtime bridge trust contract (`/ws/vault`)

This document defines how the FastAPI **Vault WebSocket** treats identity, progression, and analytics. Agents (Cursor / Windsurf) should read this before changing `backend/server.py` websocket handlers.

## Authenticated socket by default

Outside **dev / local / test** environments, connections **must** present a valid **`session_token`** (query `?session_token=` or cookie set by the web session).

| Mechanism | Behavior |
|-----------|----------|
| **`FEL_ENV` / `ENVIRONMENT` / `NODE_ENV`** | Empty, `development`, `dev`, `local`, `localhost`, `test`, `testing`, `ci` → anonymous UE bridges allowed (local iteration). |
| **Unset `FEL_ENV`** | Treated like local dev (anonymous OK). **Production deployments must set `FEL_ENV=production` (or `staging`).** |
| **`FEL_VAULT_WS_REQUIRE_AUTH=1`** | Force auth on (even in dev). |
| **`FEL_VAULT_WS_REQUIRE_AUTH=0`** or **`FEL_VAULT_WS_ALLOW_ANON=1`** | Allow anonymous sockets (emergency UE testing only). |
| **Any other labeled env** (e.g. `staging`, `preview`, `production`) | **Require auth** unless overrides above apply. |

Production progression and economy logic assume **session-bound** sockets.

## Payload `user_id` is never authoritative

Messages may include **`user_id`** for debugging or UE bookkeeping. The server **does not** use it as identity for:

- XP, coins, referrals  
- `calculate_prq_live`  
- Vertical jump log (`vertical_jump_log`)  
- Session-bound analytics (`sync_status: pending`)

Resolved identity for those paths is **`bound_user_id`** from the validated `session_token` only.

## Telemetry frames (`telemetry` / `vault_telemetry`)

- **`user_id`** in MongoDB is set **only** when the socket is session-bound; otherwise **`null`**.  
- **`payload_user_id`** retains the client claim for diagnostics — **not** used for account linkage.  
- **`metrics_trust`**: `session_bound` vs `unbound_payload_untrusted`.

## Vertical jump progress

**`vertical_jump_log`** inserts occur **only** when **`vertical_jump_inches > 0`** and **`bound_user_id`** is present. Unbound sockets cannot attribute jumps to a profile.

## Match scores (`match_score`)

Implemented via **`VaultBridge.process_match_event`**:

| `bound_user_id` | XP / coins / referrals | Analytics row |
|-----------------|------------------------|----------------|
| **Present** (WS session or HTTP `User`) | Yes (existing rules) | `sync_status: pending`, vault sync fields |
| **Absent** | **No** (`xp_earned: 0`) | `sync_status: telemetry_only`; venue session row stored with `reward_eligible: false` |

HTTP **`POST /api/session/state`** passes **`user.user_id`** as the third argument so completed sessions remain server-verified without a websocket token.

## Mobile analytics messages (`type: analytics`)

- Bound: **`sync_status: pending`** (pending vault sync pipeline).  
- Unbound: **`sync_status: telemetry_only`** — stored for ops/debug; **not** treated as verified user analytics awaiting sync.

## Testing vs production

- **CI / unit tests**: allow anon if env matches `ci` / `test` list — same as dev.  
- **Staging**: should use real **`session_token`** from the same auth stack as production (`FEL_ENV=staging` → auth required).
