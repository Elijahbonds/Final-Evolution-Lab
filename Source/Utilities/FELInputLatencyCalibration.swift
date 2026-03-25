import Foundation

/// Neuro-Mechanic HUD — aligns Swift overlay with Unreal `InputLatencyMonitor` (AUDIT_QUALITY / SHIP_CRITERIA).
enum FELInputLatencyCalibration {
    /// One frame @ 60 Hz ≈ 16.67 ms (`FELBasketballPlayerController.cpp` `kOneFrame60Ms`).
    static let oneFrame60HzMs: Double = 1000.0 / 60.0

    /// Unreal / native bridge writes ms here; Arena `FEL_NON_SHIPPING` HUD reads for DA COMPOUND video review.
    static let userDefaultsKey = "felInputToLaunchLatencyMs"
}
