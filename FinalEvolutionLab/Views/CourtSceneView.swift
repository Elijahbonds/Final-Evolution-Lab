import SwiftUI
import SceneKit

struct CourtSceneView: UIViewRepresentable {
    let neuralDrive: Double
    let verticalPotential: Double
    let auraLevel: AuraLevel
    let movementSignature: MovementSignature
    let onDunkTriggered: () -> Void
    var dunkPhase: DunkPhase = .idle
    var selectedTrick: DunkTrickSlot = .tomahawk
    var sprintCharge: Double = 0
    var jumpHeight: Double = 0
    var rotationProgress: Double = 0
    var selectedAnimation: NexusAnimationAsset? = nil

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.backgroundColor = .black
        scnView.allowsCameraControl = true
        scnView.defaultCameraController.interactionMode = .orbitTurntable
        scnView.defaultCameraController.inertiaEnabled = true
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true
        scnView.preferredFramesPerSecond = 60
        scnView.showsStatistics = false

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        scnView.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scnView.addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.2
        SCNTransaction.disableActions = false
        context.coordinator.neuralDrive = neuralDrive
        context.coordinator.verticalPotential = verticalPotential
        context.coordinator.auraLevel = auraLevel
        context.coordinator.movementSignature = movementSignature
        context.coordinator.updateAura()
        context.coordinator.updateSelectedAnimation(selectedAnimation)
        context.coordinator.updateDunkPhase(dunkPhase, trick: selectedTrick, sprintCharge: sprintCharge, jumpHeight: jumpHeight, rotationProgress: rotationProgress)
        SCNTransaction.commit()
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
        private var dunkIndex = 0
        private var avatarStateMachine = AvatarStateMachine()
        private let movementConfig = PS2MovementConfig.standard
        private var smoothedCameraPosition = SCNVector3(5, 4, 8)
        private var smoothedCameraTarget = SCNVector3(0, 1.5, 0)
        private var cameraShakeIntensity: Float = 0
        private var isImpactZoom: Bool = false
        private var neonStripNodes: [SCNNode] = []
        private var rimNode: SCNNode?
        private var trailEmitter: SCNNode?
        private var currentDunkPhase: DunkPhase = .idle
        private var engineDrivenDunk = false
        private var currentAnimationId: String? = nil

        func updateSelectedAnimation(_ animation: NexusAnimationAsset?) {
            guard let animation = animation else {
                if currentAnimationId != nil {
                    currentAnimationId = nil
                    avatarRoot?.removeAction(forKey: "keyframeAnimation")
                    completeDunk()
                }
                return
            }
            
            guard currentAnimationId != animation.id else { return }
            currentAnimationId = animation.id
            playKeyframeAnimation(animation)
        }

        func playKeyframeAnimation(_ asset: NexusAnimationAsset) {
            avatarRoot?.removeAction(forKey: "idle")
            avatarRoot?.removeAction(forKey: "keyframeAnimation")
            
            let duration = asset.header.duration
            let action = SCNAction.customAction(duration: duration) { [weak self] node, elapsed in
                guard let self = self else { return }
                let time = Double(elapsed)
                
                // Find the two keyframes to interpolate between
                let sortedKeyframes = asset.keyframes.sorted { $0.timestamp < $1.timestamp }
                guard !sortedKeyframes.isEmpty else { return }
                
                var prevFrame = sortedKeyframes.first!
                var nextFrame = sortedKeyframes.first!
                
                for kf in sortedKeyframes {
                    if kf.timestamp <= time {
                        prevFrame = kf
                    }
                    if kf.timestamp >= time {
                        nextFrame = kf
                        break
                    }
                }
                
                let t: Double
                if nextFrame.timestamp == prevFrame.timestamp {
                    t = 0.0
                } else {
                    t = (time - prevFrame.timestamp) / (nextFrame.timestamp - prevFrame.timestamp)
                }
                
                // Interpolate joint rotations and apply to nodes
                let jointsToAnimate = ["head", "torso", "lUpperArm", "rUpperArm", "lLeg", "rLeg", "lShin", "rShin", "hip", "lKnee", "rKnee"]
                for jointName in jointsToAnimate {
                    guard let jointNode = self.avatarRoot.childNode(withName: jointName, recursively: false) else { continue }
                    
                    if let prevRot = prevFrame.jointRotations[jointName],
                       let nextRot = nextFrame.jointRotations[jointName] {
                        // Interpolate SCNVector4 (x, y, z, w)
                        let rx = Float(prevRot.x + (nextRot.x - prevRot.x) * Float(t))
                        let ry = Float(prevRot.y + (nextRot.y - prevRot.y) * Float(t))
                        let rz = Float(prevRot.z + (nextRot.z - prevRot.z) * Float(t))
                        let rw = Float(prevRot.w + (nextRot.w - prevRot.w) * Float(t))
                        jointNode.eulerAngles = SCNVector3(rx * rw, ry * rw, rz * rw)
                    }
                    
                    if let prevTrans = prevFrame.translationOffsets[jointName],
                       let nextTrans = nextFrame.translationOffsets[jointName] {
                        let px = Float(prevTrans.x + (nextTrans.x - prevTrans.x) * Float(t))
                        let py = Float(prevTrans.y + (nextTrans.y - prevTrans.y) * Float(t))
                        let pz = Float(prevTrans.z + (nextTrans.z - prevTrans.z) * Float(t))
                        jointNode.position = SCNVector3(px, py, pz)
                    }
                }
            }
            
            avatarRoot?.runAction(action, forKey: "keyframeAnimation") { [weak self] in
                // Return to idle
                self?.completeDunk()
            }
        }

