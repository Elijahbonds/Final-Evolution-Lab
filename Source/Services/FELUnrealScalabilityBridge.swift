import Foundation

/// Swift ↔ Unreal scalability: toggles persist for the embedded Metal viewport / UE runtime.
/// When the native UE iOS host is linked, subscribe to `felUnrealConsoleCommandRequested` and call `UFELPlatformManager::ApplyLowPowerScreenPercentage` or exec `r.ScreenPercentage`.
enum FELUnrealScalabilityBridge {
    static let lowPowerKey = "felLowPowerViewportMode"

    /// Low Power: `r.ScreenPercentage 75` vs `100` — boosts FPS during Bonds Apex / heavy VFX.
    static func setLowPowerMode(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: lowPowerKey)
        let cmd = enabled ? "r.ScreenPercentage 75" : "r.ScreenPercentage 100"
        NotificationCenter.default.post(
            name: .felUnrealConsoleCommandRequested,
            object: nil,
            userInfo: ["command": cmd, "lowPower": enabled]
        )
    }

    static var isLowPowerMode: Bool {
        UserDefaults.standard.bool(forKey: lowPowerKey)
    }
}
