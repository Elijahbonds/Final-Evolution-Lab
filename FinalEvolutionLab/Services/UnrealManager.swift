import Foundation
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
}

