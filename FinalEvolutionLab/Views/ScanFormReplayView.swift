import SwiftUI
import SceneKit
import UIKit

/// Lift-App-parity 3D form replay + optimal-form overlay.
///
/// Renders the scan's generated avatar (``NexusGameplayAvatarLoader`` procedural
/// rig — never a cloned skinned mesh) in an orbitable SceneKit scene, plays a
/// representative athletic loading→drive motion on it, and overlays a semi-
/// transparent "ideal form" ghost. Problem joints from ``BiomechanicsAudit`` are
/// color-coded with deviation callouts.
///
/// HONESTY: per-frame captured motion is not retained by ``ScanCaptureService``,
/// so the played motion is a REPRESENTATIVE drive cycle derived from the scan's
/// metrics — it is labeled "illustrative" in the UI. Joint deviations and segment
/// proportions come from the real scan/audit.
struct ScanFormReplayView: View {
    let result: SystemScanResult
    let audit: BiomechanicsAudit
    let analysis: ScanFormAnalysis

    @Environment(\.dismiss) private var dismiss
    @State private var showGhost = true
    @State private var isPlaying = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.deepBlack.ignoresSafeArea()

                ScanReplaySceneView(
                    appearance: appearance,
                    joints: analysis.joints,
                    showGhost: showGhost,
                    isPlaying: isPlaying
                )
                .ignoresSafeArea(edges: .bottom)

