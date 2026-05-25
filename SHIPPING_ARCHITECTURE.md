# Shipping architecture lock

**Canonical source of truth** for what ships to production in this monorepo. Read **`SHIPPING_ARCHITECTURE.md`** (this file) before changing app shells, overlay URLs, native bridges, Data Connect wiring, or commerce paths. It **supersedes** conflicting claims in older READMEs, one-off agent notes, or wiki-style docs unless those docs explicitly defer here.

This repo contains multiple shells and integrations. **Follow this lock when changing runtime wiring.**

## Production shipping target & Hybrid UI Architecture

We adopt a **hybrid UI design and runtime architecture** to decouple high-fidelity physics simulations from standard user administration interfaces:

- **Core Simulation Engine (Canonical Host):** Unreal Engine 5.7 (`~/Developer/FinalEvolutionLab57/FinalEvolutionLab.uproject`) serves as the authoritative engine for physics, biotensegrity joint simulations, and direct low-latency hardware integration.
- **Decoupled UI Layer:** A decoupled frontend shell (React-based HUD plugin or unified cross-platform Flutter/web frame) manages non-performance-critical flows: user profiles, streaks, coaching chat logs, and secondary HUD telemetry overlays.
- **Low-Latency Telemetry Bridge:** Unreal Engine utilizes a high-frequency WebSocket and loopback IPC connection to synchronize physics results, joint-angle computations, and biometric events to the UI layer at >90Hz to prevent telemetry lag.
- **Unified Deployment Path:** The decoupled UI and web shell target a single codebase that builds and deploys consistently across macOS Standalone, iOS, and Android, maintaining the **"arcade-technical"** aesthetic (translucent glassmorphism gauges, neon borders, and live console stream panels).
- **Unity 6 & Swift-First Shells:** Deprecated/reference tracks only; not the active shipping hosts.

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
