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
final class NexusBridge {
    static let shared = NexusBridge()

    /// Objective‑C API on the UE host class: `- (void)receiveSystemScanJSON:(NSString *)json;`
    private static let receiveSystemScanJSONSelector = NSSelectorFromString("receiveSystemScanJSON:")
    private static let getInstanceSelector = NSSelectorFromString("getInstance")
    private static let runEmbeddedSelector = NSSelectorFromString("runEmbedded")
    private static let unloadApplicationSelector = NSSelectorFromString("unloadApplication")
    private static let rootViewSelector = NSSelectorFromString("rootView")
    private static let receiveFirebaseBridgeJSONSelector = NSSelectorFromString("receiveFirebaseBridgeJSON:")
    /// Optional Obj‑C hook: `- (void)receiveBodyIQJSON:(NSString *)json` — Movement Snack / corrective montage routing.
    private static let receiveBodyIQJSONSelector = NSSelectorFromString("receiveBodyIQJSON:")
    /// Obj‑C hook: `- (void)receiveAvatarAppearanceJSON:(NSString *)json` — full appearance payload for the player avatar.
    private static let receiveAvatarAppearanceJSONSelector = NSSelectorFromString("receiveAvatarAppearanceJSON:")

    private static let bridgeLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab", category: "UnrealBridge")

    private(set) var isUnrealLoaded: Bool = false

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

    /// Latest Firebase identity JSON for UE; flushed after `loadUnreal()` when `receiveFirebaseBridgeJSON:` exists.
    private var pendingFirebaseBridgeJSON: String?

    /// Latest avatar appearance payload; flushed after `loadUnreal()` when `receiveAvatarAppearanceJSON:` exists.
    private var pendingAvatarAppearanceJSON: Data?

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

        flushPendingSystemScanAfterBoot()
        flushPendingFirebaseBridgeAfterBoot()
        flushPendingAvatarAppearanceAfterBoot()
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
            print("[NexusBridge] deliverSystemScanJSON: <invalid UTF-8, \(data.count) bytes>")
            return
        }

        print("[NexusBridge] deliverSystemScanJSON (exact JSON): \(jsonString)")
        Self.bridgeLog.debug("\(jsonString)")

        if tryDeliverSystemScanToNative(jsonString: jsonString) {
            print("[NexusBridge] Native listener accepted system scan JSON.")
        } else {
            print("[NexusBridge] System scan cached for Unreal boot (listener not ready). isLoaded=\(isUnrealLoaded) listening=\(isSystemScanListenerReady)")
        }
    }

    /// Call when your UE/ObjC host finishes wiring `receiveSystemScanJSON:` (if that happens after ``loadUnreal()``).
    func notifyUnrealSystemScanListenerReady() {
        flushPendingSystemScanAfterBoot()
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
        print("[NexusBridge] Boot handshake: flushed pending system scan to Unreal listener.")
    }

    /// Delivers the full player avatar appearance JSON to `receiveAvatarAppearanceJSON:` in the Nexus/UE host.
    /// Queued until the framework loads if called early.
    func deliverAvatarAppearanceJSON(_ data: Data) {
        pendingAvatarAppearanceJSON = data
        guard let jsonString = String(data: data, encoding: .utf8) else {
            Self.bridgeLog.error("Avatar appearance bridge: invalid UTF-8 (\(data.count) bytes)")
            return
        }
        Self.bridgeLog.debug("Avatar appearance payload ready (\(data.count) bytes)")

        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else {
            Self.bridgeLog.notice("Avatar appearance JSON queued — Nexus not loaded yet.")
            return
        }
        guard fw.responds(to: Self.receiveAvatarAppearanceJSONSelector) else {
            Self.bridgeLog.notice("Nexus host has no receiveAvatarAppearanceJSON: — implement on bridge to apply avatar.")
            return
        }
        _ = fw.perform(Self.receiveAvatarAppearanceJSONSelector, with: jsonString as NSString)
        Self.bridgeLog.debug("Avatar appearance pushed to Nexus.")
    }

    private func flushPendingAvatarAppearanceAfterBoot() {
        guard let data = pendingAvatarAppearanceJSON,
              let jsonString = String(data: data, encoding: .utf8),
              let fw = unrealFramework as? NSObject,
              isUnrealLoaded,
              fw.responds(to: Self.receiveAvatarAppearanceJSONSelector) else { return }
        _ = fw.perform(Self.receiveAvatarAppearanceJSONSelector, with: jsonString as NSString)
        Self.bridgeLog.debug("Boot handshake: flushed pending avatar appearance to Nexus.")
    }

    /// Delivers a **Body IQ** Movement Snack payload for corrective sequences in Unreal (Phase B/C asset IDs).
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

        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else {
            Self.bridgeLog.notice("Body IQ JSON not delivered — Unreal not loaded (\(snack.id)).")
            print("[NexusBridge] Body IQ JSON queued in-memory only — load UE to apply \(snack.requiredUnrealAnimationAssetID)")
            return
        }
        guard fw.responds(to: Self.receiveBodyIQJSONSelector) else {
            Self.bridgeLog.notice("UE host has no receiveBodyIQJSON: — implement on Obj‑C bridge to play corrective assets.")
            return
        }
        _ = fw.perform(Self.receiveBodyIQJSONSelector, with: json as NSString)
        Self.bridgeLog.debug("Body IQ snack pushed to Unreal: \(snack.requiredUnrealAnimationAssetID)")
    }
}

