import Foundation

/// Phase 6 — Live skeleton / LEAKING·MODERATE HUD is diagnostic; retail should not show it unless the user opts in.
enum FELArenaDiagnosticsPreference {
    static let userDefaultsKey = "FELArenaDiagnosticsOverlay"

    /// DEBUG: default on when the key has never been set. Release: unset key reads as `false` via `bool(forKey:)`.
    static func seedDefaultsIfNeeded() {
        #if DEBUG
        if UserDefaults.standard.object(forKey: userDefaultsKey) == nil {
            UserDefaults.standard.set(true, forKey: userDefaultsKey)
        }
        #endif
    }

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: userDefaultsKey)
    }
}
