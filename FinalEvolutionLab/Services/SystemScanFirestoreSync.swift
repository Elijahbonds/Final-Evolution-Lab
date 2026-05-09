import Foundation
import FirebaseFirestore

/// Writes System Scan snapshots to Firestore for cross-device sync and Unreal consumption.
@MainActor
final class SystemScanFirestoreSync {
    static let shared = SystemScanFirestoreSync()

    private init() {}

    private var db: Firestore? {
        guard FirebaseBootstrap.isConfigured else { return nil }
        return Firestore.firestore()
    }

    /// Persists a historical scan and upserts the latest avatar vector for UE.
    func syncLatestFromHealthKit(_ health: HealthKitService) async throws {
        guard let db else { return }
        try await FirebaseIdentity.ensureUserSignedIn()
        guard let uid = FirebaseIdentity.userId else { return }

        let scan = SystemScanRecord.makeFromHealthKit(health)
        let encoder = Firestore.Encoder()

        let batch = db.batch()
        let scanRef = db.collection("users").document(uid).collection("system_scans").document()
        try batch.setData(from: scan, forDocument: scanRef, encoder: encoder)

        let avatarRef = db.collection("users").document(uid).collection("avatar_performance").document("current")
        try batch.setData(from: scan.avatar, forDocument: avatarRef, merge: true, encoder: encoder)

        try await batch.commit()
    }
}