        private let brandBlue = UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1)
        private let brandCyan = UIColor(red: 0, green: 0.95, blue: 0.9, alpha: 1)
        private let neonMagenta = UIColor(red: 1.0, green: 0.0, blue: 0.6, alpha: 1)
        private let neonOrange = UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1)
        private let goldHighlight = UIColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1)

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

        private func buildScene() {
            scene.background.contents = UIColor.black

            buildCamera()
            buildCinematicLighting()
            buildAsphaltCourt()
            buildHoop()
            buildBall()
            buildAvatar()
            buildVeniceEnvironment()
            buildNeonAccents()
            buildVolumetricParticles()
            buildAuraEffect()
            buildAvatarTrail()
            startCinematicCameraLoop()
            startNeonPulseLoop()
        }

        private func buildCamera() {
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = 48
            cameraNode.camera?.zNear = 0.1
            cameraNode.camera?.zFar = 80
            cameraNode.camera?.wantsHDR = true
            cameraNode.camera?.bloomIntensity = 0.5
            cameraNode.camera?.bloomThreshold = 0.65
            cameraNode.camera?.bloomBlurRadius = 8
            cameraNode.camera?.wantsDepthOfField = false
            cameraNode.camera?.vignettingIntensity = 0.5
            cameraNode.camera?.vignettingPower = 1.2
            cameraNode.camera?.contrast = 1.06
            cameraNode.camera?.saturation = 1.1
            cameraNode.position = SCNVector3(x: 5, y: 4, z: 8)
            cameraNode.look(at: SCNVector3(x: 0, y: 1.5, z: 0))
            cameraNode.name = "mainCamera"
            scene.rootNode.addChildNode(cameraNode)
        }

        private func buildCinematicLighting() {
            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light?.type = .ambient
            ambient.light?.color = UIColor(red: 0.04, green: 0.05, blue: 0.10, alpha: 1)
            ambient.light?.intensity = 300
            scene.rootNode.addChildNode(ambient)

            let keyLight = SCNNode()
            keyLight.light = SCNLight()
            keyLight.light?.type = .spot
            keyLight.light?.color = brandBlue.withAlphaComponent(0.7)
            keyLight.light?.intensity = 1200
            keyLight.light?.spotInnerAngle = 25
            keyLight.light?.spotOuterAngle = 55
            keyLight.light?.castsShadow = true
            keyLight.light?.shadowRadius = 4
            keyLight.light?.shadowMapSize = CGSize(width: 1024, height: 1024)
            keyLight.light?.shadowSampleCount = 4
            keyLight.position = SCNVector3(x: 2, y: 10, z: 4)
            keyLight.look(at: SCNVector3(x: 0, y: 0, z: 0))
            scene.rootNode.addChildNode(keyLight)

            let fillLight = SCNNode()
            fillLight.light = SCNLight()
            fillLight.light?.type = .omni
            fillLight.light?.color = UIColor(red: 0.08, green: 0.06, blue: 0.20, alpha: 1)
            fillLight.light?.intensity = 400
            fillLight.position = SCNVector3(x: -4, y: 3, z: 5)
            scene.rootNode.addChildNode(fillLight)

            let rimLight = SCNNode()
            rimLight.light = SCNLight()
            rimLight.light?.type = .omni
            rimLight.light?.color = neonMagenta
            rimLight.light?.intensity = 300
            rimLight.position = SCNVector3(x: 3, y: 5, z: -3)
            scene.rootNode.addChildNode(rimLight)
        }

        private func buildAsphaltCourt() {
            let floor = SCNFloor()
            floor.reflectivity = 0.35
            floor.reflectionFalloffEnd = 5
            floor.reflectionResolutionScaleFactor = 0.5
            let floorMat = SCNMaterial()
            floorMat.diffuse.contents = UIColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1)
            floorMat.roughness.contents = 0.7
            floorMat.metalness.contents = 0.15
            floor.materials = [floorMat]
            let floorNode = SCNNode(geometry: floor)
            scene.rootNode.addChildNode(floorNode)

            let courtSurface = SCNBox(width: 9, height: 0.03, length: 6, chamferRadius: 0)
            let courtMat = SCNMaterial()
            courtMat.diffuse.contents = UIColor(red: 0.0, green: 0.15, blue: 0.45, alpha: 1)
            courtMat.roughness.contents = 0.85
            courtMat.metalness.contents = 0.08
            courtSurface.materials = [courtMat]
            let courtNode = SCNNode(geometry: courtSurface)
            courtNode.position = SCNVector3(x: 0, y: 0.015, z: 0)
            scene.rootNode.addChildNode(courtNode)

            let paintArea = SCNBox(width: 4, height: 0.005, length: 4.8, chamferRadius: 0)
            let paintMat = SCNMaterial()
            paintMat.diffuse.contents = UIColor(red: 0.6, green: 0.15, blue: 0.0, alpha: 0.4)
            paintMat.emission.contents = UIColor(red: 0.6, green: 0.15, blue: 0.0, alpha: 0.08)
            paintArea.materials = [paintMat]
            let paintNode = SCNNode(geometry: paintArea)
            paintNode.position = SCNVector3(x: 2.5, y: 0.035, z: 0)
            scene.rootNode.addChildNode(paintNode)

            buildCourtLines()
        }

        private func buildCourtLines() {
            let lineColor = brandCyan.withAlphaComponent(0.5)
            let emissionColor = brandCyan.withAlphaComponent(0.15)

            func makeLine(from: SCNVector3, to: SCNVector3, width: CGFloat = 0.04) {
                let dx = to.x - from.x
                let dz = to.z - from.z
                let length = sqrt(dx * dx + dz * dz)
                let line = SCNBox(width: CGFloat(length), height: 0.006, length: width, chamferRadius: 0)
                let mat = SCNMaterial()
                mat.diffuse.contents = lineColor
                mat.emission.contents = emissionColor
                line.materials = [mat]
                let node = SCNNode(geometry: line)
                node.position = SCNVector3(x: (from.x + to.x) / 2, y: 0.035, z: (from.z + to.z) / 2)
                let angle = atan2(dz, dx)
                node.eulerAngles.y = -angle
                scene.rootNode.addChildNode(node)
            }

            makeLine(from: SCNVector3(-4.5, 0, -3), to: SCNVector3(-4.5, 0, 3))
            makeLine(from: SCNVector3(4.5, 0, -3), to: SCNVector3(4.5, 0, 3))
            makeLine(from: SCNVector3(-4.5, 0, -3), to: SCNVector3(4.5, 0, -3))
            makeLine(from: SCNVector3(-4.5, 0, 3), to: SCNVector3(4.5, 0, 3))
            makeLine(from: SCNVector3(0, 0, -3), to: SCNVector3(0, 0, 3))

            let circle = SCNTorus(ringRadius: 1.0, pipeRadius: 0.02)
            let circleMat = SCNMaterial()
            circleMat.diffuse.contents = lineColor
            circleMat.emission.contents = emissionColor
            circle.materials = [circleMat]
            let circleNode = SCNNode(geometry: circle)
            circleNode.position = SCNVector3(x: 0, y: 0.035, z: 0)
            scene.rootNode.addChildNode(circleNode)

            let threePointArc = SCNTorus(ringRadius: 2.2, pipeRadius: 0.018)
            let arcMat = SCNMaterial()
            arcMat.diffuse.contents = brandBlue.withAlphaComponent(0.3)
            arcMat.emission.contents = brandBlue.withAlphaComponent(0.08)
            threePointArc.materials = [arcMat]
            let arcNode = SCNNode(geometry: threePointArc)
            arcNode.position = SCNVector3(x: 3.0, y: 0.035, z: 0)
            scene.rootNode.addChildNode(arcNode)
        }

        private func buildHoop() {
            let poleGeo = SCNCylinder(radius: 0.07, height: 3.15)
            let poleMat = SCNMaterial()
            poleMat.diffuse.contents = UIColor(white: 0.18, alpha: 1)
            poleMat.metalness.contents = 0.85
            poleMat.roughness.contents = 0.3
            poleGeo.materials = [poleMat]
            let pole = SCNNode(geometry: poleGeo)
            pole.position = SCNVector3(x: 4.0, y: 1.575, z: 0)
            scene.rootNode.addChildNode(pole)

            let backboardGeo = SCNBox(width: 1.3, height: 0.85, length: 0.05, chamferRadius: 0.02)
            let bbMat = SCNMaterial()
            bbMat.diffuse.contents = UIColor(white: 0.12, alpha: 1)
            bbMat.transparency = 0.6
            bbMat.metalness.contents = 0.4
            bbMat.roughness.contents = 0.2
            backboardGeo.materials = [bbMat]
            let backboard = SCNNode(geometry: backboardGeo)
            backboard.position = SCNVector3(x: 3.65, y: 3.15, z: 0)
            scene.rootNode.addChildNode(backboard)

            let bbBorder = SCNBox(width: 1.32, height: 0.87, length: 0.01, chamferRadius: 0.02)
            let bbBorderMat = SCNMaterial()
            bbBorderMat.diffuse.contents = UIColor.clear
            bbBorderMat.emission.contents = brandCyan.withAlphaComponent(0.2)
            bbBorder.materials = [bbBorderMat]
            let bbBorderNode = SCNNode(geometry: bbBorder)
            bbBorderNode.position = SCNVector3(x: 3.64, y: 3.15, z: 0)
            scene.rootNode.addChildNode(bbBorderNode)

            let rimGeo = SCNTorus(ringRadius: 0.24, pipeRadius: 0.018)
            let rimMat = SCNMaterial()
            rimMat.diffuse.contents = neonOrange
            rimMat.emission.contents = neonOrange.withAlphaComponent(0.5)
            rimMat.metalness.contents = 0.9
            rimMat.roughness.contents = 0.2
            rimGeo.materials = [rimMat]
            let rim = SCNNode(geometry: rimGeo)
            rim.position = SCNVector3(x: 3.25, y: 3.15, z: 0)
            rim.name = "rim"
            scene.rootNode.addChildNode(rim)
            rimNode = rim

            let rimGlow = SCNNode()
            rimGlow.light = SCNLight()
            rimGlow.light?.type = .omni
            rimGlow.light?.color = neonOrange
            rimGlow.light?.intensity = 120
            rimGlow.light?.attenuationStartDistance = 0.2
            rimGlow.light?.attenuationEndDistance = 2.0
            rimGlow.position = SCNVector3(x: 3.25, y: 3.15, z: 0)
            scene.rootNode.addChildNode(rimGlow)

            let netSegments = 10
            for i in 0..<netSegments {
                let angle = Float(i) / Float(netSegments) * .pi * 2
                let x = cos(angle) * 0.22
                let z = sin(angle) * 0.22
                let netLine = SCNCylinder(radius: 0.004, height: 0.35)
                let netMat = SCNMaterial()
                netMat.diffuse.contents = UIColor.white.withAlphaComponent(0.35)
                netMat.emission.contents = UIColor.white.withAlphaComponent(0.05)
                netLine.materials = [netMat]
                let netNode = SCNNode(geometry: netLine)
                netNode.position = SCNVector3(x: 3.25 + x, y: 2.98, z: z)
                scene.rootNode.addChildNode(netNode)
            }
        }

        private func buildBall() {
            let ballGeo = SCNSphere(radius: 0.13)
            let ballMat = SCNMaterial()
            ballMat.diffuse.contents = UIColor(red: 0.85, green: 0.38, blue: 0.08, alpha: 1)
            ballMat.roughness.contents = 0.65
            ballMat.metalness.contents = 0.1
            ballGeo.materials = [ballMat]
            ballNode = SCNNode(geometry: ballGeo)
            ballNode.position = SCNVector3(x: -1.5, y: 1.4, z: 0)
            ballNode.castsShadow = true
            scene.rootNode.addChildNode(ballNode)

            let bobAction = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 0.9),
                SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 0.9)
            ])
            bobAction.timingMode = .easeInEaseOut
            ballNode.runAction(SCNAction.repeatForever(bobAction))

            let spin = SCNAction.rotateBy(x: 0, y: 0.5, z: 0, duration: 3.0)
            ballNode.runAction(SCNAction.repeatForever(spin))
        }

        private func buildAvatar() {
            avatarRoot = SCNNode()
            avatarRoot.position = SCNVector3(x: -1.5, y: 0, z: 0)

            let emission = CGFloat(movementSignature.limbEmission)

            func limb(radius: CGFloat, height: CGFloat) -> SCNNode {
                let geo = SCNCapsule(capRadius: radius, height: height)
                let mat = SCNMaterial()
                mat.diffuse.contents = brandBlue
                mat.emission.contents = brandBlue.withAlphaComponent(emission + 0.15)
                mat.metalness.contents = 0.6
                mat.roughness.contents = 0.3
                geo.materials = [mat]
                let node = SCNNode(geometry: geo)
                node.castsShadow = true
                return node
            }

            func joint(radius: CGFloat) -> SCNNode {
                let geo = SCNSphere(radius: radius)
                let mat = SCNMaterial()
                mat.diffuse.contents = brandCyan
                mat.emission.contents = brandCyan.withAlphaComponent(emission + 0.35)
                mat.metalness.contents = 0.7
                mat.roughness.contents = 0.2
                geo.materials = [mat]
                return SCNNode(geometry: geo)
            }

            let head = joint(radius: 0.13)
            head.position = SCNVector3(x: 0, y: 1.9, z: 0)
            head.name = "head"

            let torso = limb(radius: 0.06, height: 0.65)
            torso.position = SCNVector3(x: 0, y: 1.42, z: 0)
            torso.name = "torso"

            let lUpperArm = limb(radius: 0.032, height: 0.38)
            lUpperArm.position = SCNVector3(x: -0.22, y: 1.58, z: 0)
            lUpperArm.eulerAngles.z = 0.4
            lUpperArm.name = "lUpperArm"

            let rUpperArm = limb(radius: 0.032, height: 0.38)
            rUpperArm.position = SCNVector3(x: 0.22, y: 1.58, z: 0)
            rUpperArm.eulerAngles.z = -0.4
            rUpperArm.name = "rUpperArm"

            let lLeg = limb(radius: 0.042, height: 0.52)
            lLeg.position = SCNVector3(x: -0.11, y: 0.78, z: 0)
            lLeg.name = "lLeg"

            let rLeg = limb(radius: 0.042, height: 0.52)
            rLeg.position = SCNVector3(x: 0.11, y: 0.78, z: 0)
            rLeg.name = "rLeg"

            let lShin = limb(radius: 0.038, height: 0.48)
            lShin.position = SCNVector3(x: -0.11, y: 0.32, z: 0)
            lShin.name = "lShin"

            let rShin = limb(radius: 0.038, height: 0.48)
            rShin.position = SCNVector3(x: 0.11, y: 0.32, z: 0)
            rShin.name = "rShin"

            let hipJoint = joint(radius: 0.065)
            hipJoint.position = SCNVector3(x: 0, y: 1.08, z: 0)
            hipJoint.name = "hip"

            let lKnee = joint(radius: 0.032)
            lKnee.position = SCNVector3(x: -0.11, y: 0.55, z: 0)
            lKnee.name = "lKnee"

            let rKnee = joint(radius: 0.032)
            rKnee.position = SCNVector3(x: 0.11, y: 0.55, z: 0)
            rKnee.name = "rKnee"

            for node in [head, torso, lUpperArm, rUpperArm, lLeg, rLeg, lShin, rShin, hipJoint, lKnee, rKnee] {
                avatarRoot.addChildNode(node)
            }

            scene.rootNode.addChildNode(avatarRoot)

            let breathe = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.025, z: 0, duration: 1.4),
                SCNAction.moveBy(x: 0, y: -0.025, z: 0, duration: 1.4)
            ])
            breathe.timingMode = .easeInEaseOut
            avatarRoot.runAction(SCNAction.repeatForever(breathe), forKey: "idle")
        }

        private func buildAuraEffect() {
            let aura = SCNNode()
            aura.name = "aura"

            let particles = SCNParticleSystem()
            particles.birthRate = 0
            particles.particleLifeSpan = 1.5
            particles.particleSize = 0.02
            particles.particleSizeVariation = 0.01
            particles.particleColor = brandCyan
            particles.emitterShape = SCNCylinder(radius: 0.4, height: 2.0)
            particles.spreadingAngle = 180
            particles.particleVelocity = 0.4
            particles.particleVelocityVariation = 0.2
            particles.birthDirection = .random
            particles.blendMode = .additive
            aura.addParticleSystem(particles)
            aura.position = SCNVector3(x: -1.5, y: 1, z: 0)

            scene.rootNode.addChildNode(aura)
            auraNode = aura
        }

        private func buildAvatarTrail() {
            let emitter = SCNNode()
            let trail = SCNParticleSystem()
            trail.birthRate = 0
            trail.particleLifeSpan = 0.5
            trail.particleSize = 0.04
            trail.particleSizeVariation = 0.02
            trail.particleColor = brandCyan.withAlphaComponent(0.3)
            trail.emitterShape = SCNSphere(radius: 0.25)
            trail.spreadingAngle = 180
            trail.particleVelocity = 0.08
            trail.birthDirection = .random
            trail.blendMode = .additive
            emitter.addParticleSystem(trail)
            emitter.position = SCNVector3(x: -1.5, y: 1.2, z: 0)
            emitter.name = "trail"
            scene.rootNode.addChildNode(emitter)
            trailEmitter = emitter
        }

        func updateAura() {
            guard let auraNode, let particles = auraNode.particleSystems?.first else { return }

            if let trail = trailEmitter?.particleSystems?.first {
                trail.particleColor = auraLevel == .maxIntent ? neonMagenta.withAlphaComponent(0.5) : brandCyan.withAlphaComponent(0.3)
            }

            switch auraLevel {
            case .maxIntent:
                particles.birthRate = 25
                particles.particleColor = UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 0.8)
                particles.particleSize = 0.03
            case .primed:
                particles.birthRate = 15
                particles.particleColor = brandCyan.withAlphaComponent(0.6)
                particles.particleSize = 0.025
            case .active:
                particles.birthRate = 8
                particles.particleColor = brandBlue.withAlphaComponent(0.4)
                particles.particleSize = 0.02
            case .baseline:
                particles.birthRate = 3
                particles.particleColor = brandBlue.withAlphaComponent(0.15)
                particles.particleSize = 0.015
            }
        }

        private func buildVeniceEnvironment() {
            let sandColor = UIColor(red: 0.6, green: 0.52, blue: 0.36, alpha: 1)
            let boardwalkColor = UIColor(red: 0.28, green: 0.19, blue: 0.10, alpha: 1)
            let palmGreen = UIColor(red: 0.10, green: 0.35, blue: 0.12, alpha: 1)
            let wallHeight: CGFloat = 5
            let thick: CGFloat = 0.08

            func wallMat(_ color: UIColor) -> SCNMaterial {
                let m = SCNMaterial()
                m.diffuse.contents = color
                m.roughness.contents = 0.9
                m.isDoubleSided = true
                return m
            }

            let backWall = SCNBox(width: 18, height: wallHeight, length: thick, chamferRadius: 0)
            backWall.materials = [wallMat(sandColor)]
            let backNode = SCNNode(geometry: backWall)
            backNode.position = SCNVector3(x: 0, y: Float(wallHeight / 2), z: -7)
            scene.rootNode.addChildNode(backNode)

            let skyGradient = SCNBox(width: 18, height: wallHeight * 0.5, length: 0.02, chamferRadius: 0)
            let skyMat = SCNMaterial()
            skyMat.diffuse.contents = UIColor(red: 0.08, green: 0.18, blue: 0.40, alpha: 1)
            skyGradient.materials = [skyMat]
            let skyNode = SCNNode(geometry: skyGradient)
            skyNode.position = SCNVector3(x: 0, y: Float(wallHeight * 0.85), z: -6.95)
            scene.rootNode.addChildNode(skyNode)

            let oceanWall = SCNBox(width: 18, height: wallHeight, length: thick, chamferRadius: 0)
            let oceanMat = SCNMaterial()
            oceanMat.diffuse.contents = UIColor(red: 0.06, green: 0.18, blue: 0.35, alpha: 1)
            oceanMat.roughness.contents = 0.4
            oceanWall.materials = [oceanMat]
            let frontNode = SCNNode(geometry: oceanWall)
            frontNode.position = SCNVector3(x: 0, y: Float(wallHeight / 2), z: 9)
            scene.rootNode.addChildNode(frontNode)

            let leftWall = SCNBox(width: thick, height: wallHeight, length: 16, chamferRadius: 0)
            leftWall.materials = [wallMat(boardwalkColor)]
            let leftNode = SCNNode(geometry: leftWall)
            leftNode.position = SCNVector3(x: -9, y: Float(wallHeight / 2), z: 1)
            scene.rootNode.addChildNode(leftNode)

            let rightWall = SCNBox(width: thick, height: wallHeight, length: 16, chamferRadius: 0)
            rightWall.materials = [wallMat(boardwalkColor)]
            let rightNode = SCNNode(geometry: rightWall)
            rightNode.position = SCNVector3(x: 9, y: Float(wallHeight / 2), z: 1)
            scene.rootNode.addChildNode(rightNode)

            for x in stride(from: -6.0, through: 6.0, by: 6.0) {
                let trunk = SCNCylinder(radius: 0.09, height: 4.0)
                let tMat = SCNMaterial()
                tMat.diffuse.contents = UIColor(red: 0.35, green: 0.25, blue: 0.12, alpha: 1)
                trunk.materials = [tMat]
                let tNode = SCNNode(geometry: trunk)
                tNode.position = SCNVector3(x: Float(x), y: 2, z: -6.5)
                scene.rootNode.addChildNode(tNode)

                let crown = SCNSphere(radius: 0.7)
                let cMat = SCNMaterial()
                cMat.diffuse.contents = palmGreen
                crown.materials = [cMat]
                let cNode = SCNNode(geometry: crown)
                cNode.position = SCNVector3(x: Float(x), y: 4.3, z: -6.5)
                cNode.scale = SCNVector3(x: 1.2, y: 0.5, z: 1.2)
                scene.rootNode.addChildNode(cNode)
            }

            let boardwalk = SCNBox(width: 18, height: 0.08, length: 2.0, chamferRadius: 0)
            let bwMat = SCNMaterial()
            bwMat.diffuse.contents = boardwalkColor
            bwMat.roughness.contents = 0.95
            boardwalk.materials = [bwMat]
            let bwNode = SCNNode(geometry: boardwalk)
            bwNode.position = SCNVector3(x: 0, y: 0.04, z: -5.5)
            scene.rootNode.addChildNode(bwNode)
        }

        private func buildNeonAccents() {
            func neonStrip(width: CGFloat, length: CGFloat, color: UIColor, position: SCNVector3, rotY: Float = 0) -> SCNNode {
                let geo = SCNBox(width: width, height: 0.04, length: length, chamferRadius: 0.01)
                let mat = SCNMaterial()
                mat.diffuse.contents = color
                mat.emission.contents = color
                mat.roughness.contents = 0.1
                mat.metalness.contents = 0.8
                geo.materials = [mat]
                let node = SCNNode(geometry: geo)
                node.position = position
                node.eulerAngles.y = rotY
                return node
            }

            let leftStrip = neonStrip(width: 0.06, length: 16, color: brandCyan.withAlphaComponent(0.6), position: SCNVector3(x: -9, y: 0.12, z: 1))
            let rightStrip = neonStrip(width: 0.06, length: 16, color: neonMagenta.withAlphaComponent(0.4), position: SCNVector3(x: 9, y: 0.12, z: 1))
            let courtEdgeL = neonStrip(width: 9, length: 0.05, color: brandBlue.withAlphaComponent(0.35), position: SCNVector3(x: 0, y: 0.04, z: -3))
            let courtEdgeR = neonStrip(width: 9, length: 0.05, color: brandBlue.withAlphaComponent(0.35), position: SCNVector3(x: 0, y: 0.04, z: 3))

            neonStripNodes = [leftStrip, rightStrip, courtEdgeL, courtEdgeR]
            for strip in neonStripNodes {
                scene.rootNode.addChildNode(strip)
            }
        }

        private func buildVolumetricParticles() {
            let dustEmitter = SCNNode()
            let dust = SCNParticleSystem()
            dust.birthRate = 10
            dust.particleLifeSpan = 4
            dust.particleSize = 0.012
            dust.particleSizeVariation = 0.006
            dust.particleColor = brandCyan.withAlphaComponent(0.15)
            dust.emitterShape = SCNBox(width: 10, height: 0.2, length: 6, chamferRadius: 0)
            dust.spreadingAngle = 15
            dust.particleVelocity = 0.12
            dust.particleVelocityVariation = 0.06
            dust.birthDirection = .constant
            dust.emittingDirection = SCNVector3(0, 1, 0)
            dust.blendMode = .additive
            dustEmitter.addParticleSystem(dust)
            dustEmitter.position = SCNVector3(x: 0, y: 0.1, z: 0)
            scene.rootNode.addChildNode(dustEmitter)
        }

        private func startNeonPulseLoop() {
            let pulseAction = SCNAction.customAction(duration: 1000) { [weak self] _, elapsed in
                guard let self else { return }
                let t = Float(elapsed.truncatingRemainder(dividingBy: 3.0)) / 3.0
                let intensity = 0.3 + sin(t * .pi * 2) * 0.2
                for strip in self.neonStripNodes {
                    strip.geometry?.firstMaterial?.emission.intensity = CGFloat(intensity)
                }
            }
            scene.rootNode.runAction(SCNAction.repeatForever(pulseAction), forKey: "neonPulse")
        }

        func updateDunkPhase(_ phase: DunkPhase, trick: DunkTrickSlot, sprintCharge: Double, jumpHeight: Double, rotationProgress: Double) {
            guard phase != currentDunkPhase else {
                if phase == .approach {
                    let chargeScale = Float(0.88 + sprintCharge * 0.12)
                    avatarRoot?.scale = SCNVector3(1.0, chargeScale, 1.0)
                }
                if phase == .airborne {
                    let rotY = Float(rotationProgress * .pi * 2)
                    avatarRoot?.eulerAngles.y = rotY
                }
                return
            }
            currentDunkPhase = phase

            switch phase {
            case .idle:
                if engineDrivenDunk {
                    engineDrivenDunk = false
                    completeDunk()
                }
            case .approach:
                engineDrivenDunk = true
                isDunking = true
                avatarRoot?.removeAction(forKey: "idle")
                avatarStateMachine = avatarStateMachine.transitioning(to: .sprint, at: CACurrentMediaTime())
                enableTrail()
            case .launch:
                avatarStateMachine = avatarStateMachine.transitioning(to: .gather, at: CACurrentMediaTime())
                let crouch = crouchAction()
                avatarRoot?.runAction(crouch, forKey: "gather")
            case .airborne:
                avatarStateMachine = avatarStateMachine.transitioning(to: .jump, at: CACurrentMediaTime())
                let height = dunkJumpHeight() * Float(max(0.5, jumpHeight))
                let moveUp = SCNAction.moveBy(x: 3.0, y: Double(height), z: 0, duration: 0.5)
                moveUp.timingMode = .easeOut
                avatarRoot?.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles.z = -2.8
                avatarRoot?.childNode(withName: "lLeg", recursively: false)?.eulerAngles.x = -0.6
                avatarRoot?.runAction(moveUp, forKey: "airJump")
                ballNode?.runAction(SCNAction.move(to: SCNVector3(x: 3.25, y: 3.35, z: 0), duration: 0.6))
            case .landing:
                break
            case .scored:
                avatarStateMachine = avatarStateMachine.transitioning(to: .dunk, at: CACurrentMediaTime())
                triggerDunkImpact()
                avatarRoot?.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles = SCNVector3(0, 0, -0.8)
                let slamDown = SCNAction.moveBy(x: 0.5, y: Double(-dunkJumpHeight() * 0.6), z: 0, duration: 0.2)
                slamDown.timingMode = .easeIn
                avatarRoot?.runAction(slamDown, forKey: "slam")
                animateBallThroughRim(delay: 0.05)
                Task { @MainActor in
                    onDunk()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                    self?.currentDunkPhase = .idle
                    self?.engineDrivenDunk = false
                    self?.completeDunk()
                }
            }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard !isDunking, !engineDrivenDunk else { return }
            isDunking = true
            avatarStateMachine = avatarStateMachine.transitioning(to: .gather, at: CACurrentMediaTime())
            Task { @MainActor in
                onDunk()
            }
            performFreestyleDunk()
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard !isDunking, !engineDrivenDunk else { return }
            isDunking = true
            avatarStateMachine = avatarStateMachine.transitioning(to: .gather, at: CACurrentMediaTime())
            Task { @MainActor in
                onDunk()
            }
            performSpecialDunk()
        }

        private func startCinematicCameraLoop() {
            let cameraAction = SCNAction.customAction(duration: 1000) { [weak self] _, _ in
                guard let self, let camNode = self.scene.rootNode.childNode(withName: "mainCamera", recursively: false) else { return }
                let delta: Float = 1.0 / 60.0
                let cameraLerp = 1.0 - exp(-6 * delta)
                let targetLerp = 1.0 - exp(-8 * delta)

                let avatarPos = self.avatarRoot?.position ?? SCNVector3(0, 0, 0)
                let zoomOffset: Float = self.isImpactZoom ? -2.5 : 0
                let targetCamPos = SCNVector3(avatarPos.x + 5, avatarPos.y + 4, avatarPos.z + 8 + zoomOffset)
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

                let shakeAmt = self.cameraShakeIntensity
                let shakeX = Float.random(in: -0.1...0.1) * shakeAmt
                let shakeY = Float.random(in: -0.08...0.08) * shakeAmt
                let shakeZ = Float.random(in: -0.1...0.1) * shakeAmt

                camNode.position = SCNVector3(
                    self.smoothedCameraPosition.x + shakeX,
                    self.smoothedCameraPosition.y + shakeY,
                    self.smoothedCameraPosition.z + shakeZ
                )
                camNode.look(at: self.smoothedCameraTarget)

                self.cameraShakeIntensity = max(0, self.cameraShakeIntensity - delta * 3)
            }
            scene.rootNode.runAction(SCNAction.repeatForever(cameraAction), forKey: "cameraLoop")
        }

        private func performFreestyleDunk() {
            let dunkType = dunkIndex % 4
            dunkIndex += 1

            enableTrail()

            switch dunkType {
            case 0: performWindmillDunk()
            case 1: performTomahawkDunk()
            case 2: perform360Dunk()
            default: performBetweenLegsDunk()
            }
        }

        private func performSpecialDunk() {
            enableTrail()
            performPosterizeDunk()
        }

        private func enableTrail() {
            if let trail = trailEmitter?.particleSystems?.first {
                trail.birthRate = 60
            }
        }

        private func disableTrail() {
            if let trail = trailEmitter?.particleSystems?.first {
                trail.birthRate = 0
            }
        }

        private func performWindmillDunk() {
            let speed = dunkSpeed()
            let jumpHeight = dunkJumpHeight()

            avatarRoot.removeAction(forKey: "idle")
            ballNode.removeAllActions()

            let crouch = crouchAction()

            let jumpUp = SCNAction.group([
                SCNAction.moveBy(x: 3.5, y: Double(jumpHeight), z: 0, duration: speed * 0.45),
                SCNAction.customAction(duration: speed * 0.3) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles.z = -3.0
                    self?.avatarRoot.childNode(withName: "lLeg", recursively: false)?.eulerAngles.x = -0.6
                    self?.avatarRoot.childNode(withName: "rLeg", recursively: false)?.eulerAngles.x = 0.35
                }
            ])
            jumpUp.timingMode = .easeOut

            let windmillSpin = SCNAction.customAction(duration: speed * 0.2) { [weak self] _, elapsed in
                let t = Float(elapsed / (speed * 0.2))
                self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles.x = -t * .pi * 2
            }

            let hangTime = SCNAction.moveBy(x: 0.6, y: 0, z: 0, duration: speed * 0.15 * movementSignature.hangTimeFactor)
            hangTime.timingMode = .easeInEaseOut

            let dunkMoment = SCNAction.group([
                SCNAction.moveBy(x: 1.0, y: Double(-jumpHeight * 0.3), z: 0, duration: speed * 0.2),
                SCNAction.customAction(duration: speed * 0.15) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles = SCNVector3(0, 0, -0.8)
                    self?.triggerDunkImpact()
                }
            ])
            dunkMoment.timingMode = .easeIn

            let land = landAction(speed: speed)

            let sequence = SCNAction.sequence([crouch, SCNAction.wait(duration: 0.08), jumpUp, windmillSpin, hangTime, dunkMoment, SCNAction.wait(duration: 0.15), land])
            avatarStateMachine = avatarStateMachine.transitioning(to: .dunk, at: CACurrentMediaTime())
            avatarRoot.runAction(sequence) { [weak self] in self?.completeDunk() }
            animateBallThroughRim(delay: speed * 0.6)
        }

        private func performTomahawkDunk() {
            let speed = dunkSpeed()
            let jumpHeight = dunkJumpHeight()

            avatarRoot.removeAction(forKey: "idle")
            ballNode.removeAllActions()

            let crouch = crouchAction()

            let jumpUp = SCNAction.group([
                SCNAction.moveBy(x: 3.2, y: Double(jumpHeight), z: 0.3, duration: speed * 0.5),
                SCNAction.customAction(duration: speed * 0.35) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles = SCNVector3(-2.5, 0, -0.3)
                    self?.avatarRoot.childNode(withName: "torso", recursively: false)?.eulerAngles.x = 0.2
                }
            ])
            jumpUp.timingMode = .easeOut

            let hangTime = SCNAction.moveBy(x: 0.5, y: 0.1, z: -0.3, duration: speed * 0.12 * movementSignature.hangTimeFactor)

            let slam = SCNAction.group([
                SCNAction.moveBy(x: 0.8, y: Double(-jumpHeight * 0.35), z: 0, duration: speed * 0.18),
                SCNAction.customAction(duration: speed * 0.12) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles = SCNVector3(0.5, 0, -0.6)
                    self?.avatarRoot.childNode(withName: "torso", recursively: false)?.eulerAngles.x = 0
                    self?.triggerDunkImpact()
                }
            ])
            slam.timingMode = .easeIn

            let land = landAction(speed: speed)

            let sequence = SCNAction.sequence([crouch, SCNAction.wait(duration: 0.08), jumpUp, hangTime, slam, SCNAction.wait(duration: 0.15), land])
            avatarStateMachine = avatarStateMachine.transitioning(to: .dunk, at: CACurrentMediaTime())
            avatarRoot.runAction(sequence) { [weak self] in self?.completeDunk() }
            animateBallThroughRim(delay: speed * 0.55)
        }

        private func perform360Dunk() {
            let speed = dunkSpeed()
            let jumpHeight = dunkJumpHeight()

            avatarRoot.removeAction(forKey: "idle")
            ballNode.removeAllActions()

            let crouch = crouchAction()

            let jumpUp = SCNAction.group([
                SCNAction.moveBy(x: 3.0, y: Double(jumpHeight), z: 0, duration: speed * 0.5),
                SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: speed * 0.5),
                SCNAction.customAction(duration: speed * 0.3) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles.z = -2.5
                }
            ])
            jumpUp.timingMode = .easeInEaseOut

            let hangTime = SCNAction.moveBy(x: 0.4, y: 0, z: 0, duration: speed * 0.12 * movementSignature.hangTimeFactor)

            let slam = SCNAction.group([
                SCNAction.moveBy(x: 1.1, y: Double(-jumpHeight * 0.3), z: 0, duration: speed * 0.22),
                SCNAction.customAction(duration: speed * 0.15) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles.z = -0.8
                    self?.triggerDunkImpact()
                }
            ])
            slam.timingMode = .easeIn

            let land = landAction(speed: speed)

            let sequence = SCNAction.sequence([crouch, SCNAction.wait(duration: 0.08), jumpUp, hangTime, slam, SCNAction.wait(duration: 0.15), land])
            avatarStateMachine = avatarStateMachine.transitioning(to: .dunk, at: CACurrentMediaTime())
            avatarRoot.runAction(sequence) { [weak self] in self?.completeDunk() }
            animateBallThroughRim(delay: speed * 0.55)
        }

        private func performBetweenLegsDunk() {
            let speed = dunkSpeed()
            let jumpHeight = dunkJumpHeight()

            avatarRoot.removeAction(forKey: "idle")
            ballNode.removeAllActions()

            let crouch = crouchAction()

            let jumpUp = SCNAction.group([
                SCNAction.moveBy(x: 3.3, y: Double(jumpHeight), z: 0, duration: speed * 0.48),
                SCNAction.customAction(duration: speed * 0.3) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "lLeg", recursively: false)?.eulerAngles.x = -0.8
                    self?.avatarRoot.childNode(withName: "rLeg", recursively: false)?.eulerAngles.x = 0.4
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles = SCNVector3(0, 0.5, -2.8)
                }
            ])
            jumpUp.timingMode = .easeOut

            let legSwitch = SCNAction.customAction(duration: 0.12) { [weak self] _, elapsed in
                let t = Float(elapsed / 0.12)
                self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles = SCNVector3(0, 0.5 - t * 1.0, -2.8 + t * 0.5)
            }

            let hangTime = SCNAction.moveBy(x: 0.5, y: 0, z: 0, duration: speed * 0.12 * movementSignature.hangTimeFactor)

            let slam = SCNAction.group([
                SCNAction.moveBy(x: 0.7, y: Double(-jumpHeight * 0.3), z: 0, duration: speed * 0.2),
                SCNAction.customAction(duration: speed * 0.15) { [weak self] _, _ in
                    self?.resetAvatarPose()
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles.z = -0.8
                    self?.triggerDunkImpact()
                }
            ])
            slam.timingMode = .easeIn

            let land = landAction(speed: speed)

            let sequence = SCNAction.sequence([crouch, SCNAction.wait(duration: 0.08), jumpUp, legSwitch, hangTime, slam, SCNAction.wait(duration: 0.15), land])
            avatarStateMachine = avatarStateMachine.transitioning(to: .dunk, at: CACurrentMediaTime())
            avatarRoot.runAction(sequence) { [weak self] in self?.completeDunk() }
            animateBallThroughRim(delay: speed * 0.55)
        }

        private func performPosterizeDunk() {
            let speed = dunkSpeed() * 0.85
            let jumpHeight = dunkJumpHeight() * 1.2

            avatarRoot.removeAction(forKey: "idle")
            ballNode.removeAllActions()

            let crouch = crouchAction()

            let bigJump = SCNAction.group([
                SCNAction.moveBy(x: 3.8, y: Double(jumpHeight), z: 0, duration: speed * 0.55),
                SCNAction.rotateBy(x: 0, y: .pi, z: 0, duration: speed * 0.55),
                SCNAction.customAction(duration: speed * 0.35) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "rUpperArm", recursively: false)?.eulerAngles = SCNVector3(-2.8, 0, -0.2)
                    self?.avatarRoot.childNode(withName: "lUpperArm", recursively: false)?.eulerAngles = SCNVector3(0, 0, 1.8)
                    self?.avatarRoot.childNode(withName: "lLeg", recursively: false)?.eulerAngles.x = -0.7
                }
            ])
            bigJump.timingMode = .easeOut

            let hangTime = SCNAction.moveBy(x: 0.5, y: 0.15, z: 0, duration: speed * 0.2 * movementSignature.hangTimeFactor)
            hangTime.timingMode = .easeInEaseOut

            let posterize = SCNAction.group([
                SCNAction.moveBy(x: 0.5, y: Double(-jumpHeight * 0.4), z: 0, duration: speed * 0.18),
                SCNAction.customAction(duration: speed * 0.12) { [weak self] _, _ in
                    self?.resetAvatarPose()
                    self?.triggerDunkImpact()
                    self?.triggerPosterizeExplosion()
                    self?.cameraShakeIntensity = 1.0
                }
            ])
            posterize.timingMode = .easeIn

            let land = landAction(speed: speed)

            let sequence = SCNAction.sequence([crouch, SCNAction.wait(duration: 0.06), bigJump, hangTime, posterize, SCNAction.wait(duration: 0.2), land])
            avatarStateMachine = avatarStateMachine.transitioning(to: .dunk, at: CACurrentMediaTime())
            avatarRoot.runAction(sequence) { [weak self] in self?.completeDunk() }
            animateBallThroughRim(delay: speed * 0.6)
        }

        private func dunkSpeed() -> Double {
            max(0.28, (1.0 - verticalPotential / 150) * movementSignature.style.animationSpeed)
        }

        private func dunkJumpHeight() -> Float {
            (1.6 + Float(neuralDrive / 100) * 1.2) * Float(movementSignature.jumpApex)
        }

        private func crouchAction() -> SCNAction {
            let action = SCNAction.group([
                SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 0.18),
                SCNAction.customAction(duration: 0.18) { [weak self] _, _ in
                    self?.avatarRoot.childNode(withName: "lLeg", recursively: false)?.eulerAngles.x = 0.3
                    self?.avatarRoot.childNode(withName: "rLeg", recursively: false)?.eulerAngles.x = -0.3
                }
            ])
            action.timingMode = .easeIn
            return action
        }

        private func landAction(speed: Double) -> SCNAction {
            let squash = SCNAction.group([
                SCNAction.customAction(duration: 0.08) { [weak self] node, _ in
                    node.scale = SCNVector3(1.06, 0.92, 1.06)
                    self?.resetAvatarPose()
                }
            ])
            squash.timingMode = .easeOut

            let recover = SCNAction.customAction(duration: 0.2) { node, elapsed in
                let t = Float(elapsed / 0.2)
                node.scale = SCNVector3(1.06 - t * 0.06, 0.92 + t * 0.08, 1.06 - t * 0.06)
            }
            recover.timingMode = .easeOut

            let returnHome = SCNAction.move(to: SCNVector3(x: -1.5, y: 0, z: 0), duration: speed * 0.5)
            returnHome.timingMode = .easeInEaseOut

            return SCNAction.sequence([squash, recover, returnHome])
        }

        private func completeDunk() {
            isDunking = false
            disableTrail()
            avatarStateMachine = avatarStateMachine.transitioning(to: .idle, at: CACurrentMediaTime())
            avatarRoot.scale = SCNVector3(1, 1, 1)
            avatarRoot.eulerAngles = SCNVector3(0, 0, 0)

            let breathe = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: 0.025, z: 0, duration: 1.4),
                SCNAction.moveBy(x: 0, y: -0.025, z: 0, duration: 1.4)
            ])
            breathe.timingMode = .easeInEaseOut
            avatarRoot.runAction(SCNAction.repeatForever(breathe), forKey: "idle")
            resetBallPosition()
        }

        private func triggerDunkImpact() {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.15
            cameraShakeIntensity = 0.7
            isImpactZoom = true
            SCNTransaction.commit()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.3
                self?.isImpactZoom = false
                SCNTransaction.commit()
            }

            flashRim()
            triggerImpactRing()
        }

        private func triggerPosterizeExplosion() {
            for i in 0..<3 {
                let ring = SCNNode()
                let ringGeo = SCNTorus(ringRadius: 0.02, pipeRadius: 0.008)
                let ringMat = SCNMaterial()
                let color = i == 0 ? brandCyan : (i == 1 ? neonMagenta : goldHighlight)
                ringMat.diffuse.contents = color
                ringMat.emission.contents = color
                ringGeo.materials = [ringMat]
                ring.geometry = ringGeo
                ring.position = SCNVector3(x: 3.25, y: 3.15, z: 0)
                scene.rootNode.addChildNode(ring)

                let delay = Double(i) * 0.08
                let expand = SCNAction.sequence([
                    SCNAction.wait(duration: delay),
                    SCNAction.group([
                        SCNAction.scale(to: CGFloat(6 + i * 2), duration: 0.45),
                        SCNAction.fadeOut(duration: 0.45)
                    ]),
                    SCNAction.removeFromParentNode()
                ])
                ring.runAction(expand)
            }
        }

        private func triggerImpactRing() {
            let ring = SCNNode()
            let ringGeo = SCNTorus(ringRadius: 0.015, pipeRadius: 0.006)
            let ringMat = SCNMaterial()
            ringMat.diffuse.contents = brandCyan
            ringMat.emission.contents = brandCyan
            ringGeo.materials = [ringMat]
            ring.geometry = ringGeo
            ring.position = SCNVector3(x: 3.25, y: 3.15, z: 0)
            scene.rootNode.addChildNode(ring)

            let expand = SCNAction.group([
                SCNAction.scale(to: 10, duration: 0.5),
                SCNAction.fadeOut(duration: 0.5)
            ])
            ring.runAction(SCNAction.sequence([expand, SCNAction.removeFromParentNode()]))
        }

        private func animateBallThroughRim(delay: Double) {
            let ballFollow = SCNAction.sequence([
                SCNAction.wait(duration: delay),
                SCNAction.move(to: SCNVector3(x: 3.25, y: 3.35, z: 0), duration: 0.35),
                SCNAction.move(to: SCNVector3(x: 3.25, y: 2.5, z: 0), duration: 0.25),
                SCNAction.move(to: SCNVector3(x: 2.8, y: 0.13, z: 0.5), duration: 0.45),
            ])
            ballFollow.timingMode = .easeInEaseOut
            ballNode.runAction(ballFollow)
        }

        private func resetAvatarPose() {
            for name in ["lUpperArm", "rUpperArm", "lLeg", "rLeg", "lShin", "rShin", "torso"] {
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
                SCNAction.wait(duration: 0.4),
                SCNAction.move(to: SCNVector3(x: -1.5, y: 1.4, z: 0), duration: 0.5)
            ])
            returnAction.timingMode = .easeInEaseOut
            ballNode.runAction(returnAction) { [weak self] in
                let bob = SCNAction.sequence([
                    SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 0.9),
                    SCNAction.moveBy(x: 0, y: -0.06, z: 0, duration: 0.9)
                ])
                bob.timingMode = .easeInEaseOut
                self?.ballNode.runAction(SCNAction.repeatForever(bob))
                let spin = SCNAction.rotateBy(x: 0, y: 0.5, z: 0, duration: 3.0)
                self?.ballNode.runAction(SCNAction.repeatForever(spin))
            }
        }

        private func flashRim() {
            guard let rimNode else { return }
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.1
            rimNode.geometry?.firstMaterial?.emission.contents = UIColor.white
            SCNTransaction.commit()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.35
                rimNode.geometry?.firstMaterial?.emission.contents = self?.neonOrange.withAlphaComponent(0.5)
                SCNTransaction.commit()
            }
        }
    }
}
