# FEL Launch-Readiness Audit — dunk slice vs the paid-launch bar
2026-07-15. This is an AUDIT, not a make-ready pass. Scope = smallest sellable
slice (the Dunk core loop); all other modes out of scope. Two builds exist:
the PRIMARY Babylon line (repo, /play/dunk) and the Abacus R3F app (deployed
demo + money rails). Ratings: READY / GAP / BLOCKER.

## 1. PRODUCT BAR (worth money)

| Check | Rating | Truth |
|---|---|---|
| Dunk feel gate passed | **BLOCKER** | Not passed — the feel systems (fixed-timestep core, input buffer, variable gravity, hybrid blend, sensory bus) are NOT YET BUILT on the primary line. The current /play/dunk is a playable demo, not a proven-fun loop. Nothing ships on an unproven loop. |
| Zero recurring-class bugs | **BLOCKER** | The live Abacus build currently EXHIBITS all four recurring classes (T-posed NPCs, missing rim/floor, dead keyboard, AI-attacks-before-ready) — M7-QA1 is assigned but not delivered. The M7-QA1 invariants exist as a fix list, NOT as standing regression tests anywhere. The repo Babylon slice has zero smoke tests. |
| Reliable load / no data loss / clear offer | GAP | Abacus app: auth + DB persistence ✓, but scenes fail integrity. Repo slice: no persistence at all, loads reliably. Neither states clearly what a paying user gets. |

## 2. LEGAL / COMPLIANCE BAR (allowed to take money)
All items below are HUMAN/LAWYER gates — this audit flags, it does not
conclude law.

| Check | Rating | Truth |
|---|---|---|
| Asset licensing | **BLOCKER** | No license record exists for ANY Meshy-derived asset (13 environment FBX, court/map GLBs, venue renders) — NEXUS_ASSET_MANIFEST.md has no tier/license entries. Meshy Free tier = CC BY = not shippable in a paid product. Seele-pipeline animation rights also unverified. Owned-and-safe: the two Venice skybox photos. Action: Elijah confirms Meshy account tier + collects license receipts, one pass covers all. |
| Terms of Service + Privacy Policy | **BLOCKER** | None found in either codebase (searched both). Required before ANY payment or personal-data collection. |
| EU AI Act disclosure (Aug 2 2026) | GAP | User-facing AI surfaces found: Coach chat (abacus-app /api/coach/chat) and Studio-generated builds/plan text. No disclosure copy found. PRQ v1 (manual entry, no inference) is clean by design. |
| Health/PRQ/body data privacy | GAP | Task 3 will collect fitness metrics (vertical, balance…) = personal (potentially health-adjacent) data → the Privacy Policy must cover collection, retention, deletion; add account-level data-delete path. Biometric mirror (main site) same bucket. |
| Real-money IRL dunking | READY (as a gate) | Confirmed NOT live: REAL_MONEY_COMPETITION off, endpoints 403, standing in-code legal-review gate intact. Keep it that way until the skill-gaming legal review completes. |

## 3. PAYMENTS / OPS BAR (can actually run it)

| Check | Rating | Truth |
|---|---|---|
| Server-authoritative wallet/entitlements | READY (Abacus app) / N-A (repo v1) | Abacus M1 ledger audited: double-entry, idempotent, escrow, client cannot spoof — in TEST MODE. Repo Babylon line has no economy wired (Card economy is queued Task 2 and is SOFT currency — v1 takes no money by design). |
| Payment processor | GAP | Stripe integration built (checkout/portal/payout/webhooks) in test mode. Live = Elijah creates the Stripe account + keys. Refund endpoint exists (M2 claim — re-verify at flip time). |
| Support/contact path | GAP | None found — need at minimum a support email + link in-app before charging anyone. |

## 4. VERDICT

**Primary Babylon line: PRE-ALPHA.** Feel gate unproven, zero tests, no economy.
**Abacus R3F app: ALPHA.** Deployed, authed, money rails test-mode-ready — but
gameplay currently fails its own QA bar (M7-QA1 open).

### The honest shape of "first paid slice"
Per the working context, v1 ships SOFT currency — so the first real revenue
event is flipping the Pro subscription (Track A) on the Abacus app LATER.
That flip needs: M7-QA1 green + feel-gate-passed gameplay + ToS/Privacy +
license receipts + Stripe live keys + support path. Everything else on the
punch list serves that moment.

### Ordered punch list
**BLOCKERS (must, in order):**
1. Dunk feel gate — build the 6 feel systems on the repo Babylon slice
   (fixed-timestep → buffer/FSM → gravity curve → hybrid blend → sensory
   bus → camera), then the 10-dunks-wants-an-11th test. (Engineering, repo)
2. M7-QA1 delivered AND its invariants promoted into a STANDING smoke suite
   that runs on every build. (Abacus)
3. Asset license audit: Meshy tier receipts + Seele anim rights, recorded
   per-asset in the ledger. (Elijah — human)
4. ToS + Privacy Policy (covering PRQ/fitness data + AI disclosure). (Elijah
   + lawyer; template drafting can be assisted)
**GAPS (should):**
5. Support/contact path in both apps.
6. EU AI Act disclosure copy on Coach chat + Studio outputs.
7. Repo slice smoke tests — PARTIALLY CLOSED 2026-07-15: standing jest
   suite for the feel systems (frame-rate independence, buffer semantics,
   arc continuity, gravity boundaries — 9 tests) at
   frontend/src/game/__tests__/feelSystems.test.js. Still open: scene
   integrity + anim invariants (mirror of QA1).
8. Data-deletion path for PRQ entries.
**LATER (polish):** audio set beyond one impact SFX, visual polish, more
modes — all firewalled behind the feel gate anyway.

### Business decisions Elijah owns (not code)
Pricing (Pro tier $), Stripe account + live keys, Meshy license tier
purchase, lawyer review (ToS/Privacy/EU-AI-Act/skill-gaming), launch timing.
