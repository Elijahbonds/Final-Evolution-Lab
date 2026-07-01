import Foundation

#if NEXUS_USE_FIREBASE && canImport(FirebaseCore)
import FirebaseCore
#endif
#if NEXUS_USE_FIREBASE && canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if NEXUS_USE_FIREBASE && canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Configures the Firebase iOS SDK at process launch when `GoogleService-Info.plist` is in the app bundle.
/// Optional at compile time (`NEXUS_USE_FIREBASE=0`) and runtime (`NEXUS_FIREBASE_DISABLED=1` / missing plist).
/// Firestore / Auth clients assume this ran successfully; use ``isConfigured`` before writing.
enum FirebaseBootstrap {
    enum ConnectionStatus: String, Sendable {
        case live
        case preview
        case unavailable
        case disabled
    }

#if NEXUS_USE_FIREBASE && canImport(FirebaseAuth)
    private static var authStateListener: AuthStateDidChangeListenerHandle?
#endif
    private static var previewModeActive = false

    /// `true` when Firebase is compiled in and available for optional distribution / Auth / Firestore.
    static var isCompiledIn: Bool {
#if NEXUS_USE_FIREBASE
        true
#else
        false
#endif
    }

    /// `true` after a successful `FirebaseApp.configure()` for this process.
    static var isConfigured: Bool {
#if NEXUS_USE_FIREBASE && canImport(FirebaseCore)
        FirebaseApp.app() != nil
#else
        false
#endif
    }

    /// `true` when the bundled plist is present but uses placeholder / preview credentials — Firebase intentionally off.
    static var isPreviewMode: Bool { previewModeActive }

    static var connectionStatus: ConnectionStatus {
#if !NEXUS_USE_FIREBASE
        return .disabled
#else
        if ProcessInfo.processInfo.environment["NEXUS_FIREBASE_DISABLED"] == "1" {
            return .disabled
        }
        if isConfigured && !isPreviewMode {
            return .live
        }
        if isPreviewMode {
            return .preview
        }
        return .unavailable
#endif
    }

    /// Status for distribution / Auth / Firestore lane (separate from AI Studio).
    static var statusLabel: String {
        switch connectionStatus {
        case .live:
            return FELPremiumCopy.Firebase.live
        case .preview:
            return FELPremiumCopy.Firebase.preview
        case .unavailable:
            return FELPremiumCopy.Firebase.unavailable
        case .disabled:
            if ProcessInfo.processInfo.environment["NEXUS_FIREBASE_DISABLED"] == "1" {
                return FELPremiumCopy.Firebase.disabledEnv
            }
#if !NEXUS_USE_FIREBASE
            return FELPremiumCopy.Firebase.disabledCompile
#else
            return FELPremiumCopy.Firebase.disabled
#endif
        }
    }

    /// Show the top PREVIEW banner only when Firebase is offline **and** AI Studio is also offline.
    static var shouldShowOfflineBanner: Bool {
        isPreviewMode && !NexusAIStudioBootstrap.isConfigured
    }

    static func configureIfNeeded() {
#if NEXUS_USE_FIREBASE && canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else { return }

        if ProcessInfo.processInfo.environment["NEXUS_FIREBASE_DISABLED"] == "1" {
            previewModeActive = true
            logPreview("NEXUS_FIREBASE_DISABLED=1 — Firebase disabled.")
            return
        }

        // Bypass if running under UI tests or screenshot harness
        if CommandLine.arguments.contains("-UITestMode") || CommandLine.arguments.contains("-ScreenshotHarness") {
#if DEBUG
            print("[FirebaseBootstrap] Bypassing Firebase configuration for UI/Screenshot test mode.")
#endif
            return
        }

        guard let plistPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            previewModeActive = true
#if DEBUG
            print("[FirebaseBootstrap] GoogleService-Info.plist missing from bundle — Firebase disabled.")
#endif
            return
        }

        if isPlaceholderPlist(at: plistPath) {
            previewModeActive = true
            logPreview("GoogleService-Info.plist is preview/placeholder — Firebase disabled.")
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
#if DEBUG
        print("[FirebaseBootstrap] NEXUS_USE_FIREBASE=0 — Firebase compile-time disabled.")
#endif
        previewModeActive = true
        return
#endif
    }

    private static func isPlaceholderPlist(at path: String) -> Bool {
        guard let plistDict = NSDictionary(contentsOfFile: path) else { return true }
        if let apiKey = plistDict["API_KEY"] as? String, apiKey.contains("REPLACE_ME") { return true }
        if let appId = plistDict["GOOGLE_APP_ID"] as? String,
           appId == "1:000000000000:ios:0000000000000000000000" { return true }
        if let bundleId = plistDict["BUNDLE_ID"] as? String,
           bundleId == "com.yourcompany.yourapp" { return true }
        if felFirebasePreviewFlagEnabled(plistDict["FEL_FIREBASE_PREVIEW"]) { return true }
        return false
    }

    /// Accepts `FEL_FIREBASE_PREVIEW` as string `"1"`, integer/bool `1`/`true`, or legacy bool plist entries.
    private static func felFirebasePreviewFlagEnabled(_ value: Any?) -> Bool {
        switch value {
        case let s as String:
            return s == "1" || s.lowercased() == "true"
        case let n as Int:
            return n == 1
        case let b as Bool:
            return b
        case let n as NSNumber:
            return n.boolValue
        default:
            return false
        }
    }

    private static func logPreview(_ message: String) {
#if DEBUG
        print("[FirebaseBootstrap] PREVIEW · \(message)")
#else
        // Release builds still need an honest signal in Console during internal TestFlight without real plist.
        NSLog("[FirebaseBootstrap] PREVIEW · %@", message)
#endif
    }
}
