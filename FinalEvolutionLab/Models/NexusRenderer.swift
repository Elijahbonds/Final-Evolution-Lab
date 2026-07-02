import Foundation
import OSLog

// MARK: - NexusRenderer

/// Native rendering and physics subsystem for the Nexus game engine.
///
/// Replaces the embedded Unreal runtime. Owns the active scene, player physics
/// state, and all data payloads that previously were forwarded to UE via ObjC selectors.
/// Backed by the SwiftUI Canvas pipeline defined in NexusSceneView.
@Observable
@MainActor
final class NexusRenderer {

    static let shared = NexusRenderer()

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab",
        category: "NexusRenderer"
    )

    // MARK: - State

    private(set) var isReady: Bool = false
    private(set) var activeScene: NexusScene?
    private(set) var playerPhysics: NexusPhysicsConfig = NexusPhysicsConfig()
    private(set) var firebaseUID: String = ""
    private(set) var isSocialBackendOnline: Bool = false

    // MARK: - Pending payloads (buffered before prime)

    private var pendingPRQ: Double?
    private var pendingFirebasePayload: [String: Any]?
    private var pendingBodyIQSnack: [String: Any]?

    private init() {}

    // MARK: - Lifecycle

    /// Primes the renderer with the player's current ArcadePhysics state.
    /// Should be called during the NexusEngine boot sequence after profile load.
    func prime(arcadePhysics: ArcadePhysics, prq: Double) async {
        var config = NexusPhysicsConfig()
        config.applyPRQ(prq)
        // Layer in fine-grained ArcadePhysics multipliers
        config.prqSpeedMultiplier *= arcadePhysics.explosiveFirstStep
        config.prqJumpBonus += Double(arcadePhysics.hangTimeMultiplier - 1.0) * 3.0
        playerPhysics = config
        isReady = true

        flushPendingPayloads()

        Self.log.info("NexusRenderer primed. PRQ=\(prq, privacy: .public) speed=\(config.prqSpeedMultiplier, privacy: .public) jump=\(config.prqJumpBonus, privacy: .public)")
    }

    // MARK: - Scene management

    func loadScene(_ scene: NexusScene) {
        activeScene = scene
        Self.log.info("Scene loaded: \(scene.name, privacy: .public) mode=\(scene.gameModeId.rawValue, privacy: .public) entities=\(scene.entities.count)")
    }

    func updateScene(_ transform: (inout NexusScene) -> Void) {
        guard activeScene != nil else { return }
        transform(&activeScene!)
    }

    func unloadScene() {
        Self.log.info("Scene unloaded: \(self.activeScene?.name ?? "none", privacy: .public)")
        activeScene = nil
    }

    // MARK: - PRQ sync (called when player scan or HealthKit data updates)

    func applyPRQ(_ prq: Double) {
        guard isReady else {
            pendingPRQ = prq
            return
        }
        playerPhysics.applyPRQ(prq)
        activeScene?.physicsConfig.applyPRQ(prq)
        Self.log.info("PRQ applied: \(prq, privacy: .public) → speed=\(self.playerPhysics.prqSpeedMultiplier)")
    }

    // MARK: - Firebase identity (previously delivered to UE via receiveFirebaseBridgeJSON:)

    func applyFirebaseIdentity(uid: String, socialOnline: Bool, anonymous: Bool) {
        firebaseUID = uid
        isSocialBackendOnline = socialOnline
        pendingFirebasePayload = [
            "firebaseUid": uid,
            "socialSqlOnline": socialOnline,
            "anonymous": anonymous,
        ]
        if isReady {
            Self.log.debug("Firebase identity applied: uid=\(uid.isEmpty ? "none" : "set", privacy: .private) social=\(socialOnline)")
        } else {
            Self.log.notice("Firebase identity buffered — renderer not primed yet.")
        }
    }

    // MARK: - Body IQ snacks (corrective movement sequences)

    func applyBodyIQSnack(_ snack: MovementSnack) {
        let payload: [String: Any] = [
            "type": "body_iq_snack",
            "snackId": snack.id,
            "animationAssetId": snack.requiredAnimationAssetID,
            "correctivePoseId": snack.correctivePoseAssetID,
            "durationSeconds": snack.durationSeconds,
            "targetCategories": snack.targetedCategories.map(\.rawValue),
        ]
        pendingBodyIQSnack = payload
        if isReady {
            Self.log.debug("Body IQ snack queued for next scene load: \(snack.id, privacy: .public)")
        }
    }

    // MARK: - Avatar appearance

    func applyAvatarAppearance(outfitId: String, tintHex: String) {
        Self.log.info("Avatar appearance updated: outfit=\(outfitId, privacy: .public)")
        guard var scene = activeScene else { return }
        // Find skeleton components and update their amplitude based on outfit tier
        for i in scene.entities.indices {
            for j in scene.entities[i].components.indices {
                if case .skeleton(let cat, _) = scene.entities[i].components[j] {
                    scene.entities[i].components[j] = .skeleton(category: cat, amplitude: playerPhysics.prqSpeedMultiplier)
                }
            }
        }
        activeScene = scene
    }

    // MARK: - Private

    private func flushPendingPayloads() {
        if let prq = pendingPRQ {
            playerPhysics.applyPRQ(prq)
            pendingPRQ = nil
            Self.log.info("Flushed pending PRQ: \(prq)")
        }
        if let payload = pendingFirebasePayload {
            firebaseUID = payload["firebaseUid"] as? String ?? ""
            isSocialBackendOnline = payload["socialSqlOnline"] as? Bool ?? false
            pendingFirebasePayload = nil
            Self.log.debug("Flushed pending Firebase identity.")
        }
    }
}
