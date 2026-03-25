import Foundation

/// Unity / embedded runtimes call into Swift via `NativeCallProxy` (see `UnityManager`).
/// Unreal uses the inverse: C++ posts `Notification.Name.felUnrealSessionResultsReady` / `felUnrealExitToDashboard`
/// (`FELNativeBridge_IOS.mm` + `FELBridgeNotifications.swift`).

@objc public protocol NativeCallsProtocol {
    func onExerciseComplete(_ exerciseId: String, score: Int32)
    func updateUserXP(_ addedXP: Int32)
    func onRepCompleted(_ shards: Int32)
    func onWorkoutSummary(_ summaryJson: String)
}

@objc public class NativeCallProxyImpl: NSObject, NativeCallsProtocol {
    public static let shared = NativeCallProxyImpl()
    
    public func onExerciseComplete(_ exerciseId: String, score: Int32) {
        print("[NativeCallProxyImpl] Swift received onExerciseComplete - ID: \(exerciseId), Score: \(score)")
        // Logic to update UI or backend
    }
    
    public func updateUserXP(_ addedXP: Int32) {
        print("[NativeCallProxyImpl] Swift received updateUserXP - Added XP: \(addedXP)")
        // Logic to award XP
    }
    
    public func onRepCompleted(_ shards: Int32) {
        print("[NativeCallProxyImpl] Swift received onRepCompleted - Earned Shards: \(shards)")
        // Logic to update Shards
    }
    
    public func onWorkoutSummary(_ summaryJson: String) {
        print("[NativeCallProxyImpl] Swift received onWorkoutSummary - JSON: \(summaryJson)")
        // Parse and log workout summary
    }
}
