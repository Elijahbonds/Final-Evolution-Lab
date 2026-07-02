import SwiftUI

/// Golden Era HUD + **proprioceptive pulses** + joint hotspots (Bonds Standard leakage glow).
struct MovementSnackOverlayView: View {
    let audit: BiomechanicsAudit
    /// Normalized neural focus / scan-derived focus — lower → slower, calming pulses.
    var neuralFocus01: Double
    var onHotspotTap: (JointType) -> Void

    @State private var pulsePhase: CGFloat = 0

    private var pulsePeriod: Double {
        let nf = min(1.0, max(0.05, neuralFocus01))
        return MovementSnackEngine.proprioceptivePulsePeriodSeconds(neuralFocus01: nf)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerX = w * 0.5
            let topY = h * 0.12

            ZStack {
                proprioceptiveField(size: geo.size)

                stickFigure(centerX: centerX, topY: topY, width: w, height: h)

                hotspot(joint: .hip, x: centerX, y: topY + h * 0.28, severity: severity(for: .hip))
                hotspot(joint: .knee, x: centerX, y: topY + h * 0.48, severity: severity(for: .knee))
                hotspot(joint: .ankle, x: centerX, y: topY + h * 0.68, severity: severity(for: .ankle))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            startPulseLoop()
        }
        .onChange(of: neuralFocus01) { _, _ in
            startPulseLoop()
        }
    }

    private func severity(for joint: JointType) -> Double {
        audit.kineticLeakageZones.first(where: { $0.joint == joint })?.severity ?? 0
    }

    private func startPulseLoop() {
        pulsePhase = 0
        withAnimation(.linear(duration: pulsePeriod).repeatForever(autoreverses: false)) {
            pulsePhase = 1
        }
    }

    private func proprioceptiveField(size: CGSize) -> some View {
        Canvas { ctx, _ in
            let cols = 12
            let rows = 10
            let cellW = size.width / CGFloat(cols)
            let cellH = size.height / CGFloat(rows)
            for r in 0..<rows {
                for c in 0..<cols {
                    let delay = Double(c + r) / Double(cols + rows)
                    let alpha = 0.04 + 0.14 * abs(sin(Double(pulsePhase) * .pi * 2 + delay * 6))
                    let rect = CGRect(x: CGFloat(c) * cellW, y: CGFloat(r) * cellH, width: cellW, height: cellH)
                    ctx.fill(
                        Path(ellipseIn: rect.insetBy(dx: cellW * 0.15, dy: cellH * 0.15)),
                        with: .color(Theme.brandCyan.opacity(alpha))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .blur(radius: 0.5)
    }

    private func stickFigure(centerX: CGFloat, topY: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        let torso = Path { p in
            p.move(to: CGPoint(x: centerX, y: topY + height * 0.22))
            p.addLine(to: CGPoint(x: centerX, y: topY + height * 0.52))
        }
        let legs = Path { p in
            p.move(to: CGPoint(x: centerX, y: topY + height * 0.52))
            p.addLine(to: CGPoint(x: centerX - width * 0.08, y: topY + height * 0.82))
            p.move(to: CGPoint(x: centerX, y: topY + height * 0.52))
            p.addLine(to: CGPoint(x: centerX + width * 0.08, y: topY + height * 0.82))
        }
        return ZStack {
            torso.stroke(Color.white.opacity(0.25), lineWidth: 3)
            legs.stroke(Color.white.opacity(0.22), lineWidth: 3)
        }
        .allowsHitTesting(false)
    }

    private func hotspot(joint: JointType, x: CGFloat, y: CGFloat, severity: Double) -> some View {
        let leaking = severity > 0
        let glow = leaking ? Theme.brandCyan : Theme.brandBlue.opacity(0.35)
        return ZStack {
            Circle()
                .stroke(glow.opacity(0.5 + 0.35 * CGFloat(severity)), lineWidth: 2)
                .frame(width: 44 + CGFloat(severity) * 22, height: 44 + CGFloat(severity) * 22)
                .scaleEffect(1.0 + 0.08 * pulsePhase)
                .opacity(0.35 + 0.45 * Double(pulsePhase))

            Circle()
                .fill(glow.opacity(0.25))
                .frame(width: 36, height: 36)

            Text(jointLabel(joint))
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
        }
        .position(x: x, y: y)
        .contentShape(Circle())
        .onTapGesture {
            onHotspotTap(joint)
        }
        .accessibilityLabel(Text("\(joint.displayName) hotspot"))
        .accessibilityHint(Text(leaking ? "Kinetic leakage flagged — tap for cue." : "Stable region."))
    }

    private func jointLabel(_ j: JointType) -> String {
        switch j {
        case .hip: return "HIP"
        case .knee: return "KNEE"
        case .ankle: return "ANK"
        }
    }
}
