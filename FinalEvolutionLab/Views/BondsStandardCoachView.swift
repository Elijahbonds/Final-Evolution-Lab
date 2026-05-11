import SwiftUI
import SceneKit
import UIKit

/// Interactive **Bonds Standard** coach: holographic V stance, rotation cues, hike → tuck, TA corset + IAP breath-sync.
/// SceneKit reference scene; Unreal corrective montages can replace or augment via ``UnrealManager``.
///
/// **Imports:** This module does **not** import Firebase Data Connect / SocialDataConnect (social SDK lives under
/// ``TrainingLabSocialBridge`` / Body IQ flows). No SDK wiring required here.
struct BondsStandardCoachView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: BondsStandardCoachStep = .staggeredV
    @State private var torqueProgress: Double = 0.35
    @State private var simulateKneeValgus = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                methodologyRibbon

                #if DEBUG
                unrealBridgeCaption
                #endif

                instructionCard

                ZStack(alignment: .topTrailing) {
                    BondsStandardSceneContainer(
                        step: step,
                        torqueProgress: torqueProgress,
                        showKneeLeakage: simulateKneeValgus,
                        onTuckPelvicDropPeak: {
                            let gen = UIImpactFeedbackGenerator(style: .heavy)
                            gen.prepare()
                            gen.impactOccurred(intensity: 1.0)
                        }
                    )
                    .frame(height: 320)
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

                    anatomyBadges
                }

                if step == .drawingInCore {
                    CoachBreathSyncRing()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }

                if step == .replaceDownTuck {
                    Text("REPLACE THE UP WITH THE DOWN.")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(colors: [Theme.brandCyan, Theme.elitePurple], startPoint: .leading, endPoint: .trailing)
                        )
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }

                stepControls

                #if DEBUG
                Toggle(isOn: $simulateKneeValgus) {
                    Text("Demo: knee valgus warning")
                        .font(.system(.caption, design: .rounded))
                }
                .tint(Theme.brandCyan)
                #endif

                if step == .internalRotation {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("TORQUE TO BLUE")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundStyle(Theme.brandBlue)
                        Slider(value: $torqueProgress, in: 0...1)
                            .tint(Theme.brandCyan)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.cardBackground))
                }
            }
            .padding()
        }
        .background(Theme.deepBlack)
        .navigationTitle("Bonds Standard Coach")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .foregroundStyle(Theme.brandCyan)
            }
        }
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    /// Bonds methodology spine: **V + rear IR → hip hike (fascial load) → replace up with down (tuck) → IAP corset**.
    private var methodologyRibbon: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BONDS SEQUENCE")
                .font(.system(.caption2, design: .monospaced, weight: .bold))
                .foregroundStyle(Theme.brandBlue.opacity(0.9))
                .tracking(2)
            HStack(spacing: 4) {
                methodologyDot(isCurrent: ribbonSegment == 0, label: "V + IR")
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.white.opacity(0.35))
                methodologyDot(isCurrent: ribbonSegment == 1, label: "HIKE")
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.white.opacity(0.35))
                methodologyDot(isCurrent: ribbonSegment == 2, label: "TUCK")
                Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.white.opacity(0.35))
                methodologyDot(isCurrent: ribbonSegment == 3, label: "IAP")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
    }

    /// Maps coach steps to the four methodology milestones on the ribbon.
    private var ribbonSegment: Int {
        switch step {
        case .staggeredV, .internalRotation: return 0
        case .hipHike: return 1
        case .replaceDownTuck: return 2
        case .drawingInCore: return 3
        }
    }

    private func methodologyDot(isCurrent: Bool, label: String) -> some View {
        Text(label)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(isCurrent ? Theme.brandCyan : .white.opacity(0.35))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Capsule().stroke(isCurrent ? Theme.brandCyan.opacity(0.65) : Color.white.opacity(0.15), lineWidth: isCurrent ? 1.5 : 1))
    }

    private var unrealBridgeCaption: some View {
        Text("SceneKit reference · UE corrective montages: Body IQ → UnrealManager.deliverBodyIQSnackJSON")
            .font(.system(.caption2, design: .rounded))
            .foregroundStyle(.white.opacity(0.42))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.cardTitle)
                .font(.system(.caption2, design: .monospaced, weight: .black))
                .foregroundStyle(Theme.elitePurple)
                .tracking(2)
            Text(step.prompt)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
            if let hint = step.anatomyHint {
                Text(hint)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.brandCyan.opacity(0.9))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.cardBackground)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06)))
        )
    }

    private var anatomyBadges: some View {
        Group {
            if step == .internalRotation {
                VStack(alignment: .trailing, spacing: 6) {
                    badge("ADDUCTORS")
                    badge("LATERAL LINE")
                }
                .padding(10)
            }
        }
    }

    private func badge(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Theme.brandCyan.opacity(0.85)))
    }

    private var stepControls: some View {
        HStack(spacing: 12) {
            Button {
                if let prev = BondsStandardCoachStep(rawValue: step.rawValue - 1) {
                    step = prev
                }
            } label: {
                Text("BACK")
                    .font(.system(.caption, design: .monospaced, weight: .heavy))
                    .foregroundStyle(step == .staggeredV ? .gray : Theme.brandCyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.brandCyan.opacity(0.35)))
            }
            .disabled(step == .staggeredV)

            Button {
                if step == .drawingInCore {
                    dismiss()
                } else if let next = BondsStandardCoachStep(rawValue: step.rawValue + 1) {
                    step = next
                }
            } label: {
                Text(step == .drawingInCore ? "DONE" : "NEXT")
                    .font(.system(.caption, design: .monospaced, weight: .heavy))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(colors: [Theme.brandCyan, Theme.brandBlue], startPoint: .leading, endPoint: .trailing)
                            )
                    )
            }
        }
    }
}

