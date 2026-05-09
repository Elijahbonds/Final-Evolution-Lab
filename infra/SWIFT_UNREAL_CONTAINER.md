# Swift + Unreal container (shipping target)

**Final Evolution Lab** ships as **`FinalEvolutionLab.xcodeproj`**: a SwiftUI “OS” shell (HealthKit / PRQ, Creator Card market, education flows) that embeds Unreal as a **framework** for high-fidelity modes and avatar rendering.

## Responsibilities

| Layer | Role |
|--------|------|
| **Swift** | Navigation, HealthKit System Scan, Firestore sync, commerce/education UI, optional Emergent WebSocket client |
| **Unreal** | Game modes, Metal viewport, avatar visualization; receives performance attributes via Firestore listener and/or JSON bridge (Emergent / native) |

## Unreal embedding

1. Build or export the UE iOS artifact as a framework named **`UnrealFramework.framework`** (or rename to match).
2. Copy it to:

   `FinalEvolutionLab/EmbeddedFrameworks/UnrealFramework.framework`

3. Build the app. The **Embed Unreal Framework (optional)** run script copies the framework into `FinalEvolutionLab.app/Frameworks` and re-signs it when a signing identity is present.

4. Runtime loading is handled by **`UnrealManager`**, which mirrors the older `UnityManager` pattern (`getInstance`, `runEmbedded`, `unloadApplication`, `rootView`).

If the framework is missing, the **Unreal** tab shows a placeholder; the rest of the shell still runs.

## Firebase

- **`GoogleService-Info.plist`** in `FinalEvolutionLab/` (gitignored) — required for release builds that use Firestore.
- **`FirebaseBootstrap`** runs first in `FinalEvolutionLabApp`.
- **Anonymous Auth** + **System Scan** writes: see `infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md`.

## Standalone UE IPA

The RunUAT / `fel_ue5_ios_shipping_package.sh` IPA remains useful for CI and engine-only testing; it is **not** the App Store container product when using this architecture.