                VStack {
                    Spacer()
                    controlBar
                    deviationLegend
                        .padding(.bottom, 12)
                }
            }
            .navigationTitle("3D Form Replay")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Theme.brandCyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationBackground(Theme.deepBlack)
    }

    private var appearance: GameplayAvatarAppearance {
        GameplayAvatarAppearance(skinConfig: result.avatarConfig, creatorCardId: nil)
    }

    private var controlBar: some View {
        HStack(spacing: 16) {
            Button {
                isPlaying.toggle()
            } label: {
                Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.brandCyan)
                    .clipShape(Capsule())
            }

            Button {
                showGhost.toggle()
            } label: {
                Label("Ideal Ghost", systemImage: showGhost ? "eye.fill" : "eye.slash.fill")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .foregroundStyle(showGhost ? Theme.elitePurple : .secondary)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background((showGhost ? Theme.elitePurple : Color.gray).opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private var deviationLegend: some View {
        VStack(spacing: 6) {
            Text(analysis.isMeasured ? "MEASURED FORM · illustrative drive motion" : "ILLUSTRATIVE · demo scan (no measured pose)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)

            HStack(spacing: 14) {
                ForEach(analysis.joints) { joint in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Self.verdictColor(joint.verdict))
                            .frame(width: 8, height: 8)
                        Text("\(joint.label.split(separator: " ").first.map(String.init) ?? joint.label) \(Int(joint.deviationDeg.rounded()))°")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text("Drag to orbit · pinch to zoom")
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.cardBackground.opacity(0.85)))
        .padding(.horizontal, 24)
    }

    static func verdictColor(_ v: ScanFormAnalysis.JointReadout.Verdict) -> Color {
        switch v {
        case .good: return Theme.brandCyan
        case .watch: return .orange
        case .off: return Color(red: 1.0, green: 0.2, blue: 0.35)
        }
    }
}

// MARK: - SceneKit host

private struct ScanReplaySceneView: UIViewRepresentable {
    let appearance: GameplayAvatarAppearance
    let joints: [ScanFormAnalysis.JointReadout]
    let showGhost: Bool
    let isPlaying: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling2X
        view.allowsCameraControl = true          // orbit / pan / zoom
        view.autoenablesDefaultLighting = false
        view.scene = ScanReplaySceneBuilder.build(appearance: appearance, joints: joints)
        context.coordinator.view = view
        applyState(to: view)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        applyState(to: view)
    }

    private func applyState(to view: SCNView) {
        guard let scene = view.scene else { return }
        // Toggle ghost visibility.
        scene.rootNode.childNode(withName: ScanReplaySceneBuilder.ghostRootName, recursively: false)?
            .isHidden = !showGhost
        // Play / pause the athletic drive motion on the user rig.
        if let userRig = scene.rootNode.childNode(withName: ScanReplaySceneBuilder.userRootName, recursively: false) {
            userRig.isPaused = !isPlaying
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        weak var view: SCNView?
    }
}

// MARK: - Scene assembly (SceneKit only, fail-soft)

@MainActor
enum ScanReplaySceneBuilder {
    static let userRootName = "scanUserRig"
    static let ghostRootName = "scanIdealGhost"

    static func build(appearance: GameplayAvatarAppearance, joints: [ScanFormAnalysis.JointReadout]) -> SCNScene {
        let scene = SCNScene()

        // Camera on an orbit rig so allowsCameraControl frames the athlete.
        let camera = SCNCamera()
        camera.fieldOfView = 42
        camera.zNear = 0.05
        camera.zFar = 100
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.1, 3.6)
        cameraNode.look(at: SCNVector3(0, 0.95, 0))
        scene.rootNode.addChildNode(cameraNode)

        // Key + fill lighting (premium dark studio feel).
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.color = UIColor(white: 1.0, alpha: 1.0)
        key.light?.intensity = 700
        key.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.color = UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1)
        fill.light?.intensity = 220
        fill.position = SCNVector3(-2.2, 1.6, 2.4)
        scene.rootNode.addChildNode(fill)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.14, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Ground grid disc for spatial reference.
        let disc = SCNNode(geometry: gridDisc())
        disc.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(disc)

        // USER rig — the generated athlete avatar, posed into an athletic load
        // stance and given a representative drive cycle.
        let userRig = NexusGameplayAvatarLoader.makeAvatarNode(
            name: userRootName,
            position: SCNVector3(0, 0, 0),
            fallbackTint: UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1),
            appearance: appearance
        )
        userRig.name = userRootName
        // The loader adds a "breathe" bob; replace it with an athletic load→drive
        // cycle so the replay reads as a movement, not an idle.
        userRig.removeAllActions()
        applyDriveCycle(to: userRig)
        highlightJoints(on: userRig, joints: joints)
        scene.rootNode.addChildNode(userRig)

        // IDEAL ghost — a second rig in a neutral correct posture, semi-transparent
        // purple, offset slightly behind so it reads as a reference silhouette.
        let ghost = NexusGameplayAvatarLoader.makeAvatarNode(
            name: ghostRootName,
            position: SCNVector3(0, 0, -0.02),
            fallbackTint: UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1),
            appearance: idealAppearance()
        )
        ghost.name = ghostRootName
        ghost.removeAllActions()
        makeGhostMaterial(ghost)
        scene.rootNode.addChildNode(ghost)

        return scene
    }

    // MARK: - Motion

    /// Representative athletic load→drive→land cycle applied to the whole rig.
    /// This is ILLUSTRATIVE motion (per-frame capture is not retained); it dips
    /// into a loaded crouch then drives up, so the orbitable replay reads as a
    /// jump/lift rather than a static pose.
    private static func applyDriveCycle(to rig: SCNNode) {
        let load = SCNAction.moveBy(x: 0, y: -0.18, z: 0, duration: 0.55)
        load.timingMode = .easeIn
        let drive = SCNAction.moveBy(x: 0, y: 0.30, z: 0, duration: 0.32)
        drive.timingMode = .easeOut
        let hang = SCNAction.wait(duration: 0.18)
        let land = SCNAction.moveBy(x: 0, y: -0.12, z: 0, duration: 0.40)
        land.timingMode = .easeInEaseOut
        let settle = SCNAction.wait(duration: 0.35)
        let cycle = SCNAction.sequence([load, drive, hang, land, settle])
        rig.runAction(SCNAction.repeatForever(cycle), forKey: "driveCycle")

        // Slight knee/leg flexion swing so limbs articulate through the cycle.
        for legName in ["lLeg", "rLeg", "lShin", "rShin"] {
            guard let leg = rig.childNode(withName: legName, recursively: true) else { continue }
            let base = leg.eulerAngles.x
            let bend = SCNAction.sequence([
                SCNAction.rotateTo(x: CGFloat(base) + 0.28, y: 0, z: CGFloat(leg.eulerAngles.z), duration: 0.55, usesShortestUnitArc: true),
                SCNAction.rotateTo(x: CGFloat(base), y: 0, z: CGFloat(leg.eulerAngles.z), duration: 0.50, usesShortestUnitArc: true),
                SCNAction.wait(duration: 0.53)
            ])
            leg.runAction(SCNAction.repeatForever(bend), forKey: "flex")
        }
        // Arm counter-swing.
        for armName in ["lArm", "rArm"] {
            guard let arm = rig.childNode(withName: armName, recursively: true) else { continue }
            let z = CGFloat(arm.eulerAngles.z)
            let swing = SCNAction.sequence([
                SCNAction.rotateTo(x: -0.6, y: 0, z: z, duration: 0.55, usesShortestUnitArc: true),
                SCNAction.rotateTo(x: 0.4, y: 0, z: z, duration: 0.32, usesShortestUnitArc: true),
                SCNAction.rotateTo(x: 0, y: 0, z: z, duration: 0.58, usesShortestUnitArc: true)
            ])
            arm.runAction(SCNAction.repeatForever(swing), forKey: "swing")
        }
    }

    // MARK: - Overlay highlighting

    /// Color-codes the rig's joint nodes by their audit verdict so problem joints
    /// glow red/orange against good cyan. Maps the analysis joints onto the rig's
    /// named nodes.
    private static func highlightJoints(on rig: SCNNode, joints: [ScanFormAnalysis.JointReadout]) {
        // rig node names per joint region.
        let mapping: [String: [String]] = [
            "knee": ["lLeg", "rLeg"],
            "hip": ["hip", "lowerTorso"],
            "ankle": ["lShin", "rShin"],
        ]
        for joint in joints {
            guard let nodeNames = mapping[joint.id] else { continue }
            let color = uiVerdictColor(joint.verdict)
            for name in nodeNames {
                guard let node = rig.childNode(withName: name, recursively: true),
                      let geo = node.geometry else { continue }
                let mat = geo.firstMaterial ?? SCNMaterial()
                mat.emission.contents = color.withAlphaComponent(joint.verdict == .good ? 0.25 : 0.6)
                if joint.verdict != .good {
                    // Pulse the problem joint so it draws the eye.
                    let pulse = SCNAction.sequence([
                        SCNAction.customAction(duration: 0.6) { n, t in
                            n.geometry?.firstMaterial?.emission.contents =
                                color.withAlphaComponent(0.35 + 0.4 * CGFloat(t / 0.6))
                        },
                        SCNAction.customAction(duration: 0.6) { n, t in
                            n.geometry?.firstMaterial?.emission.contents =
                                color.withAlphaComponent(0.75 - 0.4 * CGFloat(t / 0.6))
                        }
                    ])
                    node.runAction(SCNAction.repeatForever(pulse), forKey: "deviationPulse")
                }
            }
        }
    }

    private static func uiVerdictColor(_ v: ScanFormAnalysis.JointReadout.Verdict) -> UIColor {
        switch v {
        case .good: return UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1)
        case .watch: return UIColor.orange
        case .off: return UIColor(red: 1.0, green: 0.2, blue: 0.35, alpha: 1)
        }
    }

    // MARK: - Ghost

    private static func idealAppearance() -> GameplayAvatarAppearance {
        var config = AvatarSkinConfig.default
        config.skinTone = .elitePurple
        config.outfitStyle = .elite
        config.heightScale = 1.0
        config.weightScale = 1.0
        config.limbLength = 1.0
        config.trailIntensity = 0.0
        config.auraColorR = 0.6; config.auraColorG = 0.2; config.auraColorB = 1.0
        return GameplayAvatarAppearance(skinConfig: config, creatorCardId: nil)
    }

    private static func makeGhostMaterial(_ ghost: SCNNode) {
        ghost.enumerateHierarchy { node, _ in
            guard let geo = node.geometry else { return }
            for mat in geo.materials {
                mat.transparency = 0.28
                mat.diffuse.contents = UIColor(red: 0.6, green: 0.2, blue: 1.0, alpha: 1)
                mat.emission.contents = UIColor(red: 0.5, green: 0.2, blue: 1.0, alpha: 1).withAlphaComponent(0.2)
                mat.writesToDepthBuffer = false
                mat.metalness.contents = 0.0
            }
            node.renderingOrder = -5
            // Strip any embedded lights so the ghost does not double the scene light.
            node.light = nil
        }
    }

    // MARK: - Ground

    private static func gridDisc() -> SCNGeometry {
        let disc = SCNCylinder(radius: 1.4, height: 0.01)
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 0.06, alpha: 1)
        mat.emission.contents = UIColor(red: 0, green: 0.83, blue: 1.0, alpha: 1).withAlphaComponent(0.06)
        disc.materials = [mat]
        return disc
    }
}
