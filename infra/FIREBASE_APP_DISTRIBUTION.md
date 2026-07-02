# Firebase App Distribution (NEXUS iOS)

**Canonical repo:** `/Users/elijahbonds/Final-Evolution-Lab`  
**Bundle ID:** `com.finalevolutionlab.app`  
**Firebase project:** `final-evolution-lab`

> **AI vs Firebase:** **Google AI Studio** is the **primary AI backend** (game generator, agent chat, NEXUS Studio). It uses `NEXUS_AI_STUDIO_API_KEY` / Keychain — **no Firebase plist required**. Firebase on this page is **optional** for **App Distribution**, **Crashlytics**, and **Auth/Firestore** only. Setup: `docs/NEXUS_AI_STUDIO_SETUP.md`.

## Correct IPA for Firebase upload

Firebase App Distribution requires an **installable** IPA — **not** the App Store / TestFlight IPA.

| IPA | Export method | Use |
|-----|---------------|-----|
| `build/FEL-Firebase-Distribution.ipa` | ad-hoc (`release-testing`) | **Firebase App Distribution** (canonical) |
| `build/FEL-export-adhoc/FinalEvolutionLab.ipa` | ad-hoc | Same as above (source copy) |
| `build/FEL-export/FinalEvolutionLab.ipa` | app-store-connect | **TestFlight / Transporter only** |

**Disk:** ensure **≥ 15 GB free** on `/` before archive/export (`df -g /`).

Build the Firebase IPA:

```bash
./scripts/archive-ios-testflight.sh --preview-firebase --export-adhoc
# or export-only from existing archive:
./scripts/archive-ios-testflight.sh --export-only --export-adhoc --preview-firebase
```

The script copies the ad-hoc IPA to `build/FEL-Firebase-Distribution.ipa` automatically.

## Firebase Console upload

1. Open the **correct** iOS app (bundle `com.finalevolutionlab.app`):
   https://console.firebase.google.com/project/final-evolution-lab/appdistribution/app/ios:com.finalevolutionlab.app/releases

2. **Do NOT** upload to the legacy **FEL** app (`FinalEvoLab` bundle ID) — upload will fail with bundle ID mismatch.

3. Drag `build/FEL-Firebase-Distribution.ipa` → add tester emails → distribute.

Full checklist: `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt`

## Apple Developer: UDID registration (required for ad-hoc)

Ad-hoc IPAs only install on devices whose **UDIDs** are in the provisioning profile.

1. Collect tester UDID (Settings → General → About, or Xcode → Window → Devices and Simulators).
2. Register at https://developer.apple.com/account/resources/devices/list
3. Re-export so Xcode refreshes the ad-hoc profile:
   ```bash
   ./scripts/archive-ios-testflight.sh --export-only --export-adhoc --preview-firebase
   ```
4. Verify UDID count printed by the script (`Ad-hoc UDIDs in profile: N`).

## Firebase iOS app registration

Two iOS apps may exist in the same Firebase project:

| Display name | Bundle ID | Firebase App ID | Use |
|--------------|-----------|-----------------|-----|
| Final Evolution Lab | `com.finalevolutionlab.app` | `1:760396881212:ios:279a55f97749059acb1239` | **NEXUS ship** |
| FEL (legacy) | `FinalEvoLab` | `1:760396881212:ios:1cc1b32780934231cb1239` | Do not upload NEXUS IPAs |

Download plist for NEXUS app:

```bash
./scripts/fetch-firebase-ios-plist.sh --download
```

## Fastlane (optional)

Point `IPA_PATH` at `build/FEL-Firebase-Distribution.ipa`. See `fastlane/.env.example`.

## Legacy UE path (archived)

The Unreal `fel_ue5_ios_shipping_package.sh --export-ipa-firebase` path is **not** the NEXUS retail ship. See `NEXUS_ONLY_PIVOT.md`.
