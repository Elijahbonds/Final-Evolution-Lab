import SwiftUI
import SceneKit

struct GameSceneHostView: UIViewRepresentable {
    let gameMode: GameModeId
    var neuralDrive: Double = 50
    let onAction: () -> Void

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = GameSceneFactory.buildScene(for: gameMode)
        scnView.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true
        scnView.defaultCameraController.minimumVerticalAngle = -15
        scnView.defaultCameraController.maximumVerticalAngle = 60
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        scnView.preferredFramesPerSecond = 60
        scnView.showsStatistics = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)

        context.coordinator.scnView = scnView
        context.coordinator.applyNeuralDriveTuning(in: scnView.scene)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.neuralDrive = neuralDrive
        context.coordinator.applyNeuralDriveTuning(in: uiView.scene)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onAction: onAction, gameMode: gameMode, neuralDrive: neuralDrive)
    }

    class Coordinator: NSObject {
        let onAction: () -> Void
        let gameMode: GameModeId
        var neuralDrive: Double
        weak var scnView: SCNView?

        init(onAction: @escaping () -> Void, gameMode: GameModeId, neuralDrive: Double) {
            self.onAction = onAction
            self.gameMode = gameMode
            self.neuralDrive = neuralDrive
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView else { return }
            let location = gesture.location(in: scnView)
            let hitResults = scnView.hitTest(location, options: [.searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue)])

            if let hit = hitResults.first {
                triggerHitEffect(at: hit.worldCoordinates, in: scnView.scene)
            }

            triggerPlayerAction(in: scnView.scene)

            Task { @MainActor in
                onAction()
            }
        }

        private func triggerPlayerAction(in scene: SCNScene?) {
            guard let scene else { return }
            let playerNames: [String]
            switch gameMode {
            case .basketballHeadToHead, .basketballDunkContest:
                playerNames = ["player1", "dunker"]
            case .basketball3v3:
                playerNames = ["blue1"]
            case .karate:
                playerNames = ["fighter1"]
            case .baseball:
                playerNames = ["batter"]
            case .soccer:
                playerNames = ["kicker"]
            case .golf:
                playerNames = ["golfer"]
            case .tennis:
                playerNames = ["player"]
            case .volleyball:
                playerNames = ["vPlayer1"]
            case .gymnastics:
                playerNames = ["gymnast"]
            case .football:
                playerNames = ["returner"]
            }

            for name in playerNames {
                guard let node = scene.rootNode.childNode(withName: name, recursively: true) else { continue }
                let speedMultiplier = actionSpeedMultiplier()
                let actionPulse = SCNAction.sequence([
                    SCNAction.scale(to: 1.12, duration: 0.06 / speedMultiplier),
                    SCNAction.scale(to: 0.96, duration: 0.05 / speedMultiplier),
                    SCNAction.scale(to: 1.0, duration: 0.1 / speedMultiplier)
                ])
                actionPulse.timingMode = .easeOut
                node.runAction(actionPulse, forKey: "actionPulse")

                if let rArm = node.childNode(withName: "rArm", recursively: false) {
                    let armSwing = SCNAction.sequence([
                        SCNAction.rotateTo(x: -1.8, y: 0, z: -0.4, duration: 0.08 / speedMultiplier),
                        SCNAction.rotateTo(x: 0.5, y: 0, z: -0.4, duration: 0.06 / speedMultiplier),
                        SCNAction.rotateTo(x: 0, y: 0, z: -0.4, duration: 0.15 / speedMultiplier)
                    ])
                    rArm.runAction(armSwing, forKey: "actionArm")
                }

                break
            }
        }

        private func actionSpeedMultiplier() -> Double {
            if gameMode == .karate {
                return 1.0 + (max(0, min(neuralDrive, 100)) / 100.0) * 0.55
            }
            return 1.0
        }

        func applyNeuralDriveTuning(in scene: SCNScene?) {
            guard gameMode == .karate, let scene else { return }
            let boost = max(0, min(neuralDrive, 100)) / 100.0
            let emissionStrength = 0.2 + boost * 0.5
            for nodeName in ["fighter1", "fighter2"] {
                guard let fighter = scene.rootNode.childNode(withName: nodeName, recursively: true) else { continue }
                fighter.enumerateChildNodes { child, _ in
                    if let material = child.geometry?.firstMaterial {
                        material.emission.contents = UIColor(red: 1.0, green: 0.2, blue: 0.1, alpha: emissionStrength)
                    }
                }
            }
        }

        private func triggerHitEffect(at position: SCNVector3, in scene: SCNScene?) {
            guard let scene else { return }
            let ring = SCNNode()
            let ringGeo = SCNTorus(ringRadius: 0.01, pipeRadius: 0.004)
            let ringMat = SCNMaterial()
            let color = UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 0.8)
            ringMat.diffuse.contents = color
            ringMat.emission.contents = color
            ringGeo.materials = [ringMat]
            ring.geometry = ringGeo
            ring.position = position
            scene.rootNode.addChildNode(ring)

            let expand = SCNAction.group([
                SCNAction.scale(to: 5, duration: 0.4),
                SCNAction.fadeOut(duration: 0.4)
            ])
            ring.runAction(SCNAction.sequence([expand, SCNAction.removeFromParentNode()]))
        }
    }
}
