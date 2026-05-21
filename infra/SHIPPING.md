# Shipping Pipeline

> **Goal:** ship the Unreal Engine 5.7 iOS build through App Store Connect / TestFlight so Superapp can surface and track the release without hosting an install feed.

---

## Canonical: Unreal Engine 5.7 iOS Build

### Build

```bash
cd "$HOME/Documents/rork-final-evolution-lab"
UPROJECT="$HOME/Developer/FinalEvolutionLab57/FinalEvolutionLab.uproject" \
SKIP_GENERATE=1 \
./fel_ue5_ios_shipping_package.sh --full-cook --shipping --export-ipa
```

### Verify cooked payload

```bash
UE_PROJECT="$HOME/Developer/FinalEvolutionLab57" \
./infra/fix_ios_descriptor_path.sh
```

The staged `.app` must contain cooked payload evidence: `cookeddata/`, `.pak`, or the Unreal iOS payload layout expected by UE 5.7. No build may be called good if it can produce the descriptor error.

### Install to device

```bash
xcrun devicectl device install app \
  --device "00008140-001079E402FA801E" \
  "$HOME/Developer/FinalEvolutionLab57/Binaries/IOS/FinalEvolutionLab.app"
```

### TestFlight upload

After IPA export (`~/Developer/FinalEvolutionLab57/Binaries/IOS/FinalEvolutionLab.ipa`):

```bash
xcrun altool --upload-app \
  -f "$HOME/Developer/FinalEvolutionLab57/Binaries/IOS/FinalEvolutionLab.ipa" \
  --api-key "$ASC_API_KEY" \
  --api-issuer "$ASC_ISSUER_ID"
```

---

## Legacy / prototype: Unity migration

> **Status: reference/prototype only.** Unreal Engine 5.7 is now the production shipping target. Do not use the Unity migration path to change the shipping app shell unless leadership explicitly reopens the Unity migration.

Unity 6 code remains in the repo (`UnityProject/`, `Unity/`) as reference material. It is not part of the production build pipeline.

---

## Legacy: Swift iOS shell

The Swift/SwiftUI app at `ios/FinalEvolutionLab.xcodeproj` is integration/reference support only. It is not the shipping gameplay client. The production iOS app is the Unreal Engine 5.7 packaged build.

---

*Last updated: Unreal re-baseline per leadership decision.*
