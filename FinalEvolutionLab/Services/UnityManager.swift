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

    private struct BridgeEnvelope: Codable {
        let type: String
        let payload: String
    }

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

        _ = instance?.perform(NSSelectorFromString("setDataBundleId:"), with: "com.unity3d.framework")
        _ = instance?.perform(NSSelectorFromString("runEmbedded"))

        isUnityLoaded = true
    }

    private func unloadUnity() {
        guard isUnityLoaded else { return }
        _ = unityFramework?.perform(NSSelectorFromString("unloadApplication"))
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
        let selector = NSSelectorFromString("sendMessageToGOWithName:functionName:message:")
        guard fw.responds(to: selector) else { return }
        let imp = fw.method(for: selector)
        typealias SendFunc = @convention(c) (AnyObject, Selector, String, String, String) -> Void
        let function = unsafeBitCast(imp, to: SendFunc.self)
        function(fw, selector, gameObject, method, message)
    }

    func sendDataToUnity(data: String) {
        sendBridgeMessage(type: "motion", payload: data)
    }

    func sendManifestToUnity(_ manifestJSON: String) {
        sendBridgeMessage(type: "manifest", payload: manifestJSON)
    }

    private func sendBridgeMessage(type: String, payload: String) {
        let envelope = BridgeEnvelope(type: type, payload: payload)
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(envelope),
              let message = String(data: data, encoding: .utf8) else {
            return
        }
        // Route all Swift → Unity communication through the dedicated bridge receiver.
        sendMessageToGO("RorkBridgeReceiver", method: "OnRorkBridgeMessage", message: message)
    }

    func takeScreenshot() -> UIImage? {
        guard let view = containerViewForScreenshot ?? unityView else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { context in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}
