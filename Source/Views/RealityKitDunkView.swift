import SwiftUI
import RealityKit
import UIKit

/// RealityKit freestyle dunk court: procedural 3D only (no external assets). Court, hoop, net, dunker, backdrop, camera, lights built from MeshResource + SimpleMaterial.
struct RealityKitDunkView: View {
    var leftStickInput: CGPoint = .zero
    var isMidAir: Bool = false
    var dunkPhase: DunkPhase = .idle
    var jumpHeight: Float = 0
    var sprintCharge: Float = 0
    var avatarConfig: AvatarSkinConfig = .default
    @Binding var dunkImpactToTrigger: (modifier: DunkModifier, impactIntensity: Double)?

    private var dunkerTint: (r: Float, g: Float, b: Float) {
        (Float(avatarConfig.auraColorR), Float(avatarConfig.auraColorG), Float(avatarConfig.auraColorB))
    }

    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = "dunkRoot"

            let courtFloor = makeCourtFloor()
            root.addChild(courtFloor)

            let backdrop = makeBackdrop()
            root.addChild(backdrop)

            let hoop = makeHoop()
            root.addChild(hoop)

            let dunker = makeDunker(tint: dunkerTint, heightScale: Float(avatarConfig.heightScale))
            dunker.name = "dunker"
            root.addChild(dunker)

            let camera = makeCamera()
            root.addChild(camera)

            let light = makeLight()
            root.addChild(light)

