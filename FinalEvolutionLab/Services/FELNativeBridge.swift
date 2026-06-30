import Foundation

// MARK: - Unity → Native Bridge (Pure Swift)
// When the Unity iOS build is embedded, the ObjC bridge (FELNativeBridge.mm)
// posts NSNotification "FELScoreUpdated" with userInfo["score"] = Int.
// This Swift file provides equivalent functionality for standalone testing
// and serves as the native-side API for the Unity bridge.
//
// Unity data flow:
//   Unity C# → FELBridge.SendScoreToNative(prqScore)
//   → _PostFELScore(score) in FELNativeBridge.mm
//   → NSNotification "FELScoreUpdated"
//   → FELScoreManager.shared observes and updates UI

nonisolated enum FELNativeBridge: Sendable {
    static func postScore(_ score: Int) {
        NotificationCenter.default.post(
            name: NSNotification.Name("FELScoreUpdated"),
            object: nil,
            userInfo: ["score": score]
        )
    }

    static func postMetrics(_ metrics: [String: Any]) {
        NotificationCenter.default.post(
            name: NSNotification.Name("FELMetricsUpdated"),
            object: nil,
            userInfo: metrics
        )
    }
}
