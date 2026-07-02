# Shipping architecture lock

**Canonical source of truth** for what ships to production in this monorepo. Read **`SHIPPING_ARCHITECTURE.md`** (this file) before changing app shells, overlay URLs, native bridges, Data Connect wiring, or commerce paths. It **supersedes** conflicting claims in older READMEs, one-off agent notes, or wiki-style docs unless those docs explicitly defer here.

This repo contains multiple shells and integrations. **Follow this lock when changing runtime wiring.**

> **Production decision (2026-06):** Retail ship is **NEXUS only** — custom C++20 engine + Swift iOS app in this repo. See **`NEXUS_ONLY_PIVOT.md`**.

## Production shipping target (NEXUS)

Retail iOS / TestFlight ships **NEXUS** — not Unreal Engine or Unity:

- **Core simulation engine (canonical):** NEXUS C++20 engine (`engine/`, `app/gameplay/`, `runtime/`) — physics, arena modes, session receipts, native bridges.
- **iOS app shell (canonical):** SwiftUI + SceneKit/Metal embed (`FinalEvolutionLab/`, `scripts/build-nexus-ios.sh`, `scripts/archive-ios-testflight.sh`) distributed via **App Store Connect / TestFlight**.
- **Decoupled UI layer:** React/web shells (`sites/`, `web/`) for marketing, dashboard, and non-gameplay flows; Firebase Hosting for static assets.
- **Telemetry bridge:** WebSocket + native bridge (`NexusGameplayBridge`, `fel_bridge_service`) synchronizes gameplay events to UI/backend.
- **Honest preview labeling:** Features not yet meeting **`DELIVERY_BAR_FINAL_EVOLUTION.md`** must be labeled preview/beta in UI and marketing — see **`NEXUS_DELIVERY_MATRIX.md`** for gaps (Metal PBR embed, live Firebase POST, TestFlight artifact).

**Canonical build/run:** `./scripts/nexus_build_gate.sh` · `./scripts/build-nexus-ios.sh` · `./scripts/archive-ios-testflight.sh` — details in **`NEXUS_RESUME.md`** and **`infra/SHIPPING.md`**.

## Legacy / archived (not production)

These paths remain in-repo for reference only — **do not** extend for retail ship:

- **Unreal Engine 5.7:** archived legacy host (`UnrealIntegration/`, `UnrealStarter/`, `fel_ue5_ios_shipping_package.sh`). Superseded by NEXUS.
- **Unity 6:** archived prototype (`Unity6-FinalEvolutionLab/`). Not a shipping host.
- **Legacy FEL/UE monorepo:** `~/Documents/rork-final-evolution-lab` — reference mirror; canonical docs live here.

## Cloud Infrastructure Transition

To maximize runtime efficiency and offload local hardware resources on playtest machines (e.g., Mac mini M4 Pro):
- **Cloud-Native APIs:** Backend services and WebSocket nodes are migrated from local-only loopbacks to containerized **Google Cloud Run** instances.
- **Database Scaling:** The backend pool points to a managed cloud PostgreSQL instance.
- **Static Assets:** The production frontend builds compile to static assets hosted on **Firebase Hosting** (e.g., `https://final-evolution-lab.web.app`), which also hosts packaged mobile APKs and macOS universal zip packages.

## Distribution Architecture

- **iOS Consumer Distribution:** Strictly through **Apple App Store Connect / TestFlight**. Direct `.ipa` installers/downloads are prohibited.
- **Android Consumer Distribution:** **Google Play Store** (via APK sideload for beta, direct release for production).
- **Official Website:** **`finalevolutiongroup.com`** is the landing page and provides official store links, beta access, release notes, and supported non-iOS downloadable installers.

## Commerce

- **Digital goods on App Store builds:** Apple **In-App Purchase (StoreKit)** — **`/api/payments/iap/verify`** uses **`storekit_catalog`** for recognition, records **`iap_pending_transactions`**, and is **fail-closed** (no entitlements) until **App Store Server API** or **verified** StoreKit 2 JWS fulfillment is wired server-side.
- **PayPal:** Physical / coaching / web flows — **not** for bypassing IAP for digital items inside the distributed iOS app.

## Truth boundaries

Server-side catalog prices, verified sessions, and user-bound orders are authoritative. Clients suggest UX only; they do not set amounts or ownership without server verification.
