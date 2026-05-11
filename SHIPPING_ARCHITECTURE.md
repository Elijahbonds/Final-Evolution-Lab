# Shipping architecture lock

**Canonical source of truth** for what ships to production in this monorepo. Read **`SHIPPING_ARCHITECTURE.md`** (this file) before changing app shells, overlay URLs, native bridges, Data Connect wiring, or commerce paths. It **supersedes** conflicting claims in older READMEs, one-off agent notes, or wiki-style docs unless those docs explicitly defer here.

This repo contains multiple shells and integrations. **Follow this lock when changing runtime wiring.**

## Production shipping target (single path)

- **Game host:** Unreal Engine (primary binary).
- **In-game OS / dashboard:** WKWebView overlay loading the approved web dashboard URL (`FELOverlay.DashboardUrl` in game config).
- **Native iOS:** The SwiftUI app under `FinalEvolutionLab/` is a **reference / lab shell** for HealthKit, Firebase, Data Connect, and iteration unless a release explicitly targets it.

Do **not** treat legacy XCFramework-only flows, standalone Swift-first navigation, or old deep-link-only commerce as the default shipping path without an explicit product decision.

**Branching:** Canonical integration branch per `infra/SHIPPING.md` — prefer **cherry-pick** over merging unrelated experiment branches. Agents (Cursor / Windsurf) should read this file before changing app shell, overlay, or commerce paths.

**Doc consistency:** `superapp-reference/IOS_UNREAL_PIPE.md` describes packaging scripts and UE Xcode outputs; **shipping UX** is Unreal host + WKWebView overlay (not Swift-first). Conflicting older wiki pages should be treated as **legacy**.

## Commerce

- **Digital goods on App Store builds:** Apple **In-App Purchase (StoreKit)** — **`/api/payments/iap/verify`** uses **`storekit_catalog`** for recognition, records **`iap_pending_transactions`**, and is **fail-closed** (no entitlements) until **App Store Server API** or **verified** StoreKit 2 JWS fulfillment is wired server-side.
- **PayPal:** Physical / coaching / web flows — **not** for bypassing IAP for digital items inside the distributed iOS app.

## Truth boundaries

Server-side catalog prices, verified sessions, and user-bound orders are authoritative. Clients suggest UX only; they do not set amounts or ownership without server verification.
