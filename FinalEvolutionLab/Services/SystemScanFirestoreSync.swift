import Foundation
import OSLog
import FirebaseFirestore

extension Notification.Name {
    /// Posted after Firestore persist + ``UnrealManager``/Emergent bridge dispatch for a system scan.
    static let felSystemScanBridgeCompleted = Notification.Name("felSystemScanBridgeCompleted")
}

/// Writes System Scan snapshots to Firestore for cross-device sync and Unreal consumption.
/// Encoding and Firestore batches run off the main actor so large stability payloads do not block UI.
final class SystemScanFirestoreSync {
    static let shared = SystemScanFirestoreSync()

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab", category: "SystemScanFirestore")

    private init() {}

    private var db: Firestore? {
        guard FirebaseBootstrap.isConfigured else { return nil }
        return Firestore.firestore()
    }

    /// Persists a historical scan and upserts the latest avatar vector for UE.
    func syncLatestFromHealthKit(_ health: HealthKitService) async throws {
        let scan = await MainActor.run {
            SystemScanRecord.makeFromHealthKit(health)
        }
        await syncScanWithDegradation(scan)
    }

    /// Debug: random realistic scan → Firestore + same bridge path as HealthKit (no HealthKit required).
    func syncSimulatedDebugScan() async throws {
        let scan = SystemScanRecord.makeSimulatedRandom()
        await syncScanWithDegradation(scan)
    }

    /// Golden loop should not block on backend availability.
    /// - Always: bridge to Unreal + optional WebSocket immediately.
    /// - Best-effort: persist to Firestore; on failure, enqueue locally and retry later.
    private func syncScanWithDegradation(_ scan: SystemScanRecord) async {
        await deliverScanToBridge(scan)

        guard FirebaseBootstrap.isConfigured else {
            SaveSystem.enqueuePendingSystemScan(scan)
            Self.log.notice("Firebase not configured — scan queued locally for later Firestore sync.")
            return
        }

        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            try await flushPendingScansIfPossible()
            try await persistScan(scan)
        } catch {
            SaveSystem.enqueuePendingSystemScan(scan)
            Self.log.error("Firestore persist failed — scan queued locally: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persistScan(_ scan: SystemScanRecord) async throws {
        guard let db, let uid = FirebaseIdentity.userId else { return }
        let encoder = Firestore.Encoder()
        let batch = db.batch()
        let scanRef = db.collection("users").document(uid).collection("system_scans").document()
        try batch.setData(from: scan, forDocument: scanRef, encoder: encoder)
        let avatarRef = db.collection("users").document(uid).collection("avatar_performance").document("current")
        try batch.setData(from: scan.avatar, forDocument: avatarRef, merge: true, encoder: encoder)
        try await batch.commit()
    }

    private func flushPendingScansIfPossible() async throws {
        guard db != nil else { return }
        var pending = SaveSystem.loadPendingSystemScans()
        guard !pending.isEmpty else { return }

        while let scan = pending.first {
            do {
                try await persistScan(scan)
                pending.removeFirst()
                SaveSystem.replacePendingSystemScans(pending)
            } catch {
                throw error
            }
        }
    }

    private func deliverScanToBridge(_ scan: SystemScanRecord) async {
        let data: Data
        do {
            data = try scan.unrealBridgeJSON()
        } catch {
            Self.log.error("unrealBridgeJSON encode failed — Unreal/WebSocket bridges skipped: \(error.localizedDescription, privacy: .public)")
#if DEBUG
            print("[SystemScanFirestoreSync] unrealBridgeJSON failed: \(error)")
#endif
            return
        }
        await MainActor.run {
            UnrealManager.shared.deliverSystemScanJSON(data)
            EmergentRealtimeClient.shared.sendSystemScanBridge(data)
            NotificationCenter.default.post(name: .felSystemScanBridgeCompleted, object: nil)
        }
        Task { @MainActor in
            await TrainingLabSocialBridge.shared.syncTrainingProfileFromScan(scan)
            if shouldPresentScanAchievement(scan) {
                let headlinePRQ = scan.avatar.verifiedPerformancePRQ ?? scan.avatar.readinessScore
                SocialShareCoordinator.shared.presentScanAchievement(
                    prq: headlinePRQ,
                    grade: scan.readiness.grade
                )
            }
        }
    }

    /// No celebration for pure readiness/vitals sync — require verified competitive PRQ or pose confidence (SCAN-54).
    private func shouldPresentScanAchievement(_ scan: SystemScanRecord) -> Bool {
        if let verified = scan.avatar.verifiedPerformancePRQ, verified > 0 { return true }
        if let pose = scan.stability?.poseConfidence01, pose >= 0.55 { return true }
        return false
    }
}