            content.add(root)
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == "dunkRoot" }),
                  let dunker = root.findEntity(named: "dunker") as? ModelEntity else { return }
            let forward = Float(leftStickInput.y)
            let baseZ: Float = 4
            let runZ = baseZ - forward * 8
            let jumpY: Float = isMidAir ? 1.2 + jumpHeight * 0.8 : 0
            let targetPosition = SIMD3<Float>(0, jumpY, runZ)
            dunker.position = targetPosition

            applyDunkerPose(to: dunker)
            updateCameraFollow(root: root, dunkerPosition: targetPosition)
            if dunkImpactToTrigger != nil {
                triggerRimEffect(root: root)
                DispatchQueue.main.async { dunkImpactToTrigger = nil }
            }
        }
        .ignoresSafeArea()
    }

    private func applyDunkerPose(to dunker: ModelEntity) {
        let (bodyPitch, bodyRoll, bodyScaleY, armLAngle, armRAngle): (Float, Float, Float, Float, Float)
        switch dunkPhase {
        case .idle:
            bodyPitch = 0
            bodyRoll = 0
            bodyScaleY = 1
            armLAngle = 0.15
            armRAngle = 0.15
        case .approach:
            let charge = min(1, sprintCharge)
            bodyPitch = -0.32 * charge
            bodyRoll = 0
            bodyScaleY = 1.0 - charge * 0.02
            armLAngle = -0.55 - charge * 0.35
            armRAngle = -0.55 - charge * 0.35
        case .launch:
            bodyPitch = -0.18
            bodyRoll = 0
            bodyScaleY = 0.97
            armLAngle = -0.7
            armRAngle = -0.7
        case .airborne:
            bodyPitch = 0.35 + jumpHeight * 0.25
            bodyRoll = jumpHeight * 0.18
            bodyScaleY = 1.04
            armLAngle = 1.0
            armRAngle = 1.0
        case .landing:
            bodyPitch = 0.08
            bodyRoll = 0
            bodyScaleY = 0.9
            armLAngle = 0.25
            armRAngle = 0.25
        case .scored:
            bodyPitch = 0
            bodyRoll = 0
            bodyScaleY = 1
            armLAngle = 0.15
            armRAngle = 0.15
        }
        dunker.orientation = simd_quatf(angle: bodyPitch, axis: [1, 0, 0]) * simd_quatf(angle: bodyRoll, axis: [0, 0, 1])
        dunker.transform.scale = SIMD3<Float>(1, bodyScaleY, 1)
        if let armL = dunker.findEntity(named: "armL") as? ModelEntity {
            armL.orientation = simd_quatf(angle: armLAngle, axis: [1, 0, 0])
        }
        if let armR = dunker.findEntity(named: "armR") as? ModelEntity {
            armR.orientation = simd_quatf(angle: armRAngle, axis: [1, 0, 0])
        }
    }

    private func makeCourtFloor() -> Entity {
        let courtMesh = MeshResource.generateBox(width: 12, height: 0.02, depth: 8)
        var courtMat = SimpleMaterial()
        courtMat.color = .init(tint: .init(red: 0.2, green: 0.13, blue: 0.06, alpha: 1))
        let court = ModelEntity(mesh: courtMesh, materials: [courtMat])
        court.position = SIMD3<Float>(0, 0.01, 0)
        court.name = "court"

        let centerLine = MeshResource.generateBox(width: 12, height: 0.02, depth: 0.14)
        var lineMat = SimpleMaterial()
        lineMat.color = .init(tint: .init(red: 0.45, green: 0.4, blue: 0.28, alpha: 1))
        let line = ModelEntity(mesh: centerLine, materials: [lineMat])
        line.position = SIMD3<Float>(0, 0.022, 0)
        court.addChild(line)

        let keyWidth: Float = 5.8
        let keyDepth: Float = 0.12
        let keyLine = MeshResource.generateBox(width: keyWidth, height: 0.02, depth: keyDepth)
        let key = ModelEntity(mesh: keyLine, materials: [lineMat])
        key.position = SIMD3<Float>(0, 0.022, -3.2)
        court.addChild(key)

        let arcSegments = 8
        let arcRadius: Float = 2.6
        for i in 0..<arcSegments {
            let t = Float(i) / Float(arcSegments)
            let angle = Float.pi * 0.5 + t * Float.pi * 0.55
            let x = cos(angle) * arcRadius
            let z = -3.0 + sin(angle) * arcRadius
            let seg = MeshResource.generateBox(width: 0.12, height: 0.02, depth: 0.5)
            let segEnt = ModelEntity(mesh: seg, materials: [lineMat])
            segEnt.position = SIMD3<Float>(x, 0.022, z)
            segEnt.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
            court.addChild(segEnt)
        }

        return court
    }

    /// Distant floor and wall so the court isn’t floating in void (Venice Beach–style environment).
    private func makeBackdrop() -> Entity {
        let group = Entity()
        group.name = "backdrop"
        let floorExtend = MeshResource.generateBox(width: 24, height: 0.1, depth: 20)
        var floorMat = SimpleMaterial()
        floorMat.color = .init(tint: .init(red: 0.15, green: 0.12, blue: 0.1, alpha: 1))
        let floor = ModelEntity(mesh: floorExtend, materials: [floorMat])
        floor.position = SIMD3<Float>(0, -0.05, -6)
        floor.name = "backdropFloor"
        group.addChild(floor)
        let wall = MeshResource.generateBox(width: 28, height: 14, depth: 0.3)
        var wallMat = SimpleMaterial()
        wallMat.color = .init(tint: .init(red: 0.25, green: 0.32, blue: 0.4, alpha: 1))
        let wallEnt = ModelEntity(mesh: wall, materials: [wallMat])
        wallEnt.position = SIMD3<Float>(0, 6, -12)
        wallEnt.name = "backdropWall"
        group.addChild(wallEnt)
        return group
    }

    private func makeHoop() -> Entity {
        let backboard = MeshResource.generateBox(width: 1.2, height: 0.9, depth: 0.08)
        var backboardMat = SimpleMaterial()
        backboardMat.color = .init(tint: .init(red: 0.5, green: 0.52, blue: 0.55, alpha: 1))
        let backboardEntity = ModelEntity(mesh: backboard, materials: [backboardMat])
        backboardEntity.position = SIMD3<Float>(-4.5, 2.5, 0)
        backboardEntity.name = "backboard"

        let rectangle = MeshResource.generateBox(width: 0.7, height: 0.45, depth: 0.02)
        var rectMat = SimpleMaterial()
        rectMat.color = .init(tint: .init(white: 0.95, alpha: 1))
        let rect = ModelEntity(mesh: rectangle, materials: [rectMat])
        rect.position = SIMD3<Float>(0, -0.2, 0.05)
        backboardEntity.addChild(rect)

        let rim = MeshResource.generateCylinder(height: 0.08, radius: 0.45)
        var rimMat = SimpleMaterial()
        rimMat.color = .init(tint: .init(red: 0.85, green: 0.22, blue: 0.12, alpha: 1))
        let rimEntity = ModelEntity(mesh: rim, materials: [rimMat])
        rimEntity.position = SIMD3<Float>(0, -0.4, 0)
        rimEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        backboardEntity.addChild(rimEntity)

        makeNet(parent: backboardEntity)

        return backboardEntity
    }

    private func makeNet(parent: Entity) {
        let netSegment = MeshResource.generateBox(width: 0.08, height: 0.06, depth: 0.04)
        var netMat = SimpleMaterial()
        netMat.color = .init(tint: .init(white: 0.75, alpha: 1))
        let count = 12
        for i in 0..<count {
            let angle = Float(i) / Float(count) * 2 * .pi
            let x = cos(angle) * 0.42
            let z = sin(angle) * 0.42
            let seg = ModelEntity(mesh: netSegment, materials: [netMat])
            seg.position = SIMD3<Float>(x, -0.42, z)
            seg.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
            parent.addChild(seg)
        }
    }

    private func makeDunker(tint: (r: Float, g: Float, b: Float), heightScale: Float = 1) -> Entity {
        let scale = heightScale
        let bodyMesh = MeshResource.generateBox(width: 0.38, height: 0.85 * scale, depth: 0.22)
        var bodyMat = SimpleMaterial()
        bodyMat.color = .init(tint: .init(red: CGFloat(tint.r), green: CGFloat(tint.g), blue: CGFloat(tint.b), alpha: 1))
        let body = ModelEntity(mesh: bodyMesh, materials: [bodyMat])
        body.position = SIMD3<Float>(0, 0.42 * scale, 0)

        let headMesh = MeshResource.generateSphere(radius: 0.14 * scale)
        var headMat = SimpleMaterial()
        headMat.color = .init(tint: .init(red: CGFloat(tint.r * 0.9), green: CGFloat(tint.g * 0.9), blue: CGFloat(tint.b * 0.9), alpha: 1))
        let head = ModelEntity(mesh: headMesh, materials: [headMat])
        head.name = "head"
        head.position = SIMD3<Float>(0, 0.58 * scale, 0)
        body.addChild(head)

        let armMesh = MeshResource.generateBox(width: 0.12, height: 0.35 * scale, depth: 0.1)
        var armMat = SimpleMaterial()
        armMat.color = .init(tint: .init(red: CGFloat(tint.r), green: CGFloat(tint.g), blue: CGFloat(tint.b), alpha: 1))
        let armL = ModelEntity(mesh: armMesh, materials: [armMat])
        armL.name = "armL"
        armL.position = SIMD3<Float>(-0.28, 0.35 * scale, 0)
        body.addChild(armL)
        let armR = ModelEntity(mesh: armMesh, materials: [armMat])
        armR.name = "armR"
        armR.position = SIMD3<Float>(0.28, 0.35 * scale, 0)
        body.addChild(armR)

        body.name = "dunker"
        body.position = SIMD3<Float>(0, 0, 4)
        return body
    }

    private func makeCamera() -> Entity {
        let camEntity = Entity()
        camEntity.name = "mainCamera"
        camEntity.position = SIMD3<Float>(2.2, 5.2, 9)
        camEntity.look(at: SIMD3<Float>(0, 2, -1), from: camEntity.position, relativeTo: nil)
        camEntity.components.set(PerspectiveCameraComponent())
        return camEntity
    }

    /// Camera follow: lerp position and look-at toward dunker so movement feels smooth and responsive.
    /// Uses DunkCameraConfig for tuning; lerp factor keeps motion smooth when state updates in quick succession.
    private func updateCameraFollow(root: Entity, dunkerPosition: SIMD3<Float>) {
        guard let camera = root.findEntity(named: "mainCamera") else { return }
        let baseZ: Float = 4
        let dz = dunkerPosition.z - baseZ
        let targetCamPos = SIMD3<Float>(
            2.2,
            5.2 + dunkerPosition.y * 0.45,
            9 + dz * 0.25
        )
        let lookAtTarget = SIMD3<Float>(
            0,
            2 + dunkerPosition.y * 0.35,
            -1 + dz * 0.15
        )
        let lerpFactor: Float = min(1, Float(PS2MovementConfig.dunkContest.cameraLerpFactor) / 22)
        let current = camera.position
        let newPos = current + (targetCamPos - current) * lerpFactor
        camera.position = newPos
        camera.look(at: lookAtTarget, from: newPos, relativeTo: nil)
    }

    private func makeLight() -> Entity {
        let group = Entity()
        group.name = "lights"

        let keyEntity = Entity()
        keyEntity.position = SIMD3<Float>(2.5, 10, 4)
        keyEntity.components.set(PointLightComponent(color: UIColor(red: 1, green: 0.95, blue: 0.88, alpha: 1), intensity: 3200, attenuationRadius: 15))
        group.addChild(keyEntity)

        let fillEntity = Entity()
        fillEntity.position = SIMD3<Float>(-3.5, 5, 5)
        fillEntity.components.set(PointLightComponent(color: UIColor(red: 0.75, green: 0.82, blue: 1.0, alpha: 1), intensity: 1000, attenuationRadius: 15))
        group.addChild(fillEntity)

        let rimEntity = Entity()
        rimEntity.position = SIMD3<Float>(-6, 3.5, 0)
        rimEntity.components.set(PointLightComponent(color: UIColor(red: 1, green: 0.85, blue: 0.6, alpha: 1), intensity: 600, attenuationRadius: 15))
        group.addChild(rimEntity)

        let ambientEntity = Entity()
        ambientEntity.position = SIMD3<Float>(0, 4, 2)
        ambientEntity.components.set(PointLightComponent(color: UIColor(red: 0.6, green: 0.65, blue: 0.75, alpha: 1), intensity: 400, attenuationRadius: 15))
        group.addChild(ambientEntity)

        return group
    }

    private func triggerRimEffect(root: Entity) {
        let ring = MeshResource.generateCylinder(height: 0.08, radius: 0.52)
        var flashMat = SimpleMaterial()
        flashMat.color = .init(tint: .init(red: 1, green: 0.8, blue: 0.35, alpha: 0.85))
        let flashEntity = ModelEntity(mesh: ring, materials: [flashMat])
        flashEntity.position = SIMD3<Float>(-4.5, 2.1, 0)
        flashEntity.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        root.addChild(flashEntity)
        Task {
            try? await Task.sleep(for: .milliseconds(420))
            await MainActor.run {
                flashEntity.removeFromParent()
            }
        }
    }
}

extension Entity {
    func findEntity(named name: String) -> Entity? {
        if self.name == name { return self }
        for child in children {
            if let found = child.findEntity(named: name) { return found }
        }
        return nil
    }
}
