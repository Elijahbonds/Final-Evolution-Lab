# NEXUS Monetization Track — Road to First Dollar (2026-07-15)

**Goal:** when Abacus finishes this track, FEL is a product that takes money the
same day: subscriptions + creator marketplace live immediately, head-to-head and
IRL-dunk-for-money fully built and waiting behind the legal gate.

Read with `NEXUS_COST_DOCTRINE.md` (spend rules) and `NEXUS_HANDOFF_FOR_ABACUS.md`
(branch/gate rules). This doc UPDATES the old "real money stays out" rule:
**real money now enters through Track A (standard commerce, ship it) and Track B
(competition money, build complete but feature-flagged until legal sign-off).**
The in-code gate stays: `// COMPLIANCE TODO: real-money IRL Dunking mode is
legal-review-gated — DO NOT ship live without sign-off` (DunkingMode.js).

## What already exists — DO NOT rebuild
- `backend/app/models/marketplace.py`: Listing / Order / Purchase
- `backend/app/models/payout.py`: PayoutAccount / PayoutSettlement (accrual)
- `backend/app/routers/economy.py`: `/wallet`, `/ledger`, `/payouts/account`,
  `/payouts/settle` — provider stubbed
- `backend/app/config.py`: split math (store fee 30%/15%, then 70/30
  creator/platform)
- `frontend/src/App.js`: PayPalScriptProvider + PayPalButtons wired
- `backend/app/models/match.py`: Match / MatchEvent
- Copilot donor branch: `engine/net` (NetSession, room codes, matchmaking_client),
  dunk ghost difficulty + combo scoring, MasteryTracker (BKT)
- Deterministic replay pattern (seeded RNG, replay honesty) from Court Carnival
- iOS: IRLDunkView, DunkRecordingTrackerView; web: BiometricMirror (main site)

---

## TRACK A — Revenue live NOW (standard commerce, no gambling analysis needed)

### A1. FEL Pro subscription (first dollar, fastest)
- PayPal Subscriptions plan behind the existing PayPalScriptProvider: monthly +
  annual SKUs. Entitlements table (userId, tier, renewsAt, status) checked by
  gateway middleware.
- Pro gates: full mastery analytics (BKT curves), training plans, ghost library
  slots (>1 saved ghost), ad-free, early mode access, Mirror Triumph history.
- Webhook handler for PayPal subscription lifecycle (activate/suspend/cancel) —
  server-authoritative entitlement, never client-claimed.

### A2. Creator marketplace GA (creators start earning)
- Complete the purchase loop: PayPal order capture → verify server-side →
  `Order`/`Purchase` rows → content unlock. Idempotent capture handler
  (orderId unique), refund endpoint writing compensating ledger entries.
- Creator payouts: unstub the provider seam with **PayPal Payouts** behind
  `PayoutProvider` interface (keep the stub for tests). Accrual ledger stays the
  source of truth; settlement moves accrued balance → PayPal on schedule
  (weekly, min $25) or on-demand.
- Creator onboarding: PayoutAccount + required tax-info fields (W-9 / 1099-K
  data seam — collect now, report later), payout email verification, creator
  agreement checkbox with versioned terms.
- Launch inventory requirement: seed 3 first-party listings (training programs
  authored via nexus-author + G-Eval gate) so the store is never empty.

### A3. One-time purchases
- Cosmetics / boost SKUs through the SAME order pipeline (no parallel code path).
  Wearables system already exists — sell skins for the dunk avatar + court.

### A4. Free-entry tournaments with sponsored prizes
- Weekly dunk-score ladder: free to enter, prizes funded by platform/sponsors
  (promotional contest, not wagering — no entry fee = no gambling analysis).
- Uses Match/MatchEvent + leaderboards; drives DAU that Track B converts later.

---

## TRACK B — Competition money (BUILD COMPLETE, ship behind flag)

