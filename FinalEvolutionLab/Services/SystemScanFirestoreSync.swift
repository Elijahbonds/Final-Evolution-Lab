import Foundation
import OSLog
import FirebaseFirestore

extension Notification.Name {
    /// Posted after Firestore persist + NEXUS bridge dispatch for a system scan.
    static let felSystemScanBridgeCompleted = Notification.Name("felSystemScanBridgeCompleted")
}

/// Writes System Scan snapshots to Firestore for cross-device sync and NEXUS gameplay consumption.
/// Encoding and Firestore batches run off the main actor so large stability payloads do not block UI.
final class SystemScanFirestoreSync {
    static let shared = SystemScanFirestoreSync()

    private static let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab", category: "SystemScanFirestore")

    private init() {}

    private var db: Firestore? {
        guard FirebaseBootstrap.isConfigured else { return nil }
        return Firestore.firestore()
    }

    /// Persists a historical scan and upserts the latest avatar vector for cross-device sync + NEXUS bridge.
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
    /// - Always: bridge to NEXUS gameplay + optional WebSocket immediately.
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
        await MainActor.run {
            deliverScanToNexusBridge(scan)
        }

        let data: Data
        do {
            data = try scan.felScanBridgeJSON()
        } catch {
            Self.log.error("felScanBridgeJSON encode failed — WebSocket bridge skipped: \(error.localizedDescription, privacy: .public)")
#if DEBUG
            print("[SystemScanFirestoreSync] felScanBridgeJSON failed: \(error)")
#endif
            return
        }
        await MainActor.run {
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

    /// Pushes readiness + fitness scalars into a short-lived NEXUS gameplay session.
    @MainActor
    private func deliverScanToNexusBridge(_ scan: SystemScanRecord) {
        guard NexusGameplayBridge.isLinked else {
            Self.log.notice("NEXUS bridge not linked — system scan fitness sync skipped.")
            return
        }
        guard let session = NexusGameplayBridge.createSession() else { return }
        defer { NexusGameplayBridge.destroySession(session) }

        let avatar = scan.avatar
        NexusGameplayBridge.syncReadiness(session, readiness: Float(avatar.readinessScore))

        let params: [String: Any] = [
            "frc_mobility": avatar.biomechanicalEfficiency,
            "frc_active_range": avatar.explosiveness,
            "frc_control": avatar.neuralFocus,
            "iap_engagement": avatar.endurance,
            "iap_confidence": avatar.recovery,
            "breath_phase": avatar.isRecoveryMode ? 0 : 1,
        ]
        let payload: [String: Any] = [
            "command": "fel.fitness.update",
            "id": "ios_system_scan_\(Int(scan.capturedAt.dateValue().timeIntervalSince1970))",
            "params": params,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8)
        else { return }
        _ = NexusGameplayBridge.handleCommand(session, commandJson: json)
        Self.log.debug("System scan delivered to NEXUS bridge (readiness=\(avatar.readinessScore, privacy: .public)).")
    }

    /// No celebration for pure readiness/vitals sync — require verified competitive PRQ or pose confidence (SCAN-54).
    private func shouldPresentScanAchievement(_ scan: SystemScanRecord) -> Bool {
        if let verified = scan.avatar.verifiedPerformancePRQ, verified > 0 { return true }
        if let pose = scan.stability?.poseConfidence01, pose >= 0.55 { return true }
        return false
    }
}
