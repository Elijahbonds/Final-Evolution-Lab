import SwiftUI
import SceneKit

struct GameSceneHostView: UIViewRepresentable {
    let gameMode: GameModeId
    let onAction: () -> Void

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = GameSceneFactory.buildScene(for: gameMode)
        scnView.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        scnView.preferredFramesPerSecond = 60
        scnView.showsStatistics = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onAction: onAction)
    }

    class Coordinator: NSObject {
        let onAction: () -> Void

        init(onAction: @escaping () -> Void) {
            self.onAction = onAction
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            Task { @MainActor in
                onAction()
            }
        }
    }
}
