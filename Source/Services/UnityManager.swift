import UIKit
import Observation

#if canImport(UnityFramework)
import UnityFramework
#endif

/// Hosts Unity as a Library (UaaL). When `UnityFramework.framework` is embedded, use the typed API path.
/// Do not make this `UIApplicationDelegate` — `FinalEvolutionLabUnrealApp` owns app lifecycle.
@Observable
@MainActor
final class UnityManager {
    static let shared = UnityManager()

    private(set) var isUnityLoaded: Bool = false
    var isUnityActive: Bool = false {
        didSet {
            if isUnityActive && !isUnityLoaded {
                loadUnity()
            } else if !isUnityActive && isUnityLoaded {
                unloadUnity()
            }
        }
    }

    weak var containerViewForScreenshot: UIView?

#if canImport(UnityFramework)
    private var ufw: UnityFramework?
#else
    private var unityFramework: AnyObject?
#endif

    private init() {}

    /// `true` when `UnityFramework.framework` is present in the app bundle (embed from Unity iOS export).
    var isUnityFrameworkEmbedded: Bool {
        let path = (Bundle.main.privateFrameworksPath ?? "") + "/UnityFramework.framework"
        return FileManager.default.fileExists(atPath: path)
    }

    /// Warm-loads Unity when the framework is embedded. Skips if missing (Swift-only builds).
    func preloadUnityAtLaunch() {
        guard isUnityFrameworkEmbedded else { return }
        isUnityActive = true
    }

    private func loadUnity() {
        guard !isUnityLoaded else { return }

        let frameworkPath = (Bundle.main.privateFrameworksPath ?? "") + "/UnityFramework.framework"
        guard let bundle = Bundle(path: frameworkPath) else {
            isUnityLoaded = false
            return
        }

        if !bundle.isLoaded {
            do {
                try bundle.loadAndReturnError()
            } catch {
                isUnityLoaded = false
                return
            }
        }

#if canImport(UnityFramework)
        guard let principalClass = bundle.principalClass as? NSObject.Type else {
            isUnityLoaded = false
            return
        }
        guard let instance = principalClass.perform(NSSelectorFromString("getInstance"))?.takeUnretainedValue() as? UnityFramework else {
            isUnityLoaded = false
            return
        }
        ufw = instance
        ufw?.setDataBundleId("com.unity3d.framework")
        ufw?.runEmbedded(withArgc: CommandLine.argc, argv: CommandLine.unsafeArgv, appLaunchOpts: nil)
        
        // Register NativeCallProxy API right after running embedded
        if let apiClass = bundle.classNamed("FrameworkLibAPI") as? NSObject.Type {
            let selector = NSSelectorFromString("registerAPIforNativeCalls:")
            if apiClass.responds(to: selector) {
                apiClass.perform(selector, with: NativeCallProxyImpl.shared)
            }
        }
#else
        guard let principalClass = bundle.principalClass as? NSObject.Type else {
            isUnityLoaded = false
            return
        }

        let instance = principalClass.perform(NSSelectorFromString("getInstance"))?.takeUnretainedValue() as? NSObject
        unityFramework = instance

        _ = instance?.perform(NSSelectorFromString("setDataBundleId:"), with: "com.unity3d.framework")
        _ = instance?.perform(NSSelectorFromString("runEmbedded"))

        if let apiClass = bundle.classNamed("FrameworkLibAPI") as? NSObject.Type {
            let selector = NSSelectorFromString("registerAPIforNativeCalls:")
            if apiClass.responds(to: selector) {
                apiClass.perform(selector, with: NativeCallProxyImpl.shared)
            }
        }
#endif

        isUnityLoaded = true
    }

    private func unloadUnity() {
        guard isUnityLoaded else { return }
#if canImport(UnityFramework)
        ufw?.unloadApplication()
        ufw = nil
#else
        _ = unityFramework?.perform(NSSelectorFromString("unloadApplication"))
        unityFramework = nil
#endif
        isUnityLoaded = false
    }

    var unityView: UIView? {
#if canImport(UnityFramework)
        guard let fw = ufw as NSObject? else { return nil }
#else
        guard let fw = unityFramework as? NSObject else { return nil }
#endif
        let appController = fw.perform(NSSelectorFromString("appController"))?.takeUnretainedValue() as? NSObject
        let rootVC = appController?.value(forKey: "rootViewController") as? UIViewController
        return rootVC?.view
    }

    func sendMessageToGO(_ gameObject: String, method: String, message: String) {
        guard isUnityLoaded else { return }
#if canImport(UnityFramework)
        ufw?.sendMessageToGO(withName: gameObject, functionName: method, message: message)
#else
        guard let fw = unityFramework as? NSObject else { return }
        let selector = NSSelectorFromString("sendMessageToGOWithName:functionName:message:")
        guard fw.responds(to: selector) else { return }
        let imp = fw.method(for: selector)
        typealias SendFunc = @convention(c) (AnyObject, Selector, String, String, String) -> Void
        let function = unsafeBitCast(imp, to: SendFunc.self)
        function(fw, selector, gameObject, method, message)
#endif
    }

    func sendDataToUnity(data: String) {
        sendMessageToGO("MotionReceiver", method: "OnMotionData", message: data)
    }

    // MARK: - Skill Lab / Film Vault (Unity GameObject `FELBridge` — add in Unity project)

    /// Film Vault clip id or JSON — received by `FELBridge.OnFilmVaultMessage` on the Unity side.
    func sendFilmVaultCommand(_ message: String) {
        sendMessageToGO("FELBridge", method: "OnFilmVaultMessage", message: message)
    }

    /// Skill Lab session id or JSON — received by `FELBridge.OnSkillLabMessage` on the Unity side.
    func sendSkillLabCommand(_ message: String) {
        sendMessageToGO("FELBridge", method: "OnSkillLabMessage", message: message)
    }

    /// Film Vault Clip Selection — received by `FELBridge.OnClipSelection` on the Unity side.
    func sendClipSelection(_ clipId: String) {
        sendMessageToGO("FELBridge", method: "OnClipSelection", message: clipId)
    }

    func takeScreenshot() -> UIImage? {
        guard let view = containerViewForScreenshot ?? unityView else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { context in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}
