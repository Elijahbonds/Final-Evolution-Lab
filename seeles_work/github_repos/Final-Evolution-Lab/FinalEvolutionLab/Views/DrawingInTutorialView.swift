import SwiftUI
import SceneKit
import UIKit

/// Interactive **Drawing In** module: visual tension maps, staged cues, breath-sync IAP, haptic torque loop.
struct DrawingInTutorialView: View {
    @State private var stage: DrawingInTutorialStage = .torqueInternalRotation
    @State private var torqueProgress: Double = 0.35
    @State private var simulateKneeValgus = false
    @State private var torqueHapticTimer: Timer?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stagePicker

                DrawingInSceneContainer(
                    stage: stage,
                    torqueProgress: torqueProgress,
                    showKneeLeakage: simulateKneeValgus
                )
                .frame(height: 340)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.brandCyan.opacity(0.55), Theme.elitePurple.opacity(0.35)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )

                if stage == .replaceDownTuck {
                    breathSyncOverlay
                        .padding(.top, 4)
                }

                cueCard

                Toggle(isOn: $simulateKneeValgus) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Simulate front knee valgus (demo)")
                            .font(.system(.subheadline, weight: .semibold))
                        Text("Production: wire ARKit / Luma body pose to drive this warning.")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .tint(Theme.brandCyan)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))

                if stage == .torqueInternalRotation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TORQUE TARGET")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.brandBlue)
                        Slider(value: $torqueProgress, in: 0...1)
                            .tint(Theme.brandCyan)
                        Text("Slide to complete internal rotation — haptics stop when you reach the blue zone.")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
                }

                whySection
            }
            .padding()
        }
        .background(Theme.deepBlack)
        .navigationTitle("Drawing In")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            startTorqueHapticsIfNeeded()
        }
        .onChange(of: stage) { _, _ in
            torqueHapticTimer?.invalidate()
            torqueHapticTimer = nil
            startTorqueHapticsIfNeeded()
        }
        .onChange(of: torqueProgress) { old, new in
            if new >= 0.92 {
                torqueHapticTimer?.invalidate()
                torqueHapticTimer = nil
                if old < 0.92 {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } else {
                startTorqueHapticsIfNeeded()
            }
        }
        .onDisappear {
            torqueHapticTimer?.invalidate()
            torqueHapticTimer = nil
        }
    }

    private var stagePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VISUAL TENSION MAP")
                .font(.system(.caption2, design: .monospaced, weight: .black))
                .foregroundStyle(Theme.elitePurple)
                .tracking(2)
            Picker("Stage", selection: $stage) {
                ForEach(DrawingInTutorialStage.allCases) { s in
                    Text(s.shortTitle).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var cueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stage.headlineCue)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
            Text(stage.detailCue)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            if stage == .hipHikeLoading {
                Text(stage.educationalNote)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.brandCyan.opacity(0.95))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Theme.brandCyan.opacity(0.1)))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06)))
        )
    }

    private var breathSyncOverlay: some View {
        BreathSyncPulseRing()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHY THIS WORKS")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue)
            Text(
                "The staggered V stance plus intentional internal rotation organizes lateral line tension so the hip can load in tensegrity. Drawing-in coordinates intra-abdominal pressure with posterior pelvic tuck — the Bonds Standard bridge from kinetic leakage to structural integrity."
            )
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Theme.cardBackground.opacity(0.95)))
    }

    private func startTorqueHapticsIfNeeded() {
        guard stage == .torqueInternalRotation, torqueProgress < 0.92 else { return }
        torqueHapticTimer?.invalidate()
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.prepare()
        torqueHapticTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: true) { _ in
            guard torqueProgress < 0.92 else {
                torqueHapticTimer?.invalidate()
                torqueHapticTimer = nil
                return
            }
            gen.impactOccurred(intensity: CGFloat(0.5 + torqueProgress * 0.45))
        }
        RunLoop.main.add(torqueHapticTimer!, forMode: .common)
    }
}

