import SwiftUI
import SceneKit

/// Sensory Mapping — Pressure Management + 90/90 rotation (Vertical Velocity Academy Build 6).
/// Educational: posterior mediastinal expansion cue, Deep Front Line + Spinal Wave (not medical diagnosis).
struct FELPressureManagementDashboardView: View {
    @State private var breath01: Double = 0.35
    @State private var rotation01: Double = 0.2
    @State private var msrResult: SFMAScreenResult = .pass
    @State private var ankleResult: SFMAScreenResult = .pass
    @State private var fascialSlingOn = false

    private var sfmaResults: [SFMAScreen: SFMAScreenResult] {
        [.multiSegmentalRotation: msrResult, .ankleClearing: ankleResult]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("PRESSURE MANAGEMENT")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(Theme.brandCyan)
                    .tracking(2)
                Text("Posterior mediastinal expansion (360° inhale) + 90/90 spinal wave — tensegrity education.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                FELSensoryMappingSceneView(breath01: breath01, rotation01: rotation01)
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.brandCyan.opacity(0.25), lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Rib expansion (inhale)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Slider(value: $breath01, in: 0...1)
                        .tint(Theme.brandCyan)
                    Text("Posterior mediastinal expansion: thoracic volume without lifting shoulders.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("90/90 Seated Rotation — Spinal Wave")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Slider(value: $rotation01, in: 0...1)
                        .tint(Theme.brandBlue)
                    Text("Deep Front Line (cyan). Drive rotation as a wave from hip through thoracic spine.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Divider().background(Color.white.opacity(0.12))

                VStack(alignment: .leading, spacing: 12) {
                    Text("SFMA / FMS CORRECTIVE LOOP")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandBlue)
                        .tracking(2)
                    screenRow("Multi-Segmental Rotation", selection: $msrResult)
                    screenRow("Ankle Clearing", selection: $ankleResult)
                    let tips = SFMA_DiagnosticManager.correctiveSuggestions(for: sfmaResults)
                    ForEach(tips, id: \.self) { tip in
                        Label(tip, systemImage: "arrow.turn.down.right")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.brandCyan)
                    }
                    Button("Apply heatmap to 3D Lab") {
                        SFMA_DiagnosticManager.publishToClinicalBridge(results: sfmaResults)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.brandCyan)
                }

                Toggle("Fascial sling (Spiral + Back Functional) — Lab preview", isOn: $fascialSlingOn)
                    .tint(Theme.brandCyan)
                    .onChange(of: fascialSlingOn) { _, v in
                        NotificationCenter.default.post(name: .felFascialSlingToggle, object: nil, userInfo: ["active": v])
                    }
            }
            .padding()
        }
        .background(Theme.deepBlack)
    }

    private func screenRow(_ title: String, selection: Binding<SFMAScreenResult>) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white)
            Spacer()
            Picker(title, selection: selection) {
                Text("Pass").tag(SFMAScreenResult.pass)
                Text("Fail").tag(SFMAScreenResult.fail)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 220)
        }
    }
}

// MARK: - SceneKit (simplified educator rig)

private struct FELSensoryMappingSceneView: UIViewRepresentable {
    var breath01: Double
    var rotation01: Double

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(white: 0.04, alpha: 1)
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        let scene = SCNScene()

        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.position = SCNVector3(0, 1.1, 2.4)
        cam.eulerAngles = SCNVector3(-0.15, 0, 0)
        scene.rootNode.addChildNode(cam)

        let ribGroup = SCNNode()
        ribGroup.name = "ribCage"
        for i in 0..<5 {
            let box = SCNBox(width: 0.55 - CGFloat(i) * 0.04, height: 0.07, length: 0.22, chamferRadius: 0.02)
            box.firstMaterial?.diffuse.contents = UIColor(white: 0.85, alpha: 0.9)
            let n = SCNNode(geometry: box)
            n.position = SCNVector3(0, Float(i) * 0.09 - 0.1, 0)
            ribGroup.addChildNode(n)
        }
        scene.rootNode.addChildNode(ribGroup)

        let tSpine = SCNNode(geometry: {
            let c = SCNCylinder(radius: 0.06, height: 0.45)
            c.firstMaterial?.diffuse.contents = UIColor(white: 0.7, alpha: 1)
            return c
        }())
        tSpine.name = "thoracicSpine"
        tSpine.position = SCNVector3(0, 0.85, -0.05)
        scene.rootNode.addChildNode(tSpine)

        let dfl = SCNNode(geometry: {
            let c = SCNCylinder(radius: 0.02, height: 1.15)
            c.firstMaterial?.diffuse.contents = UIColor(red: 0.2, green: 0.85, blue: 0.95, alpha: 0.85)
            c.firstMaterial?.emission.contents = UIColor(red: 0.1, green: 0.5, blue: 0.6, alpha: 1)
            return c
        }())
        dfl.name = "deepFrontLine"
        dfl.position = SCNVector3(0.04, 0.55, 0.1)
        dfl.eulerAngles = SCNVector3(0.25, 0, 0.08)
        scene.rootNode.addChildNode(dfl)

        context.coordinator.ribGroup = ribGroup
        context.coordinator.tSpine = tSpine
        context.coordinator.deepFrontLine = dfl
        view.scene = scene
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.update(breath01: CGFloat(breath01), rotation01: CGFloat(rotation01))
    }

    final class Coordinator {
        var ribGroup: SCNNode?
        var deepFrontLine: SCNNode?
        var tSpine: SCNNode?

        func update(breath01: CGFloat, rotation01: CGFloat) {
            // FMS-style 360° inhale: lateral + A–P expansion; posterior mediastinal cue = subtle +Z on rib stack without lifting shoulders.
            let breath = 0.92 + 0.08 * breath01
            ribGroup?.scale = SCNVector3(1, Float(breath), 1 + Float(breath01) * 0.06)
            ribGroup?.position = SCNVector3(0, 0, Float(breath01) * 0.028)
            let rot = Float(rotation01 * 0.45)
            tSpine?.eulerAngles = SCNVector3(Float(breath01) * 0.04, rot, 0)
            deepFrontLine?.opacity = 0.45 + 0.45 * rotation01
        }
    }
}
