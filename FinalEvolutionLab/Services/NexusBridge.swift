import Foundation
import OSLog
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

// MARK: - NexusBridge

/// Native data relay layer for the Nexus game engine.
///
/// Previously this class managed an embedded Unreal Engine framework via ObjC selectors.
/// It now routes data payloads (Firebase identity, system scan JSON, avatar appearance,
/// Body IQ snacks) to NexusRenderer. The public API surface is intentionally preserved so
/// call sites in NexusBootSequence and NexusEngine do not need to change.
@Observable
@MainActor
final class NexusBridge {

    static let shared = NexusBridge()

    private static let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab",
        category: "NexusBridge"
    )

    // MARK: - State

    /// Always true once the native renderer has been primed.
    var isNexusLoaded: Bool { NexusRenderer.shared.isReady }

    /// Kept for backward compat with any call sites that checked `isUnrealLoaded`.
    var isUnrealLoaded: Bool { isNexusLoaded }

    /// Whether the social/Cloud SQL backend is considered online.
    var isSocialSqlBackendOnline: Bool {
        FirebaseBootstrap.isConfigured && !Config.useFirebaseEmulators
    }

#if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?
#endif

    private init() {}

    // MARK: - Firebase identity (previously delivered via receiveFirebaseBridgeJSON:)

    /// Starts observing Firebase Auth state changes and delivers the current identity
    /// to NexusRenderer. Safe to call multiple times; subsequent calls refresh the payload.
    func startFirebaseIdentityObservation() {
#if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { return }
        guard authStateHandle == nil else {
            deliverFirebaseIdentityToRenderer()
            return
        }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor in
                self?.deliverFirebaseIdentityToRenderer()
            }
        }
#endif
        deliverFirebaseIdentityToRenderer()
    }

    private func deliverFirebaseIdentityToRenderer() {
        let uid = FirebaseIdentity.userId ?? ""
        let anonymous = FirebaseIdentity.isAnonymous
        NexusRenderer.shared.applyFirebaseIdentity(
            uid: uid,
            socialOnline: isSocialSqlBackendOnline,
            anonymous: anonymous
        )
        Self.log.debug("Firebase identity relayed to NexusRenderer: uid=\(uid.isEmpty ? "none" : "set", privacy: .private)")
    }

    // MARK: - System scan JSON (previously delivered via receiveSystemScanJSON:)

    /// Delivers a system scan payload to NexusRenderer. Falls back gracefully if the
    /// JSON cannot be decoded; the renderer retains the latest valid PRQ value.
    func deliverSystemScanJSON(_ data: Data) {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            Self.log.error("System scan bridge: invalid UTF-8 data (\(data.count) bytes)")
            return
        }
        Self.log.debug("System scan relay: \(data.count) bytes → NexusRenderer")
        print("[NexusBridge] deliverSystemScanJSON: \(jsonString)")

        // Extract PRQ from the scan record and forward to renderer
        if let record = try? JSONDecoder().decode(SystemScanRecord.self, from: data) {
            NexusRenderer.shared.applyPRQ(record.readiness.neuralReadinessScore)
        } else {
            Self.log.notice("System scan relay: could not decode SystemScanRecord — PRQ unchanged.")
        }
    }

    /// Unused stub kept for backward compatibility with call sites that call this before
    /// the renderer is primed. NexusRenderer handles its own listener readiness internally.
    func notifyUnrealSystemScanListenerReady() {}

    // MARK: - Avatar appearance (previously delivered via receiveAvatarAppearanceJSON:)

    /// Delivers a full avatar appearance JSON payload to NexusRenderer.
    func deliverAvatarAppearanceJSON(_ data: Data) {
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Self.log.error("Avatar appearance bridge: JSON decode failed (\(data.count) bytes)")
            return
        }
        let outfitId = dict["outfitId"] as? String ?? "default"
        let tintHex  = dict["tintHex"] as? String ?? "#0A84FF"
        NexusRenderer.shared.applyAvatarAppearance(outfitId: outfitId, tintHex: tintHex)
        Self.log.debug("Avatar appearance relayed to NexusRenderer: outfit=\(outfitId, privacy: .public)")
    }

    // MARK: - Body IQ snacks (previously delivered via receiveBodyIQJSON:)

    /// Delivers a Body IQ corrective movement snack to NexusRenderer.
    func deliverBodyIQSnackJSON(_ snack: MovementSnack) {
        NexusRenderer.shared.applyBodyIQSnack(snack)
        Self.log.debug("Body IQ snack relayed to NexusRenderer: \(snack.id, privacy: .public)")
    }
}
