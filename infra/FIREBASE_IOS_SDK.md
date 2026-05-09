# Firebase iOS SDK (runtime — “launch with Firebase”)

This is **not** [Firebase App Distribution](https://firebase.google.com/docs/app-distribution) (uploading `.ipa` files). It is the **Firebase client SDK** so Analytics, Crashlytics (when added), Remote Config, etc. can run inside the app after `FirebaseApp.configure()`.

## Repo Swift shell (`FinalEvolutionLab.xcodeproj`)

1. In [Firebase Console](https://console.firebase.google.com/) → your project → **Add app** → **iOS** → register the **same bundle ID** as in Xcode (e.g. `Final-Evolution-x-Unreal`).
2. Download **`GoogleService-Info.plist`** and save it as:

   `FinalEvolutionLab/GoogleService-Info.plist`

   (That path is **gitignored**; use `FinalEvolutionLab/GoogleService-Info.example.plist` as a naming reference only — replace values from the console download.)

3. Build/run: **`FirebaseBootstrap`** runs before other startup code and calls **`FirebaseApp.configure()`** when the plist is in the bundle.

4. Optional: add more Firebase products in Xcode (**File → Add Package Dependencies** already pulls `firebase-ios-sdk`; link extra products like **FirebaseCrashlytics** on the target).

## Unreal-only IPA (`Binaries/IOS/*.ipa` from UE)

The shipping script builds Epic’s **generated** Xcode project for your `.uproject`. This repo’s Swift UI shell is **not** inside that IPA unless you explicitly integrate it.

To use Firebase inside a **pure Unreal** iOS build you still need the native SDK in **that** Xcode project (e.g. CocoaPods/SPM + plist + `FirebaseApp.configure()` in an injected `AppDelegate` or UE plugin). That is a separate integration step on the UE side.