// MARK: - SceneKit host

private struct DrawingInSceneContainer: UIViewRepresentable {
    var stage: DrawingInTutorialStage
    var torqueProgress: Double
    var showKneeLeakage: Bool

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = GameSceneFactory.buildDrawingInTutorialScene()
        v.autoenablesDefaultLighting = false
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        context.coordinator.scene = v.scene
        context.coordinator.apply(stage: stage, torque01: torqueProgress, kneeLeak: showKneeLeakage)
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.apply(stage: stage, torque01: torqueProgress, kneeLeak: showKneeLeakage)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var scene: SCNScene?

        func apply(stage: DrawingInTutorialStage, torque01: Double, kneeLeak: Bool) {
            guard let scene else { return }
            guard let avatar = scene.rootNode.childNode(withName: "drawingAvatar", recursively: false) else { return }

            let ring = avatar.childNode(withName: "rLeg", recursively: true)?.childNode(withName: "overlayTorqueRing", recursively: false)
            let arrowUp = avatar.childNode(withName: "hip", recursively: true)?.childNode(withName: "overlayHipArrowUp", recursively: false)
            let arrowDown = avatar.childNode(withName: "hip", recursively: true)?.childNode(withName: "overlayHipArrowDown", recursively: false)
            let fascia = avatar.childNode(withName: "overlayFasciaBeam", recursively: true)
            let corset = avatar.childNode(withName: "overlayCorset", recursively: true)
            let kneePulse = avatar.childNode(withName: "kneeLeakagePulse", recursively: true)

            ring?.isHidden = stage != .torqueInternalRotation
            arrowUp?.isHidden = stage != .hipHikeLoading
            fascia?.isHidden = stage != .hipHikeLoading
            arrowDown?.isHidden = stage != .replaceDownTuck
            corset?.isHidden = stage != .replaceDownTuck

            kneePulse?.isHidden = !kneeLeak
            if kneeLeak {
                let blink = SCNAction.sequence([
                    SCNAction.fadeOpacity(to: 0.25, duration: 0.35),
                    SCNAction.fadeOpacity(to: 1.0, duration: 0.35)
                ])
                kneePulse?.removeAction(forKey: "blink")
                kneePulse?.runAction(SCNAction.repeatForever(blink), forKey: "blink")
            } else {
                kneePulse?.removeAction(forKey: "blink")
                kneePulse?.opacity = 1
            }

            Self.paintRearLegIntegrity(avatar: avatar, torque01: torque01)

            arrowUp?.opacity = stage == .replaceDownTuck ? 0 : 1
        }

        private static func paintRearLegIntegrity(avatar: SCNNode, torque01: Double) {
            guard let leg = avatar.childNode(withName: "rLeg", recursively: true),
                  let geo = leg.geometry as? SCNCapsule,
                  let mat = geo.materials.first as? SCNMaterial else { return }

            let stableBlue = UIColor(red: 0.2, green: 0.45, blue: 1.0, alpha: 1)
            let leakRed = UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1)
            let t = CGFloat(min(1, max(0, torque01)))
            let mixed = UIColor.mix(leakRed, stableBlue, t)
            mat.emission.contents = mixed.withAlphaComponent(0.35 + 0.45 * CGFloat(torque01))
            mat.diffuse.contents = mixed.withAlphaComponent(0.85)
        }
    }
}

private extension UIColor {
    static func mix(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * t,
            green: g1 + (g2 - g1) * t,
            blue: b1 + (b2 - b1) * t,
            alpha: 1
        )
    }
}

private struct BreathSyncPulseRing: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = sin(t / 5.0 * (Double.pi * 2))
            let scale = 0.88 + 0.14 * CGFloat((phase + 1) / 2)
            let opacity = 0.42 + 0.42 * CGFloat((phase + 1) / 2)
            ZStack {
                Circle()
                    .stroke(Theme.brandCyan.opacity(0.35), lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .scaleEffect(scale)
                    .opacity(opacity)
                Text("IAP · slow expansion")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}
