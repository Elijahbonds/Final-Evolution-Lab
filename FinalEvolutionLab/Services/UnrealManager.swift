import Foundation
import OSLog
import UIKit

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Embedded Unreal runtime manager (Swift + Unreal container).
///
/// Place the UE-built framework at **`FinalEvolutionLab/EmbeddedFrameworks/UnrealFramework.framework`**;
/// the Xcode **Embed Unreal Framework (optional)** phase copies it into:
/// **`FinalEvolutionLab.app/Frameworks/UnrealFramework.framework`**
///
/// The framework must provide an Objective‑C entrypoint class named `UnrealFramework`
/// with `getInstance`, `runEmbedded`, `unloadApplication`, and `rootView` selectors.
///
/// **Identity bridge (production SQL / scores):** optionally implement
/// `- (void)receiveFirebaseBridgeJSON:(NSString *)json` with a UTF‑8 JSON payload:
/// `firebaseUid`, `socialSqlOnline`, `anonymous`. Called after load and whenever Auth state changes.
///
/// (We keep this loose because the exact API depends on how you build UE-as-a-library.)
@Observable
@MainActor
final class UnrealManager {
    static let shared = UnrealManager()

    /// Objective‑C API on the UE host class: `- (void)receiveSystemScanJSON:(NSString *)json;`
    private static let receiveSystemScanJSONSelector = NSSelectorFromString("receiveSystemScanJSON:")
    private static let getInstanceSelector = NSSelectorFromString("getInstance")
    private static let runEmbeddedSelector = NSSelectorFromString("runEmbedded")
    private static let unloadApplicationSelector = NSSelectorFromString("unloadApplication")
    private static let rootViewSelector = NSSelectorFromString("rootView")
    private static let receiveFirebaseBridgeJSONSelector = NSSelectorFromString("receiveFirebaseBridgeJSON:")
    /// Optional Obj‑C hook: `- (void)receiveBodyIQJSON:(NSString *)json` — Movement Snack / corrective montage routing.
    private static let receiveBodyIQJSONSelector = NSSelectorFromString("receiveBodyIQJSON:")
    /// Optional: `- (void)receiveNeuroGameplayTuningJSON:(NSString *)json` — Bonds / scan scalars for dunk power meter & karate impact.
    private static let receiveNeuroGameplayTuningJSONSelector = NSSelectorFromString("receiveNeuroGameplayTuningJSON:")

    private static let bridgeLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab", category: "UnrealBridge")

    private(set) var isUnrealLoaded: Bool = false
    weak var containerViewForScreenshot: UIView?

#if canImport(FirebaseAuth)
    private var authStateHandle: AuthStateDidChangeListenerHandle?
#endif

    /// When `true`, the app is configured for **production** Firebase + Cloud SQL (Data Connect not using the local emulator).
    /// When `false` (emulators on), treat cross-player social state as **offline/local** in Unreal.
    var isSocialSqlBackendOnline: Bool {
        FirebaseBootstrap.isConfigured && !Config.useFirebaseEmulators
    }

    /// Latest system-scan JSON retained until the embedded framework can accept `receiveSystemScanJSON:`.
    private var latestPendingSystemScanJSON: Data?

    /// Latest Body IQ snack JSON retained until `receiveBodyIQJSON:` is available (mirrors system-scan queueing).
    private var latestPendingBodyIQJSON: String?

