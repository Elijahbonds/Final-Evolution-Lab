import Foundation

// MARK: - Unity → Native Bridge (Pure Swift)
// This file is the native-side API for Unity bridge calls.
// It posts NSNotification "RorkScoreUpdated" with userInfo["score"] = Int.
//
// Unity data flow:
//   Unity C# → RorkBridge.SendScoreToNative(prqScore)
//   → _PostRorkScore(score) exported from Swift via @_cdecl
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

// C-export expected by Unity C# DllImport("__Internal").
// Unity iOS can call this directly without requiring Objective-C bridge code.
@_cdecl("_PostRorkScore")
func _PostRorkScore(_ score: Int32) {
    RorkNativeBridge.postScore(Int(score))
}
