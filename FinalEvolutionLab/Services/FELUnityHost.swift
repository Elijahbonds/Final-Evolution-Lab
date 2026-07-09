import Combine
import Foundation
import SwiftUI

// MARK: - FELUnityHost (Lane F: UaaL embed seam)
//
// Owns the embedded Unity player (UnityFramework.framework) once it is linked
// into this app, and speaks the JSON HostCommand/HostEvent protocol with the
// C# side (FELUnityBridge in the FELGameplay Unity project).
//
// Build order (why the framework calls are behind a compile flag):
//   1. Unity exports the Xcode project (FEL-unity/FELGameplay/iosBuild).
//   2. UnityFramework.framework from that project is embedded into THIS app
//      target, and FEL_UNITY_EMBEDDED is added to Swift Active Compilation
//      Conditions. Until then this file compiles to a stub so the app keeps
//      building unchanged (same seam pattern as the bundled-asset drop-ins).
//
// Swift -> Unity: send(_:) encodes HostCommand JSON and calls
//   UnityFramework.sendMessageToGO(withName: "FELUnityBridge",
//                                  functionName: "ReceiveHostMessage", ...)
// Unity -> Swift: the C# side emits HostEvent JSON through a registered
//   emitter; onEvent republishes it to SwiftUI via @Published.

/// Host -> Unity command envelope (mirrors C# FEL.Bridge.HostCommand).
struct FELHostCommand: Codable {
    var type: String          // "loadMode" | "input" | "pause" | "resume" | "quit"
    var modeId: String = ""
    var action: String = ""
    var x: Float = 0
    var y: Float = 0
    var value: Float = 0
}

/// Unity -> Host event envelope (mirrors C# FEL.Bridge.HostEvent).
struct FELHostEvent: Codable {
    var type: String          // "ready" | "score" | "event" | "result"
    var name: String = ""
    var payload: String = ""
    var score: Int = 0
    var opponentScore: Int = 0
}

@MainActor
final class FELUnityHost: ObservableObject {
    static let shared = FELUnityHost()

    /// Latest event from the Unity side; SwiftUI HUD observes this.
    @Published private(set) var lastEvent: FELHostEvent?
    /// True once the Unity player is loaded and the bridge answered "ready".
    @Published private(set) var isReady = false

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: Lifecycle

    /// Load the Unity player and present the gameplay for a mode.
    func startMode(_ modeId: String) {
        loadUnityIfNeeded()
        send(FELHostCommand(type: "loadMode", modeId: modeId))
    }

    func pause()  { send(FELHostCommand(type: "pause")) }
    func resume() { send(FELHostCommand(type: "resume")) }
    func quit()   { send(FELHostCommand(type: "quit")); isReady = false }

    // MARK: Input (called from FELGamepadView / GCController handlers)

    func sendStick(x: Float, y: Float) {
        send(FELHostCommand(type: "input", action: "move", x: x, y: y))
    }

    func sendAction(_ action: String, value: Float = 1) {
        send(FELHostCommand(type: "input", action: action, value: value))
    }

    // MARK: Bridge plumbing

    private func send(_ cmd: FELHostCommand) {
        guard let data = try? encoder.encode(cmd),
              let json = String(data: data, encoding: .utf8) else { return }
        #if FEL_UNITY_EMBEDDED
        UnityBridgeShim.sendMessage(json)
        #else
        // Framework not linked yet: log so mode wiring is testable in-shell.
        print("[FELUnityHost] (stub) -> \(json)")
        #endif
    }

    /// Called by the framework shim when C# emits a HostEvent.
    func receive(json: String) {
        guard let data = json.data(using: .utf8),
              let evt = try? decoder.decode(FELHostEvent.self, from: data) else { return }
        lastEvent = evt
        if evt.type == "ready" { isReady = true }
    }

    private func loadUnityIfNeeded() {
        #if FEL_UNITY_EMBEDDED
        UnityBridgeShim.loadUnity(host: self)
        #endif
    }
}

/// SwiftUI container for the Unity render view. Shows a placeholder until the
/// framework is embedded; afterwards it hosts UnityFramework's root view.
struct FELUnityGameView: View {
    let modeId: String
    @ObservedObject private var host = FELUnityHost.shared

    var body: some View {
        ZStack {
            #if FEL_UNITY_EMBEDDED
            UnityContainerView()
                .ignoresSafeArea()
            #else
            // Pre-embed placeholder keeps navigation + HUD wiring testable.
            Color.black.ignoresSafeArea()
            VStack(spacing: 8) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.cyan)
                Text("Unity gameplay pending framework embed")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(modeId)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            #endif
        }
        .onAppear { host.startMode(modeId) }
        .onDisappear { host.quit() }
    }
}

#if FEL_UNITY_EMBEDDED
// Compiled only after UnityFramework.framework is embedded in the app target.
// UnityBridgeShim + UnityContainerView are provided alongside the embed (they
// import UnityFramework directly); see FEL-unity/README.md phase 5.
#endif
