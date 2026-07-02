import SwiftUI

struct LiveBiomechanicsOverlay: View {
    let audit: BiomechanicsAudit
    let isActive: Bool
    let currentAction: String
    var onLeakageDetected: ((JointType, Double) -> Void)?

    @State private var pulsePhase: Bool = false
    @State private var scanLineY: CGFloat = 0
    @State private var jointFlashAnkle: Bool = false
    @State private var jointFlashKnee: Bool = false
    @State private var jointFlashHip: Bool = false
    @State private var liveLeakageIntensity: Double = 0
    @State private var formQualityLabel: String = "ANALYZING"
    @State private var lastGameplayLeakageAt: [JointType: TimeInterval] = [:]

    private var ankleColor: Color {
        audit.ankleDorsiflexion.status == .optimal ? Theme.brandCyan :
        (audit.ankleDorsiflexion.status == .moderate ? .orange : .red)
    }

    private var kneeColor: Color {
        audit.kneeTracking.status == .optimal ? Theme.brandCyan :
        (audit.kneeTracking.status == .moderate ? .orange : .red)
    }

    private var hipColor: Color {
        audit.hipExtension.status == .optimal ? Theme.brandCyan :
        (audit.hipExtension.status == .moderate ? .orange : .red)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if isActive {
                    scanLine(height: geo.size.height)
                }

                skeletalWireframe(size: geo.size)
                liveJointFeedback(size: geo.size)

                if isActive && !currentAction.isEmpty {
                    actionFeedbackOverlay
                }

                if isActive {
                    formQualityIndicator
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                scanLineY = 1.0
            }
        }
        .onChange(of: currentAction) { _, newAction in
            if !newAction.isEmpty {
                triggerJointFlashes()
                evaluateLiveForm()
            }
        }
    }

    private func scanLine(height: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Theme.brandCyan.opacity(0.2), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 3)
            .offset(y: scanLineY * height - height / 2)
    }

    private func skeletalWireframe(size: CGSize) -> some View {
        let cx = size.width * 0.12
        let baseY = size.height * 0.15

        let headPos = CGPoint(x: cx, y: baseY)
        let shoulderPos = CGPoint(x: cx, y: baseY + 25)
        let hipPos = CGPoint(x: cx, y: baseY + 60)
        let leftKnee = CGPoint(x: cx - 12, y: baseY + 90)
        let rightKnee = CGPoint(x: cx + 12, y: baseY + 90)
        let leftAnkle = CGPoint(x: cx - 15, y: baseY + 118)
        let rightAnkle = CGPoint(x: cx + 15, y: baseY + 118)
        let leftElbow = CGPoint(x: cx - 25, y: baseY + 42)
        let rightElbow = CGPoint(x: cx + 25, y: baseY + 42)

        return ZStack {
            Path { path in
                path.move(to: shoulderPos)
                path.addLine(to: hipPos)

                path.move(to: shoulderPos)
                path.addLine(to: leftElbow)
                path.move(to: shoulderPos)
                path.addLine(to: rightElbow)

                path.move(to: hipPos)
                path.addLine(to: leftKnee)
                path.move(to: hipPos)
                path.addLine(to: rightKnee)

                path.move(to: leftKnee)
                path.addLine(to: leftAnkle)
                path.move(to: rightKnee)
                path.addLine(to: rightAnkle)
            }
            .stroke(
                Theme.brandCyan.opacity(isActive ? 0.25 : 0.1),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )

            Circle()
                .fill(Theme.brandCyan.opacity(0.2))
                .frame(width: 14, height: 14)
                .position(headPos)

            Circle()
                .fill(hipColor.opacity(jointFlashHip ? 0.9 : 0.4))
                .frame(width: jointFlashHip ? 10 : 7, height: jointFlashHip ? 10 : 7)
                .shadow(color: hipColor.opacity(jointFlashHip ? 0.6 : 0), radius: 4)
                .position(hipPos)

            ForEach([leftKnee, rightKnee], id: \.x) { pos in
                Circle()
                    .fill(kneeColor.opacity(jointFlashKnee ? 0.9 : 0.4))
                    .frame(width: jointFlashKnee ? 10 : 7, height: jointFlashKnee ? 10 : 7)
                    .shadow(color: kneeColor.opacity(jointFlashKnee ? 0.6 : 0), radius: 4)
                    .position(pos)
            }

            ForEach([leftAnkle, rightAnkle], id: \.x) { pos in
                Circle()
                    .fill(ankleColor.opacity(jointFlashAnkle ? 0.9 : 0.4))
                    .frame(width: jointFlashAnkle ? 10 : 7, height: jointFlashAnkle ? 10 : 7)
                    .shadow(color: ankleColor.opacity(jointFlashAnkle ? 0.6 : 0), radius: 4)
                    .position(pos)
            }
        }
    }

    private func liveJointFeedback(size: CGSize) -> some View {
        let centerX = size.width * 0.12
        let baseY = size.height * 0.3

        return VStack(alignment: .leading, spacing: 0) {
            jointPill(
                label: "HIP",
                score: audit.hipExtension,
                color: hipColor,
                isFlashing: jointFlashHip
            )

            jointPill(
                label: "KNEE",
                score: audit.kneeTracking,
                color: kneeColor,
                isFlashing: jointFlashKnee
            )
            .padding(.top, 8)

            jointPill(
                label: "ANKLE",
                score: audit.ankleDorsiflexion,
                color: ankleColor,
                isFlashing: jointFlashAnkle
            )
            .padding(.top, 8)
        }
        .position(x: centerX + 40, y: baseY)
    }

    private func jointPill(label: String, score: JointScore, color: Color, isFlashing: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .scaleEffect(isFlashing ? 1.8 : (pulsePhase ? 1.2 : 0.8))
                .shadow(color: color.opacity(isFlashing ? 0.8 : 0.3), radius: isFlashing ? 6 : 2)

            Text(label)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .foregroundStyle(color)
                .tracking(1)

            Text(score.status.label)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(color.opacity(0.7))

            if isFlashing && score.status == .deficit {
                Image(systemName: "arrow.down.right")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Theme.deepBlack.opacity(0.7))
        .clipShape(.rect(cornerRadius: 4))
    }

    @ViewBuilder
    private var actionFeedbackOverlay: some View {
        let hasLeakage = !audit.kineticLeakageZones.isEmpty

        if hasLeakage {
            VStack(spacing: 2) {
                ForEach(audit.kineticLeakageZones.prefix(2)) { zone in
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.red)

                        Text("\(zone.joint.displayName.uppercased()) LEAK")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundStyle(.red.opacity(0.8))

                        Text(String(format: "%.0f%%", zone.severity * 100))
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 3))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 8)
            .padding(.top, 60)
        }
    }

    private var formQualityIndicator: some View {
        VStack(spacing: 2) {
            Text("FORM")
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)

            Text(formQualityLabel)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(formLabelColor)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(formLabelColor)
                        .frame(width: geo.size.width * max(0, min(1, 1.0 - liveLeakageIntensity)))
                }
            }
            .frame(width: 40, height: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.trailing, 10)
        .padding(.top, 10)
    }

    private var formLabelColor: Color {
        if liveLeakageIntensity < 0.2 { return Theme.brandCyan }
        if liveLeakageIntensity < 0.5 { return .orange }
        return .red
    }

    private func evaluateLiveForm() {
        let leakage = audit.leakagePercentage / 100.0
        liveLeakageIntensity = min(1, max(0, leakage))

        if liveLeakageIntensity < 0.15 {
            formQualityLabel = "OPTIMAL"
        } else if liveLeakageIntensity < 0.35 {
            formQualityLabel = "PRIMED"
        } else if liveLeakageIntensity < 0.6 {
            formQualityLabel = "MODERATE"
        } else {
            formQualityLabel = "LEAKING"
        }

        let poseConfidence01 = min(
            1,
            max(
                0,
                (audit.ankleDorsiflexion.value + audit.kneeTracking.value + audit.hipExtension.value) / 300.0
            )
        )
        let cooldown: TimeInterval = 1.15
        let now = Date().timeIntervalSince1970

        guard !currentAction.isEmpty else { return }
        guard poseConfidence01 < 0.68 else { return }

        for zone in audit.kineticLeakageZones {
            guard zone.severity >= 0.38 else { continue }
            if let last = lastGameplayLeakageAt[zone.joint], now - last < cooldown { continue }
            lastGameplayLeakageAt[zone.joint] = now
            onLeakageDetected?(zone.joint, zone.severity)
        }
    }

    private func triggerJointFlashes() {
        if audit.ankleDorsiflexion.status == .deficit {
            withAnimation(.easeOut(duration: 0.15)) { jointFlashAnkle = true }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(.easeIn(duration: 0.3)) { jointFlashAnkle = false }
            }
        }
        if audit.kneeTracking.status == .deficit {
            withAnimation(.easeOut(duration: 0.15)) { jointFlashKnee = true }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(.easeIn(duration: 0.3)) { jointFlashKnee = false }
            }
        }
        if audit.hipExtension.status == .deficit {
            withAnimation(.easeOut(duration: 0.15)) { jointFlashHip = true }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                withAnimation(.easeIn(duration: 0.3)) { jointFlashHip = false }
            }
        }
    }
}
