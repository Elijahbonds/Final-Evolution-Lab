import SwiftUI
import SceneKit

struct GameSceneHostView: UIViewRepresentable {
    var gameMode: GameModeId = .basketballHeadToHead
    var neuralDrive: Double = 50
    var onAction: () -> Void = {}
    var onViewportReady: () -> Void = {}
    var leftStickInput: CGPoint = .zero
    var rightStickInput: CGPoint = .zero
    var isMidAir: Bool = false
    var isSpecialMove: Bool = false
    var isSlowMotion: Bool = false

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        let scene = GameSceneFactory.buildScene(for: gameMode)
        GameSceneFactory.warmSceneForDisplay(scene)
        scnView.scene = scene
        scnView.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        scnView.allowsCameraControl = false
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        scnView.rendersContinuously = true
        if let cameraNode = scene.rootNode.childNode(withName: "mainCamera", recursively: true) {
            scnView.pointOfView = cameraNode
        }
        scnView.accessibilityIdentifier = "GameSceneViewport"
        scnView.accessibilityValue = "loading"
        let screenMax = UIScreen.main.maximumFramesPerSecond
        // SceneKit preview path: prefer device refresh up to 120Hz. Full-frame UE gameplay remains in the embedded host.
        scnView.preferredFramesPerSecond = screenMax > 0 ? min(120, screenMax) : 60
        scnView.showsStatistics = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)
        context.coordinator.tapGesture = tap
        scnView.delegate = context.coordinator

        context.coordinator.scnView = scnView
        context.coordinator.applyNeuralDriveTuning(in: scnView.scene)
        context.coordinator.syncInitialCameraToPlayer(in: scnView.scene)
        context.coordinator.startCameraFollowLoop()
        context.coordinator.startPlayerMovementLoop()
        scnView.prepare(scene, shouldAbortBlock: nil)

        return scnView
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.teardown(view: uiView)
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.neuralDrive = neuralDrive
        context.coordinator.leftStickInput = leftStickInput
        context.coordinator.rightStickInput = rightStickInput
        context.coordinator.isMidAir = isMidAir
        context.coordinator.isSpecialMove = isSpecialMove
        context.coordinator.isSlowMotion = isSlowMotion
        context.coordinator.applyNeuralDriveTuning(in: uiView.scene)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onAction: onAction, onViewportReady: onViewportReady, gameMode: gameMode, neuralDrive: neuralDrive)
    }

    class Coordinator: NSObject, SCNSceneRendererDelegate {
        let onAction: () -> Void
        let onViewportReady: () -> Void
        let gameMode: GameModeId
        var neuralDrive: Double
        weak var scnView: SCNView?
        weak var tapGesture: UITapGestureRecognizer?

        /// Updated by ``SCNSceneRendererDelegate`` — drives camera smoothing at real frame deltas.
        var latestFrameDelta: Float = 1.0 / 60.0
        private var lastRendererTime: CFTimeInterval?

        var leftStickInput: CGPoint = .zero
        var rightStickInput: CGPoint = .zero
        var isMidAir: Bool = false
        var isSpecialMove: Bool = false
        var isSlowMotion: Bool = false

        private var smoothedCameraPosition = SCNVector3(0, 4, 8)
        private var smoothedCameraTarget = SCNVector3(0, 1.2, 0)
        private var cameraShakeIntensity: Float = 0
        private var cinematicZoomOffset: Float = 0
        private var cinematicHeightOffset: Float = 0
        private var cinematicAngleOffset: Float = 0
        private var lastCinematicState: CinematicState = .normal
        private var cinematicTransitionProgress: Float = 0
        private var playerVelocity: SCNVector3 = SCNVector3(0, 0, 0)
        private var lastPlayerY: Float = 0
        private var renderedFrameCount = 0
        private var didReportViewportReady = false

        private enum CinematicState: Equatable {
            case normal
            case midAir
            case specialMove
            case landing
        }

        private var playerNodeName: String {
            switch gameMode {
            case .basketballHeadToHead, .marketBrowse: return "player1"
            case .basketballDunkContest: return "dunker"
            case .basketball3v3: return "blue1"
            case .karate, .karateEndless: return "fighter1"
            case .baseball: return "batter"
            case .soccer: return "kicker"
            case .golf: return "golfer"
            case .tennis: return "player"
            case .volleyball: return "vPlayer1"
            case .gymnastics: return "gymnast"
            case .surfing: return "surfer"
            case .skateboarding: return "skater"
            case .snowboarding: return "rider"
            case .brainBrawl, .whoSceneIt: return "cognitivePlayer"
            case .courtCarnival: return "player1"
            case .football: return "returner"
            }
        }

        private var cameraConfig: CameraFollowConfig {
            switch gameMode {
            case .basketballHeadToHead, .basketball3v3, .marketBrowse:
                return CameraFollowConfig(offsetX: 2, offsetY: 5, offsetZ: 8, lookAtY: 1.2, followSpeed: 5, targetSpeed: 7, fovNormal: 48, fovAction: 38)
            case .basketballDunkContest:
                return CameraFollowConfig(offsetX: 1.5, offsetY: 5.5, offsetZ: 9, lookAtY: 2.0, followSpeed: 6, targetSpeed: 8, fovNormal: 48, fovAction: 35)
            case .karate, .karateEndless:
                return CameraFollowConfig(offsetX: 0, offsetY: 3.5, offsetZ: 6, lookAtY: 1.2, followSpeed: 7, targetSpeed: 9, fovNormal: 48, fovAction: 36)
            case .football:
                return CameraFollowConfig(offsetX: 0, offsetY: 6, offsetZ: 8, lookAtY: 1.0, followSpeed: 5, targetSpeed: 6, fovNormal: 52, fovAction: 42)
            case .soccer:
                return CameraFollowConfig(offsetX: 1, offsetY: 4, offsetZ: 7, lookAtY: 0.8, followSpeed: 5, targetSpeed: 7, fovNormal: 50, fovAction: 40)
            case .baseball:
                return CameraFollowConfig(offsetX: -2, offsetY: 3.5, offsetZ: 6, lookAtY: 1.5, followSpeed: 4, targetSpeed: 6, fovNormal: 48, fovAction: 38)
            case .golf:
                return CameraFollowConfig(offsetX: 2, offsetY: 3, offsetZ: 7, lookAtY: 1.0, followSpeed: 3, targetSpeed: 5, fovNormal: 46, fovAction: 36)
            case .tennis:
                return CameraFollowConfig(offsetX: 0, offsetY: 5, offsetZ: 9, lookAtY: 1.0, followSpeed: 5, targetSpeed: 7, fovNormal: 50, fovAction: 40)
            case .volleyball:
                return CameraFollowConfig(offsetX: 0, offsetY: 5, offsetZ: 8, lookAtY: 1.5, followSpeed: 5, targetSpeed: 7, fovNormal: 48, fovAction: 38)
            case .gymnastics:
                return CameraFollowConfig(offsetX: 1, offsetY: 4, offsetZ: 8, lookAtY: 1.5, followSpeed: 4, targetSpeed: 6, fovNormal: 48, fovAction: 36)
            case .surfing:
                return CameraFollowConfig(offsetX: 2.4, offsetY: 4.6, offsetZ: 9.2, lookAtY: 1.45, followSpeed: 5, targetSpeed: 8, fovNormal: 50, fovAction: 38)
            case .skateboarding:
                return CameraFollowConfig(offsetX: 1.1, offsetY: 3.7, offsetZ: 7.4, lookAtY: 1.15, followSpeed: 6, targetSpeed: 9, fovNormal: 48, fovAction: 36)
            case .snowboarding:
                return CameraFollowConfig(offsetX: 1.8, offsetY: 5.1, offsetZ: 9, lookAtY: 1.55, followSpeed: 4, targetSpeed: 7, fovNormal: 52, fovAction: 40)
            case .brainBrawl, .whoSceneIt:
                return CameraFollowConfig(offsetX: 0.9, offsetY: 4.2, offsetZ: 7.2, lookAtY: 1.45, followSpeed: 3, targetSpeed: 5, fovNormal: 46, fovAction: 34)
            case .courtCarnival:
                return CameraFollowConfig(offsetX: 2, offsetY: 5, offsetZ: 8, lookAtY: 1.2, followSpeed: 5, targetSpeed: 7, fovNormal: 48, fovAction: 38)
            }
        }

        private var movementBounds: MovementBounds {
            switch gameMode {
            case .basketballHeadToHead, .marketBrowse:
                return MovementBounds(minX: -3.8, maxX: 3.8, minZ: -2.5, maxZ: 2.5, speed: 0.12)
            case .basketballDunkContest:
                return MovementBounds(minX: -5.0, maxX: 4.0, minZ: -3.5, maxZ: 3.5, speed: 0.14)
            case .basketball3v3:
                return MovementBounds(minX: -4.5, maxX: 4.5, minZ: -2.8, maxZ: 2.8, speed: 0.12)
            case .karate, .karateEndless:
                return MovementBounds(minX: -2.5, maxX: 2.5, minZ: -2.5, maxZ: 2.5, speed: 0.10)
            case .football:
                return MovementBounds(minX: -4.0, maxX: 4.0, minZ: -12.0, maxZ: 12.0, speed: 0.16)
            case .soccer:
                return MovementBounds(minX: -3.0, maxX: 3.0, minZ: -2.0, maxZ: 2.0, speed: 0.08)
            case .baseball:
                return MovementBounds(minX: -1.0, maxX: 1.0, minZ: -0.5, maxZ: 0.5, speed: 0.04)
            case .golf:
                return MovementBounds(minX: -1.0, maxX: 1.0, minZ: -0.5, maxZ: 0.5, speed: 0.03)
            case .tennis:
                return MovementBounds(minX: -3.0, maxX: 3.0, minZ: -2.0, maxZ: 2.0, speed: 0.10)
            case .volleyball:
                return MovementBounds(minX: -3.0, maxX: 3.0, minZ: -1.5, maxZ: 1.5, speed: 0.09)
            case .gymnastics:
                return MovementBounds(minX: -3.0, maxX: 3.0, minZ: -2.0, maxZ: 2.0, speed: 0.08)
            case .surfing:
                return MovementBounds(minX: -3.5, maxX: 3.5, minZ: -2.8, maxZ: 2.8, speed: 0.095)
            case .skateboarding:
                return MovementBounds(minX: -3.2, maxX: 3.2, minZ: -2.4, maxZ: 2.4, speed: 0.11)
            case .snowboarding:
                return MovementBounds(minX: -3.8, maxX: 3.8, minZ: -3.2, maxZ: 3.2, speed: 0.09)
            case .brainBrawl, .whoSceneIt:
                return MovementBounds(minX: -2.4, maxX: 2.4, minZ: -1.6, maxZ: 1.6, speed: 0.055)
            case .courtCarnival:
                return MovementBounds(minX: -4.5, maxX: 4.5, minZ: -2.8, maxZ: 2.8, speed: 0.12)
            }
        }

        init(onAction: @escaping () -> Void, onViewportReady: @escaping () -> Void, gameMode: GameModeId, neuralDrive: Double) {
            self.onAction = onAction
            self.onViewportReady = onViewportReady
            self.gameMode = gameMode
            self.neuralDrive = neuralDrive
            let config = GameSceneHostView.Coordinator.defaultCameraConfig(for: gameMode)
            self.smoothedCameraPosition = SCNVector3(config.offsetX, config.offsetY, config.offsetZ)
            self.smoothedCameraTarget = SCNVector3(0, config.lookAtY, 0)
        }

        private static func defaultCameraConfig(for mode: GameModeId) -> CameraFollowConfig {
            switch mode {
            case .basketballHeadToHead, .basketball3v3:
                return CameraFollowConfig(offsetX: 2, offsetY: 5, offsetZ: 8, lookAtY: 1.2, followSpeed: 5, targetSpeed: 7, fovNormal: 48, fovAction: 38)
            case .basketballDunkContest:
                return CameraFollowConfig(offsetX: 1.5, offsetY: 5.5, offsetZ: 9, lookAtY: 2.0, followSpeed: 6, targetSpeed: 8, fovNormal: 48, fovAction: 35)
            case .karate, .karateEndless:
                return CameraFollowConfig(offsetX: 0, offsetY: 3.5, offsetZ: 6, lookAtY: 1.2, followSpeed: 7, targetSpeed: 9, fovNormal: 48, fovAction: 36)
            default:
                return CameraFollowConfig(offsetX: 1, offsetY: 4.5, offsetZ: 8, lookAtY: 1.0, followSpeed: 5, targetSpeed: 7, fovNormal: 48, fovAction: 38)
            }
        }

        func syncInitialCameraToPlayer(in scene: SCNScene?) {
            guard let scene,
                  let camNode = scene.rootNode.childNode(withName: "mainCamera", recursively: false),
                  let playerNode = scene.rootNode.childNode(withName: playerNodeName, recursively: true) else { return }

            let config = cameraConfig
            let playerPos = playerNode.position
            smoothedCameraPosition = SCNVector3(
                playerPos.x + config.offsetX,
                playerPos.y + config.offsetY,
                playerPos.z + config.offsetZ
            )
            smoothedCameraTarget = SCNVector3(
                playerPos.x,
                playerPos.y + config.lookAtY,
                playerPos.z
            )
            camNode.position = smoothedCameraPosition
            camNode.look(at: smoothedCameraTarget)
        }

        func startCameraFollowLoop() {
            guard let scene = scnView?.scene else { return }
            let cameraAction = SCNAction.customAction(duration: 100000) { [weak self] _, _ in
                self?.updateCameraFollow()
            }
            scene.rootNode.runAction(SCNAction.repeatForever(cameraAction), forKey: "cameraFollowLoop")
        }

        func startPlayerMovementLoop() {
            guard let scene = scnView?.scene else { return }
            let moveAction = SCNAction.customAction(duration: 100000) { [weak self] _, _ in
                self?.updatePlayerMovement()
            }
            scene.rootNode.runAction(SCNAction.repeatForever(moveAction), forKey: "playerMoveLoop")
        }

        private func updateCameraFollow() {
            guard let scene = scnView?.scene,
                  let camNode = scene.rootNode.childNode(withName: "mainCamera", recursively: false) else { return }

            let playerNode = scene.rootNode.childNode(withName: playerNodeName, recursively: true)
            let playerPos = playerNode?.presentation.position ?? SCNVector3(0, 0, 0)

            let delta = max(latestFrameDelta, 1.0 / 240.0)
            let config = cameraConfig

            let currentState = determineCinematicState()
            if currentState != lastCinematicState {
                cinematicTransitionProgress = 0
                lastCinematicState = currentState
            }
            cinematicTransitionProgress = min(1.0, cinematicTransitionProgress + delta * 3.0)
            let t = easeInOut(cinematicTransitionProgress)

            var targetZoomOffset: Float = 0
            var targetHeightOffset: Float = 0
            var targetAngleOffset: Float = 0
            var targetFOV: CGFloat = config.fovNormal
            var followSpeedMult: Float = 1.0
            var targetSpeedMult: Float = 1.0

            switch currentState {
            case .midAir:
                targetZoomOffset = -2.5
                targetHeightOffset = 1.5
                targetAngleOffset = -0.3
                targetFOV = config.fovAction
                followSpeedMult = 1.8
                targetSpeedMult = 2.0
                if cameraShakeIntensity < 0.1 {
                    cameraShakeIntensity = 0.15
                }
            case .specialMove:
                targetZoomOffset = -3.5
                targetHeightOffset = 0.8
                targetAngleOffset = 0.2
                targetFOV = config.fovAction - 4
                followSpeedMult = 2.5
                targetSpeedMult = 3.0
                if cameraShakeIntensity < 0.3 {
                    cameraShakeIntensity = 0.4
                }
            case .landing:
                targetZoomOffset = -1.0
                targetHeightOffset = -0.5
                targetFOV = config.fovNormal + 3
                followSpeedMult = 1.5
                targetSpeedMult = 1.5
                cameraShakeIntensity = max(cameraShakeIntensity, 0.5)
            case .normal:
                break
            }

            cinematicZoomOffset += (targetZoomOffset - cinematicZoomOffset) * t
            cinematicHeightOffset += (targetHeightOffset - cinematicHeightOffset) * t
            cinematicAngleOffset += (targetAngleOffset - cinematicAngleOffset) * t

            let cameraLerp = 1.0 - exp(-config.followSpeed * followSpeedMult * delta)
            let targetLerp = 1.0 - exp(-config.targetSpeed * targetSpeedMult * delta)

            let desiredCamPos = SCNVector3(
                playerPos.x + config.offsetX + cinematicAngleOffset * 3,
                playerPos.y + config.offsetY + cinematicHeightOffset,
                playerPos.z + config.offsetZ + cinematicZoomOffset
            )
            let desiredLookAt = SCNVector3(
                playerPos.x,
                playerPos.y + config.lookAtY + cinematicHeightOffset * 0.4,
                playerPos.z
            )

            smoothedCameraPosition = lerpVec3(smoothedCameraPosition, desiredCamPos, t: cameraLerp)
            smoothedCameraTarget = lerpVec3(smoothedCameraTarget, desiredLookAt, t: targetLerp)

            let shakeAmt = cameraShakeIntensity
            let shakeX = Float.random(in: -0.1...0.1) * shakeAmt
            let shakeY = Float.random(in: -0.08...0.08) * shakeAmt
            let shakeZ = Float.random(in: -0.1...0.1) * shakeAmt

            camNode.position = SCNVector3(
                smoothedCameraPosition.x + shakeX,
                smoothedCameraPosition.y + shakeY,
                smoothedCameraPosition.z + shakeZ
            )
            camNode.look(at: smoothedCameraTarget)

            let fovLerp = 1.0 - exp(Double(-4 * delta))
            let currentFOV = camNode.camera?.fieldOfView ?? config.fovNormal
            camNode.camera?.fieldOfView = currentFOV + (targetFOV - currentFOV) * fovLerp

            if isSlowMotion {
                camNode.camera?.motionBlurIntensity = 0.15
            } else {
                camNode.camera?.motionBlurIntensity = 0
            }

            cameraShakeIntensity = max(0, cameraShakeIntensity - delta * 2.5)
        }

        private func determineCinematicState() -> CinematicState {
            if isSpecialMove { return .specialMove }
            if isMidAir { return .midAir }

            guard let scene = scnView?.scene,
                  let playerNode = scene.rootNode.childNode(withName: playerNodeName, recursively: true) else {
                return .normal
            }
            let currentY = playerNode.presentation.position.y
            let wasAirborne = lastPlayerY > 0.3
            let isGrounded = currentY < 0.15

            if wasAirborne && isGrounded {
                lastPlayerY = currentY
                return .landing
            }

            lastPlayerY = currentY

            if currentY > 0.5 { return .midAir }

            return .normal
        }

        private func updatePlayerMovement() {
            guard let scene = scnView?.scene,
                  let playerNode = scene.rootNode.childNode(withName: playerNodeName, recursively: true) else { return }

            let stickX = Float(leftStickInput.x)
            let stickY = Float(leftStickInput.y)
            let magnitude = hypot(stickX, stickY)
            guard magnitude > 0.08 else {
                animateIdleState(playerNode)
                return
            }

            let bounds = movementBounds
            let speed = bounds.speed * Float(1.0 + neuralDrive / 200.0)
            let delta = max(latestFrameDelta, 1.0 / 240.0)
            let tickScale = delta * 60.0

            let moveX = stickX * speed * tickScale
            let moveZ = -stickY * speed * tickScale

            var newPos = playerNode.position
            newPos.x = min(bounds.maxX, max(bounds.minX, newPos.x + moveX))
            newPos.z = min(bounds.maxZ, max(bounds.minZ, newPos.z + moveZ))

            playerNode.position = newPos

            let targetAngle = atan2(stickX * speed, -stickY * speed)
            let currentAngle = playerNode.eulerAngles.y
            var angleDiff = targetAngle - currentAngle
            if angleDiff > .pi { angleDiff -= .pi * 2 }
            if angleDiff < -.pi { angleDiff += .pi * 2 }
            playerNode.eulerAngles.y += angleDiff * 0.15 * tickScale

            animateRunState(playerNode, speed: magnitude)

            if let ball = findBallNode(in: scene) {
                let ballOffset = SCNVector3(0, 1.4, 0)
                let targetBallPos = SCNVector3(newPos.x + ballOffset.x, ballOffset.y, newPos.z + ballOffset.z)
                let followT = min(0.35, 0.2 * tickScale)
                ball.position = lerpVec3(ball.position, targetBallPos, t: followT)
            }

            let rightMag = hypot(Float(rightStickInput.x), Float(rightStickInput.y))
            if rightMag > 0.3 {
                let lookAngle = atan2(Float(rightStickInput.x), Float(rightStickInput.y))
                let currentY = playerNode.eulerAngles.y
                var diff = lookAngle - currentY
                if diff > .pi { diff -= .pi * 2 }
                if diff < -.pi { diff += .pi * 2 }
                playerNode.eulerAngles.y += diff * 0.1 * tickScale
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            if let last = lastRendererTime {
                latestFrameDelta = Float(max(time - last, 1.0 / 240.0))
            }
            lastRendererTime = time
        }

        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            renderedFrameCount += 1
            guard renderedFrameCount >= 2 else { return }
            scnView?.accessibilityValue = "ready"
            guard !didReportViewportReady else { return }
            didReportViewportReady = true
            Task { @MainActor in
                onViewportReady()
            }
        }

        func teardown(view: SCNView) {
            view.delegate = nil
            lastRendererTime = nil
            renderedFrameCount = 0
            didReportViewportReady = false
            view.accessibilityValue = "loading"
            if let g = tapGesture {
                view.removeGestureRecognizer(g)
                tapGesture = nil
            }
            view.scene?.rootNode.removeAction(forKey: "cameraFollowLoop")
            view.scene?.rootNode.removeAction(forKey: "playerMoveLoop")
            view.scene = nil
            scnView = nil
        }

        private func animateRunState(_ node: SCNNode, speed: Float) {
            guard node.action(forKey: "runBob") == nil else { return }
            let bobHeight = Double(speed * 0.03)
            let bobDuration = Double(max(0.15, 0.3 - speed * 0.1))
            let bob = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: bobHeight, z: 0, duration: bobDuration),
                SCNAction.moveBy(x: 0, y: -bobHeight, z: 0, duration: bobDuration)
            ])
            bob.timingMode = .easeInEaseOut
            node.runAction(SCNAction.repeatForever(bob), forKey: "runBob")

            if let lLeg = node.childNode(withName: "lLeg", recursively: false),
               let rLeg = node.childNode(withName: "rLeg", recursively: false) {
                let legSwing = Double(speed * 0.4)
                let legDuration = Double(max(0.12, 0.25 - speed * 0.08))
                let lForward = SCNAction.rotateTo(x: CGFloat(-legSwing), y: 0, z: 0, duration: legDuration)
                let lBack = SCNAction.rotateTo(x: CGFloat(legSwing), y: 0, z: 0, duration: legDuration)
                lLeg.runAction(SCNAction.repeatForever(SCNAction.sequence([lForward, lBack])), forKey: "legAnim")

                let rForward = SCNAction.rotateTo(x: CGFloat(legSwing), y: 0, z: 0, duration: legDuration)
                let rBack = SCNAction.rotateTo(x: CGFloat(-legSwing), y: 0, z: 0, duration: legDuration)
                rLeg.runAction(SCNAction.repeatForever(SCNAction.sequence([rForward, rBack])), forKey: "legAnim")
            }

            if let lArm = node.childNode(withName: "lUpperArm", recursively: false),
               let rArm = node.childNode(withName: "rUpperArm", recursively: false) {
                let armSwing = Double(speed * 0.3)
                let armDuration = Double(max(0.12, 0.25 - speed * 0.08))
                let laFwd = SCNAction.rotateTo(x: CGFloat(armSwing), y: 0, z: 0.4, duration: armDuration)
                let laBack = SCNAction.rotateTo(x: CGFloat(-armSwing), y: 0, z: 0.4, duration: armDuration)
                lArm.runAction(SCNAction.repeatForever(SCNAction.sequence([laFwd, laBack])), forKey: "armAnim")

                let raFwd = SCNAction.rotateTo(x: CGFloat(-armSwing), y: 0, z: -0.4, duration: armDuration)
                let raBack = SCNAction.rotateTo(x: CGFloat(armSwing), y: 0, z: -0.4, duration: armDuration)
                rArm.runAction(SCNAction.repeatForever(SCNAction.sequence([raFwd, raBack])), forKey: "armAnim")
            }
        }

        private func animateIdleState(_ node: SCNNode) {
            if node.action(forKey: "runBob") != nil {
                node.removeAction(forKey: "runBob")
                for childName in ["lLeg", "rLeg", "lUpperArm", "rUpperArm"] {
                    if let child = node.childNode(withName: childName, recursively: false) {
                        child.removeAction(forKey: "legAnim")
                        child.removeAction(forKey: "armAnim")
                        let resetZ: Float = childName.contains("lUpper") ? 0.4 : (childName.contains("rUpper") ? -0.4 : 0)
                        let reset = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(resetZ), duration: 0.2)
                        reset.timingMode = .easeOut
                        child.runAction(reset)
                    }
                }
            }
        }

        private func findBallNode(in scene: SCNScene) -> SCNNode? {
            let ballNames = ["ball", "basketball", "soccerball", "baseball", "golfball", "tennisball", "volleyball"]
            for name in ballNames {
                if let node = scene.rootNode.childNode(withName: name, recursively: true) {
                    return node
                }
            }
            for child in scene.rootNode.childNodes {
                if let geo = child.geometry as? SCNSphere, geo.radius < 0.2 {
                    return child
                }
            }
            return nil
        }

        private func lerpVec3(_ a: SCNVector3, _ b: SCNVector3, t: Float) -> SCNVector3 {
            SCNVector3(
                a.x + (b.x - a.x) * t,
                a.y + (b.y - a.y) * t,
                a.z + (b.z - a.z) * t
            )
        }

        private func easeInOut(_ t: Float) -> Float {
            t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
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

        func triggerCinematicShake(intensity: Float) {
            cameraShakeIntensity = max(cameraShakeIntensity, intensity)
        }

        private func triggerPlayerAction(in scene: SCNScene?) {
            guard let scene else { return }
            guard let node = scene.rootNode.childNode(withName: playerNodeName, recursively: true) else { return }
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
        }

        private func actionSpeedMultiplier() -> Double {
            if gameMode == .karate || gameMode == .karateEndless {
                return 1.0 + (max(0, min(neuralDrive, 100)) / 100.0) * 0.55
            }
            return 1.0
        }

        func applyNeuralDriveTuning(in scene: SCNScene?) {
            guard (gameMode == .karate || gameMode == .karateEndless), let scene else { return }
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

nonisolated private struct CameraFollowConfig: Sendable {
    let offsetX: Float
    let offsetY: Float
    let offsetZ: Float
    let lookAtY: Float
    let followSpeed: Float
    let targetSpeed: Float
    let fovNormal: CGFloat
    let fovAction: CGFloat
}

nonisolated private struct MovementBounds: Sendable {
    let minX: Float
    let maxX: Float
    let minZ: Float
    let maxZ: Float
    let speed: Float
}
