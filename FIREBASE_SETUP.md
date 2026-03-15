# Firebase Migration Setup (Final Evolution Lab)

This project now includes a Firebase persistence layer with local `UserDefaults` fallback.

## What is already implemented

- `FinalEvolutionLab/Services/FirebaseBootstrap.swift`
  - Configures Firebase at app startup when SDK is present.
- `FinalEvolutionLab/Services/FirebasePersistenceService.swift`
  - Pushes/pulls a full app snapshot to Firestore.
  - Uses anonymous auth for per-device user identity.
- `FinalEvolutionLab/Services/SaveSystem.swift`
  - Keeps local save/load behavior.
  - Automatically pushes changes to Firebase after each save.
  - Can refresh local cache from Firebase on launch.
- `FinalEvolutionLab/ViewModels/LabViewModel.swift`
  - Hydrates UI state from cloud snapshot at startup.

## Xcode steps required

1. Add Firebase Swift Package dependencies:
   - `FirebaseCore`
   - `FirebaseAuth`
   - `FirebaseFirestore`
2. Download `GoogleService-Info.plist` from Firebase Console.
3. Add `GoogleService-Info.plist` to the `FinalEvolutionLab` app target.
4. Ensure Firestore is enabled in Firebase Console.
5. Ensure Anonymous Authentication is enabled in Firebase Console.

## Firestore data shape

The app writes:

- Collection: `users`
- Document: `{uid}`
- Subcollection: `state`
- Document: `snapshot`

Fields:

- `payloadVersion: Int`
- `updatedAt: Timestamp`
- `blob: String` (base64 JSON snapshot)

## Notes

- If Firebase SDK is not linked, the app still compiles and uses local storage only.
- Cloud sync currently mirrors app state snapshots (simple migration path).
- Startup restore uses `updatedAt` to avoid overwriting newer local saves with older cloud data.