    /// Optional JSON bridge from UE when a match completes (same contract as Emergent `fel_game_result`) — GAME-33.
    func deliverSessionCompleteJSON(_ data: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Self.bridgeLog.error("Session complete bridge: invalid JSON (\(data.count) bytes)")
            return
        }
        GameplaySessionReceiptCoordinator.shared.applyVerifiedPayload(obj)
    }

    /// UTF-8 convenience for Obj‑C / UE bridge strings.
    func deliverSessionCompleteJSONString(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        deliverSessionCompleteJSON(data)
    }

    /// Queued neuro gameplay JSON for embedded UE (kinetic leakage / IAP stability scalars).
    private var latestPendingNeuroGameplayJSON: String?

    /// Session context set before presenting ``UnrealContainerView`` so boot can flush tuning into GameState.
    private var embeddedNeuroSession: (mode: GameModeId, audit: BiomechanicsAudit?, metrics: PerformanceMetrics)?

    /// Latest Firebase identity JSON for UE; flushed after `loadUnreal()` when `receiveFirebaseBridgeJSON:` exists.
    private var pendingFirebaseBridgeJSON: String?

    var isUnrealActive: Bool = false {
        didSet {
            if isUnrealActive && !isUnrealLoaded {
                loadUnreal()
            } else if !isUnrealActive && isUnrealLoaded {
                unloadUnreal()
            }
        }
    }

    private var unrealFramework: AnyObject?

    private init() {}

    /// Call after ``FirebaseBootstrap/configureIfNeeded()`` so Auth changes propagate into UE when the framework exposes `receiveFirebaseBridgeJSON:`.
    func startFirebaseIdentityObservation() {
#if canImport(FirebaseAuth)
        guard FirebaseBootstrap.isConfigured else { return }
        guard authStateHandle == nil else {
            deliverFirebaseBridgeIdentityToUnreal()
            return
        }
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor in
                self?.deliverFirebaseBridgeIdentityToUnreal()
            }
        }
