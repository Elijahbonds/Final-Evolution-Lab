import SwiftUI
import SceneKit
import UIKit

/// Premium 3D skinned-model exercise demonstration.
///
/// A skinned character (default: the bundled Elijah rig via
/// ``FELBundledAssets/characterNode(_:height:)``; if the user has a scan/generated
/// avatar it can be shown via the "YOU" toggle using
/// ``NexusGameplayAvatarLoader``) performs the exercise animation on a LOOP inside
/// an orbitable ``SCNView`` (`allowsCameraControl`).
///
/// The animation is chosen by ``ExerciseAnimationLibrary``:
///  - a bespoke DeepMotion drop-in clip (`ExerciseDemo_<id>.usdz`) if bundled,
///  - else a free bundled Elijah clip (walk/run/dunk/karate/idle),
///  - else a category-appropriate PROCEDURAL animation applied to the model.
///
/// Fail-soft: if the skinned model or its clip cannot load, the caller's binding
/// flips (`renderFailed`) and the 2D ``AvatarDemoView`` is shown instead, so the
/// demo never blanks.
struct ExerciseDemo3DView: View {
    let exerciseId: String
    let category: Exercise.ExerciseCategory
    let difficulty: Exercise.Difficulty

    /// Set true by the scene builder when neither a skinned demo model nor the
    /// scan avatar could be built. The parent watches this to fall back to 2D.
    @Binding var renderFailed: Bool

    @State private var isPlaying = true
    @State private var showScanAvatar = false

    /// Whether the current profile carries a scan/generated avatar to compare.
    private let hasScanAvatar: Bool
    private let animation: ExerciseAnimationLibrary.DemoAnimation

    init(
        exerciseId: String,
        category: Exercise.ExerciseCategory,
        difficulty: Exercise.Difficulty,
        renderFailed: Binding<Bool>
    ) {
        self.exerciseId = exerciseId
        self.category = category
        self.difficulty = difficulty
        self._renderFailed = renderFailed
        self.animation = ExerciseAnimationLibrary.resolve(id: exerciseId, category: category)
        self.hasScanAvatar = SaveSystem.loadProfile().systemScan != nil
    }

    var body: some View {
        ZStack {
            ExerciseDemoSceneView(
                animation: animation,
                category: category,
                difficulty: difficulty,
                showScanAvatar: showScanAvatar,
                isPlaying: isPlaying,
                renderFailed: $renderFailed
            )

            VStack {
                HStack {
                    sourceBadge
                    Spacer()
                }
                Spacer()
                controlBar
            }
            .padding(12)
        }
    }

