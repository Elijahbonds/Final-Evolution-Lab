# Shipping architecture lock

**Canonical source of truth** for what ships to production in this monorepo. Read **`SHIPPING_ARCHITECTURE.md`** (this file) before changing app shells, overlay URLs, native bridges, Data Connect wiring, or commerce paths. It **supersedes** conflicting claims in older READMEs, one-off agent notes, or wiki-style docs unless those docs explicitly defer here.

This repo contains multiple shells and integrations. **Follow this lock when changing runtime wiring.**

## Production shipping target (single path)

- **Game host:** Unreal Engine 5.7 project at `~/Developer/FinalEvolutionLab57/FinalEvolutionLab.uproject`.
- **In-game OS / dashboard:** native iOS `WKWebView` overlay inside Unreal.
- **Native iOS:** Swift/SwiftUI code is integration/reference support only unless explicitly wired into the Unreal-host build.
- **Unity 6:** reference/prototype track only; not the production shipping host.

Do not treat Unity export, Swift-first navigation, Unreal-as-a-Library, or XCFramework embedding as the default shipping path.

**Branching:** Canonical integration branch per `infra/SHIPPING.md` — prefer **cherry-pick** over merging unrelated experiment branches. Agents (Cursor / Windsurf) should read this file before changing app shell, overlay, or commerce paths.

**Doc consistency:** `release-reference/IOS_UNREAL_PIPE.md` describes packaging scripts and UE Xcode outputs; **shipping UX** is Unreal host + WKWebView overlay (not Swift-first). Conflicting older wiki pages should be treated as **legacy**.

## Distribution Architecture

- **iOS Consumer Distribution:** Strictly through **Apple App Store Connect / TestFlight**. Alternate third-party stores (AltStore, SideStore), OTA manifest files, or direct public `.ipa` installers/downloads are prohibited.
- **Android Consumer Distribution:** **Google Play Store** (Planned, once Android build target is active).
- **Official Website:** **`finalevolutiongroup.com`** is the landing page and provides official store links, beta access, release notes, and supported non-iOS downloadable installers.

## Commerce

- **Digital goods on App Store builds:** Apple **In-App Purchase (StoreKit)** — **`/api/payments/iap/verify`** uses **`storekit_catalog`** for recognition, records **`iap_pending_transactions`**, and is **fail-closed** (no entitlements) until **App Store Server API** or **verified** StoreKit 2 JWS fulfillment is wired server-side.
- **PayPal:** Physical / coaching / web flows — **not** for bypassing IAP for digital items inside the distributed iOS app.

## Truth boundaries

Server-side catalog prices, verified sessions, and user-bound orders are authoritative. Clients suggest UX only; they do not set amounts or ownership without server verification.
