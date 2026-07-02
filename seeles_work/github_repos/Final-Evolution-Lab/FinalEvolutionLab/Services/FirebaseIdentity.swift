import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum FirebaseIdentityError: Error {
    case firebaseNotConfigured
    case noCurrentUser
}

/// Ensures a Firestore UID exists. Uses **anonymous** sign-in when no user is present so HealthKit / scan
/// data can land under `users/{uid}/…` until you wire Apple Sign In or email auth.
///
/// **Account upgrade:** Link email / Apple / etc. to the **same** `User` with `link(with:)`.
/// The UID stays stable, so existing `system_scans` and `avatar_performance` paths remain owned by that user.
enum FirebaseIdentity {
    static var userId: String? {
#if canImport(FirebaseAuth)
        Auth.auth().currentUser?.uid
#else
        nil
#endif
    }

    static var isAnonymous: Bool {
#if canImport(FirebaseAuth)
        Auth.auth().currentUser?.isAnonymous ?? false
#else
        false
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

    /// Links **Email + password** to the current session (typically anonymous). **UID is unchanged** — all
    /// Firestore data under `users/{uid}` stays attached. Enable Email/Password in Firebase Console.
    ///
    /// If the email already belongs to another Firebase user, this throws (`credentialAlreadyInUse`); handle
    /// with sign-in + optional data migration UX instead of link.
    @MainActor
    static func linkEmailPasswordAccount(email: String, password: String) async throws {
#if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { throw FirebaseIdentityError.firebaseNotConfigured }
        guard let user = Auth.auth().currentUser else { throw FirebaseIdentityError.noCurrentUser }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        _ = try await user.link(with: credential)
#else
        throw FirebaseIdentityError.firebaseNotConfigured
#endif
    }

    /// Preferred path for “Upgrade to Apple”: link `ASAuthorizationAppleIDCredential` via `OAuthProvider.appleCredential`.
    @MainActor
    static func linkWithCredential(_ credential: AuthCredential) async throws {
#if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { throw FirebaseIdentityError.firebaseNotConfigured }
        guard let user = Auth.auth().currentUser else { throw FirebaseIdentityError.noCurrentUser }
        _ = try await user.link(with: credential)
#else
        throw FirebaseIdentityError.firebaseNotConfigured
#endif
    }
}
