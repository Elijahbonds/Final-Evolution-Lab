# Product — one page

**Final Evolution Lab** is positioned as a **single product** with:

1. **Unreal Engine (UE 5.x) native iOS Shipping build** as the **game host** — arena worlds, modes, cooked content in the app bundle (`cookeddata/` and/or `.pak`).
2. **WKWebView overlay** — dashboard / “superapp” web UI hosted inside or beside the native shell (implementation lives in Unreal integration + web assets; dashboard UX often mirrored in `frontend/` for development).
3. **`finalevolution://` deep links** — parsed in-engine (Emergent/deep-link subsystem); URL scheme and plist fragments documented under `UnrealIntegration/Config/`.
4. **Health / commerce surfaces** — **HealthKit** usage can live in the Swift shell (`FinalEvolutionLab/`) while gameplay stays Unreal-first; **StoreKit / IAP** product model is part of the native+iOS story when enabled (verify entitlements and ASC configuration).
5. **Backend (`backend/`)** — REST/WebSocket-style sovereign hub, sessions, and mode metadata; device talks to configured hub URLs (see game ini / deployment).

**Distribution:** consumer delivery through **Apple’s channels** (TestFlight → App Store). Internal references to “Superapp” mean **orchestrating** that delivery (build artifact → ASC → testers/users), not alternate store installers.

**Descriptor safety:** iOS must ship a bundle that includes **staged cooked data**. Empty or pre-stage `.app` copies cause “Failed to open descriptor file” at runtime—mitigated by RunUAT staging, promoting the fully staged `.app`, and repack diagnostics in `fel_ue5_ios_shipping_package.sh`.