// MARK: - SceneKit

private struct BondsStandardSceneContainer: UIViewRepresentable {
    var step: BondsStandardCoachStep
    var torqueProgress: Double
    var showKneeLeakage: Bool
    var onTuckPelvicDropPeak: (() -> Void)?

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = GameSceneFactory.buildDrawingInTutorialScene()
        v.autoenablesDefaultLighting = false
        v.backgroundColor = .clear
        v.antialiasingMode = .multisampling4X
        context.coordinator.scene = v.scene
        context.coordinator.onPelvicDropPeak = onTuckPelvicDropPeak
        context.coordinator.apply(step: step, torque01: torqueProgress, kneeLeak: showKneeLeakage)
        return v
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.onPelvicDropPeak = onTuckPelvicDropPeak
        context.coordinator.apply(step: step, torque01: torqueProgress, kneeLeak: showKneeLeakage)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var scene: SCNScene?
        var onPelvicDropPeak: (() -> Void)?
        private var previousCoachStep: BondsStandardCoachStep?

        func apply(step: BondsStandardCoachStep, torque01: Double, kneeLeak: Bool) {
            guard let scene else { return }
            guard let avatar = scene.rootNode.childNode(withName: "drawingAvatar", recursively: false) else { return }

            let ring = avatar.childNode(withName: "rLeg", recursively: true)?.childNode(withName: "overlayTorqueRing", recursively: false)
            let arrowUp = avatar.childNode(withName: "hip", recursively: true)?.childNode(withName: "overlayHipArrowUp", recursively: false)
            let arrowDown = avatar.childNode(withName: "hip", recursively: true)?.childNode(withName: "overlayHipArrowDown", recursively: false)
            let fascia = avatar.childNode(withName: "overlayFasciaBeam", recursively: true)
            let corset = avatar.childNode(withName: "overlayCorset", recursively: true)
            let kneePulse = avatar.childNode(withName: "kneeLeakagePulse", recursively: true)

            let prev = previousCoachStep
            let enteringTuck = step == .replaceDownTuck && prev != .replaceDownTuck
            let enteringIAP = step == .drawingInCore && prev != .drawingInCore
            let leavingIAP = prev == .drawingInCore && step != .drawingInCore

            switch step {
            case .staggeredV:
                ring?.isHidden = true
                arrowUp?.isHidden = true
                arrowDown?.isHidden = true
                fascia?.isHidden = true
                corset?.isHidden = true
                Self.paintRearLegIntegrity(avatar: avatar, torque01: 0.45)

            case .internalRotation:
                ring?.isHidden = false
                arrowUp?.isHidden = true
                arrowDown?.isHidden = true
                fascia?.isHidden = true
                corset?.isHidden = true
                Self.paintRearLegIntegrity(avatar: avatar, torque01: torque01)

            case .hipHike:
                ring?.isHidden = true
                arrowUp?.isHidden = false
                arrowDown?.isHidden = true
                fascia?.isHidden = false
                corset?.isHidden = true
                arrowUp?.opacity = 1
                Self.paintRearLegIntegrity(avatar: avatar, torque01: max(torque01, 0.75))

            case .replaceDownTuck:
                ring?.isHidden = true
                arrowUp?.isHidden = true
                arrowDown?.isHidden = false
                fascia?.isHidden = true
                corset?.isHidden = true
                arrowDown?.opacity = 1
                Self.paintRearLegIntegrity(avatar: avatar, torque01: 0.88)

                if enteringTuck, let hip = avatar.childNode(withName: "hip", recursively: true) {
                    hip.removeAction(forKey: "tuckDrop")
                    let peak = SCNAction.run { [weak self] _ in
                        self?.onPelvicDropPeak?()
                    }
                    let drop = SCNAction.sequence([
                        SCNAction.moveBy(x: 0, y: -0.07, z: 0, duration: 0.1),
                        peak,
                        SCNAction.moveBy(x: 0, y: 0.03, z: 0, duration: 0.18)
                    ])
                    drop.timingMode = .easeInEaseOut
                    hip.runAction(drop, forKey: "tuckDrop")
                }

            case .drawingInCore:
                ring?.isHidden = true
                arrowUp?.isHidden = true
                arrowDown?.isHidden = false
                fascia?.isHidden = true
                corset?.isHidden = false
                arrowDown?.opacity = 0.35
                Self.paintRearLegIntegrity(avatar: avatar, torque01: 0.92)

                if enteringIAP {
                    corset?.removeAction(forKey: "corsetSqueeze")
                    corset?.removeAction(forKey: "iapCorsetPulse")
                    corset?.scale = SCNVector3(1, 1, 1)
                    let iapPulse = SCNAction.repeatForever(
                        SCNAction.sequence([
                            SCNAction.scale(to: 1.14, duration: 0.62),
                            SCNAction.scale(to: 0.90, duration: 0.62)
                        ])
                    )
                    iapPulse.timingMode = .easeInEaseOut
                    corset?.runAction(iapPulse, forKey: "iapCorsetPulse")
                    if let torus = corset?.geometry as? SCNTorus,
                       let mat = torus.materials.first as? SCNMaterial {
                        mat.emission.contents = UIColor(red: 0.35, green: 1.0, blue: 0.85, alpha: 1).withAlphaComponent(0.55)
                    }
                }
            }

            if leavingIAP {
                corset?.removeAction(forKey: "iapCorsetPulse")
                corset?.scale = SCNVector3(1, 1, 1)
            }

            previousCoachStep = step

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
        }

        private static func paintRearLegIntegrity(avatar: SCNNode, torque01: Double) {
            guard let leg = avatar.childNode(withName: "rLeg", recursively: true),
                  let geo = leg.geometry as? SCNCapsule,
                  let mat = geo.materials.first as? SCNMaterial else { return }

            let stableBlue = UIColor(red: 0.2, green: 0.45, blue: 1.0, alpha: 1)
            let leakRed = UIColor(red: 1.0, green: 0.25, blue: 0.25, alpha: 1)
            let t = CGFloat(min(1, max(0, torque01)))
            let mixed = UIColor.mixCoach(leakRed, stableBlue, t)
            mat.emission.contents = mixed.withAlphaComponent(0.35 + 0.45 * CGFloat(torque01))
            mat.diffuse.contents = mixed.withAlphaComponent(0.85)
        }
    }
}

private extension UIColor {
    static func mixCoach(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
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

/// Breath-sync ring for IAP / drawing-in step (matches Drawing-In cadence).
private struct CoachBreathSyncRing: View {
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
                Text("IAP · drawing-in")
                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}
