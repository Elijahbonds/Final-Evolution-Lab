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
    private var loadRetry: Timer?

    private init() {}

    // MARK: Lifecycle

    /// Load the Unity player and present the gameplay for a mode.
    ///
    /// Unity boots asynchronously after runEmbedded — a loadMode sent
    /// immediately lands before the FELUnityBridge GameObject exists and is
    /// silently dropped. So we retry every 0.7s until the mode's "ready"
    /// event arrives (LoadMode is convergent on the C# side; last one wins).
    func startMode(_ modeId: String) {
        loadUnityIfNeeded()
        isReady = false
        loadRetry?.invalidate()
        send(FELHostCommand(type: "loadMode", modeId: modeId))
        loadRetry = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isReady {
                    self.loadRetry?.invalidate()
                    self.loadRetry = nil
                } else {
                    self.send(FELHostCommand(type: "loadMode", modeId: modeId))
                }
            }
        }
    }

    func pause()  { send(FELHostCommand(type: "pause")) }
    func resume() { send(FELHostCommand(type: "resume")) }
    func quit() {
        loadRetry?.invalidate()
        loadRetry = nil
        send(FELHostCommand(type: "quit"))
        isReady = false
    }

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

/// Single gameplay entry point used by every mode-launching screen. Routes the
/// Unity-ported hero modes into the embedded engine and everything else to the
/// legacy SceneKit GamePlayView — so entry point (Play tab, Dashboard, Lab)
/// can't bypass the Unity path.
struct FELModeLauncherView: View {
    let viewModel: LabViewModel
    let gameMode: GameMode
    var sessionReadiness: Double = 0

    /// Modes whose Unity port is live (device-verified one at a time), mapped
    /// from the Swift snake_case GameModeId to the Unity FELModeRegistry id.
    private static let unityModeIds: [GameModeId: String] = [
        .karateEndless: "karateEndless",
        .basketballDunkContest3D: "basketballDunkContest3D",
    ]

    var body: some View {
        #if FEL_UNITY_EMBEDDED
        if let unityId = Self.unityModeIds[gameMode.id] {
            FELUnityGameView(modeId: unityId)
        } else {
            GamePlayView(viewModel: viewModel, gameMode: gameMode, sessionReadiness: sessionReadiness)
        }
        #else
        GamePlayView(viewModel: viewModel, gameMode: gameMode, sessionReadiness: sessionReadiness)
        #endif
    }
}

/// Per-mode mapping from the shared pad vocabulary to bridge action verbs.
/// Karate: □ jab, △ kick, ✕ block (hold), ○ special — mirroring the SceneKit
/// karate layout so muscle memory transfers.
private enum FELUnityPadMap {
    static func action(for button: FELPadButton, modeId: String) -> String? {
        switch modeId {
        case "karate", "karateEndless":
            switch button {
            case .square: return "jab"
            case .triangle: return "kick"
            case .cross: return "block"
            case .circle: return "special"
            default: return nil
            }
        case "basketballDunkContest3D":
            switch button {
            case .cross: return "dunk"
            case .square, .triangle, .circle: return "jump"
            default: return nil
            }
        default:
            // Generic verbs; mode controllers ignore what they don't use.
            switch button {
            case .cross: return "action"
            case .square: return "shoot"
            case .triangle: return "jump"
            case .circle: return "special"
            default: return nil
            }
        }
    }

    /// Buttons whose release matters (held states like block).
    static func isHold(_ action: String) -> Bool { action == "block" }
}

/// SwiftUI container for the Unity render view + the shared gamepad overlay.
/// Shows a placeholder until the framework is embedded.
struct FELUnityGameView: View {
    let modeId: String
    @ObservedObject private var host = FELUnityHost.shared
    @Environment(\.dismiss) private var dismiss
    @State private var pad = FELGamepadState()
    @State private var stickPump: Timer?

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

            // Shared controller overlay -> bridge input.
            FELGamepadView(state: pad, isActive: true)

            // Minimal chrome: exit top-left, live score chip top-right
            // (the chip is fed by the Unity->Swift event pump — its updating
            // on device is the visible proof the C#->Swift loop is closed).
            VStack {
                HStack {
                    Button {
                        host.quit()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .bold))
                            Text("EXIT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1.5)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.55))
                        .clipShape(Capsule())
                    }
                    Spacer()
                    if let evt = host.lastEvent {
                        Text("\(evt.score)")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
            }
            .padding(12)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            host.startMode(modeId)
            wireInput()
        }
        .onDisappear {
            stickPump?.invalidate()
            stickPump = nil
            host.quit()
        }
    }

    private func wireInput() {
        // Discrete edges: buttons -> mode verbs (dpad handled by moveVector).
        pad.onEvent = { event in
            switch event {
            case .buttonDown(let button):
                if let action = FELUnityPadMap.action(for: button, modeId: modeId) {
                    FELUnityHost.shared.sendAction(action, value: 1)
                }
            case .buttonUp(let button):
                if let action = FELUnityPadMap.action(for: button, modeId: modeId),
                   FELUnityPadMap.isHold(action) {
                    FELUnityHost.shared.sendAction(action, value: 0)
                }
            case .dpadDown, .dpadUp:
                break
            }
        }
        // Continuous movement: pump the merged stick+dpad vector at 30Hz,
        // sending only on change (and a final zero so the player stops).
        var lastSent = CGPoint.zero
        stickPump = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                let v = pad.moveVector
                guard v != lastSent else { return }
                lastSent = v
                FELUnityHost.shared.sendStick(x: Float(v.x), y: Float(v.y))
            }
        }
    }
}

#if FEL_UNITY_EMBEDDED
// Compiled only after UnityFramework.framework is embedded in the app target.
// UnityBridgeShim + UnityContainerView are provided alongside the embed (they
// import UnityFramework directly); see FEL-unity/README.md phase 5.
#endif
