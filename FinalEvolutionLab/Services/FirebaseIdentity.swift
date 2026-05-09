import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Ensures a Firestore UID exists. Uses **anonymous** sign-in when no user is present so HealthKit / scan
/// data can land under `users/{uid}/…` until you wire Apple Sign In or email auth.
enum FirebaseIdentity {
    static var userId: String? {
#if canImport(FirebaseAuth)
        Auth.auth().currentUser?.uid
#else
        nil
#endif
    }

    @MainActor
    static func ensureUserSignedIn() async throws {
#if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { return }
        if Auth.auth().currentUser != nil { return }
        _ = try await Auth.auth().signInAnonymously()
#endif
    }
}