**Flag: `REAL_MONEY_COMPETITION` (default OFF). Turning it on requires:
legal review sign-off + payment-processor written approval + state allowlist
configured. No exceptions — this repeats the standing in-code gate.**

### B1. Head-to-head money matches (web H2H + async score-duel)
- Entry-fee escrow flow on the double-entry ledger:
  `wallet → escrow(matchId)` on join; on result: `escrow → winner_wallet` minus
  platform rake (config, default 10%); on dispute/void: full refund entries.
  Every transition is a ledger row — no balance mutation without an entry.
- Server-authoritative results only. For deterministic modes: both clients play
  the same seed, server replays/validates the input log (replay-honesty pattern).
  RNG must NOT influence outcome in money matches — skill-game classification
  depends on it; document this in the match spec.
- Matchmaking: room codes (NetSession) for challenge-a-friend; rating-banded
  queue (reuse Elo/BKT-adjacent rating) for open queue. Async score-duel mode
  (both play the same seeded run within 24h) covers thin liquidity at launch.
- Gates: 18+ attestation + DOB, geo-check (IP + declared state) against
  `skill_game_state_allowlist` in config, KYC provider seam (interface now,
  provider later), deposit/withdraw limits, self-exclusion endpoint.
- Wallet top-up via PayPal is a **deposit** (ledger entry), withdrawals via the
  payout rail — same plumbing as creator payouts.

### B2. IRL Dunk Contest for money — vs ghost
- Recording pipeline: video upload (or in-app capture) + scoring submission →
  human-review queue seam (auto-score later; reviewer UI now) → verified score.
- **Ghost = a verified past run.** Challenge structures:
  - *Mirror Triumph*: beat YOUR verified best (streaks, badges — free feature
    NOW for retention; money-vs-self allowed only under the same B gates).
  - *Ghost duel*: stake an entry fee against another athlete's posted verified
    run (async — no scheduling problem, works day one).
- Anti-fraud minimum: reviewer checks video continuity + rim/court markers;
  submission hash + timestamp; one verified gym/court profile per account.
- iOS note: real-money contest entry CANNOT go through Apple IAP — money flows
  are **web-only** (link out); iOS app shows the contest read-only until policy
  review.

### B-compliance checklist (Abacus builds the scaffolding, Elijah signs off)
1. Skill-vs-chance memo per money mode (deterministic seed evidence attached).
2. State allowlist config + geo-block middleware (start conservative).
3. Processor approval: PayPal prohibits real-money gaming without written
   approval — apply, or add a licensed skill-gaming PSP behind the provider
   interface. Track A revenue is NOT blocked by this.
4. KYC/AML provider integration point + records retention.
5. Terms of service: contest rules, dispute window, void conditions.
6. **Tencent/China-hosted models never touch likeness/biometric video** (cost
   doctrine denylist) — IRL video review runs on approved providers only.

---

## Ledger requirements (both tracks share it)
Double-entry, append-only, idempotency keys on every external event (PayPal
capture id, webhook id), escrow as first-class account type, daily invariant
job: sum(debits)=sum(credits), wallet ≥ 0, escrow matches open matches.
Every money bug is a ledger bug — tests here are not optional.

---

## TRACK C — NEXUS & CELL as products (the tech itself earns)

**Positioning (do not drift from this):** NEXUS Studio does NOT compete as a
general AI app builder — that market is a distribution war (Replit, Lovable,
v0, Abacus itself). It wins as the **creator tool of a vertical closed loop**:
Studio builds cartridges → cartridges sell in the FEL marketplace → marketplace
revenue funds creators → creators need Studio. CELL sells separately as the
adaptive-education engine behind an API. FEL is the proof case for both.

### C1. NEXUS Studio — Creator subscription (the flywheel)
- **Free tier:** limited builds/month, output listable in marketplace at
  standard 70/30 split, "Built with NEXUS" badge.