#endif
        deliverFirebaseBridgeIdentityToUnreal()
    }

    var isFrameworkPresent: Bool {
        resolvedUnrealFrameworkURL() != nil
    }

    /// Embedded layouts differ by toolchain; probe both Apple's private-frameworks convention and `<App>.app/Frameworks/`.
    private func resolvedUnrealFrameworkURL() -> URL? {
        let fm = FileManager.default
        var candidates: [URL] = []
        if let sub = Bundle.main.privateFrameworksPath {
            candidates.append(URL(fileURLWithPath: sub, isDirectory: true).appendingPathComponent("UnrealFramework.framework", isDirectory: true))
        }
        candidates.append(Bundle.main.bundleURL.appendingPathComponent("Frameworks/UnrealFramework.framework", isDirectory: true))

        return candidates.first { fm.fileExists(atPath: $0.path) }
    }

    /// `true` when the runtime is loaded **and** the principal class implements `receiveSystemScanJSON:`.
    var isSystemScanListenerReady: Bool {
        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else { return false }
        return fw.responds(to: Self.receiveSystemScanJSONSelector)
    }

    /// `true` when the runtime is loaded **and** the UE host implements `receiveBodyIQJSON:`.
    var isBodyIQListenerReady: Bool {
        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else { return false }
        return fw.responds(to: Self.receiveBodyIQJSONSelector)
    }

    /// `true` when embedded UE implements `receiveNeuroGameplayTuningJSON:` (Bonds / scan scalars).
    var isNeuroGameplayListenerReady: Bool {
        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else { return false }
        return fw.responds(to: Self.receiveNeuroGameplayTuningJSONSelector)
    }

    private func loadUnreal() {
        guard !isUnrealLoaded else { return }

        guard let frameworkURL = resolvedUnrealFrameworkURL() else {
            Self.bridgeLog.notice("Unreal bundle path: framework not found (embed phase skipped or different layout).")
            isUnrealLoaded = false
            return
        }

        guard let bundle = Bundle(url: frameworkURL) else {
            Self.bridgeLog.error("Unreal bundle path: Bundle(url:) failed \(frameworkURL.path, privacy: .public)")
            isUnrealLoaded = false
            return
        }

        if !bundle.isLoaded {
            do {
                try bundle.loadAndReturnError()
            } catch {
                Self.bridgeLog.error("Unreal load failed: \(error.localizedDescription, privacy: .public)")
                isUnrealLoaded = false
                return
            }
        }

        guard let principalMeta = bundle.principalClass else {
            Self.bridgeLog.error("Unreal principalClass missing — check UE export / Info.plist Principal class.")
            isUnrealLoaded = false
            return
        }

        let klass = principalMeta as AnyObject
        guard klass.responds(to: Self.getInstanceSelector) else {
            Self.bridgeLog.error("UE host \(String(describing: principalMeta)) does not implement getInstance.")
            unrealFramework = nil
            isUnrealLoaded = false
            return
        }

        guard let raw = klass.perform(Self.getInstanceSelector)?.takeUnretainedValue() as? NSObject else {
            Self.bridgeLog.error("getInstance returned nil or non-NSObject — aborting UE load.")
            unrealFramework = nil
            isUnrealLoaded = false
            return
        }

        unrealFramework = raw
        if raw.responds(to: Self.runEmbeddedSelector) {
            _ = raw.perform(Self.runEmbeddedSelector)
        } else {
            Self.bridgeLog.notice("UE runtime has no runEmbedded — continuing (listener may wire later).")
        }

        isUnrealLoaded = true
        CrashReporter.setUnrealLoaded(true)
        if !raw.responds(to: Self.receiveSystemScanJSONSelector) {
            Self.bridgeLog.notice("UE runtime loaded but receiveSystemScanJSON: not wired yet — scan JSON will queue until notified.")
        }
        if !raw.responds(to: Self.receiveNeuroGameplayTuningJSONSelector) {
            Self.bridgeLog.notice("UE runtime has no receiveNeuroGameplayTuningJSON: — fel_neuro_gameplay payloads queue until implemented.")
        }

        flushPendingSystemScanAfterBoot()
        flushPendingBodyIQAfterBoot()
        flushPendingFirebaseBridgeAfterBoot()
        flushEmbeddedNeuroGameplayAfterBoot()
    }

    private func unloadUnreal() {
        guard isUnrealLoaded else { return }
        if let fw = unrealFramework as? NSObject, fw.responds(to: Self.unloadApplicationSelector) {
            _ = fw.perform(Self.unloadApplicationSelector)
        }
        unrealFramework = nil
        isUnrealLoaded = false
        CrashReporter.setUnrealLoaded(false)
    }

    /// Builds JSON for `receiveFirebaseBridgeJSON:` and forwards or queues until UE is listening.
    private func deliverFirebaseBridgeIdentityToUnreal() {
        let uid = FirebaseIdentity.userId ?? ""
        let payload: [String: Any] = [
            "firebaseUid": uid,
            "socialSqlOnline": isSocialSqlBackendOnline,
            "anonymous": FirebaseIdentity.isAnonymous,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return
        }
        pendingFirebaseBridgeJSON = json

        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else {
            Self.bridgeLog.notice("Firebase bridge JSON queued until Unreal loads (\(uid.isEmpty ? "no uid" : "uid present")).")
            return
        }
        guard fw.responds(to: Self.receiveFirebaseBridgeJSONSelector) else {
            Self.bridgeLog.notice("UE host has no receiveFirebaseBridgeJSON: — identity not pushed into native.")
            return
        }
        _ = fw.perform(Self.receiveFirebaseBridgeJSONSelector, with: json as NSString)
        Self.bridgeLog.debug("Pushed Firebase bridge JSON to Unreal.")
    }

    private func flushPendingFirebaseBridgeAfterBoot() {
        guard let json = pendingFirebaseBridgeJSON,
              let fw = unrealFramework as? NSObject,
              isUnrealLoaded,
              fw.responds(to: Self.receiveFirebaseBridgeJSONSelector) else { return }
        _ = fw.perform(Self.receiveFirebaseBridgeJSONSelector, with: json as NSString)
    }

    /// View provided by the embedded Unreal runtime.
    var unrealView: UIView? {
        guard isUnrealLoaded, let fw = unrealFramework as? NSObject else { return nil }
        guard fw.responds(to: Self.rootViewSelector) else {
            Self.bridgeLog.notice("UE host has no rootView selector — presenter will show placeholder.")
            return nil
        }
        return fw.perform(Self.rootViewSelector)?.takeUnretainedValue() as? UIView
    }

    /// Always retains the latest payload, logs it, and forwards to **`receiveSystemScanJSON:`** when the listener is ready.
    /// If Unreal is not loaded or not listening yet, the JSON is **cached** and sent on the next successful boot (see ``notifyUnrealSystemScanListenerReady()``).
    func deliverSystemScanJSON(_ data: Data) {
        latestPendingSystemScanJSON = data
        guard let jsonString = String(data: data, encoding: .utf8) else {
            Self.bridgeLog.error("System scan bridge: invalid UTF-8 data (\(data.count) bytes)")
#if DEBUG
            print("[UnrealManager] deliverSystemScanJSON: <invalid UTF-8, \(data.count) bytes>")
#endif
            return
        }

#if DEBUG
        print("[UnrealManager] deliverSystemScanJSON (exact JSON): \(jsonString)")
        Self.bridgeLog.debug("\(jsonString)")
#else
        Self.bridgeLog.debug("deliverSystemScanJSON (\(data.count) bytes) — payload omitted in Release")
#endif

        if tryDeliverSystemScanToNative(jsonString: jsonString) {
#if DEBUG
            print("[UnrealManager] Native listener accepted system scan JSON.")
#endif
            Self.bridgeLog.debug("System scan delivered to native listener.")
        } else {
#if DEBUG
            print("[UnrealManager] System scan cached for Unreal boot (listener not ready). isLoaded=\(isUnrealLoaded) listening=\(isSystemScanListenerReady)")
#endif
            Self.bridgeLog.notice("System scan cached until Unreal listener ready (loaded=\(self.isUnrealLoaded), listening=\(self.isSystemScanListenerReady)).")
        }
    }

    /// Call when your UE/ObjC host finishes wiring `receiveSystemScanJSON:` (if that happens after ``loadUnreal()``).
    func notifyUnrealSystemScanListenerReady() {
        flushPendingSystemScanAfterBoot()
    }

    /// Call when your UE/ObjC host finishes wiring `receiveBodyIQJSON:` (if Movement Snacks were queued before the selector existed).
    func notifyUnrealBodyIQListenerReady() {
        flushPendingBodyIQAfterBoot()
    }

    /// Call when UE wires `receiveNeuroGameplayTuningJSON:` after boot.
    func notifyUnrealNeuroGameplayListenerReady() {
        flushEmbeddedNeuroGameplayAfterBoot()
    }

    /// Capture scan/audit-derived scalars for the upcoming embedded session (call before `isUnrealActive = true`).
    func prepareEmbeddedNeuroSession(mode: GameModeId, audit: BiomechanicsAudit?, metrics: PerformanceMetrics) {
        embeddedNeuroSession = (mode, audit, metrics)
        if let data = try? JSONSerialization.data(
            withJSONObject: NeuroGameplayTuning.jsonDictionary(
                arenaGameModeId: mode.rawValue,
                audit: audit,
                metrics: metrics,
                mode: mode
            ),
            options: [.sortedKeys]
        ),
            let json = String(data: data, encoding: .utf8) {
            latestPendingNeuroGameplayJSON = json
        }
    }

    func clearEmbeddedNeuroSession() {
        embeddedNeuroSession = nil
        latestPendingNeuroGameplayJSON = nil
    }

    @discardableResult
    private func tryDeliverNeuroGameplayToNative(jsonString: String) -> Bool {
        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else { return false }
        guard fw.responds(to: Self.receiveNeuroGameplayTuningJSONSelector) else { return false }
        _ = fw.perform(Self.receiveNeuroGameplayTuningJSONSelector, with: jsonString as NSString)
        return true
    }

    private func flushEmbeddedNeuroGameplayAfterBoot() {
        let jsonToSend: String?
        if let pending = latestPendingNeuroGameplayJSON {
            jsonToSend = pending
        } else if let s = embeddedNeuroSession {
            let dict = NeuroGameplayTuning.jsonDictionary(
                arenaGameModeId: s.mode.rawValue,
                audit: s.audit,
                metrics: s.metrics,
                mode: s.mode
            )
            guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]) else { return }
            jsonToSend = String(data: data, encoding: .utf8)
        } else {
            jsonToSend = nil
        }
        guard let js = jsonToSend else { return }
        if tryDeliverNeuroGameplayToNative(jsonString: js) {
            latestPendingNeuroGameplayJSON = nil
            Self.bridgeLog.debug("Boot handshake: flushed fel_neuro_gameplay JSON to Unreal.")
            return
        }
        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else {
            Self.bridgeLog.notice("fel_neuro_gameplay JSON retained until Unreal loads.")
            return
        }
        if !fw.responds(to: Self.receiveNeuroGameplayTuningJSONSelector) {
            Self.bridgeLog.notice("UE host has no receiveNeuroGameplayTuningJSON: — retained until wiring; call notifyUnrealNeuroGameplayListenerReady() after UE exposes selector.")
        }
    }

    @discardableResult
    private func tryDeliverSystemScanToNative(jsonString: String) -> Bool {
        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else { return false }
        guard fw.responds(to: Self.receiveSystemScanJSONSelector) else { return false }
        _ = fw.perform(Self.receiveSystemScanJSONSelector, with: jsonString as NSString)
        return true
    }

    private func flushPendingSystemScanAfterBoot() {
        guard let data = latestPendingSystemScanJSON,
              let jsonString = String(data: data, encoding: .utf8) else { return }
        guard tryDeliverSystemScanToNative(jsonString: jsonString) else { return }
#if DEBUG
        print("[UnrealManager] Boot handshake: flushed pending system scan to Unreal listener.")
#endif
        Self.bridgeLog.debug("Boot handshake: flushed pending system scan to Unreal listener.")
    }

    private func flushPendingBodyIQAfterBoot() {
        guard let json = latestPendingBodyIQJSON,
              let fw = unrealFramework as? NSObject,
              isUnrealLoaded,
              fw.responds(to: Self.receiveBodyIQJSONSelector) else { return }
        _ = fw.perform(Self.receiveBodyIQJSONSelector, with: json as NSString)
        latestPendingBodyIQJSON = nil
        Self.bridgeLog.debug("Boot handshake: flushed pending Body IQ JSON to Unreal.")
    }

    /// Delivers a **Body IQ** Movement Snack payload for corrective sequences in Unreal (Phase B/C asset IDs).
    /// If `receiveBodyIQJSON:` is not wired yet, the payload is queued and delivered after Unreal loads with that selector or when you call ``notifyUnrealBodyIQListenerReady()``.
    func deliverBodyIQSnackJSON(_ snack: MovementSnack) {
        let payload: [String: Any] = [
            "type": "body_iq_snack",
            "snackId": snack.id,
            "requiredUnrealAnimationAssetID": snack.requiredUnrealAnimationAssetID,
            "unrealCorrectivePoseAssetID": snack.unrealCorrectivePoseAssetID,
            "unrealDiaphragmBreathAssetID": snack.unrealDiaphragmBreathAssetID,
            "phaseMappingCarsCue": snack.phaseMappingCarsCue,
            "phaseBreathCue": snack.phaseBreathCue,
            "durationSeconds": snack.durationSeconds,
            "targetCategories": snack.targetedCategories.map(\.rawValue),
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            Self.bridgeLog.error("Body IQ bridge: JSON serialization failed for \(snack.id)")
            return
        }

        latestPendingBodyIQJSON = json

        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else {
            Self.bridgeLog.notice("Body IQ JSON queued until Unreal loads (\(snack.id)).")
            return
        }
        guard fw.responds(to: Self.receiveBodyIQJSONSelector) else {
            Self.bridgeLog.notice("UE host has no receiveBodyIQJSON: — snack retained; call notifyUnrealBodyIQListenerReady() after wiring.")
            return
        }
        _ = fw.perform(Self.receiveBodyIQJSONSelector, with: json as NSString)
        latestPendingBodyIQJSON = nil
        Self.bridgeLog.debug("Body IQ snack pushed to Unreal: \(snack.requiredUnrealAnimationAssetID)")
    }

    /// Capture screenshot of the active Unreal view.
    func takeScreenshot() -> UIImage? {
        guard let view = containerViewForScreenshot ?? unrealView else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { context in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}

