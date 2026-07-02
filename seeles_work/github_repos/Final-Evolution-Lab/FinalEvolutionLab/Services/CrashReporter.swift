import Foundation

#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

/// Thin wrapper so Crashlytics stays optional in debug/dev builds.
enum CrashReporter {
    static func configureIfAvailable() {
#if canImport(FirebaseCrashlytics)
        let c = Crashlytics.crashlytics()
        c.setCustomValue(Config.appRuntimeEnvironment.rawValue, forKey: "fel_env")
        c.setCustomValue(Config.useFirebaseEmulators, forKey: "fel_use_emulators")
#endif
    }

    static func setGameMode(id: String?) {
#if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(id ?? "none", forKey: "fel_game_mode_id")
#endif
    }

    static func setUnrealLoaded(_ loaded: Bool) {
#if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().setCustomValue(loaded, forKey: "fel_unreal_loaded")
#endif
    }
}