- **Creator Pro ($19–29/mo):** unlimited standard builds, priority build queue,
  premium runtime library + assets, better split (e.g. 75/25), analytics on
  listing performance. Uses the SAME entitlements + PayPal subscription rails
  as A1 — one billing system, two products.
- **Build metering:** every build logs token cost (Studio Phase 2 cost
  dashboard is the meter). Included quota per tier; overage billed as build
  credits (pass-through LLM cost + margin). **BYO API keys tier:** bring your
  own Anthropic/OpenAI key, pay only the subscription — routing/caching is the
  value, not resold tokens.

### C2. Cartridge economy (Studio output = sellable unit)
- Every Studio build packages as a **cartridge** (nexus_cartridge_runtime is
  the packaging unit) with a manifest: author, version, license, price.
- Sell/license cartridges through the existing marketplace pipeline (same
  Listing/Order/Purchase/accrual models — no parallel money code).
- White-label licensing seam: a gym/trainer/school buys a cartridge bundle
  with their branding — B2B order type on the same ledger.

### C3. CELL-as-a-Service (B2B API, AFTER FEL proves it)
- Externalize the sequencing engine behind `/nexus/v1/*`: partner API keys,
  per-key usage metering + rate limits, sandbox tenant, developer docs.
  Product: "adaptive curriculum in a box" — BKT mastery tracking, lesson
  queueing, budget-metered provider routing — for other fitness/edtech apps.
- Pricing: per-MAU tiers or per-sequencing-call; metered on the same ledger
  (a partner is a wallet with an API key).
- **Gate to launch:** FEL's own numbers are the sales deck (retention lift,
  mastery velocity). Do not sell CELL externally before FEL demonstrates it —
  build the metering/keys scaffolding now, open the tap when the case study
  exists.
- Compliance carries over: partner data never routes to denylisted providers;
  per-partner data isolation; CELL learns per-tenant, never across tenants
  without contract.

### Track C build order
1. Entitlements table gains product dimension (fel_pro | studio_creator) —
   trivial extension of A1.
2. Build metering + quota enforcement in Studio (Phase 2 dashboard feeds it).
3. Cartridge manifest + marketplace listing type "cartridge".
4. Partner API-key + usage-metering scaffolding on the gateway (flag-gated,
   like Track B — off until the FEL case study).

## Definition of MONEY-READY (acceptance for Abacus)
- [ ] A1: a real PayPal sandbox subscription activates Pro and survives webhook
      replay + cancellation.
- [ ] A2: sandbox purchase of a seeded listing unlocks content; creator accrual
      appears; sandbox payout settles and is idempotent on retry.
- [ ] A3: one cosmetic SKU purchasable end-to-end.
- [ ] A4: weekly ladder pays a (virtual) sponsored prize automatically.
- [ ] B1: with flag ON in a test env, full escrow lifecycle (join → play →
      payout / dispute → refund) passes tests; with flag OFF, every money-match
      endpoint returns 403 + the geo/age gates are unreachable.
- [ ] B2: a ghost duel resolves from two verified submissions in review queue.
- [ ] Ledger invariant job green over the whole test suite.
- [ ] All flows behind `/nexus/v1/*` gateway; no client-trusted amounts anywhere.
- [ ] C1: a Studio Creator subscription activates via the same rails as A1 and
      gates the priority build queue; build overage produces a metered charge.
- [ ] C2: a Studio-built cartridge lists and sells through the standard
      marketplace pipeline with creator accrual.
- [ ] C3: partner API key issues, meters usage to a ledger wallet, and is
      rejected when its flag is off.

## Sequence to first dollar
1. A1 Pro subscription (days, not weeks — PayPal already in the bundle).
2. A2 purchase capture + creator accrual visible (store can open with 3 seeded
   listings even before payouts unstub).
3. A2 payout unstub → first creator paid.
4. A4 ladder live → audience for B.
5. B built + flagged → legal/processor work runs in parallel, not blocking.
