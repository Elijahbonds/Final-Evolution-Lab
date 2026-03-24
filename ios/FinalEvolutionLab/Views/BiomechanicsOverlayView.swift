import SwiftUI

struct BiomechanicsOverlayView: View {
    let audit: BiomechanicsAudit
    @State private var pulsePhase: Bool = false
    @State private var scanLineY: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                scanLine(height: geo.size.height)
                skeletonOverlay(size: geo.size)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulsePhase = true
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                scanLineY = 1.0
            }
        }
    }

    private func scanLine(height: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, Theme.brandCyan.opacity(0.3), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 4)
            .offset(y: scanLineY * height - height / 2)
            .allowsHitTesting(false)
    }

    private func skeletonOverlay(size: CGSize) -> some View {
        let centerX = size.width * 0.5
        let topY = size.height * 0.15

        return ZStack {
            jointIndicator(
                x: centerX, y: topY + size.height * 0.65,
                joint: .ankle, score: audit.ankleDorsiflexion
            )

            jointIndicator(
                x: centerX, y: topY + size.height * 0.45,
                joint: .knee, score: audit.kneeTracking
            )

            jointIndicator(
                x: centerX, y: topY + size.height * 0.28,
                joint: .hip, score: audit.hipExtension
            )

            ForEach(audit.kineticLeakageZones) { zone in
                leakageIndicator(zone: zone, size: size, topY: topY, centerX: centerX)
            }
        }
    }

    private func jointIndicator(x: CGFloat, y: CGFloat, joint: JointType, score: JointScore) -> some View {
        let color = statusColor(score.status)
        return ZStack {
            Circle()
                .fill(color.opacity(pulsePhase ? 0.3 : 0.1))
                .frame(width: 32, height: 32)

            Circle()
                .stroke(color.opacity(0.6), lineWidth: 2)
                .frame(width: 32, height: 32)

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .position(x: x, y: y)
        .overlay(alignment: .trailing) {
            VStack(alignment: .leading, spacing: 1) {
                Text(joint.displayName.uppercased())
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundStyle(color)
                    .tracking(1)

                Text(score.status.label)
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundStyle(color.opacity(0.7))

                Text(String(format: "%.0f", score.value))
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.deepBlack.opacity(0.8))
            .clipShape(.rect(cornerRadius: 4))
            .position(x: x + 50, y: y)
        }
    }

    private func leakageIndicator(zone: LeakageZone, size: CGSize, topY: CGFloat, centerX: CGFloat) -> some View {
        let y: CGFloat
        switch zone.joint {
        case .ankle: y = topY + size.height * 0.65
        case .knee: y = topY + size.height * 0.45
        case .hip: y = topY + size.height * 0.28
        }

        return ZStack {
            Circle()
                .stroke(Color.red.opacity(pulsePhase ? 0.5 : 0.2), lineWidth: 1.5)
                .frame(width: 44 + CGFloat(zone.severity) * 20, height: 44 + CGFloat(zone.severity) * 20)

            if zone.severity > 0.3 {
                Circle()
                    .stroke(Color.red.opacity(0.15), lineWidth: 1)
                    .frame(width: 60 + CGFloat(zone.severity) * 20, height: 60 + CGFloat(zone.severity) * 20)
            }
        }
        .position(x: centerX, y: y)
    }

    private func statusColor(_ status: JointStatus) -> Color {
        switch status {
        case .optimal: Theme.brandCyan
        case .moderate: .orange
        case .deficit: .red
        }
    }
}

struct BiomechanicsDashboardCard: View {
    let audit: BiomechanicsAudit

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BIOMECHANICS AUDIT")
                        .font(.system(.caption2, design: .monospaced, weight: .bold))
                        .foregroundStyle(Theme.brandCyan)
                        .tracking(2)

                    Text(audit.overallGrade.rawValue)
                        .font(.system(.title3, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("KINETIC LEAKAGE")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)

                    Text(String(format: "%.0f%%", audit.leakagePercentage))
                        .font(.system(.title2, design: .monospaced, weight: .black))
                        .foregroundStyle(audit.leakagePercentage > 30 ? .red : (audit.leakagePercentage > 15 ? .orange : Theme.brandCyan))
                }
            }

            HStack(spacing: 10) {
                JointScoreCell(label: "ANKLE", score: audit.ankleDorsiflexion)
                JointScoreCell(label: "KNEE", score: audit.kneeTracking)
                JointScoreCell(label: "HIP", score: audit.hipExtension)
            }

            if !audit.kineticLeakageZones.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LEAKAGE ZONES")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .tracking(1)

                    ForEach(audit.kineticLeakageZones) { zone in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(zone.severity > 0.3 ? Color.red : .orange)
                                .frame(width: 6, height: 6)

                            Text(zone.description)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 9))
                Text(audit.auditDate, style: .relative)
                    .font(.system(size: 10, design: .monospaced))
            }
            .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.brandCyan.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

struct JointScoreCell: View {
    let label: String
    let score: JointScore

    private var statusColor: Color {
        switch score.status {
        case .optimal: Theme.brandCyan
        case .moderate: .orange
        case .deficit: .red
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(statusColor.opacity(0.2), lineWidth: 3)
                    .frame(width: 44, height: 44)

                Circle()
                    .trim(from: 0, to: score.value / 100)
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                Text(String(format: "%.0f", score.value))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(1)

            Text(score.status.label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.1))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
    }
}
