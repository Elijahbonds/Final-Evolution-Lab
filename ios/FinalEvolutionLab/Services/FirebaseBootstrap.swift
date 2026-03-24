import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseBootstrap {
    static func configureIfNeeded() {
#if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
#endif
    }
}
