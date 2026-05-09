import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Configures the Firebase iOS SDK at process launch when `GoogleService-Info.plist` is present in the app bundle.
/// Add that file from Firebase Console → Project settings → Your apps → iOS (download); keep secrets out of Git.
enum FirebaseBootstrap {
    static func configureIfNeeded() {
#if canImport(FirebaseCore)
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            return
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
#else
        return
#endif
    }
}
