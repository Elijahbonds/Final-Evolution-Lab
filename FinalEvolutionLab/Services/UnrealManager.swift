import Foundation
import OSLog
import UIKit

/// Embedded Unreal runtime manager (Swift + Unreal container).
///
/// Place the UE-built framework at **`FinalEvolutionLab/EmbeddedFrameworks/UnrealFramework.framework`**;
/// the Xcode **Embed Unreal Framework (optional)** phase copies it into:
/// **`FinalEvolutionLab.app/Frameworks/UnrealFramework.framework`**
///
/// The framework must provide an Objective‑C entrypoint class named `UnrealFramework`
/// with `getInstance`, `runEmbedded`, `unloadApplication`, and `rootView` selectors.
///
/// (We keep this loose because the exact API depends on how you build UE-as-a-library.)
@Observable
@MainActor
final class UnrealManager {
    static let shared = UnrealManager()

    /// Objective‑C API on the UE host class: `- (void)receiveSystemScanJSON:(NSString *)json;`
    private static let receiveSystemScanJSONSelector = NSSelectorFromString("receiveSystemScanJSON:")

    private static let bridgeLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FinalEvolutionLab", category: "UnrealBridge")

    private(set) var isUnrealLoaded: Bool = false

    /// Latest system-scan JSON retained until the embedded framework can accept `receiveSystemScanJSON:`.
    private var latestPendingSystemScanJSON: Data?

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

    var isFrameworkPresent: Bool {
        let bundlePath = Bundle.main.privateFrameworksPath ?? ""
        let frameworkPath = bundlePath + "/UnrealFramework.framework"
        return FileManager.default.fileExists(atPath: frameworkPath)
    }

    /// `true` when the runtime is loaded **and** the principal class implements `receiveSystemScanJSON:`.
    var isSystemScanListenerReady: Bool {
        guard let fw = unrealFramework as? NSObject, isUnrealLoaded else { return false }
        return fw.responds(to: Self.receiveSystemScanJSONSelector)
    }

    private func loadUnreal() {
        guard !isUnrealLoaded else { return }

        let bundlePath = Bundle.main.privateFrameworksPath ?? ""
        let frameworkPath = bundlePath + "/UnrealFramework.framework"
        guard let bundle = Bundle(path: frameworkPath) else {
            isUnrealLoaded = false
            return
        }

        if !bundle.isLoaded {
            do {
                try bundle.loadAndReturnError()
            } catch {
                isUnrealLoaded = false
                return
            }
        }

        guard let principalClass = bundle.principalClass as? NSObject.Type else {
            isUnrealLoaded = false
            return
        }

        let instance = principalClass.perform(NSSelectorFromString("getInstance"))?.takeUnretainedValue() as? NSObject
        unrealFramework = instance
        _ = instance?.perform(NSSelectorFromString("runEmbedded"))
        isUnrealLoaded = true
        flushPendingSystemScanAfterBoot()
    }

    private func unloadUnreal() {
        guard isUnrealLoaded else { return }
        _ = unrealFramework?.perform(NSSelectorFromString("unloadApplication"))
        unrealFramework = nil
        isUnrealLoaded = false
    }

    /// View provided by the embedded Unreal runtime.
    var unrealView: UIView? {
        guard isUnrealLoaded, let fw = unrealFramework as? NSObject else { return nil }
        return fw.perform(NSSelectorFromString("rootView"))?.takeUnretainedValue() as? UIView
    }

    /// Always retains the latest payload, logs it, and forwards to **`receiveSystemScanJSON:`** when the listener is ready.
    /// If Unreal is not loaded or not listening yet, the JSON is **cached** and sent on the next successful boot (see ``notifyUnrealSystemScanListenerReady()``).
    func deliverSystemScanJSON(_ data: Data) {
        latestPendingSystemScanJSON = data
        guard let jsonString = String(data: data, encoding: .utf8) else {
            Self.bridgeLog.error("System scan bridge: invalid UTF-8 data (\(data.count) bytes)")
            print("[UnrealManager] deliverSystemScanJSON: <invalid UTF-8, \(data.count) bytes>")
            return
        }

        print("[UnrealManager] deliverSystemScanJSON (exact JSON): \(jsonString)")
        Self.bridgeLog.debug("\(jsonString)")

        if tryDeliverSystemScanToNative(jsonString: jsonString) {
            print("[UnrealManager] Native listener accepted system scan JSON.")
        } else {
            print("[UnrealManager] System scan cached for Unreal boot (listener not ready). isLoaded=\(isUnrealLoaded) listening=\(isSystemScanListenerReady)")
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
        print("[UnrealManager] Boot handshake: flushed pending system scan to Unreal listener.")
    }
}

