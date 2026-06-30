import Foundation
import OSLog
import FirebaseFirestore

// MARK: - Supporting types

/// Lightweight container for a session that is currently live inside the Nexus engine.
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
/// Owns the app boot sequence, pillar navigation, session lifecycle, and subsystem health.
/// NexusEngine coordinates native subsystems — Firebase, HealthKit, NexusRenderer, EmergentWS —
/// without delegating to any external runtime. All game rendering runs through NexusRenderer
/// and is displayed by NexusSceneView. NexusBridge provides the data relay layer.
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
        case bootingRenderer
        case connectingEmergent
        case ready
        case failed(NexusError)

        static func == (lhs: BootState, rhs: BootState) -> Bool {
            switch (lhs, rhs) {
            case (.cold, .cold), (.bootingFirebase, .bootingFirebase),
                 (.bootingHealthKit, .bootingHealthKit), (.bootingRenderer, .bootingRenderer),
                 (.connectingEmergent, .connectingEmergent), (.ready, .ready):
                return true
            case (.failed(let a), .failed(let b)):
                return a == b
            default:
                return false
            }
        }

        var displayLabel: String {
            switch self {
            case .cold:                return "Initializing"
            case .bootingFirebase:     return "Connecting to cloud"
            case .bootingHealthKit:    return "Linking HealthKit"
            case .bootingRenderer:     return "Loading Nexus renderer"
            case .connectingEmergent:  return "Joining arena network"
            case .ready:               return "Ready"
            case .failed:              return "Boot failed"
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
            case .scan:     "Body Scan"
            case .cards:    "Creator Cards"
            case .arena:    "Arena"
            case .academy:  "Academy"
            }
        }

        var iconName: String {
            switch self {
            case .scan:     "waveform.path.ecg"
            case .cards:    "rectangle.stack.fill"
            case .arena:    "sportscourt.fill"
            case .academy:  "brain.head.profile"
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
        case 4:      return .optimal
        case 1...:   return .degraded
        default:     return .offline
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
        Self.log.info("NexusEngine boot sequence started.")

        // Step 1 — Firebase
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

        // Step 2 — HealthKit
        bootState = .bootingHealthKit
        do {
            let authorized = try await NexusBootSequence.requestHealthKit()
            healthKitAuthorized = authorized
            Self.log.info("HealthKit step complete — authorized=\(authorized).")
        } catch {
            // Denial is non-fatal; app degrades gracefully.
            Self.log.notice("HealthKit authorization denied — continuing in degraded mode.")
            healthKitAuthorized = false
        }

        // Step 3 — Native renderer prime
        bootState = .bootingRenderer
        let profile = SaveSystem.loadProfile()
        let arcadePhysics = ArcadePhysics.fromPRQ(
            profile.metrics.prqScore,
            neuralDrive: profile.metrics.neuralDrive,
            audit: nil
        )
        await NexusRenderer.shared.prime(arcadePhysics: arcadePhysics, prq: profile.metrics.prqScore)
        await NexusBootSequence.primeAvatar(profile: profile)
        nexusEngineReady = NexusRenderer.shared.isReady
        Self.log.info("Nexus renderer primed — ready=\(self.nexusEngineReady).")

        // Step 4 — Emergent WebSocket
        bootState = .connectingEmergent
        NexusBootSequence.connectEmergent()
        emergentConnected = Config.resolvedEmergentGameWebSocketURL() != nil
        Self.log.info("Emergent step complete — connected=\(self.emergentConnected).")

        bootState = .ready
        Self.log.info("NexusEngine boot complete. health=\(String(describing: self.overallHealth)).")
    }

    // MARK: Session lifecycle

    /// Initiates matchmaking then transitions to a live session with a loaded NexusScene.
    ///
    /// Throws `sessionConflict` when a session is already active and `nexusNotReady` when
    /// the Nexus renderer has not finished loading.
    func launchMode(_ id: GameModeId, readiness: Double, profile: UserProfile) async throws {
        switch sessionState {
        case .idle:
            break
        case .ended:
            sessionState = .idle
        default:
            throw NexusError.sessionConflict
        }

        guard nexusEngineReady else {
            throw NexusError.nexusNotReady
        }

        Self.log.info("Launch requested: mode=\(id.rawValue, privacy: .public) readiness=\(readiness).")
        sessionState = .matchmaking(id)
        await Task.yield()

        sessionState = .launching(id)

        // Build and load a scene for this mode with current PRQ physics
        let scene = NexusScene.default(for: id, prq: readiness)
        NexusRenderer.shared.loadScene(scene)

        // Sync latest PRQ into the renderer
        NexusRenderer.shared.applyPRQ(readiness)

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
            Self.log.notice("endSession called but no live session — ignoring.")
            return
        }
        Self.log.info("Session ended: \(session.id, privacy: .public).")
        NexusRenderer.shared.unloadScene()
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

    // MARK: PRQ sync

    /// Syncs the latest PRQ/scan data into NexusRenderer, updating active scene physics.
    func syncPRQToRenderer(_ profile: UserProfile) async {
        Self.log.info("PRQ sync triggered for profile=\(profile.id, privacy: .private).")
        NexusRenderer.shared.applyPRQ(profile.metrics.prqScore)
        guard FirebaseBootstrap.isConfigured else {
            Self.log.notice("PRQ sync: Firebase not configured — renderer updated, Firestore skipped.")
            return
        }
        do {
            try await FirebaseIdentity.ensureUserSignedIn()
            Self.log.info("PRQ sync: Firestore identity confirmed.")
        } catch {
            Self.log.error("PRQ sync: Firestore identity failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Avatar appearance

    func updateAvatarAppearance(outfitId: String, tintHex: String) {
        NexusRenderer.shared.applyAvatarAppearance(outfitId: outfitId, tintHex: tintHex)
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
            return "The Nexus renderer is not ready. Wait for the boot sequence to complete before launching a mode."
        }
    }
}
