import SwiftUI
import SceneKit

struct GameSceneHostView: UIViewRepresentable {
    var gameMode: GameModeId = .basketballHeadToHead
    var neuralDrive: Double = 50
    var onAction: () -> Void = {}
    var leftStickInput: CGPoint = .zero
    var rightStickInput: CGPoint = .zero
    var isMidAir: Bool = false
    var isSpecialMove: Bool = false
    var isSlowMotion: Bool = false
    /// Increments when `performAction` runs so the SceneKit layer can play a matching animation.
    var sceneActionNonce: UInt64 = 0
    var sceneActionName: String = ""

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = GameSceneFactory.buildScene(for: gameMode)
        Self.applySceneKitPerformanceDefaults(to: scnView.scene)
        scnView.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        scnView.allowsCameraControl = false
        // Phase 7 — 2x MSAA vs 4x: lower fill cost on ProMotion devices while keeping edges acceptable.
        scnView.antialiasingMode = .multisampling2X
        scnView.isPlaying = true
        scnView.preferredFramesPerSecond = 60
        scnView.showsStatistics = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)

        context.coordinator.scnView = scnView
        context.coordinator.applyNeuralDriveTuning(in: scnView.scene)
        context.coordinator.trackedGameMode = gameMode
        context.coordinator.resetCameraAnchors(for: gameMode)
        context.coordinator.startCameraFollowLoop()
        context.coordinator.startPlayerMovementLoop()

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        if context.coordinator.trackedGameMode != gameMode {
            context.coordinator.trackedGameMode = gameMode
            uiView.scene = GameSceneFactory.buildScene(for: gameMode)
            Self.applySceneKitPerformanceDefaults(to: uiView.scene)
            context.coordinator.resetCameraAnchors(for: gameMode)
            context.coordinator.scnView = uiView
            context.coordinator.startCameraFollowLoop()
            context.coordinator.startPlayerMovementLoop()
        }
        context.coordinator.neuralDrive = neuralDrive
        context.coordinator.leftStickInput = leftStickInput
        context.coordinator.rightStickInput = rightStickInput
        context.coordinator.isMidAir = isMidAir
        context.coordinator.isSpecialMove = isSpecialMove
        context.coordinator.isSlowMotion = isSlowMotion
        context.coordinator.sceneActionNonce = sceneActionNonce
        context.coordinator.sceneActionName = sceneActionName
        context.coordinator.applyNeuralDriveTuning(in: uiView.scene)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onAction: onAction, gameMode: gameMode, neuralDrive: neuralDrive)
    }

    private static func applySceneKitPerformanceDefaults(to scene: SCNScene?) {
        guard let scene else { return }
        scene.physicsWorld.timeStep = 1.0 / 60.0
    }

    class Coordinator: NSObject {
        let onAction: () -> Void
        var trackedGameMode: GameModeId
        var neuralDrive: Double
        weak var scnView: SCNView?

        var leftStickInput: CGPoint = .zero
        var rightStickInput: CGPoint = .zero
        var isMidAir: Bool = false
        var isSpecialMove: Bool = false
        var isSlowMotion: Bool = false
        var sceneActionNonce: UInt64 = 0
        var sceneActionName: String = ""
        private var lastProcessedSceneActionNonce: UInt64 = 0
        private var verticalVelocity: Float = 0
        private var groundY: Float = 0

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

        private enum CinematicState: Equatable {
            case normal
            case midAir
            case specialMove
            case landing
        }

        private var playerNodeName: String {
            switch trackedGameMode {
            case .basketballHeadToHead: return "player1"
            case .basketballDunkContest: return "dunker"
            case .basketball3v3: return "blue1"
            case .karate1v1, .karateEndless: return "fighter1"
            case .baseball: return "batter"
            case .soccer: return "kicker"
            case .golf: return "golfer"
            case .tennis: return "player"
            case .volleyball: return "vPlayer1"
            case .gymnastics: return "gymnast"
            case .football: return "returner"
            }
        }

        private var cameraConfig: ArenaSceneMovementConfig.CameraFollow {
            ArenaSceneMovementConfig.cameraFollow(for: trackedGameMode)
        }

        private var movementBounds: ArenaSceneMovementConfig.MovementBounds {
            ArenaSceneMovementConfig.movementBounds(for: trackedGameMode)
        }

        func resetCameraAnchors(for mode: GameModeId) {
            let c = ArenaSceneMovementConfig.cameraFollow(for: mode)
            smoothedCameraPosition = SCNVector3(c.offsetX, c.offsetY, c.offsetZ)
            smoothedCameraTarget = SCNVector3(0, c.lookAtY, 0)
            lastCinematicState = .normal
            cinematicTransitionProgress = 0
            verticalVelocity = 0
            groundY = 0
        }

        init(onAction: @escaping () -> Void, gameMode: GameModeId, neuralDrive: Double) {
            self.onAction = onAction
            self.trackedGameMode = gameMode
            self.neuralDrive = neuralDrive
            let config = ArenaSceneMovementConfig.cameraFollow(for: gameMode)
            self.smoothedCameraPosition = SCNVector3(config.offsetX, config.offsetY, config.offsetZ)
            self.smoothedCameraTarget = SCNVector3(0, config.lookAtY, 0)
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

            let delta: Float = 1.0 / 60.0
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

            consumeSceneActionIfNeeded(on: playerNode, in: scene)

            let delta: Float = 1.0 / 60.0
            if groundY == 0, playerNode.position.y <= 0.02 {
                groundY = playerNode.position.y
            }

            verticalVelocity += -0.32 * delta
            var newPos = playerNode.position
            newPos.y += verticalVelocity
            if newPos.y <= groundY {
                newPos.y = groundY
                verticalVelocity = 0
            }

            let stickX = Float(leftStickInput.x)
            let stickY = Float(leftStickInput.y)
            let magnitude = hypot(stickX, stickY)
            let bounds = movementBounds
            let neuralMul = Float(1.0 + neuralDrive / 200.0)
            let rightMag = hypot(Float(rightStickInput.x), Float(rightStickInput.y))
            let sprintMul: Float = rightMag > 0.65 ? 1.38 : 1.0

            if magnitude > 0.08 {
                var speed = bounds.baseSpeed * neuralMul * sprintMul
                let moveX = stickX * speed
                let moveZ = -stickY * speed

                newPos.x = min(bounds.maxX, max(bounds.minX, newPos.x + moveX))
                newPos.z = min(bounds.maxZ, max(bounds.minZ, newPos.z + moveZ))

                let targetAngle = atan2(moveX, moveZ)
                let currentAngle = playerNode.eulerAngles.y
                var angleDiff = targetAngle - currentAngle
                if angleDiff > .pi { angleDiff -= .pi * 2 }
                if angleDiff < -.pi { angleDiff += .pi * 2 }
                playerNode.eulerAngles.y += angleDiff * 0.15

                animateRunState(playerNode, speed: min(1.2, magnitude))

                if rightMag > 0.3 {
                    let lookAngle = atan2(Float(rightStickInput.x), Float(rightStickInput.y))
                    let currentY = playerNode.eulerAngles.y
                    var diff = lookAngle - currentY
                    if diff > .pi { diff -= .pi * 2 }
                    if diff < -.pi { diff += .pi * 2 }
                    playerNode.eulerAngles.y += diff * 0.1
                }
            } else {
                animateIdleState(playerNode)
            }

            playerNode.position = newPos

            if let ball = findBallNode(in: scene) {
                let ballOffset = SCNVector3(0, 1.4, 0)
                let targetBallPos = SCNVector3(newPos.x + ballOffset.x, ballOffset.y + newPos.y, newPos.z + ballOffset.z)
                ball.position = lerpVec3(ball.position, targetBallPos, t: 0.2)
            }
        }

        private func consumeSceneActionIfNeeded(on playerNode: SCNNode, in scene: SCNScene) {
            guard sceneActionNonce != lastProcessedSceneActionNonce else { return }
            lastProcessedSceneActionNonce = sceneActionNonce
            let raw = sceneActionName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return }
            applySceneActionAnimation(named: raw, on: playerNode, in: scene)
        }

        private func applySceneActionAnimation(named raw: String, on playerNode: SCNNode, in scene: SCNScene) {
            let a = raw.lowercased()
            let mode = trackedGameMode

            switch mode {
            case .basketballHeadToHead, .basketball3v3, .basketballDunkContest:
                if a.contains("dunk") || a.contains("jump") || a.contains("launch") {
                    verticalVelocity = max(verticalVelocity, 0.26)
                    triggerCinematicShake(intensity: 0.35)
                }
                if a.contains("shoot") || a.contains("shot") || a.contains("3") {
                    playArmWindup(playerNode, lead: 1.1, duration: 0.22)
                }
                if a.contains("pass") {
                    playArmWindup(playerNode, lead: -0.9, duration: 0.18)
                }
                if a.contains("block") || a.contains("steal") {
                    bothArmsUp(playerNode, duration: 0.2)
                }
                if a.contains("sprint") || a.contains("drive") || a.contains("crossover") {
                    triggerCinematicShake(intensity: 0.12)
                }
            case .karate1v1, .karateEndless:
                triggerCinematicShake(intensity: a.contains("kick") ? 0.45 : 0.32)
                punchFlash(playerNode, isKick: a.contains("kick"))
            case .football:
                if a.contains("throw") || a.contains("pass") {
                    playArmWindup(playerNode, lead: 1.0, duration: 0.25)
                }
                if a.contains("juk") || a.contains("juke") || a.contains("spin") {
                    triggerCinematicShake(intensity: 0.15)
                }
            case .soccer:
                if a.contains("kick") || a.contains("shot") {
                    legKickPulse(playerNode)
                }
            case .baseball:
                if a.contains("swing") || a.contains("hit") {
                    playArmWindup(playerNode, lead: 1.4, duration: 0.2)
                }
            case .golf:
                if a.contains("swing") {
                    playArmWindup(playerNode, lead: 1.5, duration: 0.35)
                }
            case .tennis, .volleyball:
                if a.contains("spike") || a.contains("serve") || a.contains("swing") {
                    bothArmsUp(playerNode, duration: 0.22)
                }
            case .gymnastics:
                if a.contains("tumble") || a.contains("vault") || a.contains("flip") {
                    verticalVelocity = max(verticalVelocity, 0.2)
                    nodeFlipRoll(playerNode)
                }
                if a.contains("dismount") {
                    verticalVelocity = max(verticalVelocity, 0.14)
                }
            }

            let pulse = SCNAction.sequence([
                SCNAction.scale(to: 1.08, duration: 0.05),
                SCNAction.scale(to: 1.0, duration: 0.12)
            ])
            pulse.timingMode = .easeOut
            playerNode.runAction(pulse, forKey: "actionRootPulse")
        }

        private func playArmWindup(_ node: SCNNode, lead: Float, duration: TimeInterval) {
            guard let arm = node.childNode(withName: lead > 0 ? "rArm" : "lArm", recursively: false) else { return }
            let wind = SCNAction.sequence([
                SCNAction.rotateTo(x: CGFloat(lead), y: 0, z: lead > 0 ? -0.4 : 0.4, duration: duration * 0.45),
                SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(lead > 0 ? -0.4 : 0.4), duration: duration * 0.55)
            ])
            arm.runAction(wind, forKey: "windup")
        }

        private func bothArmsUp(_ node: SCNNode, duration: TimeInterval) {
            for name in ["lArm", "rArm"] {
                guard let arm = node.childNode(withName: name, recursively: false) else { continue }
                let up = SCNAction.sequence([
                    SCNAction.rotateTo(x: -1.0, y: 0, z: name == "lArm" ? 0.4 : -0.4, duration: duration * 0.5),
                    SCNAction.rotateTo(x: 0, y: 0, z: name == "lArm" ? 0.4 : -0.4, duration: duration * 0.5)
                ])
                arm.runAction(up, forKey: "blockArms")
            }
        }

        private func legKickPulse(_ node: SCNNode) {
            guard let leg = node.childNode(withName: "rLeg", recursively: false) else { return }
            let kick = SCNAction.sequence([
                SCNAction.rotateTo(x: CGFloat(0.9), y: 0, z: 0, duration: 0.08),
                SCNAction.rotateTo(x: 0, y: 0, z: 0, duration: 0.12)
            ])
            leg.runAction(kick, forKey: "kick")
        }

        private func punchFlash(_ node: SCNNode, isKick: Bool) {
            if isKick {
                legKickPulse(node)
            } else {
                playArmWindup(node, lead: 1.2, duration: 0.14)
            }
        }

        private func nodeFlipRoll(_ node: SCNNode) {
            let roll = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 0.45)
            roll.timingMode = .easeInEaseOut
            node.runAction(roll, forKey: "gymFlip")
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

            if let lArm = node.childNode(withName: "lArm", recursively: false),
               let rArm = node.childNode(withName: "rArm", recursively: false) {
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
                for childName in ["lLeg", "rLeg", "lArm", "rArm"] {
                    if let child = node.childNode(withName: childName, recursively: false) {
                        child.removeAction(forKey: "legAnim")
                        child.removeAction(forKey: "armAnim")
                        let resetZ: Float = childName == "lArm" ? 0.4 : (childName == "rArm" ? -0.4 : 0)
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
            if trackedGameMode.isKarateFamily {
                return 1.0 + (max(0, min(neuralDrive, 100)) / 100.0) * 0.55
            }
            return 1.0
        }

        func applyNeuralDriveTuning(in scene: SCNScene?) {
            guard trackedGameMode.isKarateFamily, let scene else { return }
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
