import Foundation

/// Handles `FELNativeCallProxy` notifications (Unity → native via `DllImport("__Internal")`).
enum FELUnityNativeCallbacks {
    static let exerciseComplete = Notification.Name("FEL_OnExerciseComplete")
    static let updateUserXP = Notification.Name("FEL_UpdateUserXP")
    static let repCompleted = Notification.Name("FEL_OnRepCompleted")

    @MainActor
    static func register() {
        NotificationCenter.default.addObserver(forName: exerciseComplete, object: nil, queue: .main) { note in
            guard let json = note.userInfo?["json"] as? String else { return }
            PRQNativeBridge.postMetrics(["unityExerciseComplete": json])
        }
        NotificationCenter.default.addObserver(forName: updateUserXP, object: nil, queue: .main) { note in
            guard let xp = note.userInfo?["xp"] as? Int else { return }
            PRQNativeBridge.postMetrics(["unityXP": xp])
        }
        NotificationCenter.default.addObserver(forName: repCompleted, object: nil, queue: .main) { note in
            guard let shards = note.userInfo?["shards"] as? Int else { return }
            PRQNativeBridge.postMetrics(["unityRepShards": shards])
        }
    }
}
