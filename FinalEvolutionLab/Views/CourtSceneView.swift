import SwiftUI
import SceneKit

struct CourtSceneView: UIViewRepresentable {
    let neuralDrive: Double
    let verticalPotential: Double
    let auraLevel: AuraLevel
    let movementSignature: MovementSignature
    let onDunkTriggered: () -> Void

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.backgroundColor = UIColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1)
        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.neuralDrive = neuralDrive
        context.coordinator.verticalPotential = verticalPotential
        context.coordinator.auraLevel = auraLevel
        context.coordinator.movementSignature = movementSignature
        context.coordinator.updateAura()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            neuralDrive: neuralDrive,
            verticalPotential: verticalPotential,
            auraLevel: auraLevel,
            movementSignature: movementSignature,
            onDunk: onDunkTriggered
        )
    }

    class Coordinator: NSObject {
        let scene: SCNScene
        var neuralDrive: Double
        var verticalPotential: Double
        var auraLevel: AuraLevel
        var movementSignature: MovementSignature
        let onDunk: () -> Void

        private var avatarRoot: SCNNode!
        private var ballNode: SCNNode!
        private var auraNode: SCNNode?
        private var isDunking = false
        private var avatarStateMachine = AvatarStateMachine()
        private let movementConfig = PS2MovementConfig.standard
        private var smoothedCameraPosition = SCNVector3(4, 3.5, 6)
        private var smoothedCameraTarget = SCNVector3(0, 1.5, 0)

        init(neuralDrive: Double, verticalPotential: Double, auraLevel: AuraLevel, movementSignature: MovementSignature, onDunk: @escaping () -> Void) {
            self.neuralDrive = neuralDrive
            self.verticalPotential = verticalPotential
            self.auraLevel = auraLevel
            self.movementSignature = movementSignature
            self.onDunk = onDunk
            self.scene = SCNScene()
            super.init()
            buildScene()
        }

        private let brandBlue = UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1)
        private let brandCyan = UIColor(red: 0, green: 0.95, blue: 0.9, alpha: 1)

        private func buildScene() {
            scene.background.contents = UIColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)

            buildCamera()
            buildLighting()
            buildCourt()
            buildHoop()
            buildBall()
            buildAvatar()
            buildVeniceBeachWalls()
            buildParticleAmbience()
            buildAuraEffect()
            startPS2CameraLoop()
        }

        private func buildCamera() {
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 50
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 100
            cameraNode.position = SCNVector3(x: 4, y: 3.5, z: 6)
            cameraNode.look(at: SCNVector3(x: 0, y: 1.5, z: 0))
            scene.rootNode.addChildNode(cameraNode)
        }

        private func buildLighting() {
            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.color = UIColor(white: 0.15, alpha: 1)
            scene.rootNode.addChildNode(ambient)

            let spot = SCNNode()
            spot.light = SCNLight()
            spot.light?.type = .spot
            spot.light?.color = brandBlue.withAlphaComponent(0.6)
            spot.light?.intensity = 800
            spot.light?.spotInnerAngle = 30
            spot.light?.spotOuterAngle = 60
            spot.light?.castsShadow = true
            spot.light?.shadowRadius = 4
            spot.position = SCNVector3(x: 0, y: 8, z: 3)
            spot.look(at: SCNVector3(x: 0, y: 0, z: 0))
            scene.rootNode.addChildNode(spot)

            let fill = SCNNode()
            fill.light = SCNLight()
            fill.light?.type = .omni
            fill.light?.color = UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1)
            fill.light?.intensity = 300
            fill.position = SCNVector3(x: -3, y: 2, z: 4)
            scene.rootNode.addChildNode(fill)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light?.type = .omni
            rim.light?.color = brandCyan
            rim.light?.intensity = 200
            rim.position = SCNVector3(x: 2, y: 4, z: -2)
            scene.rootNode.addChildNode(rim)
        }

        private func buildCourt() {
            let floor = SCNFloor()
            floor.reflectivity = 0.15
            floor.reflectionFalloffEnd = 3
            let floorMaterial = SCNMaterial()
            floorMaterial.diffuse.contents = UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
            floorMaterial.roughness.contents = 0.8
            floor.materials = [floorMaterial]
            let floorNode = SCNNode(geometry: floor)
            scene.rootNode.addChildNode(floorNode)

            let courtSurface = SCNBox(width: 8, height: 0.02, length: 5, chamferRadius: 0)
            let courtMat = SCNMaterial()
            courtMat.diffuse.contents = UIColor(red: 0.08, green: 0.06, blue: 0.04, alpha: 1)
            courtMat.roughness.contents = 0.9
            courtSurface.materials = [courtMat]
            let courtNode = SCNNode(geometry: courtSurface)
            courtNode.position = SCNVector3(x: 0, y: 0.01, z: 0)
            scene.rootNode.addChildNode(courtNode)

            buildCourtLines()
        }

        private func buildCourtLines() {
            let lineColor = brandBlue.withAlphaComponent(0.3)

            func makeLine(from: SCNVector3, to: SCNVector3) {
                let dx = to.x - from.x
                let dz = to.z - from.z
                let length = sqrt(dx * dx + dz * dz)
                let line = SCNBox(width: CGFloat(length), height: 0.005, length: 0.03, chamferRadius: 0)
                let mat = SCNMaterial()
                mat.diffuse.contents = lineColor
                mat.emission.contents = lineColor
                line.materials = [mat]
                let node = SCNNode(geometry: line)
                node.position = SCNVector3(x: (from.x + to.x) / 2, y: 0.025, z: (from.z + to.z) / 2)
                let angle = atan2(dz, dx)
                node.eulerAngles.y = -angle
                scene.rootNode.addChildNode(node)
            }

            makeLine(from: SCNVector3(-4, 0, -2.5), to: SCNVector3(-4, 0, 2.5))
            makeLine(from: SCNVector3(4, 0, -2.5), to: SCNVector3(4, 0, 2.5))
            makeLine(from: SCNVector3(-4, 0, -2.5), to: SCNVector3(4, 0, -2.5))
            makeLine(from: SCNVector3(-4, 0, 2.5), to: SCNVector3(4, 0, 2.5))
            makeLine(from: SCNVector3(0, 0, -2.5), to: SCNVector3(0, 0, 2.5))

            let circle = SCNTorus(ringRadius: 0.9, pipeRadius: 0.015)
            let circleMat = SCNMaterial()
            circleMat.diffuse.contents = lineColor
            circleMat.emission.contents = lineColor
            circle.materials = [circleMat]
            let circleNode = SCNNode(geometry: circle)
            circleNode.position = SCNVector3(x: 0, y: 0.025, z: 0)
            scene.rootNode.addChildNode(circleNode)
        }

        private func buildHoop() {
            let poleGeo = SCNCylinder(radius: 0.06, height: 3.05)
            let poleMat = SCNMaterial()
            poleMat.diffuse.contents = UIColor(white: 0.2, alpha: 1)
            poleMat.metalness.contents = 0.8
            poleGeo.materials = [poleMat]
            let pole = SCNNode(geometry: poleGeo)
            pole.position = SCNVector3(x: 3.5, y: 1.525, z: 0)
            scene.rootNode.addChildNode(pole)

            let backboardGeo = SCNBox(width: 1.2, height: 0.8, length: 0.04, chamferRadius: 0.02)
            let bbMat = SCNMaterial()
            bbMat.diffuse.contents = UIColor(white: 0.15, alpha: 1)
            bbMat.transparency = 0.7
            bbMat.metalness.contents = 0.3
            backboardGeo.materials = [bbMat]
            let backboard = SCNNode(geometry: backboardGeo)
            backboard.position = SCNVector3(x: 3.2, y: 3.05, z: 0)
            scene.rootNode.addChildNode(backboard)

            let rimGeo = SCNTorus(ringRadius: 0.225, pipeRadius: 0.015)
            let rimMat = SCNMaterial()
            rimMat.diffuse.contents = UIColor.orange
            rimMat.emission.contents = UIColor.orange.withAlphaComponent(0.3)
            rimMat.metalness.contents = 0.9
            rimGeo.materials = [rimMat]
            let rim = SCNNode(geometry: rimGeo)
            rim.position = SCNVector3(x: 2.85, y: 3.05, z: 0)
            scene.rootNode.addChildNode(rim)

            let netSegments = 8
            for i in 0..<netSegments {
                let angle = Float(i) / Float(netSegments) * .pi * 2
                let x = cos(angle) * 0.2
                let z = sin(angle) * 0.2
                let netLine = SCNCylinder(radius: 0.003, height: 0.3)
                let netMat = SCNMaterial()
                netMat.diffuse.contents = UIColor.white.withAlphaComponent(0.4)
                netLine.materials = [netMat]
                let netNode = SCNNode(geometry: netLine)
                netNode.position = SCNVector3(x: 2.85 + x, y: 2.9, z: z)
                scene.rootNode.addChildNode(netNode)
            }
        }

        private func buildBall() {
            let ballGeo = SCNSphere(radius: 0.12)
            let ballMat = SCNMaterial()
            ballMat.diffuse.contents = UIColor(red: 0.8, green: 0.35, blue: 0.1, alpha: 1)
            ballMat.roughness.contents = 0.7
            ballGeo.materials = [ballMat]
            ballNode = SCNNode(geometry: ballGeo)
            ballNode.position = SCNVector3(x: -1.5, y: 1.4, z: 0)
            scene.rootNode.addChildNode(ballNode)

            let bobAction = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.8),
                SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.8)
            ])
            ballNode.runAction(SCNAction.repeatForever(bobAction))
        }

        private func buildAvatar() {
            avatarRoot = SCNNode()
            avatarRoot.position = SCNVector3(x: -1.5, y: 0, z: 0)

            let emission = CGFloat(movementSignature.limbEmission)

            func limb(radius: CGFloat, height: CGFloat) -> SCNNode {
                let geo = SCNCapsule(capRadius: radius, height: height)
                let mat = SCNMaterial()
                mat.diffuse.contents = brandBlue
                mat.emission.contents = brandBlue.withAlphaComponent(emission)
                geo.materials = [mat]
                return SCNNode(geometry: geo)
            }

            func joint(radius: CGFloat) -> SCNNode {
                let geo = SCNSphere(radius: radius)
                let mat = SCNMaterial()
                mat.diffuse.contents = brandCyan
                mat.emission.contents = brandCyan.withAlphaComponent(emission + 0.2)
                geo.materials = [mat]
                return SCNNode(geometry: geo)
            }

            let head = joint(radius: 0.12)
            head.position = SCNVector3(x: 0, y: 1.85, z: 0)
            head.name = "head"

            let torso = limb(radius: 0.05, height: 0.6)
            torso.position = SCNVector3(x: 0, y: 1.4, z: 0)
            torso.name = "torso"

            let lUpperArm = limb(radius: 0.03, height: 0.35)
            lUpperArm.position = SCNVector3(x: -0.2, y: 1.55, z: 0)
            lUpperArm.eulerAngles.z = 0.4
            lUpperArm.name = "lUpperArm"

            let rUpperArm = limb(radius: 0.03, height: 0.35)
            rUpperArm.position = SCNVector3(x: 0.2, y: 1.55, z: 0)
            rUpperArm.eulerAngles.z = -0.4
            rUpperArm.name = "rUpperArm"

            let lLeg = limb(radius: 0.04, height: 0.5)
            lLeg.position = SCNVector3(x: -0.1, y: 0.75, z: 0)
            lLeg.name = "lLeg"

            let rLeg = limb(radius: 0.04, height: 0.5)
            rLeg.position = SCNVector3(x: 0.1, y: 0.75, z: 0)
            rLeg.name = "rLeg"

            let lShin = limb(radius: 0.035, height: 0.45)
            lShin.position = SCNVector3(x: -0.1, y: 0.3, z: 0)
            lShin.name = "lShin"

            let rShin = limb(radius: 0.035, height: 0.45)
            rShin.position = SCNVector3(x: 0.1, y: 0.3, z: 0)
            rShin.name = "rShin"

            let lAnkle = joint(radius: 0.025)
            lAnkle.position = SCNVector3(x: -0.1, y: 0.08, z: 0)
            lAnkle.name = "lAnkle"

            let rAnkle = joint(radius: 0.025)
            rAnkle.position = SCNVector3(x: 0.1, y: 0.08, z: 0)
            rAnkle.name = "rAnkle"

            let lKnee = joint(radius: 0.03)
            lKnee.position = SCNVector3(x: -0.1, y: 0.52, z: 0)
            lKnee.name = "lKnee"

            let rKnee = joint(radius: 0.03)
            rKnee.position = SCNVector3(x: 0.1, y: 0.52, z: 0)
            rKnee.name = "rKnee"

            let hipJoint = joint(radius: 0.06)
            hipJoint.position = SCNVector3(x: 0, y: 1.05, z: 0)
            hipJoint.name = "hip"

            for node in [head, torso, lUpperArm, rUpperArm, lLeg, rLeg, lShin, rShin, hipJoint, lAnkle, rAnkle, lKnee, rKnee] {
                avatarRoot.addChildNode(node)
            }

            scene.rootNode.addChildNode(avatarRoot)

            let breathe = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 1.2),
                SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: 1.2)
            ])
            avatarRoot.runAction(SCNAction.repeatForever(breathe), forKey: "idle")
        }

        private func buildAuraEffect() {
            let aura = SCNNode()
            aura.name = "aura"

            let particles = SCNParticleSystem()
            particles.birthRate = 0
            particles.particleLifeSpan = 1.5
            particles.particleSize = 0.03
            particles.particleSizeVariation = 0.02
            particles.particleColor = brandCyan
            particles.emitterShape = SCNCylinder(radius: 0.4, height: 2)
            particles.spreadingAngle = 180
            particles.particleVelocity = 0.5
            particles.particleVelocityVariation = 0.2
            particles.birthDirection = .random
            particles.blendMode = .additive
            aura.addParticleSystem(particles)
            aura.position = SCNVector3(x: -1.5, y: 1, z: 0)

            scene.rootNode.addChildNode(aura)
            auraNode = aura
        }

        func updateAura() {
            guard let auraNode, let particles = auraNode.particleSystems?.first else { return }

            switch auraLevel {
            case .maxIntent:
                particles.birthRate = 40
                particles.particleColor = UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 0.8)
                particles.particleSize = 0.04
            case .primed:
                particles.birthRate = 25
                particles.particleColor = brandCyan.withAlphaComponent(0.6)
                particles.particleSize = 0.03
            case .active:
                particles.birthRate = 12
                particles.particleColor = brandBlue.withAlphaComponent(0.4)
                particles.particleSize = 0.025
            case .baseline:
                particles.birthRate = 0
            }
        }

        private func buildVeniceBeachWalls() {
            let sandColor = UIColor(red: 0.76, green: 0.70, blue: 0.50, alpha: 1)
            let boardwalkColor = UIColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1)
            let palmGreen = UIColor(red: 0.15, green: 0.45, blue: 0.15, alpha: 1)
            let wallHeight: CGFloat = 4
            let wallThickness: CGFloat = 0.05

            func wallMat(_ color: UIColor) -> SCNMaterial {
                let m = SCNMaterial()
                m.diffuse.contents = color
                m.emission.contents = color.withAlphaComponent(0.05)
                m.isDoubleSided = true
                return m
            }

            let backWall = SCNBox(width: 16, height: wallHeight, length: wallThickness, chamferRadius: 0)
            backWall.materials = [wallMat(sandColor)]
            let backNode = SCNNode(geometry: backWall)
            backNode.position = SCNVector3(x: 0, y: Float(wallHeight / 2), z: -6)
            scene.rootNode.addChildNode(backNode)

            let frontWall = SCNBox(width: 16, height: wallHeight, length: wallThickness, chamferRadius: 0)
            frontWall.materials = [wallMat(UIColor(red: 0.12, green: 0.30, blue: 0.55, alpha: 1))]
            let frontNode = SCNNode(geometry: frontWall)
            frontNode.position = SCNVector3(x: 0, y: Float(wallHeight / 2), z: 8)
            scene.rootNode.addChildNode(frontNode)

            let leftWall = SCNBox(width: wallThickness, height: wallHeight, length: 14, chamferRadius: 0)
            leftWall.materials = [wallMat(boardwalkColor)]
            let leftNode = SCNNode(geometry: leftWall)
            leftNode.position = SCNVector3(x: -8, y: Float(wallHeight / 2), z: 1)
            scene.rootNode.addChildNode(leftNode)

            let rightWall = SCNBox(width: wallThickness, height: wallHeight, length: 14, chamferRadius: 0)
            rightWall.materials = [wallMat(boardwalkColor)]
            let rightNode = SCNNode(geometry: rightWall)
            rightNode.position = SCNVector3(x: 8, y: Float(wallHeight / 2), z: 1)
            scene.rootNode.addChildNode(rightNode)

            for x in stride(from: -7.0, through: 7.0, by: 3.5) {
                let trunk = SCNCylinder(radius: 0.08, height: 3.5)
                let tMat = SCNMaterial()
                tMat.diffuse.contents = UIColor(red: 0.4, green: 0.3, blue: 0.15, alpha: 1)
                trunk.materials = [tMat]
                let tNode = SCNNode(geometry: trunk)
                tNode.position = SCNVector3(x: Float(x), y: 1.75, z: -5.5)
                scene.rootNode.addChildNode(tNode)

                let crown = SCNSphere(radius: 0.6)
                let cMat = SCNMaterial()
                cMat.diffuse.contents = palmGreen
                cMat.emission.contents = palmGreen.withAlphaComponent(0.1)
                crown.materials = [cMat]
                let cNode = SCNNode(geometry: crown)
                cNode.position = SCNVector3(x: Float(x), y: 3.8, z: -5.5)
                cNode.scale = SCNVector3(x: 1, y: 0.6, z: 1)
                scene.rootNode.addChildNode(cNode)
            }

            let boardwalk = SCNBox(width: 16, height: 0.06, length: 1.5, chamferRadius: 0)
            let bwMat = SCNMaterial()
            bwMat.diffuse.contents = boardwalkColor
            bwMat.roughness.contents = 0.95
            boardwalk.materials = [bwMat]
            let bwNode = SCNNode(geometry: boardwalk)
            bwNode.position = SCNVector3(x: 0, y: 0.03, z: -5)
            scene.rootNode.addChildNode(bwNode)

            let sandStrip = SCNBox(width: 16, height: 0.02, length: 3, chamferRadius: 0)
            let sMat = SCNMaterial()
            sMat.diffuse.contents = sandColor.withAlphaComponent(0.4)
            sandStrip.materials = [sMat]
            let sNode = SCNNode(geometry: sandStrip)
            sNode.position = SCNVector3(x: 0, y: 0.005, z: 7)
            scene.rootNode.addChildNode(sNode)

            let sunGlow = SCNNode()
            sunGlow.light = SCNLight()
            sunGlow.light?.type = .omni
            sunGlow.light?.color = UIColor(red: 1.0, green: 0.85, blue: 0.5, alpha: 1)
            sunGlow.light?.intensity = 100
            sunGlow.position = SCNVector3(x: 5, y: 6, z: -5)
            scene.rootNode.addChildNode(sunGlow)
        }

        private func buildParticleAmbience() {
            let emitter = SCNNode()
            let particles = SCNParticleSystem()
            particles.birthRate = 15
            particles.particleLifeSpan = 4
            particles.particleSize = 0.015
            particles.particleSizeVariation = 0.01
            particles.particleColor = brandCyan.withAlphaComponent(0.3)
            particles.emitterShape = SCNBox(width: 8, height: 0.1, length: 5, chamferRadius: 0)
            particles.spreadingAngle = 10
            particles.particleVelocity = 0.3
            particles.particleVelocityVariation = 0.1
            particles.birthDirection = .constant
            particles.emittingDirection = SCNVector3(0, 1, 0)
            particles.blendMode = .additive
            emitter.addParticleSystem(particles)
            emitter.position = SCNVector3(x: 0, y: 0, z: 0)
            scene.rootNode.addChildNode(emitter)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard !isDunking else { return }
            isDunking = true
            avatarStateMachine = avatarStateMachine.transitioning(to: .gather, at: CACurrentMediaTime())
            Task { @MainActor in
                onDunk()
            }
            performDunkAnimation()
        }

        private func startPS2CameraLoop() {
            let cameraAction = SCNAction.customAction(duration: 1000) { [weak self] _, elapsed in
                guard let self, let camNode = self.scene.rootNode.childNodes.first(where: { $0.camera != nil }) else { return }
                let delta: Float = 1.0 / 60.0
                let cameraLerp = 1.0 - exp(-self.movementConfig.cameraLerpFactor * delta)
                let targetLerp = 1.0 - exp(-self.movementConfig.cameraTargetLerpFactor * delta)

                let avatarPos = self.avatarRoot?.position ?? SCNVector3(0, 0, 0)
                let targetCamPos = SCNVector3(avatarPos.x + 4, avatarPos.y + 3.5, avatarPos.z + 6)
                let targetLookAt = SCNVector3(avatarPos.x, avatarPos.y + 1.5, avatarPos.z)

                self.smoothedCameraPosition = SCNVector3(
                    self.smoothedCameraPosition.x + (targetCamPos.x - self.smoothedCameraPosition.x) * cameraLerp,
                    self.smoothedCameraPosition.y + (targetCamPos.y - self.smoothedCameraPosition.y) * cameraLerp,
                    self.smoothedCameraPosition.z + (targetCamPos.z - self.smoothedCameraPosition.z) * cameraLerp
                )
                self.smoothedCameraTarget = SCNVector3(
                    self.smoothedCameraTarget.x + (targetLookAt.x - self.smoothedCameraTarget.x) * targetLerp,
                    self.smoothedCameraTarget.y + (targetLookAt.y - self.smoothedCameraTarget.y) * targetLerp,
                    self.smoothedCameraTarget.z + (targetLookAt.z - self.smoothedCameraTarget.z) * targetLerp
                )

                camNode.position = self.smoothedCameraPosition
                camNode.look(at: self.smoothedCameraTarget)
            }
            scene.rootNode.runAction(SCNAction.repeatForever(cameraAction), forKey: "ps2Camera")
        }

        private func performDunkAnimation() {
            let apexMultiplier = Float(movementSignature.jumpApex)
            let hangFactor = movementSignature.hangTimeFactor
            let jumpHeight: Float = (1.5 + Float(neuralDrive / 100) * 1.0) * apexMultiplier
            let speed = max(0.3, (1.0 - verticalPotential / 150) * movementSignature.style.animationSpeed)

            avatarRoot.removeAction(forKey: "idle")
            ballNode.removeAllActions()

            let crouch = SCNAction.group([
                SCNAction.moveBy(x: 0, y: -0.15, z: 0, duration: 0.2),
                SCNAction.customAction(duration: 0.2) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "lLeg", recursively: false)?.eulerAngles.x = 0.3
                    self?.avatarRoot.childNode(withName: "rLeg", recursively: false)?.eulerAngles.x = -0.3
                }
            ])

            let jumpUp = SCNAction.group([
                SCNAction.moveBy(x: 3, y: Double(jumpHeight), z: 0, duration: speed * 0.5),
                SCNAction.customAction(duration: speed * 0.3) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles.z = -2.8
                    self?.avatarRoot.childNode(withName: "lLeg", recursively: false)?.eulerAngles.x = -0.5
                    self?.avatarRoot.childNode(withName: "rLeg", recursively: false)?.eulerAngles.x = 0.3
                }
            ])

            let hangTime = SCNAction.moveBy(x: 0.5, y: 0, z: 0, duration: speed * 0.15 * hangFactor)

            let dunkMoment = SCNAction.group([
                SCNAction.moveBy(x: 1.0, y: Double(-jumpHeight * 0.3), z: 0, duration: speed * 0.25),
                SCNAction.customAction(duration: speed * 0.2) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles.z = -0.8
                    self?.flashRim()
                    self?.triggerImpactEffect()
                }
            ])

            let land = SCNAction.group([
                SCNAction.move(to: SCNVector3(x: -1.5, y: 0, z: 0), duration: speed * 0.6),
                SCNAction.customAction(duration: speed * 0.3) { [weak self] _, _ in
                    self?.resetAvatarPose()
                }
            ])

            let sequence = SCNAction.sequence([
                crouch,
                SCNAction.wait(duration: 0.1),
                jumpUp,
                hangTime,
                dunkMoment,
                SCNAction.wait(duration: 0.2),
                land,
                SCNAction.wait(duration: 0.3)
            ])

            avatarStateMachine = avatarStateMachine.transitioning(to: .dunk, at: CACurrentMediaTime())

            avatarRoot.runAction(sequence) { [weak self] in
                self?.isDunking = false
                self?.avatarStateMachine = self?.avatarStateMachine.transitioning(to: .idle, at: CACurrentMediaTime()) ?? AvatarStateMachine()
                let breathe = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 1.2),
                    SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: 1.2)
                ])
                self?.avatarRoot.runAction(SCNAction.repeatForever(breathe), forKey: "idle")
                self?.resetBallPosition()
            }

            let ballFollow = SCNAction.sequence([
                SCNAction.wait(duration: 0.3),
                SCNAction.move(to: SCNVector3(x: 2.85, y: 3.2, z: 0), duration: speed * 0.5),
                SCNAction.move(to: SCNVector3(x: 2.85, y: 2.5, z: 0), duration: 0.3),
                SCNAction.move(to: SCNVector3(x: 2.5, y: 0.12, z: 0.5), duration: 0.5),
            ])
            ballNode.runAction(ballFollow)
        }

        private func triggerImpactEffect() {
            let impactRing = SCNNode()
            let ringGeo = SCNTorus(ringRadius: 0.01, pipeRadius: 0.005)
            let ringMat = SCNMaterial()
            ringMat.diffuse.contents = brandCyan
            ringMat.emission.contents = brandCyan
            ringGeo.materials = [ringMat]
            impactRing.geometry = ringGeo
            impactRing.position = SCNVector3(x: 2.85, y: 3.05, z: 0)
            scene.rootNode.addChildNode(impactRing)

            let expand = SCNAction.group([
                SCNAction.scale(to: 8, duration: 0.5),
                SCNAction.fadeOut(duration: 0.5)
            ])
            impactRing.runAction(SCNAction.sequence([expand, SCNAction.removeFromParentNode()]))
        }

        private func resetAvatarPose() {
            for name in ["lUpperArm", "rUpperArm", "lLeg", "rLeg", "lShin", "rShin"] {
                let node = avatarRoot.childNode(withName: name, recursively: false)
                if name == "lUpperArm" {
                    node?.eulerAngles = SCNVector3(0, 0, 0.4)
                } else if name == "rUpperArm" {
                    node?.eulerAngles = SCNVector3(0, 0, -0.4)
                } else {
                    node?.eulerAngles = SCNVector3(0, 0, 0)
                }
            }
        }

        private func resetBallPosition() {
            let returnAction = SCNAction.sequence([
                SCNAction.wait(duration: 0.5),
                SCNAction.move(to: SCNVector3(x: -1.5, y: 1.4, z: 0), duration: 0.6)
            ])
            ballNode.runAction(returnAction) { [weak self] in
                let bob = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.08, z: 0, duration: 0.8),
                    SCNAction.moveBy(x: 0, y: -0.08, z: 0, duration: 0.8)
                ])
                self?.ballNode.runAction(SCNAction.repeatForever(bob))
            }
        }

        private func flashRim() {
            scene.rootNode.enumerateChildNodes { node, _ in
                if let torus = node.geometry as? SCNTorus, torus.ringRadius > 0.2 {
                    let originalColor = node.geometry?.firstMaterial?.emission.contents
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.15
                    node.geometry?.firstMaterial?.emission.contents = UIColor.white
                    SCNTransaction.commit()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        SCNTransaction.begin()
                        SCNTransaction.animationDuration = 0.3
                        node.geometry?.firstMaterial?.emission.contents = originalColor
                        SCNTransaction.commit()
                    }
                }
            }
        }
    }
}
