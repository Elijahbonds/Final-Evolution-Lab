# Final Evolution Lab — delivery bar (product standard)

**Purpose.** This document defines what “shipping Final Evolution” means for **each pillar** without shrinking the product vision. The vision stays intact; **acceptance criteria** describe what must be true in code, measurement, and user-facing truth before a pillar is treated as **production-grade** rather than **preview**.

**Philosophy.**

- **Do not compromise the roadmap.** All pillars remain in scope: System Scan, avatar/PRQ, arena/game modes, Creator Cards, coach economy, education, BioFuel, privacy, Unreal host, super-app distribution.
- **Do compromise claims.** Anything not yet meeting this bar must be **labeled accurately** in UI and marketing copy (preview, beta, estimate, demo pipeline, pending verification)—never presented as clinical truth, finished gameplay, or money-good economy until the bar is met.
- **The bar rises until the app catches it.** Each pillar graduates from preview → verified when its acceptance criteria below are satisfied.

**Canonical wiring.** Implementation order and guards follow **`SHIPPING_ARCHITECTURE.md`**, **`infra/SHIPPING.md`**, and the **`infra/*CONTRACT*.md`** files. Run **`./scripts/fel_release_preflight.sh`** before release tagging.

---

## Global acceptance (every build)

| Requirement | Bar |
|-------------|-----|
| Architecture | Unreal host + WKWebView overlay for shipped athlete OS UX unless product explicitly ships Swift-first; see **`SHIPPING_ARCHITECTURE.md`**. |
| Commerce truth | No digital entitlements without server-verified StoreKit path; fail-closed IAP per **`SHIPPING_ARCHITECTURE.md`**. |
| Agent hygiene | Phase cleanup patches applied; contracts present; no drift against **`fel_release_preflight`**. |
| Honest labeling | No surface implies capabilities the implementation does not provide (biomechanics, clinical nutrition, full MMO depth, liquid economy) until the pillar section below is satisfied. |

---

## Pillar: System Scan / PRQ / competitive metrics

**Vision.** Measured athlete assessment feeding trustworthy PRQ and scan-derived coaching where appropriate.

**Production bar**

- Pipeline is **documented and implemented**: capture → inference → confidence → commit rules aligned with **`infra/SYSTEM_SCAN_ACCURACY_CONTRACT.md`**.
- User-visible distinction between **demo / synthetic** and **measured** paths is **always clear** (labels, sources, gates).
- No marketing or in-app copy claims specific pathology detection (e.g. APT, rib flare, knee valgus) from video until validated by the implemented pipeline and safety review.
- Competitive PRQ commits only when **`commitsCompetitiveMetrics`** (or equivalent) rules are satisfied.

**Until the bar:** Frame as **preview scan / readiness profile / demo pipeline**; “measured scan coming” is acceptable; **measured** claims are not.

---

## Pillar: Avatar, readiness, HealthKit-adjacent signals

**Vision.** Athlete identity and readiness integrated with Apple Health where appropriate, without overstating medical meaning.

**Production bar**

- Data flows and permission UX match **`infra/`** privacy/safety posture; minors gated per **`infra/PRIVACY_MINOR_SAFETY_CONTRACT.md`**.
- Copy does not imply diagnosis or medical device behavior.

**Until the bar:** “Readiness-style” and integration **foundation** language is honest.

---

## Pillar: Gameplay / arena / Unreal

**Vision.** Deep, mode-distinct arena experiences with authoritative progression where claimed.

**Production bar**

- Per-mode **playability and reward authority** match **`infra/GAMEPLAY_RECEIPT_CONTRACT.md`** and server/session truth where applicable.
- Unreal-hosted modes: **device-validated** cook/install path documented in **`infra/SHIPPING.md`**; modes claimed as “shipped” are verified on target hardware.
- Modes not yet meeting depth/receipt rules remain **preview modules** in UX—not silently marketed as finished titles.

**Until the bar:** **Arena modules and previews**; mode count can be broad **internally** without implying equal depth for every slot.

---

## Pillar: Unreal integration & super-app shell

**Vision.** Single athlete OS: UE binary + WKWebView dashboard shell.

**Production bar**

- Overlay URL, packaging, and reference docs consistent with **`SHIPPING_ARCHITECTURE.md`** and **`release-reference/`**.
- Local UE build/cook/install executed on Apple Silicon host per **`infra/SHIPPING.md`** before claiming “shipped to device.”

**Until the bar:** **Shipping path prepared** / **integration validated locally**—not “every user has the full UE build in hand” until proven.

---

## Pillar: Economy — shards, Creator Cards, shop, coaching money flows

**Vision.** Server-authoritative balance, ownership, and App Store-safe digital commerce.

**Production bar**

- Spend/claim paths align with **`infra/ECONOMY_AUTHORITY_CONTRACT.md`** and Data Connect rules; StoreKit verification posture per **`SHIPPING_ARCHITECTURE.md`**.
- No treating **local-only** balances or caches as authoritative for money-like outcomes.

**Until the bar:** **Creator/economy prototype with verification gates**; liquid secondary/market claims wait for implementation.

---

## Pillar: Education / Academy

**Vision.** Substantive tracks, assessment integrity, certificates where promised.

**Production bar**

- Assessment and progression integrity per **`infra/EDUCATION_INTEGRITY_CONTRACT.md`**.
- Content depth sufficient that “Academy” labeling is defensible for shipped tracks (expand until true—or narrow shipped scope).

**Until the bar:** **Tracks + assessment engine**; avoid implying **complete curriculum** until content meets depth targets.

---

## Pillar: BioFuel / nutrition

**Vision.** Performance-oriented logging and coaching tone without clinical overreach.

**Production bar**

- Bounds, hydration, allergy posture, and logging honesty per **`infra/BIOFUEL_NUTRITION_SAFETY_CONTRACT.md`**.
- Scan/meal estimates labeled as estimates; defaults (e.g. weight) visible or configurable where they drive targets.

**Until the bar:** **Performance nutrition assistant**, not dietitian or medical nutrition therapy.

---

## Pillar: Privacy / minors / public surfaces

**Vision.** Fail-private defaults; discovery and passes safe by design.

**Production bar**

- Behavior matches **`infra/PRIVACY_MINOR_SAFETY_CONTRACT.md`**; opt-ins explicit; minors protected on discovery and pass sharing.

---

## Pillar: Realtime / social / vault bridge

**Vision.** Trusted progression and identity on realtime paths.

**Production bar**

- **`infra/REALTIME_TRUST_CONTRACT.md`** enforced in **production** env (`FEL_ENV` / auth defaults); no client-supplied identity for rewards.

---

## Naming releases (optional but honest)

Internal or TestFlight channels may use **Final Evolution Lab Preview** / **Athlete OS Beta** until **most** customer-critical pillars hit production bar for that channel. Rename when the bar is met—don’t shrink the product to match a weak build.

---

## Revision

When a pillar graduates, update this section and the corresponding contract; keep **`DELIVERY_BAR_FINAL_EVOLUTION.md`** the single **product** complement to **`SHIPPING_ARCHITECTURE.md`** (engineering lock).
