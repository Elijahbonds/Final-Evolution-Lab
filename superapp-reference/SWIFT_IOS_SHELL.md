# Swift iOS shell (`FinalEvolutionLab/`)

Native **Swift / SwiftUI** code lives here alongside the Unreal-led product track:

- **`Services/HealthKitService.swift`** — HealthKit integration patterns.
- **`ViewModels/`**, **`Views/`** — SwiftUI flows (vault, lab, etc.).
- **`FinalEvolutionLab.xcodeproj`** — Xcode project for this shell.

**Important:** The **production Shipping game binary** is normally the **UE-generated iOS target** (`FinalEvolutionLab (IOS).xcworkspace` from UE), not this Swift project alone. HealthKit and StoreKit work must be reconciled with the **actual shipping target’s** entitlements and **Info.plist** (often merged via UE `AdditionalPlistData` + Xcode capabilities).

When Superapp asks for “the iOS app,” clarify whether they mean **UE Shipping .ipa** (game) or **Swift shell** (native experiments)—this manifest treats **UE Shipping** as the consumer deliverable unless product direction says otherwise.
