import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Configures the Firebase iOS SDK at process launch when `GoogleService-Info.plist` is in the app bundle.
/// Firestore / Auth clients assume this ran successfully; use ``isConfigured`` before writing.
enum FirebaseBootstrap {
#if canImport(FirebaseAuth)
    private static var authStateListener: AuthStateDidChangeListenerHandle?
#endif
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
        
        // Bypass if running under UI tests or screenshot harness
        if CommandLine.arguments.contains("-UITestMode") || CommandLine.arguments.contains("-ScreenshotHarness") {
#if DEBUG
            print("[FirebaseBootstrap] Bypassing Firebase configuration for UI/Screenshot test mode.")
#endif
            return
        }
        
        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
#if DEBUG
            print("[FirebaseBootstrap] GoogleService-Info.plist missing from bundle — Firebase disabled.")
#endif
            return
        }
        
        if let plistDict = NSDictionary(contentsOfFile: plistPath),
           let apiKey = plistDict["API_KEY"] as? String,
           apiKey.contains("REPLACE_ME") {
#if DEBUG
            print("[FirebaseBootstrap] GoogleService-Info.plist contains placeholder API key — Firebase disabled.")
#endif
            return
        }
        
        FirebaseApp.configure()
        CrashReporter.configureIfAvailable()
#if canImport(FirebaseFirestore)
        if Config.useFirebaseEmulators {
            let raw = Config.firestoreEmulatorHost
            let parts = raw.split(separator: ":", omittingEmptySubsequences: false)
            let host = parts.first.map(String.init) ?? "127.0.0.1"
            let port = parts.count >= 2 ? Int(parts[1]) ?? 8085 : 8085
            Firestore.firestore().useEmulator(withHost: host, port: port)
#if DEBUG
            print("[FirebaseBootstrap] Firestore emulator \(host):\(port)")
#endif
        }
#endif
#if canImport(FirebaseAuth)
        if Config.useFirebaseEmulators {
            Auth.auth().useEmulator(withHost: Config.authEmulatorHost, port: Config.authEmulatorPort)
#if DEBUG
            print("[FirebaseBootstrap] Auth emulator \(Config.authEmulatorHost):\(Config.authEmulatorPort)")
#endif
        }

        // Phase 8: Ensure we treat Auth UID changes as an identity boundary for cached SQL keys.
        if authStateListener == nil {
            authStateListener = Auth.auth().addStateDidChangeListener { _, _ in
                Task { @MainActor in
                    TrainingLabSocialBridge.shared.reconcileCachedIdentityWithCurrentAuth()
                }
            }
        }
#endif
#if DEBUG
        if let app = FirebaseApp.app() {
            print("[FirebaseBootstrap] Configured googleAppID=\(app.options.googleAppID) env=\(Config.appRuntimeEnvironment.rawValue)")
        }
#endif
#else
        return
#endif
    }
}
