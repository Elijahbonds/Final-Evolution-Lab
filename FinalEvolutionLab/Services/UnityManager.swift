import UIKit

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

    private var unityFramework: AnyObject?

    private init() {}

    private func loadUnity() {
        guard !isUnityLoaded else { return }

        let bundlePath = Bundle.main.privateFrameworksPath ?? ""
        let frameworkPath = bundlePath + "/UnityFramework.framework"
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

        guard let principalClass = bundle.principalClass as? NSObject.Type else {
            isUnityLoaded = false
            return
        }

        let instance = principalClass.perform(NSSelectorFromString("getInstance"))?.takeUnretainedValue() as? NSObject
        unityFramework = instance

        instance?.perform(NSSelectorFromString("setDataBundleId:"), with: "com.unity3d.framework")
        instance?.perform(NSSelectorFromString("runEmbeddedWithArgc:argv:appLaunchOpts:"), with: nil, with: nil, with: nil)

        isUnityLoaded = true
    }

    private func unloadUnity() {
        guard isUnityLoaded else { return }
        unityFramework?.perform(NSSelectorFromString("unloadApplication"))
        unityFramework = nil
        isUnityLoaded = false
    }

    var unityView: UIView? {
        guard isUnityLoaded, let fw = unityFramework as? NSObject else { return nil }
        let appController = fw.perform(NSSelectorFromString("appController"))?.takeUnretainedValue() as? NSObject
        let rootVC = appController?.value(forKey: "rootViewController") as? UIViewController
        return rootVC?.view
    }

    func sendMessageToGO(_ gameObject: String, method: String, message: String) {
        guard isUnityLoaded, let fw = unityFramework as? NSObject else { return }
        fw.perform(
            NSSelectorFromString("sendMessageToGOWithName:functionName:message:"),
            with: gameObject,
            with: method,
            with: message
        )
    }

    func sendDataToUnity(data: String) {
        sendMessageToGO("MotionReceiver", method: "OnMotionData", message: data)
    }

    func takeScreenshot() -> UIImage? {
        guard let view = containerViewForScreenshot ?? unityView else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { context in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}
