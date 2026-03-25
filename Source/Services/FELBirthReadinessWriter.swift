import Foundation

nonisolated let felTwinBirthDidWriteNotification = Notification.Name("FelTwinBirthDidWrite")

/// First contact: `PRQManager` writes `readiness_snapshot.json`; call `notifyTwinBirth` after sync so Unreal / shell code can react.
enum FELBirthReadinessWriter {
    @MainActor
    static func notifyTwinBirth() {
        NotificationCenter.default.post(name: felTwinBirthDidWriteNotification, object: nil)
    }

    /// Call from the Bio-Sync loading screen after re-sync — includes absolute path for embedded Unreal hot-load.
    @MainActor
    static func notifyBioSyncComplete(snapshotURL: URL?) {
        var info: [String: Any] = [:]
        if let snapshotURL {
            info["readinessSnapshotPath"] = snapshotURL.path
        }
        NotificationCenter.default.post(name: .felBioSyncComplete, object: nil, userInfo: info)
        notifyTwinBirth()
    }
}
