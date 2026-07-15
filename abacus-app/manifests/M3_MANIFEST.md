# FEL × NEXUS — Milestone M3 (Track C): NEXUS Studio Creator Monetization

**Status:** code-complete, tests green, build green, checkpoint saved. **Not deployed.** Entire
surface is **flag-gated OFF** (`STUDIO_CREATOR_ENABLED`) so it ships dark until you flip it.

**Export:** `fel-nexus-M3-studio.zip`

---

## What shipped

A monetization layer that sits **on top of** the existing Phase-2 CELL cost engine
(`CellUsage` rows already record per-build token/$ spend). It adds tier resolution, a
monthly build quota, an included build budget, prepaid overage credits, cartridge
publishing, and a metered partner API — without touching real-money ledger invariants.

### 1. Feature flags (`lib/flags.ts`)
- `isStudioCreatorEnabled()` — env `STUDIO_CREATOR_ENABLED` (ON only for `1/true/on/yes`). Every M3 route checks this and returns `FEATURE_DISABLED` (403) when off.
- `isRealMoneyCompetitionEnabled()` — declared now, wired in M4. Default OFF.

### 2. Plan config — one visible module (`lib/studio-plan.ts`)
Every tuned number is here and marked `// TUNE(elijah)`:
- **FREE**: 3 builds/mo, no metered budget, no overage (platform-funded trial).
- **CREATOR**: 100 builds/mo, $10.00 included metered build spend, overage via prepaid credits.
- **BYO**: brings own provider keys → builds route to their provider, platform does not meter cost; 1000/mo abuse ceiling only.
- Credit packs: `$5→500cr`, `$20→2200cr (+10%)`, `$50→5750cr (+15%)` (1 credit = 1 US cent).
- Partner unit costs: `build:read`=1, `build:create`=10, `catalog:read`=1. Key prefix `nxk_live_`.

### 3. STUDIO_CREDIT ledger book (`lib/studio-credits.ts`)
New **isolated virtual currency** on the M1 double-entry ledger (1 credit = 1 US cent):
- `ledgerStudioCreditsGrant` — after a paid credit-pack purchase (idempotent).
- `ledgerStudioOverageSpend` — draws credits for build overage; `enforceNonNegative` so a build can **never** overdraw prepaid balance.
- Real USD revenue for a pack is recognized **separately** as USD_CENTS at purchase (in the Stripe webhook), so real-money invariants stay clean. Confirmed: `ledger-invariants.ts` still reports `globalSum=0`.

### 4. Metering & entitlement service (`lib/studio-service.ts`)
- `resolveStudioTier` — precedence **BYO > CREATOR > FREE**.
- `getStudioUsage` — distinct build count + summed metered $ for the billing month.
- `checkBuildAllowed` — read-only pre-build gate (never charges). Returns tier/plan/usage/creditBalance + a typed reason.
- `settleBuildOverage` — post-build, draws credits only for the portion **above** the included budget; idempotent per `buildId`.
- `validateCartridgeManifest` — name/semver/entry-in-files/≥1-file validation.

### 5. Partner API keys (`lib/partner-keys.ts`)
- Store **only** sha256(rawKey); raw shown exactly once. Bearer auth, scope parsing, monthly unit rollup, best-effort usage recording.

### 6. Routes
- `GET  /api/studio/entitlement` — tier/plan/usage/credit balance/build-gate.
- `GET/POST /api/studio/credits` — balance + packs + history; POST starts a Stripe checkout for a credit pack.
- `GET/POST /api/studio/cartridges` — list public cartridges / publish a cartridge (Creator+ only; validates manifest).
- `GET/POST/DELETE /api/studio/partner-keys` — issue (raw shown once), list (masked + units this month), revoke.
- `GET  /api/partner/v1/catalog` — public partner endpoint; Bearer partner-key auth, scope + monthly-quota enforcement (429 + `X-Quota-*` headers), metered.
- Wired into existing routes: `stripe/checkout` (+`STUDIO_CREDITS` product), `stripe/webhook` (grant on purchase), `cell/compile` (flag-gated pre-build gate + post-build overage settle).

### 7. Schema (all additive — `prisma db push` clean, no data loss)
- `LedgerCurrency` enum + TS union: added `STUDIO_CREDIT`.
- `MarketplaceListing`: added `listingType` (default `COSMETIC`), `version`, `manifest`, `sourceProjectId`, index `[listingType, active]`.
- New models `StudioPartnerKey`, `PartnerUsage`; `User.partnerKeys` relation.

---

## Tests & evidence

`yarn tsx scripts/m3-tests.ts` → **11 passed, 0 failed**:
- T1/T2 cartridge manifest accept + reject (semver, missing entry, empty files, entry-not-in-files, missing name).
- T3 partner key crypto (prefix, deterministic sha256, hint masking, bearer parse, unit table).
- T4 partner key storage contract (hash stored, lookup by keyHash, raw never persisted).
- T5 STUDIO_CREDIT grant → balance + idempotent replay.
- T6 overage spend draws + rejects overdraw (`NEGATIVE_BALANCE`).
- T7 tier precedence FREE/CREATOR/BYO.
- T8 usage aggregation (distinct builds + summed cents).
- T9 build-gate transitions (**caught a real bug**: FREE first build was being blocked by the `$0` included budget; fixed so build-count quota is the sole limiter for no-budget tiers).
- T10 overage settlement bills only above the included budget; idempotent per build.
- T11 partner usage rolls up units per billing month.

Regression checks: `ledger-invariants.ts` OK (`globalSum=0`, 65 txns balanced, 56 accounts non-negative); `m2-tests.ts` 9/9; `tsc --noEmit` exit 0; production build exit 0.

**Known pre-existing failure (NOT a regression, out of M3 scope):** `ledger-tests.ts` → "balanced transaction … wallet + external must net to zero" fails because it reads the *global* shared `EXTERNAL:LC` account, which is legitimately large-negative on the shared dev DB (real LC issued to 55 users). It assumes an empty/isolated ledger. The authoritative integrity script (`ledger-invariants.ts`) passes. My STUDIO_CREDIT work only touches an isolated book and cannot affect `EXTERNAL:LC`.

---

## What's next
- **M4 Track B (gated):** real-money competition behind `REAL_MONEY_COMPETITION` (default OFF, you own the flag): escrow lifecycle, 18+/geo/KYC stub, async score-duels, IRL ghost-duel, free Mirror Triumph.
- **M5 Game parity:** port batch-2 gameplay logic (miss gating, combo/PRQ, input contract) into the R3F hero modes + headless smoke.
- **M6 Studio to spec (needs LLM credits):** Phase 2 live demo → Phase 3 self-verifying builds; compliance denylist in provider router.

## Open questions
1. **Pricing/quota** in `studio-plan.ts` are my `TUNE(elijah)` defaults — confirm the FREE allowance (3/mo), CREATOR included budget ($10/mo), and credit-pack bonuses.
2. **BYO = unmetered** is intentional (they pay their own provider). OK, or do you want a nominal platform fee even for BYO?
3. **Cartridge publishing** currently requires Creator+; should FREE be able to publish (just not build much), or stay gated?
4. Ready to keep M3 dark and move to **M4**, or hold?
