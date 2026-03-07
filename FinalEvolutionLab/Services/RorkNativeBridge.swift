import Foundation

// MARK: - Unity → Native Bridge (Pure Swift)
// When the Unity iOS build is embedded, the ObjC bridge (RorkNativeBridge.mm)
// posts NSNotification "RorkScoreUpdated" with userInfo["score"] = Int.
// This Swift file provides equivalent functionality for standalone testing
// and serves as the native-side API for the Unity bridge.
//
// Unity data flow:
//   Unity C# → RorkBridge.SendScoreToNative(prqScore)
//   → _PostRorkScore(score) in RorkNativeBridge.mm
//   → NSNotification "RorkScoreUpdated"
//   → RorkScoreManager.shared observes and updates UI

nonisolated enum RorkNativeBridge: Sendable {
    static func postScore(_ score: Int) {
        NotificationCenter.default.post(
            name: NSNotification.Name("RorkScoreUpdated"),
            object: nil,
            userInfo: ["score": score]
        )
    }

    static func postMetrics(_ metrics: [String: Any]) {
        NotificationCenter.default.post(
            name: NSNotification.Name("RorkMetricsUpdated"),
            object: nil,
            userInfo: metrics
        )
    }
}
