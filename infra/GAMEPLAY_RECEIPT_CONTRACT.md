# Gameplay receipt authority (iOS / UE / Emergent)

Defines how **Swift fallback sessions**, **UE bridge payloads**, and future **server-signed receipts** interact with **ranked PRQ**, **shard ledger**, and **local history**. Implementations live in `GameSessionTrustLevel`, `GameSessionResult`, `GameplaySessionReceiptCoordinator`, `LabViewModel.ingestVerifiedGameplayReceipt`, and `GamePlayView.finalizeResults`.

## Trust levels (`GameSessionTrustLevel`)

| Level | Meaning | Typical source |
|-------|---------|----------------|
| **`localPractice`** | Native Swift mini-game shell — practice UX. | `GamePlayView` finalize |
| **`sessionBound`** | UE/Emergent JSON over an authenticated channel **without** a cryptographic server receipt. History allowed; **no ranked PRQ / ranked economy** in Release. | Default when bridge omits `fel_trust_level` |
| **`serverVerified`** | Explicit backend trust — payload must set `fel_trust_level` / `trust_level` to `server_verified` (until JWS/signature is wired). | Future signed completions |

## Stable receipt IDs (deduplication)

- **Swift fallback:** `local:<UUID>` where UUID is the in-memory `matchSessionId` for that run. `finalizeResults` is already guarded from double execution per session.
- **UE / Emergent:** `ue:<session_id>` from `session_id`, `ue_session_id`, `emergent_session_id`, `game_session_id`, or `fel_session_id`. Optional explicit `fel_receipt_id` wins.
- **Fallback** when no session id is present: `ue:nosession:<deterministic_hash>` from mode + scores + duration (weak dedup).

Ingestion checks **`gameResults`** for an existing **`id`** and **drops** repeat processing so ranked profile state cannot be replay-inflated.

## Ranked PRQ and economy (Release)

| Trust | Apply `prqBonus` to `profile.metrics.prqScore` | Shards |
|-------|-----------------------------------------------|--------|
| `localPractice` | **No** (Swift gains are **DEBUG-only** in `GamePlayView`) | Pending ledger path unchanged |
| `sessionBound` | **No** | Not credited from ingest unless policy adds pending-only UX |
| `serverVerified` | **Yes** | Added to **`pendingUnverifiedShardCredits`** from ingest / offline persist |

## Swift practice (`GamePlayView.finalizeResults`)

- **`#if DEBUG`:** applies PRQ + neural adjustments from the mini-game (developer iteration).
- **Release:** does **not** move ranked PRQ or neural from fallback play.
- Persisted **`GameSessionResult`** always uses **`trustLevel: localPractice`** and id **`local:<matchSessionId>`**.

## UE / Emergent (`applyVerifiedPayload` → `ingestVerifiedGameplayReceipt`)

- Duplicate **`stableReceiptId`** → early return (no duplicate history rows via profile replay).
- **`sessionBound`** (default): append **`GameSessionResult`** for UX/history; **do not** mutate competitive PRQ or ingest shards into profile.
- **`serverVerified`**: apply PRQ, neural bump, pending shard credits as implemented in Swift.

## Offline coordinator (`persistReceiptWithoutViewModel`)

When **`LabViewModel`** is not attached, the same rules apply: **`serverVerified`** only for profile mutations; dedup by stable id before save.

## Future work

Replace string trust flags with **signed payloads** (nonce, UE session id, server signature) and treat **`serverVerified`** only when cryptography validates.
