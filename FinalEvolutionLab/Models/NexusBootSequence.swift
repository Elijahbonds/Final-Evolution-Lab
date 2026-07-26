import Foundation
import OSLog
import FirebaseFirestore

// MARK: - NexusBootSequence

/// Static helpers that encapsulate each async step of the NexusEngine boot sequence.
///
/// Keeping the steps here prevents NexusEngine from growing into a monolith and makes
/// each step independently testable.
struct NexusBootSequence {

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab",
        category: "NexusBootSequence"
    )

    // MARK: Step 1 — Firebase

    /// Configures the Firebase SDK and ensures an anonymous user session exists.
    ///
    /// Throws `NexusError.firebaseFailed` only when Firebase reports a hard failure.
    /// Missing `GoogleService-Info.plist` is treated as disabled-by-design rather than a crash.
    static func bootstrapFirebase() async throws {
        FirebaseBootstrap.configureIfNeeded()
        guard FirebaseBootstrap.isConfigured else {
            log.notice("Firebase not configured — plist missing or canImport(FirebaseCore) unavailable.")
            return
        }
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            log.info("Firebase identity ready: uid=\(FirebaseIdentity.userId ?? "nil", privacy: .private).")
        } catch {
            log.error("Firebase identity sign-in failed: \(error.localizedDescription, privacy: .public)")
            throw NexusError.firebaseFailed
        }
    }

    // MARK: Step 2 — HealthKit

    /// Requests HealthKit authorization and returns whether it was granted.
    ///
    /// Returns `false` (rather than throwing) when HealthKit is unavailable on device
    /// (e.g. iPadOS or simulator) so callers can degrade gracefully.
    @MainActor
    static func requestHealthKit() async throws -> Bool {
        let service = HealthKitService()
        guard service.isAvailable else {
            log.notice("HealthKit unavailable on this device.")
            return false
        }
        await service.requestAuthorization()
        if !service.isAuthorized {
            throw NexusError.healthKitDenied
        }
        return true
    }

    // MARK: Step 3 — Avatar / renderer prime

    /// Starts Firebase identity observation (so the data relay has an auth state)
    /// and delivers the player's persisted scan to NexusRenderer so physics are
    /// calibrated from the moment the first game mode launches.
    ///
    /// Non-throwing: any failure is logged and silently swallowed so it never blocks boot.
    @MainActor
    static func primeAvatar(profile: UserProfile) async {
        // Start watching Firebase Auth state — NexusBridge will push identity to NexusRenderer
        NexusBridge.shared.startFirebaseIdentityObservation()

        guard let scan = profile.systemScan else {
            log.notice("No system scan in profile — avatar prime skipped, using default PRQ physics.")
            return
        }

        let record = SystemScanRecord(
            schemaVersion: 1,
            source: "nexus_boot",
            capturedAt: .init(date: scan.date),
            vitals: SystemScanRecord.VitalsSnapshot(
                heartRateBpm: nil,
                restingHeartRateBpm: nil,
                hrvSdnnMs: nil,
                activeKcal: nil,
                weeklyHrvAverageMs: nil,
                sleepHoursLastNight: nil
            ),
            readiness: SystemScanRecord.ReadinessSnapshot(
                neuralReadinessScore: scan.prqScore,
                grade: prqGradeString(scan.prqScore),
                hrvTrend: "STABLE",
                recoveryEstimateHours: 0
            ),
            avatar: AvatarPerformanceAttributes.calculateAttributes(
                vitals: SystemScanRecord.VitalsSnapshot(
                    heartRateBpm: nil,
                    restingHeartRateBpm: nil,
                    hrvSdnnMs: nil,
                    activeKcal: nil,
                    weeklyHrvAverageMs: nil,
                    sleepHoursLastNight: nil
                ),
                readiness: SystemScanRecord.ReadinessSnapshot(
                    neuralReadinessScore: scan.prqScore,
                    grade: prqGradeString(scan.prqScore),
                    hrvTrend: "STABLE",
                    recoveryEstimateHours: 0
                ),
                sleepHoursForMapping: nil,
                speedMultiplier: 1.0,
                hangTimeBonus: 0.0,
                isRecoveryMode: false
            )
        )

        do {
            let data = try record.felScanBridgeJSON()
            // Route through NexusBridge → NexusRenderer (replaces the old Unreal ObjC path)
            NexusBridge.shared.deliverSystemScanJSON(data)
            log.info("Avatar prime: scan JSON relayed to NexusRenderer (PRQ=\(scan.prqScore, privacy: .public)).")
        } catch {
            log.error("Avatar prime: encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Step 4 — Emergent

    /// Connects the Emergent WebSocket client if a URL is configured.
    static func connectEmergent() {
        EmergentRealtimeClient.shared.startIfConfigured()
        log.info("Emergent realtime client start requested.")
    }

    // MARK: Helpers

    private static func prqGradeString(_ prq: Double) -> String {
        switch prq {
        case 80...:     return "ELITE"
        case 60 ..< 80: return "PRIMED"
        case 40 ..< 60: return "READY"
        default:        return "RECOVERING"
        }
    }
}
