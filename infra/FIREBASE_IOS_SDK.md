# Firebase iOS SDK (runtime — “launch with Firebase”)

This is **not** [Firebase App Distribution](https://firebase.google.com/docs/app-distribution) (uploading `.ipa` files). It is the **Firebase client SDK** so Auth, Firestore, Crashlytics, etc. can run inside the app after `FirebaseApp.configure()`.

Official SDK repo (Swift Package Manager preferred): **[firebase/firebase-ios-sdk](https://github.com/firebase/firebase-ios-sdk)**

## Installation (Swift Package Manager)

NEXUS ships Firebase via **SPM only** (no CocoaPods). CocoaPods publishing ends October 2026 per the [official README](https://github.com/firebase/firebase-ios-sdk#installation).

| Setting | Value |
|---------|-------|
| Package URL | `https://github.com/firebase/firebase-ios-sdk` |
| Version rule | **Exact** `12.15.0` (pinned in `FinalEvolutionLab.xcodeproj`) |
| Target | `FinalEvolutionLab` |

**Linked SPM products** (as of audit 2026-06-19):

| Product | Used by |
|---------|---------|
| `FirebaseCore` | `FirebaseBootstrap` → `FirebaseApp.configure()` |
| `FirebaseAuth` | `FirebaseIdentity`, `TrainingLabSocialBridge` |
| `FirebaseFirestore` | `SystemScanFirestoreSync`, social bridge |
| `FirebaseCrashlytics` | `CrashReporter` + Release symbol upload build phase |

**Not linked** (optional / not required for current ship):

- `FirebaseAnalytics` — precompiled with SPM but not added to target; enable in Xcode if Analytics needed
- `FirebaseAppDistribution` — **not required** for console IPA uploads; only for in-app update prompts
- `FirebaseMessaging`, `FirebaseRemoteConfig`, etc.

To bump the SDK: Xcode → Project → Package Dependencies → `firebase-ios-sdk` → set exact version → resolve packages → run sim build.

## Repo Swift shell (`FinalEvolutionLab.xcodeproj`)

1. In [Firebase Console](https://console.firebase.google.com/project/final-evolution-lab/settings/general) → **Add app** → **iOS** → register bundle ID **`com.finalevolutionlab.app`** (not legacy `FinalEvoLab`).
2. Download **`GoogleService-Info.plist`** and save it as:

   `FinalEvolutionLab/GoogleService-Info.plist`

   (Gitignored; `FinalEvolutionLab/GoogleService-Info.example.plist` is the preview template.)

3. Validate locally:

   ```bash
   ./scripts/lib/firebase-plist-check.sh validate FinalEvolutionLab/GoogleService-Info.plist
   ```

   Or fetch via CLI (rejects wrong bundle ID):

   ```bash
   ./scripts/fetch-firebase-ios-plist.sh          # list iOS apps
   ./scripts/fetch-firebase-ios-plist.sh <APP_ID>
   ```

4. Build/run: **`FirebaseBootstrap.configureIfNeeded()`** runs first in `FinalEvolutionLabApp` and calls **`FirebaseApp.configure()`** when the plist is in the bundle. Use **`FirebaseBootstrap.isConfigured`** before touching Firestore.

5. **Firestore + Auth (linked on target):** **`FirebaseIdentity.ensureUserSignedIn()`** signs in **anonymously** if needed so writes can use `users/{uid}/…`. System Scan snapshots are written by **`SystemScanFirestoreSync`** (see `infra/SYSTEM_SCAN_FIRESTORE_SCHEMA.md`).

6. **Preview lane** (`--preview-firebase`): placeholder plist → `FirebaseBootstrap.isPreviewMode == true` → Firebase offline at runtime; Crashlytics upload skipped. See `Config/FEL_FIREBASE_TESTFLIGHT_CHECKLIST.txt`.

## AI Studio decouple (Phase 6 — optional Firebase)

Core app boot (**agent chat**, **game generator**, **BioFuel**) uses **Google AI Studio / Gemini REST** via `NexusAIStudioBootstrap` — **no Firebase plist required**.

| Lane | Bootstrap | Required for core boot? |
|------|-----------|-------------------------|
| **AI Studio** | `NexusAIStudioBootstrap.configureIfNeeded()` | Yes (or local stub when key missing) |
| **Firebase** | `FirebaseBootstrap.configureIfNeeded()` | No — Auth, Firestore, Crashlytics, App Distribution only |

**AI Studio API key** (never commit):

| Env var | Notes |
|---------|--------|
| `NEXUS_AI_STUDIO_API_KEY` | Primary (Phase 6) |
| `NEXUS_AGENT_GEMINI_KEY` | Alias (agent / engine parity) |
| `GEMINI_API_KEY` | Alias (Firebase AI Logic compat) |
| `FEL_LLM_KEY` | Legacy alias |

Key resolution: scheme env → Keychain (`com.finalevolutionlab.nexus.aistudio`). First env launch may persist to Keychain for device runs without Xcode.

**Runtime Firebase off:** `NEXUS_FIREBASE_DISABLED=1` or missing / placeholder `GoogleService-Info.plist`.

**Compile-time Firebase strip (optional):** remove `NEXUS_USE_FIREBASE` from `SWIFT_ACTIVE_COMPILATION_CONDITIONS`:

```bash
xcodebuild ... SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG'   # Debug sim without Firebase compile path
```

Or set `NEXUS_USE_FIREBASE=0` when invoking CI (pass empty / override `SWIFT_ACTIVE_COMPILATION_CONDITIONS` on the `FinalEvolutionLab` target). SPM packages remain linked unless manually removed from the target.

**UI:** Status tab → **Backend Lanes** card shows AI Studio vs Firebase separately. Top banner is suppressed when AI Studio is connected even if Firebase is offline.

## Unreal-only IPA (`Binaries/IOS/*.ipa` from UE)

The shipping script builds Epic’s **generated** Xcode project for your `.uproject`. This repo’s Swift UI shell is **not** inside that IPA unless you explicitly integrate it.

To use Firebase inside a **pure Unreal** iOS build you still need the native SDK in **that** Xcode project (SPM + plist + `FirebaseApp.configure()` in an injected `AppDelegate` or UE plugin). That is a separate integration step on the UE side.
