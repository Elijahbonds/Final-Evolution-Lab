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

    /// Logs the exact UTF-8 JSON, then forwards to **`receiveSystemScanJSON:`** when the embedded framework is loaded and implements it.
    func deliverSystemScanJSON(_ data: Data) {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            Self.bridgeLog.error("System scan bridge: invalid UTF-8 data (\(data.count) bytes)")
            print("[UnrealManager] deliverSystemScanJSON: <invalid UTF-8, \(data.count) bytes>")
            return
        }

        print("[UnrealManager] deliverSystemScanJSON (exact JSON): \(jsonString)")
        Self.bridgeLog.debug("\(jsonString)")

        guard let fw = unrealFramework as? NSObject else {
            print("[UnrealManager] Unreal runtime not loaded — JSON printed above only (no receiveSystemScanJSON: target).")
            return
        }

        guard fw.responds(to: Self.receiveSystemScanJSONSelector) else {
            print("[UnrealManager] UnrealFramework does not implement receiveSystemScanJSON: — add ObjC shim on UE host.")
            return
        }

        _ = fw.perform(Self.receiveSystemScanJSONSelector, with: jsonString as NSString)
    }
}

