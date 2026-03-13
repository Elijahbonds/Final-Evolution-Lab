import Foundation

// MARK: - Game Engine → Native Bridge (Pure Swift)
// This file is the native-side API for embedded engine bridge calls
// (Unity and Unreal).
// It posts NSNotification "RorkScoreUpdated" with userInfo["score"] = Int.
//
// Example data flow:
//   Game runtime -> _PostRorkScore(score)
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

// C-export consumed by game runtimes on iOS.
// This can be called from Unity (DllImport) or Unreal (extern symbol).
@_cdecl("_PostRorkScore")
func _PostRorkScore(_ score: Int32) {
    RorkNativeBridge.postScore(Int(score))
}
