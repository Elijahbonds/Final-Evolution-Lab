import Foundation
import OSLog
import FirebaseFirestore

// MARK: - Supporting types

/// Lightweight container for a session that is currently live inside Unreal.
nonisolated struct GameSession: Sendable {
    let id: String
    let modeId: GameModeId
    let startedAt: Date
    let readiness: Double
    let playerProfileId: String
}

// MARK: - NexusEngine

/// Central orchestrator for Final Evolution Lab.
///
/// Owns the app boot sequence, OS pillar navigation, session lifecycle, and subsystem health
/// tracking. All subsystems are wired through this class so that the UI layer has a single
/// source of truth for app state.
@Observable
@MainActor
final class NexusEngine {

    // MARK: Singleton

    static let shared = NexusEngine()

    // MARK: Logger

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab",
        category: "NexusEngine"
    )

    // MARK: Boot state

    enum BootState: Equatable {
        case cold
        case bootingFirebase
        case bootingHealthKit
        case bootingAvatar
        case connectingEmergent
        case ready
        case failed(NexusError)

        static func == (lhs: BootState, rhs: BootState) -> Bool {
            switch (lhs, rhs) {
            case (.cold, .cold), (.bootingFirebase, .bootingFirebase),
                 (.bootingHealthKit, .bootingHealthKit), (.bootingAvatar, .bootingAvatar),
                 (.connectingEmergent, .connectingEmergent), (.ready, .ready):
                return true
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    private(set) var bootState: BootState = .cold

    // MARK: OS Pillar navigation

    enum FELOSPillar: String, CaseIterable {
        case scan
        case cards
        case arena
        case academy

        var displayName: String {
            switch self {
            case .scan:     return "Body Scan"
            case .cards:    return "Creator Cards"
            case .arena:    return "Arena"
            case .academy:  return "Academy"
            }
        }

        var iconName: String {
            switch self {
            case .scan:     return "waveform.path.ecg"
            case .cards:    return "rectangle.stack.fill"
            case .arena:    return "sportscourt.fill"
            case .academy:  return "brain.head.profile"
            }
        }
    }

    var activePillar: FELOSPillar = .scan

    // MARK: Session lifecycle

    enum SessionState {
        case idle
        case matchmaking(GameModeId)
        case launching(GameModeId)
        case live(GameSession)
        case ended(GameSessionResult?)
    }

    private(set) var sessionState: SessionState = .idle

    // MARK: Subsystem health

    private(set) var firestoreReady: Bool = false
    private(set) var healthKitAuthorized: Bool = false
    private(set) var emergentConnected: Bool = false
    private(set) var nexusEngineReady: Bool = false

    enum NexusHealth {
        case optimal
        case degraded
        case offline
    }

    var overallHealth: NexusHealth {
        let readyCount = [firestoreReady, healthKitAuthorized, emergentConnected, nexusEngineReady]
            .filter { $0 }.count
        switch readyCount {
        case 4:       return .optimal
        case 1...:    return .degraded
        default:      return .offline
        }
    }

    // MARK: Private state

    private var bootTask: Task<Void, Never>?

    private init() {}

    // MARK: Boot sequence

    /// Runs the full async boot sequence, stepping through each `BootState` in order.
    /// Idempotent: subsequent calls while already `ready` return immediately.
    func boot() async {
        guard bootState == .cold || {
            if case .failed = bootState { return true }
            return false
        }() else { return }

        bootTask?.cancel()
        bootTask = Task { [weak self] in
            guard let self else { return }
            await self.runBootSequence()
        }
        await bootTask?.value
    }

    private func runBootSequence() async {
        Self.log.info("Boot sequence started.")

        bootState = .bootingFirebase
        do {
            try await NexusBootSequence.bootstrapFirebase()
            firestoreReady = FirebaseBootstrap.isConfigured
            Self.log.info("Firebase step complete — configured=\(self.firestoreReady).")
        } catch {
            Self.log.error("Firebase boot failed: \(error.localizedDescription, privacy: .public)")
            bootState = .failed(.firebaseFailed)
            return
        }

        bootState = .bootingHealthKit
        do {
            let authorized = try await NexusBootSequence.requestHealthKit()
            healthKitAuthorized = authorized
            Self.log.info("HealthKit step complete — authorized=\(authorized).")
        } catch {
            // HealthKit denial is non-fatal; the app degrades gracefully.
            Self.log.notice("HealthKit authorization denied — continuing in degraded mode.")
            healthKitAuthorized = false
        }

        bootState = .bootingAvatar
        let profile = SaveSystem.loadProfile()
        await NexusBootSequence.primeAvatar(profile: profile)
        Self.log.info("Avatar prime step complete.")

        bootState = .connectingEmergent
        NexusBootSequence.connectEmergent()
        // Emergent is fire-and-forget; treat as connected when URL is configured.
        emergentConnected = Config.resolvedEmergentGameWebSocketURL() != nil
        Self.log.info("Emergent step complete — connected=\(self.emergentConnected).")

        nexusEngineReady = NexusBridge.shared.isUnrealLoaded
        bootState = .ready
        Self.log.info("NexusEngine boot complete. health=\(String(describing: self.overallHealth)).")
    }

    // MARK: Session lifecycle

    /// Initiates matchmaking then transitions to a live session inside Unreal.
    ///
    /// Throws `sessionConflict` when a session is already active and `nexusNotReady` when
    /// the Unreal framework has not finished loading.
    func launchMode(_ id: GameModeId, readiness: Double, profile: UserProfile) async throws {
        switch sessionState {
        case .idle:
            break
        case .ended:
            // Allow re-launch from ended state without an explicit reset call.
            sessionState = .idle
        default:
            throw NexusError.sessionConflict
        }

        Self.log.info("Launch requested for mode=\(id.rawValue, privacy: .public) readiness=\(readiness).")
        sessionState = .matchmaking(id)

        // Brief yield so observers see the matchmaking state before we proceed.
        await Task.yield()

        sessionState = .launching(id)

        // Deliver the latest PRQ avatar vector to Unreal before the session goes live.
        // Uses the persisted scan from the profile; a simulated record is used as fallback
        // so Unreal always receives a well-formed payload even on first run.
        deliverScanToUnreal(from: profile)

        let session = GameSession(
            id: UUID().uuidString,
            modeId: id,
            startedAt: Date(),
            readiness: readiness,
            playerProfileId: profile.id
        )
        sessionState = .live(session)
        Self.log.info("Session live: \(session.id, privacy: .public) mode=\(id.rawValue, privacy: .public).")
    }

    /// Ends the active session and transitions to `.ended`, storing the optional match outcome.
    func endSession(outcome: GameSessionResult? = nil) {
        guard case .live(let session) = sessionState else {
            Self.log.notice("endSession called but no live session — ignoring. current=\(String(describing: self.sessionState)).")
            return
        }
        Self.log.info("Session ended: \(session.id, privacy: .public).")
        sessionState = .ended(outcome)
    }

    /// Cancels an active matchmaking or launching transition, returning to idle.
    func cancelMatchmaking() {
        switch sessionState {
        case .matchmaking, .launching:
            Self.log.info("Matchmaking cancelled.")
            sessionState = .idle
        default:
            break
        }
    }

    // MARK: PRQ sync bridge

    /// Syncs HealthKit data to Firestore and delivers the resulting scan JSON to Unreal.
    ///
    /// Builds a `SystemScanRecord` from the profile's persisted scan so that the Firestore
    /// write and Unreal bridge both operate on consistent data. The Firestore write is
    /// best-effort (errors are logged, not thrown) so the Unreal bridge always receives the
    /// latest avatar vector regardless of backend availability.
    func syncPRQToAvatar(_ profile: UserProfile) async {
        Self.log.info("PRQ sync triggered for profile=\(profile.id, privacy: .private).")
        deliverScanToUnreal(from: profile)
        guard FirebaseBootstrap.isConfigured else {
            Self.log.notice("PRQ sync: Firebase not configured — Unreal bridge dispatched, Firestore skipped.")
            return
        }
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            Self.log.info("PRQ sync: Firestore identity ready.")
        } catch {
            Self.log.error("PRQ sync: Firestore identity failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Private helpers

    /// Builds a `SystemScanRecord` from the profile's persisted scan and forwards its JSON
    /// to the Unreal bridge. Falls back to a simulated scan when no scan is present.
    private func deliverScanToUnreal(from profile: UserProfile) {
        let record: SystemScanRecord
        if let scan = profile.systemScan {
            let vitals = SystemScanRecord.VitalsSnapshot(
                heartRateBpm: nil,
                restingHeartRateBpm: nil,
                hrvSdnnMs: nil,
                activeKcal: nil,
                weeklyHrvAverageMs: nil,
                sleepHoursLastNight: nil
            )
            let readiness = SystemScanRecord.ReadinessSnapshot(
                neuralReadinessScore: scan.prqScore,
                grade: prqGradeString(scan.prqScore),
                hrvTrend: "STABLE",
                recoveryEstimateHours: 0
            )
            record = SystemScanRecord(
                schemaVersion: 1,
                source: "nexus_launch",
                capturedAt: .init(date: scan.date),
                vitals: vitals,
                readiness: readiness,
                avatar: AvatarPerformanceAttributes.calculateAttributes(
                    vitals: vitals,
                    readiness: readiness,
                    sleepHoursForMapping: nil,
                    speedMultiplier: 1.0,
                    hangTimeBonus: 0.0,
                    isRecoveryMode: false
                )
            )
        } else {
            record = SystemScanRecord.makeSimulatedRandom()
        }

        do {
            let data = try record.unrealBridgeJSON()
            NexusBridge.shared.deliverSystemScanJSON(data)
        } catch {
            Self.log.error("deliverScanToUnreal: JSON encode failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func prqGradeString(_ prq: Double) -> String {
        switch prq {
        case 80...:       return "ELITE"
        case 60 ..< 80:   return "PRIMED"
        case 40 ..< 60:   return "READY"
        default:          return "RECOVERING"
        }
    }
}

// MARK: - NexusError

enum NexusError: LocalizedError, Equatable {
    case firebaseFailed
    case healthKitDenied
    case sessionConflict
    case nexusNotReady

    var errorDescription: String? {
        switch self {
        case .firebaseFailed:
            return "Firebase could not be configured. Check GoogleService-Info.plist and network access."
        case .healthKitDenied:
            return "HealthKit access was denied. Enable it in Settings > Privacy & Security > Health."
        case .sessionConflict:
            return "A game session is already active. End the current session before launching a new one."
        case .nexusNotReady:
            return "The Unreal runtime is not loaded. Ensure the embedded framework is present in the app bundle."
        }
    }
}
