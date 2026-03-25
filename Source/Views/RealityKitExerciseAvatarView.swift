import SwiftUI
import RealityKit

/// Simple RealityKit avatar used to demo all exercises when coach video is unavailable.
/// Lightweight procedural figure (boxes + spheres) with category-specific motion profiles:
/// jump (plyometric), squat (strength), stretch (mobility), shuffle (agility), breathe (recovery).
struct RealityKitExerciseAvatarView: View {
    let exercise: Exercise

    @State private var phase: Double = 0

    var body: some View {
        RealityView { content in
            let root = Entity()
            root.name = "exerciseAvatarRoot"

            let floor = makeFloor()
            root.addChild(floor)

            let avatar = makeAvatar()
            avatar.name = "avatar"
            root.addChild(avatar)

            let camera = makeCamera()
            root.addChild(camera)

            let light = makeLight()
            root.addChild(light)

            content.add(root)
        } update: { content in
            phase += 0.025
            guard let root = content.entities.first(where: { $0.name == "exerciseAvatarRoot" }),
                  let avatar = root.findEntity(named: "avatar"),
                  let body = avatar.findEntity(named: "body") else { return }

            let category = exercise.category
            let t = Float(sin(phase))
            let t2 = Float(sin(phase * 0.7 + 0.5))
            let motion = motionProfile(category: category, t: t, t2: t2)

            var avatarTransform = avatar.transform
            avatarTransform.translation = SIMD3<Float>(motion.swayX, 0.6 + motion.yOffset, 0)
            avatarTransform.rotation = simd_quatf(angle: motion.tiltZ, axis: SIMD3<Float>(0, 0, 1))
            avatar.transform = avatarTransform

            var bodyTransform = body.transform
            bodyTransform.rotation = simd_quatf(angle: motion.leanZ, axis: SIMD3<Float>(0, 0, 1))
            body.transform = bodyTransform
        }
        .ignoresSafeArea()
    }

    /// Motion profile per category so the avatar reads as jump, squat, stretch, shuffle, or breathe.
    private func motionProfile(category: Exercise.ExerciseCategory, t: Float, t2: Float) -> (yOffset: Float, swayX: Float, tiltZ: Float, leanZ: Float) {
        switch category {
        case .plyometric:
            let jump = max(0, t) * 0.7
            let landSway = t2 * 0.08
            return (jump, landSway, 0, 0)
        case .strength:
            let squatDown = (1 + t) * 0.5
            let dip = -0.22 * squatDown
            let lean = t * 0.06
            return (dip, 0, 0, lean)
        case .mobility:
            let sway = t * 0.35
            let stretchLean = t * 0.2
            return (0, sway, stretchLean * 0.3, stretchLean)
        case .agility:
            let shuffle = t * 0.5
            let quickSway = t2 * 0.12
            return (0.05 * abs(t2), shuffle, 0, quickSway)
        case .recovery:
            let breathe = t * 0.06
            return (breathe, 0, 0, 0)
        }
    }

    private func makeFloor() -> Entity {
        let mesh = MeshResource.generatePlane(width: 2, depth: 2)
        var mat = SimpleMaterial()
        mat.color = .init(tint: .init(red: 0.0, green: 0.2, blue: 0.15, alpha: 1), texture: nil)
        let floor = ModelEntity(mesh: mesh, materials: [mat])
        floor.position = SIMD3<Float>(0, 0, 0)
        return floor
    }

    private func makeAvatar() -> Entity {
        let group = Entity()

        var bodyMat = SimpleMaterial()
        bodyMat.color = .init(tint: .init(red: 0.1, green: 0.9, blue: 0.8, alpha: 1), texture: nil)

        let bodyMesh = MeshResource.generateBox(size: SIMD3<Float>(0.25, 0.6, 0.18))
        let body = ModelEntity(mesh: bodyMesh, materials: [bodyMat])
        body.name = "body"
        body.position = SIMD3<Float>(0, 0.6, 0)

        let headMesh = MeshResource.generateSphere(radius: 0.14)
        var headMat = bodyMat
        headMat.color = .init(tint: .init(red: 0.2, green: 0.95, blue: 0.9, alpha: 1), texture: nil)
        let head = ModelEntity(mesh: headMesh, materials: [headMat])
        head.position = SIMD3<Float>(0, 0.5, 0)
        body.addChild(head)

        let limbMesh = MeshResource.generateBox(size: SIMD3<Float>(0.08, 0.35, 0.08))
        let armL = ModelEntity(mesh: limbMesh, materials: [bodyMat])
        armL.position = SIMD3<Float>(-0.18, 0.18, 0)
        body.addChild(armL)

        let armR = ModelEntity(mesh: limbMesh, materials: [bodyMat])
        armR.position = SIMD3<Float>(0.18, 0.18, 0)
        body.addChild(armR)

        let legMesh = MeshResource.generateBox(size: SIMD3<Float>(0.09, 0.4, 0.09))
        let legL = ModelEntity(mesh: legMesh, materials: [bodyMat])
        legL.position = SIMD3<Float>(-0.08, -0.45, 0)
        body.addChild(legL)

        let legR = ModelEntity(mesh: legMesh, materials: [bodyMat])
        legR.position = SIMD3<Float>(0.08, -0.45, 0)
        body.addChild(legR)

        group.addChild(body)
        return group
    }

    private func makeCamera() -> Entity {
        let cam = Entity()
        cam.name = "exerciseCamera"
        cam.position = SIMD3<Float>(0, 1.1, 2.2)
        cam.look(at: SIMD3<Float>(0, 0.8, 0), from: cam.position, relativeTo: nil)
        cam.components.set(PerspectiveCameraComponent())
        return cam
    }

    private func makeLight() -> Entity {
        let light = Entity()
        light.name = "exerciseLight"
        var component = DirectionalLightComponent()
        component.intensity = 800
        component.color = .init(red: 1, green: 1, blue: 1, alpha: 1)
        light.components.set(component)
        light.position = SIMD3<Float>(1.5, 3, 2)
        light.look(at: SIMD3<Float>(0, 0.6, 0), from: light.position, relativeTo: nil)
        return light
    }
}

