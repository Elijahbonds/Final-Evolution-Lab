# M4 MANIFEST — Track B: Real-money Competition

**Completed:** 2026-07-15  
**Export:** `/home/ubuntu/exports/fel-nexus-M4-competition.zip`  
**Milestone:** M4 Track B — gated real-money competition behind `REAL_MONEY_COMPETITION` flag (default OFF; Elijah owns the flag).

---

## What shipped

### Schema (additive, `db push` clean)
- **`CompetitionMatch`** — full H2H / score-duel / ghost-duel lifecycle: WAITING → ACTIVE → SCORED → SETTLED / DISPUTED / VOIDED / EXPIRED. Tracks entry fee (USD cents), rake %, deterministic RNG seed, per-player scores + submission timestamps, escrow/settle/refund ledger transaction IDs, async expiry deadline, dispute metadata.
- **`MatchEvent`** — append-only event stream per match (CREATED, JOINED, ESCROW_LOCKED, SCORE_SUBMITTED, SETTLED, DISPUTED, VOIDED, REFUNDED, EXPIRED) with seq counter + JSON payload.
- **`MirrorTriumph`** — free-tier beat-your-own-ghost streaks: bestScore, currentStreak, longestStreak, totalBeats per user×mode. `@@unique([userId, mode])`.
- **User model extended** (all additive, defaults compatible): `dobYear Int?`, `kycStatus String @default("NONE")`, `kycProvider String?`, `kycVerifiedAt DateTime?`, `selfExcludedAt DateTime?`, `declaredState String?`.

### lib/competition.ts — pure config & gate logic
- **Configuration constants** (all `// TUNE(elijah)`): `DEFAULT_RAKE_PERCENT` (10%), entry fee bounds ($1–$100), deposit/withdraw bounds ($5–$500), `SCORE_DUEL_EXPIRY_HOURS` (24h), `SKILL_GAME_STATE_ALLOWLIST` (20 US states), `MIN_AGE_YEARS` (18).
- **`checkCompetitionEligibility(user)`** — checks self-exclusion → age (DOB year) → geo (declared state vs allowlist) → KYC status (REJECTED/PENDING block, NONE/VERIFIED pass). Returns `{ allowed, reason?, detail? }`.
- **`validateEntryFee(cents)`** — range + integer check.
- **`generateMatchSeed()`** — `crypto.randomBytes(16).toString('hex')`, 32-char hex for deterministic skill-game replay.
- **Escrow math** — `totalPot()`, `rakeAmount()`, `winnerPayout()` — integer-safe.
- **`appendMatchEvent()`** — auto-incrementing seq, JSON payload.
- **`scoreDuelExpiry()` / `isExpired()`** — async score-duel deadline helpers.

### lib/stripe-helpers.ts — 5 new escrow ledger bridge functions
| Function | Flow | enforceNonNegative | Idempotency key pattern |
|---|---|---|---|
| `ledgerEscrowLock` | USER_WALLET → ESCROW(matchId) | `true` (user must have funds) | `escrow-create:{matchId}:{player}` |
| `ledgerEscrowSettle` | ESCROW → USER_WALLET(winner) + PLATFORM_REVENUE(rake) | `false` | `escrow-settle:{matchId}` |
| `ledgerEscrowRefund` | ESCROW → USER_WALLET | `false` | `escrow-refund:{matchId}:{player}` |
| `ledgerWalletDeposit` | EXTERNAL → USER_WALLET (USD_CENTS) | `false` | `deposit:{paymentRef}` |
| `ledgerWalletWithdraw` | USER_WALLET → EXTERNAL (USD_CENTS) | `true` | `withdraw:{ref}` |

### API routes (all flag-gated, return 403 when OFF)

