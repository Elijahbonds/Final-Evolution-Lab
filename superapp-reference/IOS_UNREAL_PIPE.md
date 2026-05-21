# iOS + Unreal shipping pipe (canonical)

> This is the **canonical** iOS distribution pipeline for Final Evolution Lab. Unreal Engine 5.7 is the production shipping target.

---

## Pipeline overview

```
UE 5.7 Editor
    → Full Cook (iOS Shipping)
    → IPA Export
    → Cooked Payload Verification
    → xcrun devicectl install (dev)
    → xcrun altool upload (TestFlight)
    → App Store Connect review
    → Superapp tracks release metadata
```

## Key components

| Component | Location |
|-----------|----------|
| Unreal project | `~/Developer/FinalEvolutionLab57/FinalEvolutionLab.uproject` |
| Build script | `./fel_ue5_ios_shipping_package.sh` |
| Descriptor fix | `./infra/fix_ios_descriptor_path.sh` |
| Expected IPA | `~/Developer/FinalEvolutionLab57/Binaries/IOS/FinalEvolutionLab.ipa` |
| TestFlight upload | `xcrun altool --upload-app` with ASC API key |

## In-app architecture

- **Gameplay:** Unreal viewport (all 12 arena modes rendered in-engine)
- **Dashboard:** native iOS `WKWebView` overlay inside the Unreal app
- **Deep links:** `finalevolution://launch?mode=basketball_h2h` routes through `UFELEmergentDeepLinkSubsystem` — no app switching
- **Economy:** session receipts from Unreal gameplay → server verification → no local shard mutation

## What this replaces

- ~~Unreal-as-a-Library~~ — not used
- ~~XCFramework embedding~~ — not used
- ~~SwiftUI-first app shell~~ — not used
- ~~App switching between Swift app and Unreal~~ — not used
- ~~Sideload / AltStore / Sovereign Store~~ — not used

Unreal is not archived or legacy. It is the canonical shipping path.

---

*Last updated: Unreal re-baseline per leadership decision.*