    private var sourceBadge: some View {
        Text(animation.isRealClip ? "3D MOTION" : "3D PROCEDURAL")
            .font(.system(size: 9, weight: .black, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(animation.isRealClip ? Theme.brandCyan : Theme.elitePurple)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((animation.isRealClip ? Theme.brandCyan : Theme.elitePurple).opacity(0.14))
            .clipShape(Capsule())
    }

    private var controlBar: some View {
        HStack(spacing: 10) {
            Button {
                isPlaying.toggle()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(Theme.brandCyan)
                    .clipShape(Circle())
            }

            if hasScanAvatar {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) { showScanAvatar.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showScanAvatar ? "person.crop.circle.fill" : "figure.mixed.cardio")
                            .font(.system(size: 12, weight: .bold))
                        Text(showScanAvatar ? "YOU" : "DEMO MODEL")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundStyle(showScanAvatar ? Theme.elitePurple : Theme.brandCyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background((showScanAvatar ? Theme.elitePurple : Theme.brandCyan).opacity(0.14))
                    .clipShape(Capsule())
                }
            }

            Spacer()

            Text("DRAG TO ORBIT")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}

// MARK: - SceneKit host

private struct ExerciseDemoSceneView: UIViewRepresentable {
    let animation: ExerciseAnimationLibrary.DemoAnimation
    let category: Exercise.ExerciseCategory
    let difficulty: Exercise.Difficulty
    let showScanAvatar: Bool
    let isPlaying: Bool
    @Binding var renderFailed: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        rebuild(view, context: context)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        // Rebuild only when the demonstrator identity changes (demo model ⇄ you).
        if context.coordinator.builtWithScanAvatar != showScanAvatar {
            rebuild(view, context: context)
        }
        // Play / pause the whole demonstrator subtree.
        if let demonstrator = view.scene?.rootNode.childNode(
            withName: ExerciseDemoSceneBuilder.demonstratorName, recursively: false
        ) {
            demonstrator.isPaused = !isPlaying
        }
    }

    private func rebuild(_ view: SCNView, context: Context) {
        let result = ExerciseDemoSceneBuilder.build(
            animation: animation,
            category: category,
            difficulty: difficulty,
            useScanAvatar: showScanAvatar
        )
        view.scene = result.scene
        context.coordinator.builtWithScanAvatar = showScanAvatar
        // Surface a hard failure so the parent can fall back to 2D.
        DispatchQueue.main.async {
            if renderFailed != !result.demonstratorPlaced {
                renderFailed = !result.demonstratorPlaced
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var builtWithScanAvatar = false
    }
}

// MARK: - Scene assembly (SceneKit only, fail-soft)

@MainActor
enum ExerciseDemoSceneBuilder {
    static let demonstratorName = "exerciseDemonstrator"

    struct BuildResult {
        let scene: SCNScene
        /// False only if NO demonstrator (skinned model or scan avatar) could be
        /// placed — the parent then falls back to the 2D avatar.
        let demonstratorPlaced: Bool
    }

    static func build(
        animation: ExerciseAnimationLibrary.DemoAnimation,
        category: Exercise.ExerciseCategory,
        difficulty: Exercise.Difficulty,
        useScanAvatar: Bool
    ) -> BuildResult {
        let scene = SCNScene()
        addStudio(to: scene, tint: tint(for: category))

        let placed: Bool
        if useScanAvatar {
            placed = placeScanAvatar(in: scene, animation: animation, difficulty: difficulty)
        } else {
            placed = placeDemoModel(in: scene, animation: animation, difficulty: difficulty)
                // If the skinned model path fails, try the scan/procedural rig so
                // the 3D view still shows *something* animated before 2D fallback.
                || placeScanAvatar(in: scene, animation: animation, difficulty: difficulty)
        }
        return BuildResult(scene: scene, demonstratorPlaced: placed)
    }

    // MARK: Demonstrator: bundled skinned model

    private static func placeDemoModel(
        in scene: SCNScene,
        animation: ExerciseAnimationLibrary.DemoAnimation,
        difficulty: Exercise.Difficulty
    ) -> Bool {
        let node: SCNNode?
        switch animation {
        case .bundledExerciseClip(let resource):
            node = loadBundledClipNode(resource: resource, height: 1.85)
        case .freeClip(let asset):
            node = FELBundledAssets.characterNode(asset, height: 1.85)
        case .procedural(let motion):
            // Grounded, idle-posed skinned body to drive procedurally.
            let base = FELBundledAssets.characterNode(.elijahKarateIdle, height: 1.85)
            if let base { applyProcedural(motion, to: base, amplitude: amplitude(difficulty)) }
            node = base
        }
        guard let node else { return false }
        node.name = demonstratorName
        node.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(node)
        return true
    }

    /// Loads a bespoke DeepMotion drop-in clip (`ExerciseDemo_<id>.usdz`) with the
    /// same joint-normalization + auto-play contract as pipeline clips.
    private static func loadBundledClipNode(resource: String, height: Float) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "usdz"),
              let scene = try? SCNScene(url: url, options: [.checkConsistency: false]) else {
            return nil
        }
        let root = SCNNode()
        for child in scene.rootNode.childNodes { root.addChildNode(child) }
        root.childNode(withName: "Alpha_Surface", recursively: true)?.removeFromParentNode()

        let container = SCNNode()
        container.addChildNode(root)
        let head = root.childNode(withName: "head_end", recursively: true)
            ?? root.childNode(withName: "Head", recursively: true)
        let foot = root.childNode(withName: "LeftFoot", recursively: true)
            ?? root.childNode(withName: "RightFoot", recursively: true)
        if let head, let foot {
            let span = head.worldPosition.y - foot.worldPosition.y
            if span > 0.0001 { let s = height / (span * 1.12); container.scale = SCNVector3(s, s, s) }
        }
        root.enumerateHierarchy { child, _ in
            if child.skinner != nil {
                child.boundingBox = (min: SCNVector3(-50, -50, -50), max: SCNVector3(50, 50, 50))
            }
        }
        FELBundledAssets.playAllAnimations(on: container, loop: true)
        FELBundledAssets.ensureAlive(container)
        return container
    }

    // MARK: Demonstrator: scan / generated avatar (procedural rig)

    private static func placeScanAvatar(
        in scene: SCNScene,
        animation: ExerciseAnimationLibrary.DemoAnimation,
        difficulty: Exercise.Difficulty
    ) -> Bool {
        let appearance = GameplayAvatarAppearance.fromProfile(SaveSystem.loadProfile())
        let rig = NexusGameplayAvatarLoader.makeAvatarNode(
            name: demonstratorName,
            position: SCNVector3(0, 0, 0),
            fallbackTint: UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1),
            appearance: appearance
        )
        rig.name = demonstratorName
        // The generated rig can't play skinned clips — always drive it with the
        // category-appropriate procedural motion (mapped from the resolved anim).
        rig.removeAllActions()
        applyProcedural(proceduralEquivalent(of: animation), to: rig, amplitude: amplitude(difficulty))
        scene.rootNode.addChildNode(rig)
        return true
    }

    /// Maps any resolved animation onto its procedural equivalent, so the scan
    /// avatar (which cannot play baked clips) still performs the right pattern.
    private static func proceduralEquivalent(
        of animation: ExerciseAnimationLibrary.DemoAnimation
    ) -> ExerciseAnimationLibrary.ProceduralMotion {
        switch animation {
        case .procedural(let m): return m
        case .freeClip(let asset):
            switch asset {
            case .elijahDunk: return .jump
            case .characterElijahRunAnim, .characterElijahRunning,
                 .characterElijahWalkAnim, .characterElijahWalking: return .shuffle
            case .elijahKarateIdle, .elijahGuard: return .breathe
            default: return .sway
            }
        case .bundledExerciseClip: return .jump
        }
    }

    // MARK: Procedural motion

    /// Applies a category-appropriate procedural animation to a demonstrator
    /// node: whole-node motion plus any drivable named joints (works for both the
    /// scan procedural rig — lLeg/rLeg/lArm/rArm — and, harmlessly, skinned nodes).
    static func applyProcedural(
        _ motion: ExerciseAnimationLibrary.ProceduralMotion,
        to node: SCNNode,
        amplitude: CGFloat
    ) {
        FELBundledAssets.stopAliveIdle(node)
        node.removeAllActions()
        let a = amplitude
        switch motion {
        case .jump:
            let load = SCNAction.moveBy(x: 0, y: -0.18 * a, z: 0, duration: 0.5); load.timingMode = .easeIn
            let drive = SCNAction.moveBy(x: 0, y: 0.34 * a, z: 0, duration: 0.28); drive.timingMode = .easeOut
            let hang = SCNAction.wait(duration: 0.16)
            let land = SCNAction.moveBy(x: 0, y: -0.16 * a, z: 0, duration: 0.38); land.timingMode = .easeInEaseOut
            let settle = SCNAction.wait(duration: 0.32)
            node.runAction(.repeatForever(.sequence([load, drive, hang, land, settle])), forKey: "demoMotion")
            driveLegs(node, flex: 0.30 * a, downDur: 0.5, upDur: 0.28, hold: 0.48)
            driveArms(node, swing: 0.7 * a)
        case .squat:
            let down = SCNAction.moveBy(x: 0, y: -0.24 * a, z: 0, duration: 0.9); down.timingMode = .easeInEaseOut
            let up = SCNAction.moveBy(x: 0, y: 0.24 * a, z: 0, duration: 0.9); up.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([down, up, .wait(duration: 0.2)])), forKey: "demoMotion")
            driveLegs(node, flex: 0.5 * a, downDur: 0.9, upDur: 0.9, hold: 0.2)
        case .sway:
            let l = SCNAction.rotateBy(x: 0, y: CGFloat(0.35 * a), z: 0, duration: 1.4); l.timingMode = .easeInEaseOut
            let r = SCNAction.rotateBy(x: 0, y: CGFloat(-0.7 * a), z: 0, duration: 2.8); r.timingMode = .easeInEaseOut
            let back = SCNAction.rotateBy(x: 0, y: CGFloat(0.35 * a), z: 0, duration: 1.4); back.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([l, r, back])), forKey: "demoMotion")
            driveArms(node, swing: 0.5 * a, slow: true)
        case .shuffle:
            let lft = SCNAction.moveBy(x: -0.16 * a, y: 0.04 * a, z: 0, duration: 0.32); lft.timingMode = .easeOut
            let rgt = SCNAction.moveBy(x: 0.32 * a, y: -0.04 * a, z: 0, duration: 0.32); rgt.timingMode = .easeOut
            let ctr = SCNAction.moveBy(x: -0.16 * a, y: 0, z: 0, duration: 0.2)
            node.runAction(.repeatForever(.sequence([lft, rgt, ctr])), forKey: "demoMotion")
            driveArms(node, swing: 0.4 * a)
        case .breathe:
            let up = SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 1.8); up.timingMode = .easeInEaseOut
            let dn = SCNAction.moveBy(x: 0, y: -0.03, z: 0, duration: 1.8); dn.timingMode = .easeInEaseOut
            node.runAction(.repeatForever(.sequence([up, dn])), forKey: "demoMotion")
        }
    }

    private static func driveLegs(_ node: SCNNode, flex: CGFloat, downDur: TimeInterval, upDur: TimeInterval, hold: TimeInterval) {
        for name in ["lLeg", "rLeg", "lShin", "rShin"] {
            guard let leg = node.childNode(withName: name, recursively: true) else { continue }
            let base = CGFloat(leg.eulerAngles.x)
            let z = CGFloat(leg.eulerAngles.z)
            leg.runAction(.repeatForever(.sequence([
                SCNAction.rotateTo(x: base + flex, y: 0, z: z, duration: downDur, usesShortestUnitArc: true),
                SCNAction.rotateTo(x: base, y: 0, z: z, duration: upDur, usesShortestUnitArc: true),
                SCNAction.wait(duration: hold)
            ])), forKey: "demoFlex")
        }
    }

    private static func driveArms(_ node: SCNNode, swing: CGFloat, slow: Bool = false) {
        for name in ["lArm", "rArm"] {
            guard let arm = node.childNode(withName: name, recursively: true) else { continue }
            let z = CGFloat(arm.eulerAngles.z)
            let d: TimeInterval = slow ? 1.4 : 0.5
            arm.runAction(.repeatForever(.sequence([
                SCNAction.rotateTo(x: -swing, y: 0, z: z, duration: d, usesShortestUnitArc: true),
                SCNAction.rotateTo(x: swing * 0.6, y: 0, z: z, duration: d * 0.7, usesShortestUnitArc: true),
                SCNAction.rotateTo(x: 0, y: 0, z: z, duration: d, usesShortestUnitArc: true)
            ])), forKey: "demoSwing")
        }
    }

    private static func amplitude(_ difficulty: Exercise.Difficulty) -> CGFloat {
        switch difficulty {
        case .foundation: return 0.7
        case .flight: return 0.85
        case .elite: return 1.0
        }
    }

    // MARK: Studio

    private static func tint(for category: Exercise.ExerciseCategory) -> UIColor {
        switch category {
        case .plyometric, .agility: return UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1)   // cyan
        case .strength:             return UIColor(red: 0.2, green: 1.0, blue: 0.5, alpha: 1)
        case .mobility, .recovery:  return UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1)   // purple
        }
    }

    private static func addStudio(to scene: SCNScene, tint: UIColor) {
        let camera = SCNCamera()
        camera.fieldOfView = 44
        camera.zNear = 0.05
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.05, 3.7)
        cameraNode.look(at: SCNVector3(0, 0.95, 0))
        scene.rootNode.addChildNode(cameraNode)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 750
        key.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.color = tint
        fill.light?.intensity = 240
        fill.position = SCNVector3(-2.2, 1.6, 2.4)
        scene.rootNode.addChildNode(fill)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.13, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let disc = SCNCylinder(radius: 1.35, height: 0.01)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 0.05, alpha: 1)
        mat.emission.contents = tint.withAlphaComponent(0.07)
        disc.materials = [mat]
        let discNode = SCNNode(geometry: disc)
        scene.rootNode.addChildNode(discNode)
    }
}