| Route | Method | Purpose |
|---|---|---|
| `/api/competition/create` | POST | Create match + escrow-lock creator's entry fee |
| `/api/competition/join` | POST | Player 2 joins + escrow-lock their fee; status → ACTIVE |
| `/api/competition/submit-score` | POST | Submit server-authoritative score; both in → SCORED |
| `/api/competition/settle` | POST | Pay winner from escrow, take rake; status → SETTLED |
| `/api/competition/dispute` | POST | Participant disputes; status → DISPUTED |
| `/api/competition/void` | POST | Admin voids match, refunds all escrow → both wallets |
| `/api/competition/config` | GET | Public competition config (limits, allowed states, rake) |
| `/api/competition/eligibility` | GET | Check caller's compliance gates |
| `/api/wallet/balance` | GET | User's USD_CENTS wallet balance from ledger |
| `/api/wallet/deposit` | POST | Record a deposit (after Stripe confirmation) |
| `/api/wallet/withdraw` | POST | Request a withdrawal (ledger entry + stub payout) |
| `/api/mirror-triumph` | GET/POST | **FREE** (no flag gate) — beat-your-own-ghost streaks |

### Compliance gates wired
1. **18+ attestation** — `dobYear` on User; blocked if under 18 or unset.
2. **Geo-check** — `declaredState` against `SKILL_GAME_STATE_ALLOWLIST` (20 states, expand after legal review).
3. **KYC stub** — `kycStatus` field (NONE → PENDING → VERIFIED/REJECTED); provider interface ready, wired later. Currently NONE and VERIFIED pass.
4. **Self-exclusion** — `selfExcludedAt` non-null blocks all money competition.
5. **Deterministic seed** — every money match gets a `crypto.randomBytes` seed for skill-game classification / replay honesty.

### Mirror Triumph (free tier, no flag gate)
- Track personal bests per game mode.
- Beat your ghost → streak increments; fail → streak resets to 0.
- `longestStreak` and `totalBeats` never decrease.
- No money involved — pure retention / engagement feature.

---

## Tests

**m4-tests.ts: 13/13 PASS** (rollback-tx pattern, no persistent data)
- T1: Eligibility accepts eligible user
- T2: Eligibility rejects underage / geo-blocked / self-excluded / KYC-rejected / KYC-pending / no-DOB / no-state
- T3: Entry fee validation (range + integer)
- T4: Full escrow lock → settle lifecycle (2 players, escrow balance, winner payout, platform rake)
- T5: Full escrow lock → void/refund lifecycle (both wallets restored, escrow drained)
- T6: Escrow lock rejects insufficient funds (NEGATIVE_BALANCE)
- T7: Wallet deposit + withdraw lifecycle
- T8: Wallet withdraw rejects overdraw (NEGATIVE_BALANCE)
- T9: Mirror Triumph first play + beat increments streak
- T10: Mirror Triumph failure resets currentStreak (longestStreak preserved)
- T11: Match seed generation (32-char hex, unique)
- T12: Score-duel expiry calculation + isExpired
- T13: Rake + payout math (integer-safe)

**Regression:** ledger-invariants OK (`globalSum=0`, 67 txns); m2-tests 9/9; m3-tests 11/11; tsc 0 errors; build 0 errors (45 routes).

---

## Flag behavior

| Flag | State | Effect |
|---|---|---|
| `REAL_MONEY_COMPETITION` | OFF (default) | All `/api/competition/*` and `/api/wallet/*` return `{ error: 'feature_disabled' }` with 403. Mirror Triumph works regardless. |
| `REAL_MONEY_COMPETITION` | ON | Full escrow lifecycle active. Compliance gates enforced. Elijah owns the toggle. |

---

## What's next: M5 & M6

- **M5 GAME PARITY:** Batch-2 logic ported to R3F modes (miss gating, combo/PRQ, input contract), headless smoke.
- **M6 STUDIO TO SPEC:** Phase 2 live demo → Phase 3 self-verifying; compliance denylist in provider router before non-US providers.

---

## Open questions for Elijah

1. **State allowlist expansion** — current 20 states are conservative. Which additional states should be cleared?
2. **KYC provider** — provider interface is stubbed. Which KYC vendor to integrate first? (Persona, Stripe Identity, Jumio?)
3. **Tie handling** — currently ties must be voided (full refund). Should ties split the pot instead?
4. **Ghost duel video review** — the GHOST_DUEL matchType is wired but the video upload + human review queue UI is M5+ scope. Confirm priority.
5. **Deposit/withdraw integration** — currently records ledger entries. Wire to Stripe Connect for actual money movement?
