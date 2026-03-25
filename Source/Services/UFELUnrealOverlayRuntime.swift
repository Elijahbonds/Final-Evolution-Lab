import Combine
import Foundation

/// Shared state for embedding a full-screen Unreal Metal viewport in SwiftUI. When `bIsUnrealReady` is true, Arena/System Scan suppress 2D placeholder layers.
/// **iOS device:** full Metal host path in `UFELUnrealViewportContainer`. **Simulator:** Metal host is disabled; use for UI/TestFlight prep without Unreal binaries.
@MainActor
final class UFELUnrealOverlayRuntime: ObservableObject {
    static let shared = UFELUnrealOverlayRuntime()

    /// `false` on Simulator — keeps local simulator builds free of embedded Unreal Metal expectations.
    static var felUsesEmbeddedUnrealMetalHost: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    /// Posted when native / embedded UE signals the Metal view is live (optional hook for future bridge).
    static let viewportReadyNotification = Notification.Name("FELUnrealViewportSurfaceReady")

    /// Top-most Unreal layer is active; hide SwiftUI mesh/grid/ghost fallbacks.
    @Published var bIsUnrealReady: Bool

    /// Set when arena mode is chosen / level loads — drives Swift input overlays (`swipeGolf`, `penaltyKick`, etc.).
    @Published var activeHandshakeInputScheme: InputScheme?

    private init() {
        let d = UserDefaults.standard
        if d.object(forKey: Self.udKey) != nil {
            bIsUnrealReady = d.bool(forKey: Self.udKey)
        } else if let plist = Bundle.main.object(forInfoDictionaryKey: "FELUnrealViewportReady") as? Bool {
            bIsUnrealReady = plist
        } else if let s = Bundle.main.object(forInfoDictionaryKey: "FELUnrealViewportReady") as? String {
            bIsUnrealReady = (s as NSString).boolValue
        } else {
            bIsUnrealReady = false
        }
    }

    private static let udKey = "felUnrealViewportReady"

    func setUnrealReady(_ value: Bool) {
        bIsUnrealReady = value
        UserDefaults.standard.set(value, forKey: Self.udKey)
    }

    func applyHandshakeInputScheme(for modeId: GameModeId?) {
        activeHandshakeInputScheme = modeId?.inputScheme
    }
}
