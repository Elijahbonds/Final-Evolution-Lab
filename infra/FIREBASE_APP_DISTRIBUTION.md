# Firebase App Distribution (iOS)

## Why `FinalEvolutionLab.ipa` “doesn’t work” in Firebase

An IPA exported with **App Store** method (`ExportOptions.plist` / `method: app-store`) is for **Transporter / App Store Connect**, not for sideloading to Ad Hoc testers. **Firebase App Distribution** expects an installable build, typically **Ad Hoc** (or Enterprise / Development with correct signing).

## Build the correct IPA in this repo

**Ad Hoc / Firebase** (writes `FinalEvolutionLab-Firebase.ipa`):

```bash
export UE_ROOT="/Users/Shared/Epic Games/UE_5.7"
UPROJECT="/path/to/FinalEvolutionLab.uproject" \
  /path/to/final-evolution-lab/fel_ue5_ios_shipping_package.sh --full-cook --export-ipa-firebase
```

Output: **`.../Binaries/IOS/FinalEvolutionLab-Firebase.ipa`**  
Uses **`infra/ue5_config/ExportOptions.ad-hoc.plist`**.

**Also need App Store IPA** (same run, one archive):

```bash
./fel_ue5_ios_shipping_package.sh --full-cook --export-ipa --export-ipa-firebase
```

- **`FinalEvolutionLab.ipa`** — app-store (TestFlight / Transporter)  
- **`FinalEvolutionLab-Firebase.ipa`** — ad-hoc (Firebase)

## Apple Developer requirements

- Tester device **UDIDs** registered in your Apple Developer account.  
- **Ad Hoc** provisioning profile (or automatic signing that includes those devices).

## Fastlane

Point **`IPA_PATH`** at **`FinalEvolutionLab-Firebase.ipa`**, not the App Store IPA. See **`fastlane/.env.example`** and run **`bundle exec fastlane distribute`**.
