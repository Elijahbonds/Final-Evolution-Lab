import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Configures the Firebase iOS SDK at process launch when `GoogleService-Info.plist` is in the app bundle.
/// Firestore / Auth clients assume this ran successfully; use ``isConfigured`` before writing.
enum FirebaseBootstrap {
    /// `true` after a successful `FirebaseApp.configure()` for this process.
    static var isConfigured: Bool {
#if canImport(FirebaseCore)
        FirebaseApp.app() != nil
#else
        false
#endif
    }

    static func configureIfNeeded() {
#if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else { return }
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
#if DEBUG
            print("[FirebaseBootstrap] GoogleService-Info.plist missing from bundle — Firebase disabled.")
#endif
            return
        }
        FirebaseApp.configure()
#if DEBUG
        if let app = FirebaseApp.app() {
            print("[FirebaseBootstrap] Configured googleAppID=\(app.options.googleAppID)")
        }
#endif
#else
        return
#endif
    }
}
