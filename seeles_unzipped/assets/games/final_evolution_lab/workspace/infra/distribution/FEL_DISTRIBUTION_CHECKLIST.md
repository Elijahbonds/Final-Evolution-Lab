# FEL Distribution Checklist
# Final Evolution AI Coach — com.finalevolutionlab.app
# ============================================================

## ✅ iOS Prerequisites

- [ ] **Apple Developer Account** — enrolled in Apple Developer Program ($99/yr)
- [ ] **Apple Distribution Certificate** — installed in Keychain on M4 Pro Mac Mini
  - Verify: `security find-identity -v -p codesigning | grep "Apple Distribution"`
- [ ] **App Store Provisioning Profile** — downloaded and installed for `com.finalevolutionlab.app`
  - Create at: [developer.apple.com → Profiles → + → App Store Distribution](https://developer.apple.com/account/resources/profiles/list)
  - Install: double-click `.mobileprovision` file
- [ ] **ExportOptions.plist** — `infra/ios/ExportOptions.plist` present with `signingStyle=automatic`, `destination=upload`, zero REPLACE_WITH_* placeholders
- [ ] **App Store Connect API Key** — `.p8` file at `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`
  - Create at: App Store Connect → Users & Access → Keys → Add (+)
  - Populate `API_KEY_ID` and `API_ISSUER_ID` in `infra/ios/fel_appstore_connect.sh`
- [ ] **Bundle ID registered** — `com.finalevolutionlab.app` created at [developer.apple.com → Identifiers](https://developer.apple.com/account/resources/identifiers/list)
- [ ] **App record created** — App record exists in App Store Connect with matching bundle ID

---

## ✅ Android Prerequisites

- [ ] **Google Play Developer Account** — enrolled ($25 one-time)
- [ ] **App created in Play Console** — `com.finalevolutionlab.app` app record created at [play.google.com/console](https://play.google.com/console)
- [ ] **Release keystore generated** — follow instructions in `infra/android/fel_keystore.properties`
  - `keytool -genkeypair -storetype PKCS12 -keystore fel_release.keystore -alias fel_key -keyalg RSA -keysize 2048 -validity 10000`
- [ ] **Keystore properties populated** — `infra/android/fel_keystore.properties` has all REPLACE_WITH_* filled
- [ ] **Google Play JSON key** — service account JSON key downloaded from Play Console → Setup → API access
  - Populate `GOOGLE_PLAY_JSON_KEY_PATH` in `infra/android/upload_to_google_play.sh`
- [ ] **App Signing by Google** — opted in for Play App Signing (recommended) in Play Console → Setup → App signing

---

## ✅ Pre-Submission Checks

- [ ] **Bundle IDs match** — `com.finalevolutionlab.app` in DefaultEngine.ini, ExportOptions.plist, and store records
- [ ] **Version numbers set** — `ProjectVersion=1.0.0` in Config/DefaultGame.ini; `StoreVersion=1` in DefaultEngine.ini
- [ ] **Gate 1 passing** — `production_modes=14` in `backend/FEL_ModeManager.production.json`
- [ ] **All 6 CI gates pass** — run `infra/fel_prebuild_ci_check.sh --strict`
- [ ] **App icons prepared** — 1024×1024 PNG (iOS), 512×512 PNG (Android), no alpha channel
- [ ] **Screenshots captured** — iPhone 6.7" + 6.5" (iOS), phone + 7" tablet (Android)
- [ ] **Privacy policy URL** — hosted and reachable (required by both stores)
- [ ] **Age rating / content rating** — completed in App Store Connect and Play Console
- [ ] **Backend live** — `https://finalevolutiongroup.com/games/session` reachable
- [ ] **Deep link tested** — `finalevolution://launch?map=VeniceBeach&mode=basketball_h2h&session=test` works

---

## 🚀 iOS Upload Steps

```bash
# Step 1: Full cook + build + archive + IPA export
cd "/Users/elijahbonds/Documents/Unreal Projects/MyProject"
bash infra/ios/fel_ios_shipping_build.sh

# Step 2: Upload to TestFlight
bash infra/ios/fel_appstore_connect.sh
```

- Check TestFlight processing: [App Store Connect → TestFlight](https://appstoreconnect.apple.com/apps)
- Processing takes 5–30 minutes
- Add internal testers immediately after processing completes

---

## 🚀 Android Upload Steps

```bash
# Step 1: Full cook + build + AAB
cd "/Users/elijahbonds/Documents/Unreal Projects/MyProject"
bash infra/android/fel_android_shipping_build.sh

# Step 2: Upload to Internal Testing track
bash infra/android/upload_to_google_play.sh
```

- Check status: [Play Console → Testing → Internal testing](https://play.google.com/console)

---

## 🧪 TestFlight Beta / Internal Track

- [ ] iOS: Add testers in App Store Connect → TestFlight → Internal Testers (up to 100)
- [ ] Android: Add testers in Play Console → Testing → Internal testing → Testers tab
- [ ] Distribute invite links to QA team
- [ ] Collect feedback via TestFlight notes / Play Console feedback

---

## 📦 App Store Review / Production Promotion

### iOS
- [ ] Complete App Store listing (description, keywords, screenshots, preview video)
- [ ] Set pricing (Free + IAP)
- [ ] Submit for review: App Store Connect → Prepare for Submission → Submit for Review
- [ ] Review time: typically 1–3 business days

### Android
- [ ] Complete store listing in Play Console (description, screenshots, content rating)
- [ ] Promote from internal → production: Play Console → Releases → Promote release
- [ ] Review time: typically 1–7 days for new apps

---

## 📋 Post-Launch

- [ ] Monitor crash reports (Xcode Organizer / Play Console → Android Vitals)
- [ ] Monitor TestFlight feedback / Play Store reviews
- [ ] Push P1 Economy patch (apply_p1_economy.sh) to GitHub branch
- [ ] Update `final_evolution_lab.json` urls field with live App Store / Play Store URLs
