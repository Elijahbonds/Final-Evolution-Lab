import Foundation

// MARK: - Unity / External → Native Bridge (Pure Swift)
// When the Unity iOS build is embedded, the ObjC bridge should post
// NSNotification "PRQScoreUpdated" with userInfo["score"] = Int.
// This file provides the native-side API and standalone testing.
//
// Data flow: External (Unity C# / ObjC) → post "PRQScoreUpdated"
// → PRQScoreManager.shared observes and updates UI

nonisolated enum PRQNativeBridge: Sendable {
    static func postScore(_ score: Int) {
        NotificationCenter.default.post(
            name: NSNotification.Name("PRQScoreUpdated"),
            object: nil,
            userInfo: ["score": score]
        )
    }

    static func postMetrics(_ metrics: [String: Any]) {
        NotificationCenter.default.post(
            name: NSNotification.Name("PRQMetricsUpdated"),
            object: nil,
            userInfo: metrics
        )
    }
}
