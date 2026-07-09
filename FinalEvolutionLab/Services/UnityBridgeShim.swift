import Foundation
import SwiftUI

// MARK: - UnityBridgeShim (Lane F: framework glue)
//
// The only file that talks to UnityFramework directly. Everything is behind
// FEL_UNITY_EMBEDDED so the app builds identically before the framework is
// linked. To activate:
//   1. Drag UnityFramework.framework (built from FEL-unity/FELGameplay/iosBuild,
//      scheme "UnityFramework") into the FinalEvolutionLab app target
//      (General → Frameworks, Embed & Sign).
//   2. Add FEL_UNITY_EMBEDDED to Build Settings → Swift Compiler → Custom Flags
//      → Active Compilation Conditions.
//
// Unity 6 UaaL surface used here (stable since 2019.3):
//   UnityFramework.getInstance() / -runEmbedded(withArgc:argv:appLaunchOpts:)
//   -sendMessageToGO(withName:functionName:message:)  (Swift-bridged name)
//   -appController().rootView                          (the render UIView)
//   NativeCallProxy pattern replaced by C# HostEmitter -> objc callback.

#if FEL_UNITY_EMBEDDED
import MachO
import UnityFramework

enum UnityBridgeShim {
    private static var framework: UnityFramework?

    /// Load + run the embedded Unity player once; register the C#->Swift emitter.
    @MainActor
    static func loadUnity(host: FELUnityHost) {
        if framework != nil { return }
        guard let bundlePath = Bundle.main.privateFrameworksPath.map({ $0 + "/UnityFramework.framework" }),
              let bundle = Bundle(path: bundlePath) else {
            print("[UnityShim] UnityFramework.framework not found in app bundle")
            return
        }
        if !bundle.isLoaded { bundle.load() }
        guard let ufw = bundle.principalClass?.getInstance() else {
            print("[UnityShim] UnityFramework.getInstance() failed")
            return
        }
        if ufw.appController() == nil {
            // Canonical UaaL bootstrap: hand Unity the host executable's Mach-O
            // header. Resolved at runtime via dyld (image 0 = main executable)
            // because this app builds with Xcode's debug-dylib mechanism, where
            // the static __mh_execute_header symbol is unavailable.
            if let raw = _dyld_get_image_header(0) {
                raw.withMemoryRebound(to: MachHeader.self, capacity: 1) {
                    ufw.setExecuteHeader($0)
                }
            }
            ufw.setDataBundleId("com.unity3d.framework")
            ufw.runEmbedded(withArgc: CommandLine.argc,
                            argv: CommandLine.unsafeArgv,
                            appLaunchOpts: [:])
        }
        framework = ufw

        // C# FELUnityBridge.EmitToHost lands here (see FELUnityEmitter.mm note
        // in FEL-unity/README.md): route JSON back onto the main actor.
        FELUnityEventPump.shared.onEvent = { json in
            Task { @MainActor in host.receive(json: json) }
        }
    }

    /// Swift -> C#: route a HostCommand JSON to the FELUnityBridge GameObject.
    static func sendMessage(_ json: String) {
        framework?.sendMessageToGO(withName: "FELUnityBridge",
                                   functionName: "ReceiveHostMessage",
                                   message: json)
    }

    /// The Unity render view, re-parented into SwiftUI.
    static var unityRootView: UIView? {
        framework?.appController()?.rootView
    }
}

/// Hosts Unity's render UIView inside SwiftUI.
struct UnityContainerView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        UnityBridgeShim.unityRootView ?? UIView()
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// Singleton relay for the C# emitter callback (registered via the tiny ObjC
/// category the embed step adds; until then events simply do not flow).
final class FELUnityEventPump: NSObject {
    static let shared = FELUnityEventPump()
    var onEvent: ((String) -> Void)?

    /// Exposed to ObjC so the C# HostEmitter's native callback can reach Swift.
    @objc func pump(_ json: String) { onEvent?(json) }
}
#endif
