# Swift + Unreal container — **ARCHIVED / legacy reference**

> **NEXUS-only production ship:** Retail Final Evolution Lab ships as **`FinalEvolutionLab.xcodeproj`** with **NEXUS C++20 engine** (`NexusGameplayBridge`, SceneKit preview, Metal embed path) — **not** an embedded Unreal framework. This document describes the **superseded UE-as-framework** architecture retained for historical reference and optional `NEXUS_LEGACY` Debug builds. Authority: `NEXUS_ONLY_PIVOT.md`, `SHIPPING_ARCHITECTURE.md`. Do not extend for App Store ship.

## Current production architecture (NEXUS)

| Layer | Role |
|--------|------|
| **Swift** | Navigation, HealthKit System Scan, Firestore sync, commerce/education UI, `NexusGameplayBridge` / `NexusGameplayEngine` |
| **NEXUS engine** | Game modes, venue `.nexusmesh.json`, gameplay sims, Metal/SceneKit preview surfaces |
| **Firebase** | Auth, Firestore scan persistence, session receipts (see `infra/FIREBASE_IOS_SDK.md`) |

Build and ship commands: `./scripts/nexus_build_gate.sh`, `./scripts/build-nexus-ios.sh`, `./scripts/archive-ios-testflight.sh`.

---

## Archived — UE framework embed (pre-pivot)

The following applied when UE was the intended iOS gameplay host. **`UnrealManager`**, **`UnrealContainerView`**, and **`UnityManager`** are gated behind `#if NEXUS_LEGACY` and **excluded from Release** builds (see `docs/NEXUS_VISION_ALIGNMENT.md` sprint-vision-regression grep).

### Responsibilities (legacy)

| Layer | Role |
|--------|------|
| **Swift** | Navigation, HealthKit System Scan, Firestore sync, commerce/education UI, optional Vault WebSocket client |
| **Unreal** | Game modes, Metal viewport, avatar visualization; received performance attributes via Firestore listener and/or JSON bridge (runtime / native) |

### Unreal embedding (legacy opt-in)

1. Build or export the UE iOS artifact as a framework named **`UnrealFramework.framework`** (or rename to match).
2. Copy it to:

   `FinalEvolutionLab/EmbeddedFrameworks/UnrealFramework.framework`

3. Build the app with **`NEXUS_LEGACY`** defined. The **Embed Unreal Framework (optional)** run script copies the framework into `FinalEvolutionLab.app/Frameworks` and re-signs it when a signing identity is present.

4. Runtime loading was handled by **`UnrealManager`** (mirrors older `UnityManager` pattern: `getInstance`, `runEmbedded`, `unloadApplication`, `rootView`). System-scan JSON was cached until `receiveSystemScanJSON:` was available; **`notifyUnrealSystemScanListenerReady()`** flushed after a late ObjC hook-up. **Production path today:** `NexusGameplayBridge` + `fel.fitness.update` (see `infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md`).

If the framework is missing, the legacy **Unreal** tab showed a placeholder; the NEXUS shell runs without it.

### Firebase (unchanged)

- **`GoogleService-Info.plist`** in `FinalEvolutionLab/` (gitignored) — required for release builds that use Firestore.
- **`FirebaseBootstrap`** runs first in `FinalEvolutionLabApp`.
- **Anonymous Auth** + **System Scan** writes: see `infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md`.

### Standalone UE IPA (archived)

The RunUAT / `fel_ue5_ios_shipping_package.sh` IPA remains useful for CI and engine-only testing; it is **not** the App Store container product under NEXUS-only ship.
